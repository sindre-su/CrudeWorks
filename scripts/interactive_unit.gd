class_name InteractiveUnit
extends StaticBody3D

var unit_id := ""
var display_name := ""
var mesh_instance: MeshInstance3D
var status_label: Label3D
var material: StandardMaterial3D
var alarm_beacon: MeshInstance3D
var alarm_beacon_material: StandardMaterial3D
var alarm_severity := ""


func configure(
	p_unit_id: String,
	p_display_name: String,
	p_mesh: Mesh,
	p_shape: Shape3D,
	p_color: Color,
	p_label_height: float
) -> void:
	unit_id = p_unit_id
	display_name = p_display_name

	material = StandardMaterial3D.new()
	material.albedo_color = p_color
	material.metallic = 0.35
	material.roughness = 0.42

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = p_mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.shape = p_shape
	add_child(collision)

	status_label = Label3D.new()
	status_label.position = Vector3(0.0, p_label_height, 0.0)
	status_label.text = display_name
	status_label.font_size = 44
	status_label.outline_size = 10
	status_label.modulate = Color.WHITE
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = true
	add_child(status_label)


func set_status(status: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = "%s\n%s" % [display_name, status]


func set_active(active: bool, active_color := Color(0.2, 1.0, 0.45)) -> void:
	if not is_instance_valid(material):
		return
	material.emission_enabled = active
	material.emission = active_color if active else Color.BLACK
	material.emission_energy_multiplier = 0.45 if active else 0.0


func create_alarm_beacon(position_3d: Vector3) -> void:
	alarm_beacon = MeshInstance3D.new()
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.13
	beacon_mesh.height = 0.26
	beacon_mesh.radial_segments = 16
	alarm_beacon.mesh = beacon_mesh
	alarm_beacon.position = position_3d
	alarm_beacon_material = StandardMaterial3D.new()
	alarm_beacon_material.albedo_color = Color("ffca3a")
	alarm_beacon_material.emission_enabled = true
	alarm_beacon.material_override = alarm_beacon_material
	alarm_beacon.visible = false
	add_child(alarm_beacon)


func set_alarm_severity(severity: String) -> void:
	alarm_severity = severity.to_upper()
	if not is_instance_valid(alarm_beacon):
		return
	var colors := {
		"LOW": Color("ffca3a"),
		"MEDIUM": Color("ff7a3d"),
		"HIGH": Color("ff4d4d"),
	}
	alarm_beacon.visible = colors.has(alarm_severity)
	if alarm_beacon.visible:
		var color: Color = colors[alarm_severity]
		alarm_beacon_material.albedo_color = color
		alarm_beacon_material.emission = color
		alarm_beacon_material.emission_energy_multiplier = 2.0


func make_transparent(alpha: float) -> void:
	if not is_instance_valid(material):
		return
	var transparent_color := material.albedo_color
	transparent_color.a = clampf(alpha, 0.15, 1.0)
	material.albedo_color = transparent_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED


func interaction_prompt() -> String:
	match unit_id:
		"pump":
			return "E — start/stopp pumpe"
		"feed_valve":
			return "E — åpne/lukke ventil"
		"heater":
			return "E — endre temperaturmål"
		"sales_terminal":
			return "E — analyser og selg diesel"
		"area02_control":
			return "E — åpne LS-201 lokalstasjon"
		"area02_generator":
			return "E — start/stopp PG-101 generator"
		"area02_mcc":
			return "E — inspiser/reset MCC-101"
		"generator_fuel":
			return "E — fyll GF-101 fra lagret diesel"
		"instrument_air":
			return "E — start/stopp IA-101"
		"cooling_tower", "cooling_water":
			return "E — start/stopp CWP-101"
		_:
			return "E — inspiser %s" % display_name
