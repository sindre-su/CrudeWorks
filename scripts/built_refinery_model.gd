class_name BuiltRefineryModel
extends RefCounted

const ProcessNetworkScript = preload("res://scripts/process_network.gd")

const AMBIENT_TEMPERATURE_C := 20.0
const TANK_CAPACITY_L := 1000.0
const BATCH_VOLUME_L := 1000.0
const CRUDE_BATCH_COST := 300
const PUMP_CAPACITY_LPS := 10.0
const DIESEL_TARGET_L := 200.0
const APPROVED_QUALITY_PERCENT := 90.0
const DIESEL_PRICE_PER_L := 8.0

var network
var equipment: Dictionary = {}
var commissioning_batch_available := true
var actual_flow_lps := 0.0
var last_status := "Bygg og valider prosesslinjen."


func _init(p_network = null) -> void:
	network = p_network if p_network != null else ProcessNetworkScript.new()


func register_unit(unit_id: String, equipment_type: String, display_name := "") -> Dictionary:
	var graph_result: Dictionary = network.register_unit(unit_id, equipment_type, display_name)
	if not graph_result["ok"]:
		return graph_result
	var state := {
		"type": equipment_type,
		"name": display_name if not display_name.is_empty() else unit_id,
	}
	match equipment_type:
		"tank":
			state.merge({
				"capacity_l": TANK_CAPACITY_L,
				"volume_l": 0.0,
				"contents": "empty",
				"temperature_c": AMBIENT_TEMPERATURE_C,
				"quality_percent": 0.0,
			})
		"pump":
			state.merge({
				"running": false,
				"max_flow_lps": PUMP_CAPACITY_LPS,
				"actual_flow_lps": 0.0,
			})
		"heater":
			state.merge({
				"setpoint_c": 0.0,
				"temperature_c": AMBIENT_TEMPERATURE_C,
			})
		"column":
			state["processed_total_l"] = 0.0
	equipment[unit_id] = state
	return {"ok": true, "message": "%s er klar for tilkobling." % state["name"]}


func unregister_unit(unit_id: String) -> void:
	equipment.erase(unit_id)
	network.unregister_unit(unit_id)
	actual_flow_lps = 0.0
	last_status = network.validate_configuration()["message"]


func can_remove(unit_id: String) -> Dictionary:
	if not equipment.has(unit_id):
		return _result(false, "Utstyret er ikke registrert.")
	var state: Dictionary = equipment[unit_id]
	if state["type"] == "tank" and state["volume_l"] > 0.001:
		return _result(false, "Tøm %s før den fjernes." % state["name"])
	if state["type"] == "pump" and state["running"]:
		return _result(false, "Stopp %s før den fjernes." % state["name"])
	if actual_flow_lps > 0.01:
		return _result(false, "Stopp prosessen før utstyr fjernes.")
	return _result(true, "%s kan fjernes." % state["name"])


func interact(unit_id: String, can_pay_for_crude := false) -> Dictionary:
	if not equipment.has(unit_id):
		return _result(false, "Ukjent bygd utstyr.")
	match equipment[unit_id]["type"]:
		"pump":
			return _toggle_pump(unit_id)
		"heater":
			return _cycle_heater(unit_id)
		"tank":
			if _is_route_source(unit_id) and equipment[unit_id]["volume_l"] <= 0.001:
				return load_crude_batch(unit_id, can_pay_for_crude)
	return _result(true, inspect_unit(unit_id))


func load_crude_batch(unit_id: String, paid_batch := false) -> Dictionary:
	if not _is_route_source(unit_id):
		return _result(false, "Tanken må være koblet som råoljekilde i en komplett prosesslinje.")
	var tank: Dictionary = equipment[unit_id]
	if tank["volume_l"] > 0.001:
		return _result(false, "%s er ikke tom." % tank["name"])
	var charge := 0
	if commissioning_batch_available:
		commissioning_batch_available = false
	elif paid_batch:
		charge = CRUDE_BATCH_COST
	else:
		return _result(false, "Ny råoljebatch koster %d kr." % CRUDE_BATCH_COST)
	tank["volume_l"] = BATCH_VOLUME_L
	tank["contents"] = "crude"
	tank["temperature_c"] = AMBIENT_TEMPERATURE_C
	tank["quality_percent"] = 0.0
	last_status = "1 000 L råolje er lastet. Varm opp anlegget før pumpen startes."
	var message := "Commissioning batch lastet gratis: 1 000 L råolje."
	if charge > 0:
		message = "Ny råoljebatch lastet for %d kr." % charge
	return {"ok": true, "message": message, "charge": charge}


func tick(delta: float) -> void:
	_update_heaters(delta)
	actual_flow_lps = 0.0
	for state in equipment.values():
		if state["type"] == "pump":
			state["actual_flow_lps"] = 0.0

	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		last_status = validation["message"]
		return
	var route: Dictionary = validation["route"]
	var pump: Dictionary = equipment[route["pump"]]
	if not pump["running"]:
		last_status = "Prosesslinjen er klar. Start pumpen for å produsere."
		return
	var source: Dictionary = equipment[route["source"]]
	if source["volume_l"] <= 0.001 or source["contents"] != "crude":
		pump["running"] = false
		last_status = "LOW FLOW — råoljetanken er tom."
		return

	var heater: Dictionary = equipment[route["heater"]]
	var fractions := fractions_for_temperature(heater["temperature_c"])
	var safe_input := minf(source["volume_l"], pump["max_flow_lps"] * delta)
	var products: Dictionary = route["products"]
	for product_name in ["light", "diesel", "heavy"]:
		var tank: Dictionary = equipment[products[product_name]]
		if tank["contents"] != "empty" and tank["contents"] != product_name:
			last_status = "%s inneholder allerede et annet produkt." % tank["name"]
			return
		var remaining: float = tank["capacity_l"] - tank["volume_l"]
		var fraction := _fraction_value(fractions, product_name)
		safe_input = minf(safe_input, remaining / fraction)
	if safe_input <= 0.0001:
		last_status = _full_product_message(route)
		return

	_process_input(route, safe_input, fractions, heater["temperature_c"])
	actual_flow_lps = safe_input / delta if delta > 0.0 else 0.0
	pump["actual_flow_lps"] = actual_flow_lps
	last_status = "Produksjon %.1f L/s ved %.0f °C." % [actual_flow_lps, heater["temperature_c"]]
	if source["volume_l"] <= 0.001:
		source["volume_l"] = 0.0
		source["contents"] = "empty"
		pump["running"] = false
		last_status = "Batch ferdig. Kontroller dieselkvaliteten ved LAB / SALG."


func sell_diesel() -> Dictionary:
	var diesel_tanks := _tanks_containing("diesel")
	var total_volume := 0.0
	var weighted_quality := 0.0
	for tank in diesel_tanks:
		total_volume += tank["volume_l"]
		weighted_quality += tank["volume_l"] * tank["quality_percent"]
	if total_volume < DIESEL_TARGET_L:
		return _result(false, "For lite bygd diesel: %.0f / %.0f liter." % [total_volume, DIESEL_TARGET_L])
	var quality := weighted_quality / total_volume
	if quality < APPROVED_QUALITY_PERCENT:
		return _result(false, "OFF-SPEC: Bygd diesel er %.1f %%, minst %.0f %% kreves." % [quality, APPROVED_QUALITY_PERCENT])
	var revenue := int(round(total_volume * DIESEL_PRICE_PER_L))
	for tank in diesel_tanks:
		tank["volume_l"] = 0.0
		tank["contents"] = "empty"
		tank["quality_percent"] = 0.0
	last_status = "%.0f L bygd diesel solgt for %d kr." % [total_volume, revenue]
	return {
		"ok": true,
		"message": last_status,
		"revenue": revenue,
		"sold_volume_l": total_volume,
	}


func diesel_is_approved() -> bool:
	var total_volume := 0.0
	var weighted_quality := 0.0
	for tank in _tanks_containing("diesel"):
		total_volume += tank["volume_l"]
		weighted_quality += tank["volume_l"] * tank["quality_percent"]
	return (
		total_volume >= DIESEL_TARGET_L
		and weighted_quality / total_volume >= APPROVED_QUALITY_PERCENT
	)


func inspect_unit(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return "Ukjent bygd utstyr."
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"tank":
			var contents_name := _contents_name(state["contents"])
			var details := "%s: %.0f / %.0f L, %.0f °C" % [
				contents_name,
				state["volume_l"],
				state["capacity_l"],
				state["temperature_c"],
			]
			if state["contents"] == "diesel":
				details += ", kvalitet %.1f %%" % state["quality_percent"]
			return details + "."
		"pump":
			return "Pumpe %s, faktisk flow %.1f L/s." % [
				"PÅ" if state["running"] else "AV",
				state["actual_flow_lps"],
			]
		"heater":
			return "Varme %.0f °C, mål %.0f °C." % [state["temperature_c"], state["setpoint_c"]]
		"column":
			return "Destillasjon: %.0f L totalt prosessert." % state["processed_total_l"]
	return "Bygd prosessutstyr."


func unit_status(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return "IKKE REGISTRERT"
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"tank":
			var status := "%.0f / %.0f L  |  %s" % [
				state["volume_l"],
				state["capacity_l"],
				_contents_name(state["contents"]),
			]
			if state["contents"] == "diesel":
				status += "  |  %.1f %%" % state["quality_percent"]
			return status
		"pump":
			return "%s  |  %.1f L/s" % ["PÅ" if state["running"] else "AV", state["actual_flow_lps"]]
		"heater":
			return "%.0f °C  |  mål %.0f °C" % [state["temperature_c"], state["setpoint_c"]]
		"column":
			return "%.0f L prosessert" % state["processed_total_l"]
	return "KLAR"


func summary_text() -> String:
	var validation: Dictionary = network.validate_configuration()
	var diesel_volume := 0.0
	var diesel_quality := 0.0
	for tank in _tanks_containing("diesel"):
		diesel_quality += tank["volume_l"] * tank["quality_percent"]
		diesel_volume += tank["volume_l"]
	if diesel_volume > 0.0:
		diesel_quality /= diesel_volume
	return (
		"CRUDEWORKS — BYGGEOMRÅDE 02\n\n"
		+ "Nettverk      %s\n" % ("GYLDIG" if validation["valid"] else "UFULLSTENDIG")
		+ "Flow          %6.1f L/s\n" % actual_flow_lps
		+ "Diesel        %6.0f L\n" % diesel_volume
		+ "Kvalitet      %6.1f %%\n\n" % diesel_quality
		+ last_status
	)


func fractions_for_temperature(temperature_c: float) -> Vector3:
	if temperature_c < 170.0:
		return Vector3(0.08, 0.12, 0.80)
	if temperature_c < 185.0:
		return Vector3(0.20, 0.25, 0.55)
	if temperature_c <= 215.0:
		return Vector3(0.30, 0.35, 0.35)
	if temperature_c <= 225.0:
		return Vector3(0.40, 0.30, 0.30)
	return Vector3(0.55, 0.20, 0.25)


func _toggle_pump(unit_id: String) -> Dictionary:
	var pump: Dictionary = equipment[unit_id]
	if not pump["running"]:
		var validation: Dictionary = network.validate_configuration()
		if not validation["valid"]:
			return _result(false, validation["message"])
		pump["running"] = not pump["running"]
	last_status = "%s er %s." % [pump["name"], "startet" if pump["running"] else "stoppet"]
	return _result(true, last_status)


func _cycle_heater(unit_id: String) -> Dictionary:
	var heater: Dictionary = equipment[unit_id]
	if heater["setpoint_c"] < 1.0:
		heater["setpoint_c"] = 170.0
	elif heater["setpoint_c"] < 180.0:
		heater["setpoint_c"] = 200.0
	elif heater["setpoint_c"] < 210.0:
		heater["setpoint_c"] = 230.0
	else:
		heater["setpoint_c"] = 0.0
	last_status = "Temperaturmål satt til %.0f °C." % heater["setpoint_c"] if heater["setpoint_c"] > 0.0 else "Varmeenheten er slått av."
	return _result(true, last_status)


func _update_heaters(delta: float) -> void:
	for state in equipment.values():
		if state["type"] != "heater":
			continue
		var target: float = state["setpoint_c"] if state["setpoint_c"] > 0.0 else AMBIENT_TEMPERATURE_C
		var rate := 7.0 if actual_flow_lps > 0.01 else 18.0
		state["temperature_c"] = move_toward(state["temperature_c"], target, rate * delta)


func _process_input(route: Dictionary, input_l: float, fractions: Vector3, temperature_c: float) -> void:
	var source: Dictionary = equipment[route["source"]]
	source["volume_l"] -= input_l
	var diesel_quality := _diesel_quality(temperature_c, PUMP_CAPACITY_LPS)
	for product_name in ["light", "diesel", "heavy"]:
		var product_l := input_l * _fraction_value(fractions, product_name)
		var tank: Dictionary = equipment[route["products"][product_name]]
		if product_name == "diesel":
			var quality_total: float = tank["quality_percent"] * tank["volume_l"]
			quality_total += diesel_quality * product_l
			tank["quality_percent"] = quality_total / (tank["volume_l"] + product_l)
		tank["volume_l"] += product_l
		tank["contents"] = product_name
		tank["temperature_c"] = temperature_c
	equipment[route["column"]]["processed_total_l"] += input_l


func _diesel_quality(temperature_c: float, current_flow_lps: float) -> float:
	var temperature_penalty := absf(temperature_c - 200.0) * 1.15
	var flow_penalty := maxf(current_flow_lps - PUMP_CAPACITY_LPS, 0.0) * 2.0
	return clampf(100.0 - temperature_penalty - flow_penalty, 0.0, 100.0)


func _fraction_value(fractions: Vector3, product_name: String) -> float:
	match product_name:
		"light":
			return fractions.x
		"diesel":
			return fractions.y
		_:
			return fractions.z


func _full_product_message(route: Dictionary) -> String:
	for product_name in ["light", "diesel", "heavy"]:
		var tank: Dictionary = equipment[route["products"][product_name]]
		if tank["volume_l"] >= tank["capacity_l"] - 0.001:
			return "%s er full. Produksjonen er stoppet." % tank["name"]
	return "Ingen ledig produktkapasitet."


func _is_route_source(unit_id: String) -> bool:
	var route: Dictionary = network.find_complete_route()
	return not route.is_empty() and route["source"] == unit_id


func _tanks_containing(contents: String) -> Array:
	var tanks := []
	for state in equipment.values():
		if state["type"] == "tank" and state["contents"] == contents and state["volume_l"] > 0.001:
			tanks.append(state)
	return tanks


func _contents_name(contents: String) -> String:
	return {
		"empty": "TOM",
		"crude": "RÅOLJE",
		"light": "LETT",
		"diesel": "DIESEL",
		"heavy": "TUNG",
	}.get(contents, contents.to_upper())


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message, "charge": 0, "revenue": 0}
