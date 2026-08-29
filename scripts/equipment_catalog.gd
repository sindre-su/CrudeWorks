class_name EquipmentCatalog
extends RefCounted

## Stable catalog order doubles as the full late-game hotbar order. The first
## six entries teach the physical starter flow before routing/advanced tools.
const ORDER := ["tank", "pump", "valve", "heater", "column", "treatment", "header", "product_header", "vacuum_distillation", "power_unit", "catalytic_cracking"]

const CRUDE_TERMINAL_ID := "built_crude_intake_0"
const PRODUCT_TERMINAL_ID := "built_product_dispatch_0"
const CRUDE_TIE_IN_ID := "site_crude_feed_tie_in"
const PRODUCT_TIE_IN_ID := "site_product_dispatch_tie_in"


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
				"power_demand_kw": 0.0,
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
				"power_demand_kw": 25.0,
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
				"power_demand_kw": 0.0,
				"instrument_air_required": false,
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
				"power_demand_kw": 10.0,
				"instrument_air_required": true,
				"fail_action": "fail_closed",
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
				"power_demand_kw": 0.0,
				"cooling_water_required": true,
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
				"power_demand_kw": 20.0,
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
				"power_demand_kw": 0.0,
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
				"power_demand_kw": 0.0,
			}
		"vacuum_distillation":
			return {
				"name": "Vacuum Distillation Unit",
				"tag": "VDU-301",
				"cost": 1200,
				"size": Vector3(3.6, 5.2, 3.4),
				"color": Color("6b607e"),
				"shape": "cylinder",
				"has_input": true,
				"has_output": true,
				"power_demand_kw": 25.0,
			}
		"power_unit":
			return {
				"name": "Power Unit",
				"tag": "PU-101",
				"cost": 700,
				"size": Vector3(2.8, 2.4, 2.4),
				"color": Color("d5a63c"),
				"shape": "box",
				"has_input": false,
				"has_output": false,
				"power_demand_kw": 0.0,
				"generation_capacity_kw": 100.0,
				"fuel_use_l_per_kwh": 0.5,
				"idle_fuel_use_lpm": 0.1,
			}
		"starter_generator":
			return {
				"name": "Primary Generator",
				"tag": "PG-101",
				"power_demand_kw": 0.0,
				"generation_capacity_kw": 100.0,
				"fuel_use_l_per_kwh": 0.5,
				"idle_fuel_use_lpm": 0.1,
			}
		"generator_fuel_tank":
			return {
				"name": "Generator Fuel Day Tank",
				"tag": "GF-101",
				"power_demand_kw": 0.0,
			}
		"instrument_air_compressor":
			return {
				"name": "Instrument Air Compressor",
				"tag": "IA-101",
				"power_demand_kw": 15.0,
			}
		"cooling_tower":
			return {
				"name": "Cooling Tower",
				"tag": "CT-101",
				"power_demand_kw": 0.0,
			}
		"cooling_water_pump":
			return {
				"name": "Cooling Water Pump",
				"tag": "CWP-101",
				"power_demand_kw": 20.0,
			}
		"catalytic_cracking":
			return {
				"name": "Fluid Catalytic Cracking",
				"tag": "FCC-401",
				"cost": 2200,
				"size": Vector3(4.2, 5.4, 3.8),
				"color": Color("875b42"),
				"shape": "cylinder",
				"has_input": true,
				"has_output": true,
				"power_demand_kw": 40.0,
			}
		"crude_intake":
			return {
				"name": "Crude Feed Tie-In",
				"tag": "CI-201",
				"cost": 0,
				"size": Vector3(3.0, 2.6, 2.6),
				"color": Color("45676e"),
				"shape": "box",
				"has_input": false,
				"has_output": true,
				"power_demand_kw": 0.0,
			}
		"product_dispatch":
			return {
				"name": "Product Dispatch Tie-In",
				"tag": "PD-201",
				"cost": 0,
				"size": Vector3(3.4, 2.8, 2.8),
				"color": Color("3e6650"),
				"shape": "box",
				"has_input": true,
				"has_output": false,
				"power_demand_kw": 0.0,
			}
		"crude_intake_terminal":
			return {
				"name": "Crude Intake Terminal",
				"tag": "CI-101",
				"cost": 0,
				"size": Vector3(3.0, 2.6, 2.6),
				"color": Color("45676e"),
				"shape": "box",
				"has_input": false,
				"has_output": false,
				"power_demand_kw": 0.0,
			}
		"product_dispatch_terminal":
			return {
				"name": "Product Dispatch Terminal",
				"tag": "PD-101",
				"cost": 0,
				"size": Vector3(3.4, 2.8, 2.8),
				"color": Color("3e6650"),
				"shape": "box",
				"has_input": false,
				"has_output": false,
				"power_demand_kw": 0.0,
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
	if equipment_type == "power_unit":
		return []
	if equipment_type in ["crude_intake_terminal", "product_dispatch_terminal"]:
		return []
	if equipment_type == "crude_intake":
		return [_port("output", "output", "crude", "CRUDE OUT", Vector3(0.0, y, -z))]
	if equipment_type == "product_dispatch":
		return [
			_port("light", "input", "light", "NAPHTHA", Vector3(-1.05, y, z)),
			_port("diesel", "input", "diesel", "DIESEL", Vector3(-0.35, y, z)),
			_port("heavy", "input", "heavy", "TUNGREST", Vector3(0.35, y, z)),
			_port("vacuum_gas_oil", "input", "vacuum_gas_oil", "VGO", Vector3(1.05, y, z)),
			_port("vacuum_residue", "input", "vacuum_residue", "VAKUUMREST", Vector3(-1.05, y + 0.48, z)),
			_port("gasoline_blendstock", "input", "gasoline_blendstock", "GASOLINE", Vector3(-0.35, y + 0.48, z)),
			_port("lpg", "input", "lpg", "LPG", Vector3(0.35, y + 0.48, z)),
			_port("light_cycle_oil", "input", "light_cycle_oil", "LCO", Vector3(1.05, y + 0.48, z)),
		]
	if equipment_type == "catalytic_cracking":
		return [
			_port("input", "input", "vacuum_gas_oil", "IN", Vector3(0.0, y, z)),
			_port("gasoline", "output", "gasoline_blendstock", "GAS", Vector3(-0.9, y, -z)),
			_port("lpg", "output", "lpg", "LPG", Vector3(0.0, y, -z)),
			_port("lco", "output", "light_cycle_oil", "LCO", Vector3(0.9, y, -z)),
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
		or (from_type == "pump" and to_type == "catalytic_cracking")
		or (from_type == "valve" and to_type == "heater")
		or (from_type == "heater" and to_type == "column")
		or (from_type == "column" and to_type == "tank")
		or (from_type == "column" and to_type == "treatment")
		or (from_type == "treatment" and to_type == "tank")
		or (from_type == "vacuum_distillation" and to_type == "tank")
		or (from_type == "catalytic_cracking" and to_type == "tank")
		or (from_type == "crude_intake" and to_type == "pump")
		or (from_type == "pump" and to_type == "product_dispatch")
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


static func visible_order(hidden_equipment: Dictionary = {}) -> Array[String]:
	var visible: Array[String] = []
	for equipment_type: String in ORDER:
		if not hidden_equipment.has(equipment_type):
			visible.append(equipment_type)
	return visible


static func hotkey_label(index: int) -> String:
	return "0" if index == 9 else ("-" if index == 10 else str(index + 1))


static func hotkey_index(keycode: Key) -> int:
	if keycode == KEY_MINUS:
		return 10
	if keycode == KEY_0:
		return 9
	if keycode >= KEY_1 and keycode <= KEY_9:
		return int(keycode) - int(KEY_1)
	return -1


static func selection_help(hidden_equipment: Dictionary = {}) -> String:
	var count := visible_order(hidden_equipment).size()
	if count <= 9:
		return "1–%d Velg" % count
	return "1–9 / 0 / - Velg"


static func menu_text(locked_equipment: Dictionary = {}, hidden_equipment: Dictionary = {}) -> String:
	var lines: Array[String] = []
	var visible := visible_order(hidden_equipment)
	for index in visible.size():
		var equipment_type: String = visible[index]
		var data := definition(equipment_type)
		var lock_reason := String(locked_equipment.get(equipment_type, ""))
		lines.append(
			"%s  %-22s LÅST — %s" % [hotkey_label(index), data["name"], lock_reason]
			if not lock_reason.is_empty()
			else "%s  %-22s %4d kr" % [hotkey_label(index), data["name"], data["cost"]]
		)
	return "\n".join(lines)
