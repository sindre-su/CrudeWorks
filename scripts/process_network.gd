class_name ProcessNetwork
extends RefCounted

const Catalog = preload("res://scripts/equipment_catalog.gd")

signal topology_changed

var units: Dictionary = {}
var connections: Array[Dictionary] = []


func register_unit(unit_id: String, equipment_type: String, display_name := "") -> Dictionary:
	if unit_id.is_empty() or not Catalog.is_valid(equipment_type):
		return _result(false, "Ukjent prosessutstyr kan ikke registreres.")
	if units.has(unit_id):
		return _result(false, "%s finnes allerede i prosessnettet." % unit_id)
	units[unit_id] = {
		"type": equipment_type,
		"name": display_name if not display_name.is_empty() else unit_id,
	}
	topology_changed.emit()
	return _result(true, "%s er registrert." % _unit_name(unit_id))


func unregister_unit(unit_id: String) -> void:
	var changed := units.has(unit_id)
	units.erase(unit_id)
	for index in range(connections.size() - 1, -1, -1):
		var edge := connections[index]
		if edge["from_unit"] == unit_id or edge["to_unit"] == unit_id:
			connections.remove_at(index)
			changed = true
	if changed:
		topology_changed.emit()


func has_unit(unit_id: String) -> bool:
	return units.has(unit_id)


func try_connect(
	from_unit_id: String,
	from_port_id: String,
	to_unit_id: String,
	to_port_id: String
) -> Dictionary:
	if not units.has(from_unit_id) or not units.has(to_unit_id):
		return _result(false, "Begge maskinene må være plassert før de kan kobles.")
	if from_unit_id == to_unit_id:
		return _result(false, "En maskin kan ikke kobles til seg selv.")

	var from_type: String = units[from_unit_id]["type"]
	var to_type: String = units[to_unit_id]["type"]
	var from_port := Catalog.port_definition(from_type, from_port_id)
	var to_port := Catalog.port_definition(to_type, to_port_id)
	if from_port.is_empty():
		return _result(false, "%s har ikke porten %s." % [_unit_name(from_unit_id), from_port_id])
	if to_port.is_empty():
		return _result(false, "%s har ikke porten %s." % [_unit_name(to_unit_id), to_port_id])
	if from_port["kind"] != "output" or to_port["kind"] != "input":
		return _result(false, "Koble alltid fra et oransje OUT til et blått IN.")
	if _find_exact_edge(from_unit_id, from_port_id, to_unit_id, to_port_id) >= 0:
		return _result(false, "Disse portene er allerede koblet sammen.")
	if _find_outgoing_edge(from_unit_id, from_port_id) >= 0:
		return _result(false, "%s %s er allerede koblet." % [
			_unit_name(from_unit_id),
			from_port["label"],
		])
	if _find_incoming_edge(to_unit_id, to_port_id) >= 0:
		return _result(false, "%s sitt innløp er allerede koblet." % _unit_name(to_unit_id))
	if not _materials_are_compatible(from_port["material"], to_port["material"]):
		return _result(false, "%s kan ikke ta imot %s." % [
			_unit_name(to_unit_id),
			from_port["label"].to_lower(),
		])
	if not Catalog.process_order_allows(from_type, to_type):
		if from_type == "pump" and to_type == "heater":
			return _result(false, "Den manuelle ventilen må stå mellom pumpen og varmeenheten.")
		return _result(false, "%s kan ikke stå før %s i prosessen." % [
			_unit_name(from_unit_id),
			_unit_name(to_unit_id),
		])
	if _would_create_cycle(from_unit_id, to_unit_id):
		return _result(false, "Denne koblingen ville laget en ulovlig prosessløkke.")

	var new_edge := {
		"from_unit": from_unit_id,
		"from_port": from_port_id,
		"to_unit": to_unit_id,
		"to_port": to_port_id,
	}
	connections.append(new_edge)
	topology_changed.emit()
	return _result(true, "%s %s er koblet til %s IN." % [
		_unit_name(from_unit_id),
		from_port["label"],
		_unit_name(to_unit_id),
	])


func disconnect_ports(
	from_unit_id: String,
	from_port_id: String,
	to_unit_id: String,
	to_port_id: String
) -> bool:
	var index := _find_exact_edge(from_unit_id, from_port_id, to_unit_id, to_port_id)
	if index < 0:
		return false
	connections.remove_at(index)
	topology_changed.emit()
	return true


func connection_count() -> int:
	return connections.size()


func validate_configuration() -> Dictionary:
	var routes := find_complete_routes()
	if not routes.is_empty():
		return {
			"valid": true,
			"message": "%d prosesslinje%s er gyldig%s." % [
				routes.size(), "r" if routes.size() > 1 else "",
				"e" if routes.size() > 1 else "",
			],
			"route": routes[0],
			"routes": routes,
		}
	if units.is_empty():
		return _validation_result("Plasser utstyr før du validerer prosesslinjen.")

	var feed_edge := _find_first_type_edge("tank", "pump")
	if feed_edge.is_empty():
		return _validation_result("Koble en råoljetank OUT til pumpens IN.")
	var pump_id: String = feed_edge["to_unit"]
	var pump_edge := outgoing_edge(pump_id, "output")
	if pump_edge.is_empty():
		return _validation_result("%s sitt utløp må kobles til en manuell ventil." % _unit_name(pump_id))
	var valve_id: String = pump_edge["to_unit"]
	var valve_edge := outgoing_edge(valve_id, "output")
	if valve_edge.is_empty():
		return _validation_result("%s sitt utløp må kobles til varmeenheten." % _unit_name(valve_id))
	var heater_id: String = valve_edge["to_unit"]
	var heater_edge := outgoing_edge(heater_id, "output")
	if heater_edge.is_empty():
		return _validation_result("%s sitt utløp er ikke koblet til destillasjonskolonnen." % _unit_name(heater_id))
	var column_id: String = heater_edge["to_unit"]
	for product_port in ["light", "diesel", "heavy"]:
		if outgoing_edge(column_id, product_port).is_empty():
			var label: String = Catalog.port_definition("column", product_port)["label"]
			return _validation_result("Kolonnens %s-utløp trenger en produkttank." % label)
	var diesel_edge := outgoing_edge(column_id, "diesel")
	if _unit_type(diesel_edge["to_unit"]) == "treatment" and outgoing_edge(diesel_edge["to_unit"], "output").is_empty():
		return _validation_result("Dieselbehandlerens utløp trenger en dieseltank.")
	return _validation_result("Prosesslinjen er ikke komplett.")


func find_complete_route() -> Dictionary:
	var routes := find_complete_routes()
	return routes[0] if not routes.is_empty() else {}


func find_route_for_unit(unit_id: String) -> Dictionary:
	for route in find_complete_routes():
		if unit_id in [route["source"], route["pump"], route["valve"], route["heater"], route["column"], route.get("treatment", "")]:
			return route
		for product_id in route["products"]:
			if route["products"][product_id] == unit_id:
				return route
	return {}


func find_complete_routes() -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for edge in connections:
		if _unit_type(edge["from_unit"]) != "tank" or _unit_type(edge["to_unit"]) != "pump":
			continue
		var source_id: String = edge["from_unit"]
		var pump_id: String = edge["to_unit"]
		var pump_edge := outgoing_edge(pump_id, "output")
		if pump_edge.is_empty() or _unit_type(pump_edge["to_unit"]) != "valve":
			continue
		var valve_id: String = pump_edge["to_unit"]
		var valve_edge := outgoing_edge(valve_id, "output")
		if valve_edge.is_empty() or _unit_type(valve_edge["to_unit"]) != "heater":
			continue
		var heater_id: String = valve_edge["to_unit"]
		var heater_edge := outgoing_edge(heater_id, "output")
		if heater_edge.is_empty() or _unit_type(heater_edge["to_unit"]) != "column":
			continue
		var column_id: String = heater_edge["to_unit"]
		var products := {}
		var complete := true
		var treatment_id := ""
		for product_port in ["light", "diesel", "heavy"]:
			var product_edge := outgoing_edge(column_id, product_port)
			if product_edge.is_empty():
				complete = false
				break
			var destination_type := _unit_type(product_edge["to_unit"])
			if product_port == "diesel" and destination_type == "treatment":
				treatment_id = product_edge["to_unit"]
				var treatment_edge := outgoing_edge(treatment_id, "output")
				if treatment_edge.is_empty() or _unit_type(treatment_edge["to_unit"]) != "tank":
					complete = false
					break
				products[product_port] = treatment_edge["to_unit"]
			elif destination_type == "tank":
				products[product_port] = product_edge["to_unit"]
			else:
				complete = false
				break
		if complete:
			routes.append({
				"source": source_id,
				"pump": pump_id,
				"valve": valve_id,
				"heater": heater_id,
				"column": column_id,
				"treatment": treatment_id,
				"products": products,
			})
	return routes


func outgoing_edge(unit_id: String, port_id: String) -> Dictionary:
	var index := _find_outgoing_edge(unit_id, port_id)
	return connections[index] if index >= 0 else {}


func incoming_edge(unit_id: String, port_id: String) -> Dictionary:
	var index := _find_incoming_edge(unit_id, port_id)
	return connections[index] if index >= 0 else {}


func _find_first_type_edge(from_type: String, to_type: String) -> Dictionary:
	for edge in connections:
		if _unit_type(edge["from_unit"]) == from_type and _unit_type(edge["to_unit"]) == to_type:
			return edge
	return {}


func _find_exact_edge(
	from_unit_id: String,
	from_port_id: String,
	to_unit_id: String,
	to_port_id: String
) -> int:
	for index in connections.size():
		var edge := connections[index]
		if (
			edge["from_unit"] == from_unit_id
			and edge["from_port"] == from_port_id
			and edge["to_unit"] == to_unit_id
			and edge["to_port"] == to_port_id
		):
			return index
	return -1


func _find_outgoing_edge(unit_id: String, port_id: String) -> int:
	for index in connections.size():
		var edge := connections[index]
		if edge["from_unit"] == unit_id and edge["from_port"] == port_id:
			return index
	return -1


func _find_incoming_edge(unit_id: String, port_id: String) -> int:
	for index in connections.size():
		var edge := connections[index]
		if edge["to_unit"] == unit_id and edge["to_port"] == port_id:
			return index
	return -1


func _would_create_cycle(from_unit_id: String, to_unit_id: String) -> bool:
	var pending: Array[String] = [to_unit_id]
	var visited := {}
	while not pending.is_empty():
		var current: String = pending.pop_back()
		if current == from_unit_id:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for edge in connections:
			if edge["from_unit"] == current:
				pending.append(edge["to_unit"])
	return false


func _materials_are_compatible(from_material: String, to_material: String) -> bool:
	return from_material == "any" or to_material == "any" or from_material == to_material


func _unit_name(unit_id: String) -> String:
	return units.get(unit_id, {}).get("name", unit_id)


func _unit_type(unit_id: String) -> String:
	return units.get(unit_id, {}).get("type", "")


func _validation_result(message: String) -> Dictionary:
	return {"valid": false, "message": message, "route": {}}


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
