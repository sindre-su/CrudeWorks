class_name BuildableUnit
extends InteractiveUnit

const Catalog = preload("res://scripts/equipment_catalog.gd")
const ProcessPortScript = preload("res://scripts/process_port.gd")
const TankLiquidVisualScript = preload("res://scripts/tank_liquid_visual.gd")

const TANK_LIQUID_COLORS := {
	"crude": Color("241815"),
	"light": Color("a8e5dc"),
	"diesel": Color("e8bd22"),
	"heavy": Color("241c20"),
	"vacuum_gas_oil": Color("687a32"),
	"vacuum_residue": Color("17131d"),
	"gasoline_blendstock": Color("d85a39"),
	"lpg": Color("b98ff0"),
	"light_cycle_oil": Color("855d39"),
}

var equipment_type := ""
var serial_number := 0
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
var valve_handle: Node3D
var valve_handle_material: StandardMaterial3D
var pump_rotor: Node3D
var pump_rotor_material: StandardMaterial3D
var pump_rotor_running := false
var guidance_label: Label3D


func configure_buildable(
	type: String,
	serial_number: int,
	fixed_unit_id := "",
	fixed_display_name := ""
) -> void:
	var data: Dictionary = Catalog.definition(type)
	equipment_type = type
	self.serial_number = serial_number
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
		fixed_unit_id if not fixed_unit_id.is_empty() else "built_%s_%d" % [type, serial_number],
		fixed_display_name if not fixed_display_name.is_empty() else "%s %02d" % [data["tag"], serial_number],
		unit_mesh,
		unit_shape,
		data["color"],
		size.y * 0.5 + 0.72
	)
	create_alarm_beacon(Vector3(0.0, size.y * 0.5 + 0.22, 0.0))
	add_to_group("player_built")
	_create_ports()
	if equipment_type == "crude_intake":
		_create_guidance_label("CRUDE FEED\nCI-201 TIE-IN")
	elif equipment_type == "product_dispatch":
		_create_guidance_label("PRODUCT EXPORT\nPD-201 TIE-IN")
	elif equipment_type == "crude_intake_terminal":
		_create_guidance_label("CRUDE INTAKE\nCI-101")
	elif equipment_type == "product_dispatch_terminal":
		_create_guidance_label("PRODUCT DISPATCH\nPD-101")
	if equipment_type == "tank":
		TankLiquidVisualScript.open_transparent_shell(unit_mesh)
		make_transparent(0.48)
		_create_tank_liquid(size)
	elif equipment_type == "pump":
		_create_pump_rotor(size)
	elif equipment_type == "valve":
		_create_valve_handle(size)
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


func set_onboarding_guidance(enabled: bool) -> void:
	if is_instance_valid(guidance_label):
		guidance_label.visible = enabled


func _create_guidance_label(text_value: String) -> void:
	guidance_label = Label3D.new()
	guidance_label.text = text_value
	guidance_label.position = Vector3(0.0, footprint_size.y * 0.5 + 1.35, 0.0)
	guidance_label.font_size = 38
	guidance_label.outline_size = 10
	guidance_label.modulate = Color("fff3bd")
	guidance_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guidance_label.no_depth_test = true
	guidance_label.visible = false
	add_child(guidance_label)


func set_tank_fill(fill_ratio: float, contents: String) -> void:
	if not is_instance_valid(liquid_level):
		return
	var color: Color = TANK_LIQUID_COLORS.get(contents, Color("65777c"))
	TankLiquidVisualScript.set_fill({
		"node": liquid_level,
		"material": liquid_material,
		"max_height": liquid_max_height,
		"bottom_y": liquid_bottom_y,
	}, fill_ratio, color)


func _create_tank_liquid(size: Vector3) -> void:
	liquid_max_height = size.y * 0.86
	liquid_bottom_y = -liquid_max_height * 0.5
	var data := TankLiquidVisualScript.create(
		self, size.x * 0.42, liquid_max_height, Color("241815"), 28
	)
	liquid_level = data["node"]
	liquid_material = data["material"]


func _create_pump_rotor(size: Vector3) -> void:
	pump_rotor = Node3D.new()
	pump_rotor.position = Vector3(0.0, 0.0, -size.z * 0.5 - 0.07)
	add_child(pump_rotor)
	pump_rotor_material = StandardMaterial3D.new()
	pump_rotor_material.albedo_color = Color("c7dcdd")
	pump_rotor_material.metallic = 0.75
	pump_rotor_material.roughness = 0.22
	pump_rotor_material.emission_enabled = true
	pump_rotor_material.emission = Color("28464b")
	pump_rotor_material.emission_energy_multiplier = 0.1
	for angle_degrees in [0.0, 60.0, 120.0]:
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(0.92, 0.10, 0.10)
		spoke.mesh = spoke_mesh
		spoke.rotation.z = deg_to_rad(angle_degrees)
		spoke.material_override = pump_rotor_material
		pump_rotor.add_child(spoke)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.18
	hub_mesh.bottom_radius = 0.18
	hub_mesh.height = 0.18
	hub_mesh.radial_segments = 16
	hub.mesh = hub_mesh
	hub.rotation.x = deg_to_rad(90.0)
	hub.material_override = pump_rotor_material
	pump_rotor.add_child(hub)


func _create_valve_handle(size: Vector3) -> void:
	valve_handle = Node3D.new()
	valve_handle.position.y = size.y * 0.5 + 0.16
	add_child(valve_handle)
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.18, 0.12, 1.25)
	bar.mesh = bar_mesh
	valve_handle_material = StandardMaterial3D.new()
	valve_handle_material.albedo_color = Color("d94b3d")
	valve_handle_material.emission_enabled = true
	valve_handle_material.emission = Color("4a120d")
	valve_handle_material.emission_energy_multiplier = 0.25
	bar.material_override = valve_handle_material
	valve_handle.add_child(bar)
	set_valve_open(false)


func set_valve_open(value: bool) -> void:
	if not is_instance_valid(valve_handle):
		return
	valve_handle.rotation.y = 0.0 if value else deg_to_rad(90.0)
	var color := Color("78e08f") if value else Color("d94b3d")
	valve_handle_material.albedo_color = color
	valve_handle_material.emission = color
	valve_handle_material.emission_energy_multiplier = 0.7 if value else 0.25


func set_pump_operating(value: bool) -> void:
	if not is_instance_valid(pump_rotor):
		return
	pump_rotor_running = value
	pump_rotor_material.emission_enabled = true
	pump_rotor_material.emission = Color("7ce7e0") if value else Color("28464b")
	pump_rotor_material.emission_energy_multiplier = 1.2 if value else 0.1


func _process(delta: float) -> void:
	if pump_rotor_running and is_instance_valid(pump_rotor):
		pump_rotor.rotation.z = fmod(pump_rotor.rotation.z - delta * 8.0, TAU)


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
		"valve":
			return "E — åpne/steng manuell ventil"
		"heater":
			return "E — endre temperaturmål"
		"column":
			return "E — inspiser destillasjon"
		"treatment":
			return "E — start/stopp dieselbehandler"
		"header":
			return "E — velg fôringsrute"
		"product_header":
			return "E — velg produkttank"
	return "E — inspiser bygd utstyr"
