class_name BuildController
extends Node3D

signal placement_requested(equipment_type: String, position_3d: Vector3, rotation_quadrants: int)
signal removal_requested(unit)
signal notification_requested(message: String)

const Catalog = preload("res://scripts/equipment_catalog.gd")
const ProcessPortScript = preload("res://scripts/process_port.gd")

const GRID_SIZE := 1.0
const BUILD_BOUNDS := Rect2(-14.0, 10.5, 28.0, 20.0)

var player
var unlocked := false
var active := false
var available_money := 0
var selected_type := "tank"
var rotation_quadrants := 0
var mode := "place"
var ghost: Node3D
var ghost_body: MeshInstance3D
var ghost_material: StandardMaterial3D
var ghost_valid := false
var registered_units: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var connection_source

var canvas: CanvasLayer
var build_panel: PanelContainer
var build_label: Label
var build_hint: Label


func setup(p_player) -> void:
	player = p_player
	_build_interface()
	_rebuild_ghost()


func set_unlocked(value: bool) -> void:
	unlocked = value
	if is_instance_valid(build_hint):
		build_hint.visible = unlocked and not active
	if not unlocked and active:
		set_build_mode(false)


func set_available_money(value: int) -> void:
	available_money = value


func set_build_mode(value: bool) -> void:
	active = value and unlocked
	mode = "place"
	_clear_connection_source()
	if is_instance_valid(player):
		player.build_mode_active = active
	if is_instance_valid(build_panel):
		build_panel.visible = active
	if is_instance_valid(build_hint):
		build_hint.visible = unlocked and not active
	if is_instance_valid(ghost):
		ghost.visible = active


func register_unit(unit) -> void:
	registered_units.append({
		"node": unit,
		"footprint": unit.rotated_footprint(),
		"cost": unit.purchase_cost,
	})


func remove_registered_unit(unit) -> void:
	_clear_connection_if_source(unit)
	for index in range(connections.size() - 1, -1, -1):
		var connection: Dictionary = connections[index]
		if connection["from"] == unit or connection["to"] == unit:
			connection["pipe"].queue_free()
			connections.remove_at(index)
	for index in range(registered_units.size() - 1, -1, -1):
		if registered_units[index]["node"] == unit:
			registered_units.remove_at(index)
			break
	unit.queue_free()


func _process(_delta: float) -> void:
	if not active:
		return
	if mode == "place":
		_update_ghost()
	elif is_instance_valid(ghost):
		ghost.visible = false
	_update_build_text()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			if not unlocked:
				notification_requested.emit("Byggemodus låses opp etter første godkjente salg.")
			else:
				set_build_mode(not active)
				notification_requested.emit("Byggemodus aktiv." if active else "Byggemodus avsluttet.")
			get_viewport().set_input_as_handled()
			return
		if not active:
			return
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				var index := int(event.keycode) - int(KEY_1)
				selected_type = Catalog.ORDER[index]
				mode = "place"
				_rebuild_ghost()
			KEY_Q:
				rotation_quadrants = posmod(rotation_quadrants - 1, 4)
			KEY_E:
				rotation_quadrants = posmod(rotation_quadrants + 1, 4)
			KEY_X:
				mode = "remove" if mode != "remove" else "place"
				_clear_connection_source()
			KEY_F:
				mode = "connect"
				_handle_connection_selection()
			KEY_ESCAPE:
				if mode != "place" or is_instance_valid(connection_source):
					mode = "place"
					_clear_connection_source()
				else:
					set_build_mode(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and active:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if mode == "place":
				_try_place()
			elif mode == "remove":
				_try_remove()
			elif mode == "connect":
				_handle_connection_selection()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mode = "place"
			_clear_connection_source()
			get_viewport().set_input_as_handled()


func _try_place() -> void:
	if not ghost_valid or not is_instance_valid(ghost):
		notification_requested.emit("Kan ikke plassere utstyret her.")
		return
	var data: Dictionary = Catalog.definition(selected_type)
	if available_money < data["cost"]:
		notification_requested.emit("Ikke nok penger til %s." % data["name"])
		return
	placement_requested.emit(selected_type, ghost.position, rotation_quadrants)


func _try_remove() -> void:
	var unit = _raycast_buildable()
	if unit == null:
		notification_requested.emit("Se på en bygd maskin for å fjerne den.")
		return
	removal_requested.emit(unit)


func _handle_connection_selection() -> void:
	var unit = _raycast_buildable()
	if unit == null:
		notification_requested.emit("Se på en bygd maskin og trykk F eller venstreklikk.")
		return
	if not is_instance_valid(connection_source):
		connection_source = unit
		connection_source.set_as_connection_source(true)
		notification_requested.emit("Utløp valgt. Se på neste maskin og trykk F.")
		return
	if unit == connection_source:
		notification_requested.emit("En maskin kan ikke kobles til seg selv.")
		return
	if _connection_exists(connection_source, unit):
		notification_requested.emit("Disse maskinene er allerede koblet sammen.")
		return
	_create_connection(connection_source, unit)
	connection_source.set_as_connection_source(false)
	connection_source = null
	notification_requested.emit("Prosessrør koblet mellom OUT og IN.")


func _create_connection(from_unit, to_unit) -> void:
	var from_position: Vector3 = from_unit.output_port.global_position
	var to_position: Vector3 = to_unit.input_port.global_position
	var direction := to_position - from_position
	var pipe := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, direction.length())
	pipe.mesh = mesh
	pipe.position = (from_position + to_position) * 0.5
	add_child(pipe)
	pipe.look_at(to_position, Vector3.UP)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4f8f94")
	material.metallic = 0.65
	material.roughness = 0.24
	material.emission_enabled = true
	material.emission = Color("28555b")
	material.emission_energy_multiplier = 0.35
	pipe.material_override = material
	connections.append({"from": from_unit, "to": to_unit, "pipe": pipe})
	from_unit.set_status("OUT KOBLET")
	to_unit.set_status("IN KOBLET")


func _connection_exists(from_unit, to_unit) -> bool:
	for connection in connections:
		if connection["from"] == from_unit and connection["to"] == to_unit:
			return true
	return false


func _clear_connection_source() -> void:
	if is_instance_valid(connection_source):
		connection_source.set_as_connection_source(false)
	connection_source = null


func _clear_connection_if_source(unit) -> void:
	if connection_source == unit:
		_clear_connection_source()


func _raycast_buildable():
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return null
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * 12.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider = hit["collider"]
	if collider != null and collider.is_in_group("player_built"):
		return collider
	return null


func _update_ghost() -> void:
	if not is_instance_valid(ghost) or not is_instance_valid(player.camera):
		return
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * 24.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		ghost.visible = false
		ghost_valid = false
		return

	var hit_position: Vector3 = hit["position"]
	var data: Dictionary = Catalog.definition(selected_type)
	var size: Vector3 = data["size"]
	ghost.position = Vector3(
		roundf(hit_position.x / GRID_SIZE) * GRID_SIZE,
		0.16 + size.y * 0.5,
		roundf(hit_position.z / GRID_SIZE) * GRID_SIZE
	)
	ghost.rotation.y = deg_to_rad(float(rotation_quadrants * 90))
	ghost.visible = true
	ghost_valid = _position_is_valid(ghost.position, _selected_footprint())
	var preview_color := Color(0.20, 0.95, 0.50, 0.42) if ghost_valid else Color(1.0, 0.20, 0.18, 0.42)
	ghost_material.albedo_color = preview_color
	ghost_material.emission = Color(preview_color.r, preview_color.g, preview_color.b)


func _position_is_valid(position_3d: Vector3, footprint: Vector2) -> bool:
	var center := Vector2(position_3d.x, position_3d.z)
	var half_size := footprint * 0.5
	if center.x - half_size.x < BUILD_BOUNDS.position.x:
		return false
	if center.y - half_size.y < BUILD_BOUNDS.position.y:
		return false
	if center.x + half_size.x > BUILD_BOUNDS.end.x:
		return false
	if center.y + half_size.y > BUILD_BOUNDS.end.y:
		return false
	for entry in registered_units:
		var unit = entry["node"]
		if not is_instance_valid(unit):
			continue
		var other_center := Vector2(unit.position.x, unit.position.z)
		var other_half: Vector2 = entry["footprint"] * 0.5
		if (
			absf(center.x - other_center.x) < half_size.x + other_half.x + 0.35
			and absf(center.y - other_center.y) < half_size.y + other_half.y + 0.35
		):
			return false
	return true


func _selected_footprint() -> Vector2:
	var size: Vector3 = Catalog.definition(selected_type)["size"]
	if rotation_quadrants % 2 == 0:
		return Vector2(size.x, size.z)
	return Vector2(size.z, size.x)


func _rebuild_ghost() -> void:
	if is_instance_valid(ghost):
		ghost.queue_free()
	var data: Dictionary = Catalog.definition(selected_type)
	var size: Vector3 = data["size"]
	ghost = Node3D.new()
	ghost_body = MeshInstance3D.new()
	if data["shape"] == "cylinder":
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
		cylinder.radial_segments = 24
		ghost_body.mesh = cylinder
	else:
		var box := BoxMesh.new()
		box.size = size
		ghost_body.mesh = box
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.emission_enabled = true
	ghost_body.material_override = ghost_material
	ghost.add_child(ghost_body)
	_add_ghost_port("input", data["has_input"])
	_add_ghost_port("output", data["has_output"])
	_add_flow_direction_marker(size)
	ghost.visible = active and mode == "place"
	add_child(ghost)


func _add_ghost_port(port_kind: String, enabled: bool) -> void:
	if not enabled:
		return
	var preview_port = ProcessPortScript.new()
	preview_port.configure(port_kind)
	preview_port.position = Catalog.port_position(selected_type, port_kind)
	preview_port.name = "Preview%sPort" % port_kind.capitalize()
	ghost.add_child(preview_port)


func _add_flow_direction_marker(size: Vector3) -> void:
	var arrow_root := Node3D.new()
	arrow_root.name = "FlowDirection"
	arrow_root.position = Vector3(0.0, size.y * 0.5 + 0.08, -0.12)
	ghost.add_child(arrow_root)

	var arrow_material := StandardMaterial3D.new()
	arrow_material.albedo_color = Color("ff9b42")
	arrow_material.emission_enabled = true
	arrow_material.emission = Color("ff9b42")
	arrow_material.emission_energy_multiplier = 1.8
	arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var stem := MeshInstance3D.new()
	var stem_mesh := BoxMesh.new()
	stem_mesh.size = Vector3(0.16, 0.06, minf(size.z * 0.45, 1.15))
	stem.mesh = stem_mesh
	stem.position.z = -0.18
	stem.material_override = arrow_material
	arrow_root.add_child(stem)

	for side in [-1.0, 1.0]:
		var tip := MeshInstance3D.new()
		var tip_mesh := BoxMesh.new()
		tip_mesh.size = Vector3(0.48, 0.06, 0.13)
		tip.mesh = tip_mesh
		tip.position = Vector3(side * 0.17, 0.0, -0.70)
		tip.rotation.y = deg_to_rad(side * 42.0)
		tip.material_override = arrow_material
		arrow_root.add_child(tip)


func _build_interface() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	build_panel = PanelContainer.new()
	build_panel.position = Vector2(20.0, 330.0)
	build_panel.custom_minimum_size = Vector2(385.0, 310.0)
	build_panel.visible = false
	build_label = Label.new()
	build_label.add_theme_font_size_override("font_size", 17)
	build_label.add_theme_constant_override("outline_size", 5)
	build_label.add_theme_color_override("font_outline_color", Color.BLACK)
	build_panel.add_child(build_label)
	canvas.add_child(build_panel)

	build_hint = Label.new()
	build_hint.anchor_left = 1.0
	build_hint.anchor_right = 1.0
	build_hint.anchor_top = 1.0
	build_hint.anchor_bottom = 1.0
	build_hint.offset_left = -290.0
	build_hint.offset_right = -25.0
	build_hint.offset_top = -62.0
	build_hint.offset_bottom = -24.0
	build_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_hint.text = "B — Åpne byggemodus"
	build_hint.add_theme_font_size_override("font_size", 18)
	build_hint.add_theme_color_override("font_color", Color("9ce8c1"))
	build_hint.add_theme_constant_override("outline_size", 6)
	build_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	build_hint.visible = false
	canvas.add_child(build_hint)


func _update_build_text() -> void:
	var data: Dictionary = Catalog.definition(selected_type)
	var mode_name: String = {
		"place": "PLASSERING",
		"remove": "FJERNING",
		"connect": "RØRKOBLING",
	}[mode]
	var connection_text := ""
	if is_instance_valid(connection_source):
		connection_text = "\nValgt utløp: %s" % connection_source.display_name
	build_label.text = (
		"BYGGEMODUS — %s\nPenger: %d kr\n\n%s\n\n"
		% [mode_name, available_money, Catalog.menu_text()]
		+ "Valgt: %s (%d kr)%s\n" % [data["name"], data["cost"], connection_text]
		+ "Retning: %d°  |  IN blå  |  OUT oransje\n\n" % (rotation_quadrants * 90)
		+ "1–4 Velg  |  Q/E Roter  |  Klikk Plasser\n"
		+ "X Fjern  |  F Koble OUT → IN  |  Høyreklikk Avbryt  |  B Avslutt"
	)
