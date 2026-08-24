class_name EquipmentCatalog
extends RefCounted

const ORDER := ["tank", "pump", "heater", "column", "valve", "treatment", "header", "product_header"]


static func definition(equipment_type: String) -> Dictionary:
	match equipment_type:
		"tank":
			return {
				"name": "Tank",
				"tag": "T-201",
				"cost": 300,
				"size": Vector3(3.2, 3.6, 3.2),
				"color": Color("65777c"),
				"shape": "cylinder",
				"has_input": true,
				"has_output": true,
			}
		"pump":
			return {
				"name": "Pumpe",
				"tag": "P-201",
				"cost": 200,
				"size": Vector3(2.0, 1.4, 2.2),
				"color": Color("327b72"),
				"shape": "box",
				"has_input": true,
				"has_output": true,
			}
		"valve":
			return {
				"name": "Manuell ventil",
				"tag": "V-201",
				"cost": 200,
				"size": Vector3(1.6, 1.1, 1.8),
				"color": Color("b7791f"),
				"shape": "box",
				"has_input": true,
				"has_output": true,
			}
		"heater":
			return {
				"name": "Varmeenhet",
				"tag": "H-201",
				"cost": 400,
				"size": Vector3(3.0, 3.0, 2.8),
				"color": Color("9e4f34"),
				"shape": "box",
				"has_input": true,
				"has_output": true,
			}
		"column":
			return {
				"name": "Destillasjonskolonne",
				"tag": "D-201",
				"cost": 600,
				"size": Vector3(3.2, 6.4, 3.2),
				"color": Color("809399"),
				"shape": "cylinder",
				"has_input": true,
				"has_output": true,
			}
		"treatment":
			return {
				"name": "Dieselbehandler",
				"tag": "HT-201",
				"cost": 800,
				"size": Vector3(3.0, 3.2, 2.8),
				"color": Color("4f718f"),
				"shape": "box",
				"has_input": true,
				"has_output": true,
			}
		"header":
			return {
				"name": "Crude Feed Header",
				"tag": "FH-201",
				"cost": 350,
				"size": Vector3(3.4, 1.6, 2.8),
				"color": Color("596f82"),
				"shape": "box",
				"has_input": true,
				"has_output": true,
			}
		"product_header":
			return {
				"name": "Product Routing Header",
				"tag": "PH-201",
				"cost": 350,
				"size": Vector3(3.4, 1.6, 2.8),
				"color": Color("827059"),
				"shape": "box",
				"has_input": true,
				"has_output": true,
			}
		"vacuum_distillation":
			return {
				"name": "Vacuum Distillation Unit",
				"tag": "VDU-301",
				"cost": 0,
				"size": Vector3(3.6, 5.2, 3.4),
				"color": Color("6b607e"),
				"shape": "cylinder",
				"has_input": true,
				"has_output": true,
			}
	return {}


static func is_valid(equipment_type: String) -> bool:
	return not definition(equipment_type).is_empty()


static func port_definitions(equipment_type: String) -> Array[Dictionary]:
	var data := definition(equipment_type)
	if data.is_empty():
		return []
	var size: Vector3 = data["size"]
	var port_height := clampf(size.y * 0.25, 0.45, 1.25)
	var y := -size.y * 0.5 + port_height
	var z := size.z * 0.5 + 0.18
	if equipment_type == "column":
		return [
			_port("input", "input", "crude", "IN", Vector3(0.0, y, z)),
			_port("light", "output", "light", "LETT", Vector3(-0.82, y, -z)),
			_port("diesel", "output", "diesel", "DIESEL", Vector3(0.0, y, -z)),
			_port("heavy", "output", "heavy", "TUNG", Vector3(0.82, y, -z)),
		]
	if equipment_type == "treatment":
		return [
			_port("input", "input", "diesel", "IN", Vector3(0.0, y, z)),
			_port("output", "output", "diesel", "OUT", Vector3(0.0, y, -z)),
		]
	if equipment_type == "header":
		return [
			_port("input", "input", "crude", "IN", Vector3(0.0, y, z)),
			_port("out_a", "output", "crude", "OUT A", Vector3(-0.78, y, -z)),
			_port("out_b", "output", "crude", "OUT B", Vector3(0.78, y, -z)),
		]
	if equipment_type == "product_header":
		return [
			_port("input", "input", "any", "IN", Vector3(0.0, y, z)),
			_port("out_a", "output", "any", "OUT A", Vector3(-0.78, y, -z)),
			_port("out_b", "output", "any", "OUT B", Vector3(0.78, y, -z)),
		]
	if equipment_type == "vacuum_distillation":
		return [
			_port("input", "input", "heavy", "IN", Vector3(0.0, y, z)),
			_port("vgo", "output", "vacuum_gas_oil", "VGO", Vector3(-0.78, y, -z)),
			_port("vacuum_residue", "output", "vacuum_residue", "VAKUUMREST", Vector3(0.78, y, -z)),
		]

	var material_type := "any" if equipment_type in ["tank", "pump"] else "crude"
	return [
		_port("input", "input", material_type, "IN", Vector3(0.0, y, z)),
		_port("output", "output", material_type, "OUT", Vector3(0.0, y, -z)),
	]


static func port_definition(equipment_type: String, port_id: String) -> Dictionary:
	for port in port_definitions(equipment_type):
		if port["id"] == port_id:
			return port
	return {}


static func ports_of_kind(equipment_type: String, port_kind: String) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	for port in port_definitions(equipment_type):
		if port["kind"] == port_kind:
			matching.append(port)
	return matching


static func port_position(
	equipment_type: String,
	port_kind: String,
	port_id := ""
) -> Vector3:
	if not port_id.is_empty():
		var exact := port_definition(equipment_type, port_id)
		return exact.get("position", Vector3.ZERO)
	var ports := ports_of_kind(equipment_type, port_kind)
	return ports[0]["position"] if not ports.is_empty() else Vector3.ZERO


static func process_order_allows(from_type: String, to_type: String) -> bool:
	return (
		(from_type == "tank" and to_type == "pump")
		or (from_type == "tank" and to_type == "header")
		or (from_type == "header" and to_type == "pump")
		or (from_type == "column" and to_type == "product_header")
		or (from_type == "treatment" and to_type == "product_header")
		or (from_type == "product_header" and to_type == "tank")
		or (from_type == "pump" and to_type == "valve")
		or (from_type == "pump" and to_type == "vacuum_distillation")
		or (from_type == "valve" and to_type == "heater")
		or (from_type == "heater" and to_type == "column")
		or (from_type == "column" and to_type == "tank")
		or (from_type == "column" and to_type == "treatment")
		or (from_type == "treatment" and to_type == "tank")
		or (from_type == "vacuum_distillation" and to_type == "tank")
	)


static func _port(
	port_id: String,
	port_kind: String,
	material_type: String,
	label: String,
	position: Vector3
) -> Dictionary:
	return {
		"id": port_id,
		"kind": port_kind,
		"material": material_type,
		"label": label,
		"position": position,
	}


static func menu_text() -> String:
	var lines: Array[String] = []
	for index in ORDER.size():
		var data := definition(ORDER[index])
		lines.append("%d  %-22s %4d kr" % [index + 1, data["name"], data["cost"]])
	return "\n".join(lines)
