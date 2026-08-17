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
	_create_ports(data)
	set_status(data["name"].to_upper())


func _create_ports(data: Dictionary) -> void:
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
	return "E — inspiser bygd %s" % equipment_type
