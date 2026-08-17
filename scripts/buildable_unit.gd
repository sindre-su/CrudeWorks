class_name BuildableUnit
extends InteractiveUnit

const Catalog = preload("res://scripts/equipment_catalog.gd")
const ProcessPortScript = preload("res://scripts/process_port.gd")

var equipment_type := ""
var purchase_cost := 0
var footprint_size := Vector2.ZERO
var rotation_quadrants := 0
var input_port
var output_port
var ports: Dictionary = {}
var liquid_level: MeshInstance3D
var liquid_material: StandardMaterial3D
var liquid_max_height := 0.0
var liquid_bottom_y := 0.0


func configure_buildable(type: String, serial_number: int) -> void:
	var data: Dictionary = Catalog.definition(type)
	equipment_type = type
	purchase_cost = data["cost"]
	var size: Vector3 = data["size"]
	footprint_size = Vector2(size.x, size.z)

	var unit_mesh: Mesh
	var unit_shape: Shape3D
	if data["shape"] == "cylinder":
		var cylinder_mesh := CylinderMesh.new()
		cylinder_mesh.top_radius = size.x * 0.5
		cylinder_mesh.bottom_radius = size.x * 0.5
		cylinder_mesh.height = size.y
		cylinder_mesh.radial_segments = 28
		unit_mesh = cylinder_mesh
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = size.x * 0.5
		cylinder_shape.height = size.y
		unit_shape = cylinder_shape
	else:
		var box_mesh := BoxMesh.new()
		box_mesh.size = size
		unit_mesh = box_mesh
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		unit_shape = box_shape

	configure(
		"built_%s_%d" % [type, serial_number],
		"%s %02d" % [data["tag"], serial_number],
		unit_mesh,
		unit_shape,
		data["color"],
		size.y * 0.5 + 0.72
	)
	add_to_group("player_built")
	_create_ports()
	if equipment_type == "tank":
		make_transparent(0.48)
		_create_tank_liquid(size)
	set_status(data["name"].to_upper())


func _create_ports() -> void:
	for port_data in Catalog.port_definitions(equipment_type):
		var port = ProcessPortScript.new()
		port.configure(port_data, unit_id)
		port.position = port_data["position"]
		port.name = "%sPort" % String(port_data["id"]).capitalize()
		add_child(port)
		ports[port_data["id"]] = port
		if port_data["kind"] == "input" and input_port == null:
			input_port = port
		elif port_data["kind"] == "output" and output_port == null:
			output_port = port


func get_port(port_id: String):
	return ports.get(port_id)


func ports_of_kind(port_kind: String) -> Array:
	var matching := []
	for port in ports.values():
		if port.port_kind == port_kind:
			matching.append(port)
	return matching


func set_tank_fill(fill_ratio: float, contents: String) -> void:
	if not is_instance_valid(liquid_level):
		return
	var ratio := clampf(fill_ratio, 0.0, 1.0)
	var display_height := maxf(liquid_max_height * ratio, 0.015)
	liquid_level.scale.y = display_height
	liquid_level.position.y = liquid_bottom_y + display_height * 0.5
	liquid_level.visible = ratio > 0.001
	var color: Color = {
		"crude": Color("241815"),
		"light": Color("a8e5dc"),
		"diesel": Color("e8bd22"),
		"heavy": Color("241c20"),
	}.get(contents, Color("65777c"))
	liquid_material.albedo_color = color
	liquid_material.emission = color


func _create_tank_liquid(size: Vector3) -> void:
	liquid_max_height = size.y * 0.86
	liquid_bottom_y = -liquid_max_height * 0.5
	liquid_level = MeshInstance3D.new()
	var liquid_mesh := CylinderMesh.new()
	liquid_mesh.top_radius = size.x * 0.42
	liquid_mesh.bottom_radius = size.x * 0.42
	liquid_mesh.height = 1.0
	liquid_mesh.radial_segments = 28
	liquid_level.mesh = liquid_mesh
	liquid_material = StandardMaterial3D.new()
	liquid_material.albedo_color = Color("241815")
	liquid_material.emission_enabled = true
	liquid_material.emission = Color("241815")
	liquid_material.emission_energy_multiplier = 0.2
	liquid_level.material_override = liquid_material
	liquid_level.visible = false
	add_child(liquid_level)


func rotated_footprint() -> Vector2:
	if rotation_quadrants % 2 == 0:
		return footprint_size
	return Vector2(footprint_size.y, footprint_size.x)


func set_as_connection_source(enabled: bool, port_id := "output") -> void:
	var port = get_port(port_id)
	if is_instance_valid(port):
		port.set_highlight(enabled)
	set_active(enabled, Color("ff9b42"))


func interaction_prompt() -> String:
	match equipment_type:
		"tank":
			return "E — inspiser / last råolje"
		"pump":
			return "E — start/stopp bygd pumpe"
		"heater":
			return "E — endre temperaturmål"
		"column":
			return "E — inspiser destillasjon"
	return "E — inspiser bygd utstyr"
