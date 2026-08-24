class_name BuildController
extends Node3D

signal placement_requested(equipment_type: String, position_3d: Vector3, rotation_quadrants: int)
signal removal_requested(unit)
signal notification_requested(message: String)

const Catalog = preload("res://scripts/equipment_catalog.gd")
const ProcessPortScript = preload("res://scripts/process_port.gd")
const ProcessNetworkScript = preload("res://scripts/process_network.gd")
const FlowVisualScript = preload("res://scripts/flow_visual.gd")

const GRID_SIZE := 1.0
const BUILD_BOUNDS := Rect2(-20.0, 10.5, 40.0, 28.0)

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
var process_network
var network_feedback := "Koble en råoljetank OUT til pumpens IN."
var input_blocked := false

var canvas: CanvasLayer
var build_panel: PanelContainer
var build_label: Label
var build_hint: Label


func setup(p_player, p_process_network = null) -> void:
	player = p_player
	process_network = p_process_network if p_process_network != null else ProcessNetworkScript.new()
	_build_interface()
	_rebuild_ghost()


func set_unlocked(value: bool) -> void:
	unlocked = value
	if is_instance_valid(build_hint):
		build_hint.visible = unlocked and not active and not input_blocked
	if not unlocked and active:
		set_build_mode(false)


func set_available_money(value: int) -> void:
	available_money = value


func set_input_blocked(value: bool) -> void:
	input_blocked = value
	if is_instance_valid(build_hint):
		build_hint.visible = unlocked and not active and not input_blocked


func set_build_mode(value: bool) -> void:
	active = value and unlocked
	mode = "place"
	_clear_connection_source()
	if is_instance_valid(player):
		player.build_mode_active = active
	if is_instance_valid(build_panel):
		build_panel.visible = active
	if is_instance_valid(build_hint):
		build_hint.visible = unlocked and not active and not input_blocked
	if is_instance_valid(ghost):
		ghost.visible = active
	_set_unit_ports_visible(active)


func register_unit(unit) -> void:
	registered_units.append({
		"node": unit,
		"footprint": unit.rotated_footprint(),
		"cost": unit.purchase_cost,
	})
	if not process_network.has_unit(unit.unit_id):
		process_network.register_unit(unit.unit_id, unit.equipment_type, unit.display_name)
	for port in unit.ports.values():
		port.visible = active
	_update_network_feedback()


func has_registered_unit(unit) -> bool:
	for entry in registered_units:
		if entry["node"] == unit:
			return true
	return false


func registered_unit_by_id(unit_id: String):
	for entry in registered_units:
		var unit = entry["node"]
		if is_instance_valid(unit) and unit.unit_id == unit_id:
			return unit
	return null


func restore_connection(edge: Dictionary) -> Dictionary:
	var from_unit = registered_unit_by_id(edge.get("from_unit", ""))
	var to_unit = registered_unit_by_id(edge.get("to_unit", ""))
	if from_unit == null or to_unit == null:
		return {"ok": false, "message": "Lagret rør peker på ukjent utstyr."}
	var from_port = from_unit.get_port(edge.get("from_port", ""))
	var to_port = to_unit.get_port(edge.get("to_port", ""))
	if from_port == null or to_port == null:
		return {"ok": false, "message": "Lagret rør peker på ukjent prosessport."}
	return _connect_ports(from_port, to_port)


func _set_unit_ports_visible(value: bool) -> void:
	for entry in registered_units:
		var unit = entry["node"]
		if not is_instance_valid(unit):
			continue
		for port in unit.ports.values():
			port.visible = value


func remove_registered_unit(unit) -> void:
	_clear_connection_if_source(unit)
	process_network.unregister_unit(unit.unit_id)
	for index in range(connections.size() - 1, -1, -1):
		var connection: Dictionary = connections[index]
		if connection["from_unit_id"] == unit.unit_id or connection["to_unit_id"] == unit.unit_id:
			if is_instance_valid(connection["from_port"]):
				connection["from_port"].set_connected(false)
			if is_instance_valid(connection["to_port"]):
				connection["to_port"].set_connected(false)
			connection["pipe"].queue_free()
			connection["flow_visual"].queue_free()
			connections.remove_at(index)
	for index in range(registered_units.size() - 1, -1, -1):
		if registered_units[index]["node"] == unit:
			registered_units.remove_at(index)
			break
	unit.queue_free()
	_update_network_feedback()


func _process(_delta: float) -> void:
	if not active:
		return
	if mode == "place":
		_update_ghost()
	elif is_instance_valid(ghost):
		ghost.visible = false
	_update_build_text()


func _input(event: InputEvent) -> void:
	if input_blocked:
		return
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
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS:
				var index := 10 if event.keycode == KEY_MINUS else (9 if event.keycode == KEY_0 else int(event.keycode) - int(KEY_1))
				if index < Catalog.ORDER.size():
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
			KEY_V:
				var validation: Dictionary = process_network.validate_configuration()
				network_feedback = validation["message"]
				notification_requested.emit(network_feedback)
			KEY_G:
				_clear_connection_source()
				_try_disconnect_focused_port()
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
	var port = _raycast_connection_port()
	if port == null:
		notification_requested.emit("Se på en merket prosessport og trykk F eller venstreklikk.")
		return
	if not is_instance_valid(connection_source):
		if port.port_kind != "output":
			notification_requested.emit("Start koblingen på en oransje OUT-port.")
			return
		connection_source = port
		connection_source.set_highlight(true)
		notification_requested.emit("%s valgt. Koble til en blå IN-port." % _port_display_name(port))
		return
	if port.port_kind != "input":
		notification_requested.emit("Koblingen må ende på en blå IN-port.")
		return
	var result: Dictionary = _connect_ports(connection_source, port)
	if result["ok"]:
		_clear_connection_source()
		network_feedback = process_network.validate_configuration()["message"]
	else:
		network_feedback = result["message"]
	notification_requested.emit(result["message"])


func _connect_ports(from_port, to_port) -> Dictionary:
	var result: Dictionary = process_network.try_connect(
		from_port.owner_unit_id,
		from_port.port_id,
		to_port.owner_unit_id,
		to_port.port_id
	)
	if not result["ok"]:
		return result
	_create_connection_visual(from_port, to_port)
	return result


func _create_connection_visual(from_port, to_port) -> void:
	var from_position: Vector3 = from_port.global_position
	var to_position: Vector3 = to_port.global_position
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
	var flow_visual = FlowVisualScript.new()
	add_child(flow_visual)
	flow_visual.configure(to_local(from_position), to_local(to_position), Color("7ce7e0"))
	from_port.set_connected(true)
	to_port.set_connected(true)
	connections.append({
		"from_unit_id": from_port.owner_unit_id,
		"from_port_id": from_port.port_id,
		"to_unit_id": to_port.owner_unit_id,
		"to_port_id": to_port.port_id,
		"from_port": from_port,
		"to_port": to_port,
		"key": _connection_key(
			from_port.owner_unit_id,
			from_port.port_id,
			to_port.owner_unit_id,
			to_port.port_id
		),
		"pipe": pipe,
		"flow_visual": flow_visual,
	})


func set_process_flow(
	flow_lps: float,
	maximum_flow_lps: float,
	active_connection_keys := {}
) -> void:
	var enabled := flow_lps > 0.01
	var normalized := clampf(flow_lps / maximum_flow_lps, 0.0, 1.0) if maximum_flow_lps > 0.0 else 0.0
	for connection in connections:
		var flow_visual = connection["flow_visual"]
		if is_instance_valid(flow_visual):
			flow_visual.set_flow(enabled and active_connection_keys.has(connection["key"]), normalized)


static func _connection_key(
	from_unit_id: String,
	from_port_id: String,
	to_unit_id: String,
	to_port_id: String
) -> String:
	return "%s:%s>%s:%s" % [from_unit_id, from_port_id, to_unit_id, to_port_id]


func _connection_exists(from_port, to_port) -> bool:
	for connection in connections:
		if (
			connection["from_unit_id"] == from_port.owner_unit_id
			and connection["from_port_id"] == from_port.port_id
			and connection["to_unit_id"] == to_port.owner_unit_id
			and connection["to_port_id"] == to_port.port_id
		):
			return true
	return false


func _try_disconnect_focused_port() -> void:
	var port = _raycast_connection_port()
	if port != null and _disconnect_port(port):
		notification_requested.emit("Prosessrøret er koblet fra.")
		return
	var unit = _raycast_buildable()
	if unit != null:
		var connected_ports := []
		for candidate in unit.ports.values():
			if candidate.connected:
				connected_ports.append(candidate)
		if connected_ports.size() == 1 and _disconnect_port(connected_ports[0]):
			notification_requested.emit("Prosessrøret er koblet fra.")
			return
		if connected_ports.size() > 1:
			notification_requested.emit("Maskinen har flere rør. Se direkte på porten som skal kobles fra.")
			return
	notification_requested.emit("Se på en koblet port eller maskin for å fjerne røret.")


func _disconnect_port(port) -> bool:
	for index in connections.size():
		var connection: Dictionary = connections[index]
		var is_from: bool = (
			connection["from_unit_id"] == port.owner_unit_id
			and connection["from_port_id"] == port.port_id
		)
		var is_to: bool = (
			connection["to_unit_id"] == port.owner_unit_id
			and connection["to_port_id"] == port.port_id
		)
		if not is_from and not is_to:
			continue
		process_network.disconnect_ports(
			connection["from_unit_id"],
			connection["from_port_id"],
			connection["to_unit_id"],
			connection["to_port_id"]
		)
		if is_instance_valid(connection["from_port"]):
			connection["from_port"].set_connected(false)
		if is_instance_valid(connection["to_port"]):
			connection["to_port"].set_connected(false)
		connection["pipe"].queue_free()
		connection["flow_visual"].queue_free()
		connections.remove_at(index)
		_update_network_feedback()
		return true
	return false


func _clear_connection_source() -> void:
	if is_instance_valid(connection_source):
		connection_source.set_highlight(false)
	connection_source = null


func _clear_connection_if_source(unit) -> void:
	if is_instance_valid(connection_source) and connection_source.owner_unit_id == unit.unit_id:
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


func _raycast_connection_port():
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return null
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_transform.basis.z * 12.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider = hit["collider"]
	if collider is ProcessPort:
		return collider
	if collider is BuildableUnit:
		var desired_kind := "output" if not is_instance_valid(connection_source) else "input"
		var matching: Array = collider.ports_of_kind(desired_kind)
		if matching.size() == 1:
			return matching[0]
		if matching.size() > 1:
			notification_requested.emit("Se direkte på ønsket merket utløp.")
	return null


func _port_display_name(port) -> String:
	for entry in registered_units:
		var unit = entry["node"]
		if is_instance_valid(unit) and unit.unit_id == port.owner_unit_id:
			var port_data := Catalog.port_definition(unit.equipment_type, port.port_id)
			return "%s %s" % [unit.display_name, port_data.get("label", port.port_id)]
	return "%s %s" % [port.owner_unit_id, port.port_id]


func _update_network_feedback() -> void:
	if process_network == null:
		return
	network_feedback = process_network.validate_configuration()["message"]


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
	var ports: Array[Dictionary] = Catalog.port_definitions(selected_type)
	for port_data in ports:
		_add_ghost_port(port_data)
	if not ports.is_empty():
		_add_flow_direction_marker(size)
	ghost.visible = active and mode == "place"
	add_child(ghost)


func _add_ghost_port(port_data: Dictionary) -> void:
	var preview_port = ProcessPortScript.new()
	preview_port.configure(port_data, "", true)
	preview_port.position = port_data["position"]
	preview_port.name = "Preview%sPort" % String(port_data["id"]).capitalize()
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
	build_panel.position = Vector2(20.0, 20.0)
	build_panel.custom_minimum_size = Vector2(450.0, 420.0)
	build_panel.visible = false
	build_label = Label.new()
	build_label.add_theme_font_size_override("font_size", 17)
	build_label.add_theme_constant_override("outline_size", 5)
	build_label.add_theme_color_override("font_outline_color", Color.BLACK)
	build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		connection_text = "\nValgt utløp: %s" % _port_display_name(connection_source)
	build_label.text = (
		"BYGGEMODUS — %s\nPenger: %d kr\n\n%s\n\n"
		% [mode_name, available_money, Catalog.menu_text()]
		+ "Valgt: %s (%d kr)%s\n" % [data["name"], data["cost"], connection_text]
		+ "Retning: %d°  |  IN blå  |  OUT oransje\n\n" % (rotation_quadrants * 90)
		+ "Nettverk: %s\n\n" % network_feedback
		+ "1–9 / 0 / - Velg  |  Q/E Roter  |  Klikk Plasser\n"
		+ "X Fjern  |  F Koble  |  G Koble fra  |  V Valider  |  B Avslutt"
	)
