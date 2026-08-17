class_name EquipmentCatalog
extends RefCounted

const ORDER := ["tank", "pump", "heater", "column"]


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
	return {}


static func is_valid(equipment_type: String) -> bool:
	return not definition(equipment_type).is_empty()


static func port_position(equipment_type: String, port_kind: String) -> Vector3:
	var data := definition(equipment_type)
	if data.is_empty():
		return Vector3.ZERO
	var size: Vector3 = data["size"]
	var port_height := clampf(size.y * 0.25, 0.45, 1.25)
	var local_z := size.z * 0.5 + 0.18
	if port_kind == "output":
		local_z = -local_z
	return Vector3(0.0, -size.y * 0.5 + port_height, local_z)


static func menu_text() -> String:
	var lines: Array[String] = []
	for index in ORDER.size():
		var data := definition(ORDER[index])
		lines.append("%d  %-22s %4d kr" % [index + 1, data["name"], data["cost"]])
	return "\n".join(lines)
