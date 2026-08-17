extends Node3D

const ProcessModelScript = preload("res://scripts/process_model.gd")
const PlayerScript = preload("res://scripts/player.gd")
const InteractiveUnitScript = preload("res://scripts/interactive_unit.gd")
const FlowVisualScript = preload("res://scripts/flow_visual.gd")
const BuildControllerScript = preload("res://scripts/build_controller.gd")
const BuildableUnitScript = preload("res://scripts/buildable_unit.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment_catalog.gd")
const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")

var process_model
var built_refinery_model
var player
var units := {}
var flow_visuals := {}
var liquid_levels := {}
var pump_rotor: Node3D
var valve_handle: Node3D
var build_controller
var build_mode_unlocked := false
var build_serial_number := 0
var build_area_label: Label3D

var hud_label: Label
var objective_label: Label
var alarm_label: Label
var prompt_label: Label
var notification_label: Label
var help_label: Label
var completion_panel: PanelContainer
var notification_time_left := 0.0


func _ready() -> void:
	process_model = ProcessModelScript.new()
	built_refinery_model = BuiltRefineryModelScript.new()
	_build_environment()
	_build_process_area()
	_build_player()
	_build_build_system()
	_build_user_interface()
	_show_notification("Varm opp anlegget før du starter flowen.", 7.0)


func _process(delta: float) -> void:
	process_model.tick(delta)
	built_refinery_model.tick(delta)
	notification_time_left = maxf(notification_time_left - delta, 0.0)
	build_controller.set_available_money(process_model.money)
	build_controller.set_process_flow(
		built_refinery_model.actual_flow_lps,
		BuiltRefineryModelScript.PUMP_CAPACITY_LPS,
		built_refinery_model.active_connection_keys()
	)
	if process_model.objective_complete and not build_mode_unlocked:
		build_mode_unlocked = true
		build_controller.set_unlocked(true)
		build_area_label.text = "BYGGEOMRÅDE 02 — ÅPENT\nTrykk B for byggemodus"
		build_area_label.modulate = Color("78e08f")
		_show_notification("NYTT OMRÅDE LÅST OPP — trykk B for byggemodus.", 8.0)
	_update_process_visuals(delta)
	_update_user_interface()
	_update_unit_statuses()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("87aeb5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8edf0")
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sunlight.light_color = Color("fff0d1")
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	add_child(sunlight)

	_create_static_box(
		"Ground",
		Vector3(0.0, -0.2, 10.0),
		Vector3(36.0, 0.4, 50.0),
		Color("55656a")
	)
	_create_static_box(
		"ProcessPad",
		Vector3(0.0, 0.03, 0.0),
		Vector3(31.0, 0.12, 13.0),
		Color("8a9190")
	)
	_create_static_box(
		"BuildPad",
		Vector3(0.0, 0.04, 20.5),
		Vector3(30.0, 0.14, 22.0),
		Color("6f7b79")
	)
	build_area_label = _create_world_label(
		"BYGGEOMRÅDE 02\nFullfør pilotoppdraget for å låse opp",
		Vector3(0.0, 2.0, 10.2),
		Color("9ce8c1")
	)

	# Safety stripes make the small greybox area readable without art assets.
	for stripe_x in [-14.0, 14.0]:
		_create_visual_box(
			Vector3(stripe_x, 0.11, 0.0),
			Vector3(0.16, 0.04, 13.0),
			Color("f2c94c")
		)


func _build_process_area() -> void:
	var raw_tank = _create_cylinder_unit(
		"raw_tank", "RÅOLJETANK", Vector3(-12.0, 2.1, 0.0),
		2.1, 4.2, Color("343b3d")
	)
	units[raw_tank.unit_id] = raw_tank
	raw_tank.make_transparent(0.48)
	_create_liquid_level(raw_tank, "raw_tank", 1.82, 3.75, Color("241815"))

	var pump = _create_box_unit(
		"pump", "P-101 PUMPE", Vector3(-7.9, 0.75, 0.0),
		Vector3(2.0, 1.5, 1.7), Color("327b72")
	)
	units[pump.unit_id] = pump
	pump_rotor = _create_pump_rotor(pump)

	var valve = _create_cylinder_unit(
		"feed_valve", "V-101 VENTIL", Vector3(-5.5, 0.85, 0.0),
		0.7, 1.7, Color("d7a62a")
	)
	units[valve.unit_id] = valve
	valve_handle = _create_valve_handle(valve)

	var heater = _create_box_unit(
		"heater", "H-101 VARME", Vector3(-2.2, 1.55, 0.0),
		Vector3(3.0, 3.1, 2.7), Color("9e4f34")
	)
	units[heater.unit_id] = heater

	var column = _create_cylinder_unit(
		"column", "D-101 DESTILLASJON", Vector3(3.4, 3.4, 0.0),
		1.55, 6.8, Color("809399")
	)
	units[column.unit_id] = column

	var light_tank = _create_cylinder_unit(
		"light_tank", "LETT PRODUKT", Vector3(9.3, 1.8, -4.5),
		1.55, 3.6, Color("bdcfca")
	)
	units[light_tank.unit_id] = light_tank
	light_tank.make_transparent(0.42)
	_create_liquid_level(light_tank, "light_tank", 1.30, 3.15, Color("a8e5dc"))

	var diesel_tank = _create_cylinder_unit(
		"diesel_tank", "DIESEL", Vector3(10.7, 1.8, 0.0),
		1.55, 3.6, Color("d2b541")
	)
	units[diesel_tank.unit_id] = diesel_tank
	diesel_tank.make_transparent(0.42)
	_create_liquid_level(diesel_tank, "diesel_tank", 1.30, 3.15, Color("e8bd22"))

	var heavy_tank = _create_cylinder_unit(
		"heavy_tank", "TUNGOLJE", Vector3(9.3, 1.8, 4.5),
		1.55, 3.6, Color("494146")
	)
	units[heavy_tank.unit_id] = heavy_tank
	heavy_tank.make_transparent(0.42)
	_create_liquid_level(heavy_tank, "heavy_tank", 1.30, 3.15, Color("241c20"))

	var terminal = _create_box_unit(
		"sales_terminal", "LAB / SALG", Vector3(13.0, 1.1, -4.6),
		Vector3(1.5, 2.2, 1.4), Color("295c7a")
	)
	units[terminal.unit_id] = terminal

	_create_pipe(Vector3(-10.0, 0.7, 0.0), Vector3(-8.9, 0.7, 0.0), "feed", Color("6c3b24"))
	_create_pipe(Vector3(-6.9, 0.7, 0.0), Vector3(-6.15, 0.7, 0.0), "feed", Color("6c3b24"))
	_create_pipe(Vector3(-4.85, 0.7, 0.0), Vector3(-3.7, 0.7, 0.0), "feed", Color("6c3b24"))
	_create_pipe(Vector3(-0.7, 0.7, 0.0), Vector3(1.85, 0.7, 0.0), "feed", Color("d47a36"))
	_create_pipe(Vector3(4.95, 2.4, 0.0), Vector3(8.8, 2.4, -4.0), "light", Color("a8e5dc"))
	_create_pipe(Vector3(4.95, 2.4, 0.0), Vector3(9.15, 2.4, 0.0), "diesel", Color("f3c62f"))
	_create_pipe(Vector3(4.95, 2.4, 0.0), Vector3(8.8, 2.4, 4.0), "heavy", Color("5b3844"))


func _build_player() -> void:
	player = PlayerScript.new()
	player.position = Vector3(-10.0, 0.1, 8.0)
	player.rotation_degrees.y = -18.0
	add_child(player)
	player.interacted.connect(_on_unit_interacted)
	player.reset_requested.connect(_on_reset_requested)


func _build_build_system() -> void:
	build_controller = BuildControllerScript.new()
	add_child(build_controller)
	build_controller.setup(player, built_refinery_model.network)
	build_controller.placement_requested.connect(_on_build_placement_requested)
	build_controller.removal_requested.connect(_on_build_removal_requested)
	build_controller.notification_requested.connect(_show_notification)


func _build_user_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(22.0, 22.0)
	hud_label.size = Vector2(430.0, 290.0)
	hud_label.add_theme_font_size_override("font_size", 19)
	hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	hud_label.add_theme_constant_override("outline_size", 7)
	canvas.add_child(hud_label)

	objective_label = Label.new()
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.offset_left = -330.0
	objective_label.offset_right = 330.0
	objective_label.offset_top = 18.0
	objective_label.offset_bottom = 82.0
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.add_theme_color_override("font_color", Color("fff3bd"))
	objective_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	objective_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(objective_label)

	alarm_label = Label.new()
	alarm_label.anchor_left = 0.5
	alarm_label.anchor_right = 0.5
	alarm_label.offset_left = -360.0
	alarm_label.offset_right = 360.0
	alarm_label.offset_top = 95.0
	alarm_label.offset_bottom = 175.0
	alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alarm_label.add_theme_font_size_override("font_size", 21)
	alarm_label.add_theme_color_override("font_color", Color("ff6b5f"))
	alarm_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	alarm_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(alarm_label)

	help_label = Label.new()
	help_label.anchor_left = 1.0
	help_label.anchor_right = 1.0
	help_label.offset_left = -275.0
	help_label.offset_right = -22.0
	help_label.offset_top = 22.0
	help_label.offset_bottom = 205.0
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label.text = "WASD  Gå\nMus  Se\nShift  Løp\nSpace  Hopp\nCtrl / C  Huk\nE  Bruk utstyr\nR  Start batch på nytt\nEsc  Frigjør mus"
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.add_theme_color_override("font_outline_color", Color.BLACK)
	help_label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(help_label)

	var crosshair := Label.new()
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -15.0
	crosshair.offset_right = 15.0
	crosshair.offset_top = -18.0
	crosshair.offset_bottom = 18.0
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 26)
	canvas.add_child(crosshair)

	prompt_label = Label.new()
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -320.0
	prompt_label.offset_right = 320.0
	prompt_label.offset_top = -110.0
	prompt_label.offset_bottom = -68.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.add_theme_color_override("font_color", Color("fff3bd"))
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(prompt_label)

	notification_label = Label.new()
	notification_label.anchor_left = 0.5
	notification_label.anchor_right = 0.5
	notification_label.anchor_top = 1.0
	notification_label.anchor_bottom = 1.0
	notification_label.offset_left = -400.0
	notification_label.offset_right = 400.0
	notification_label.offset_top = -165.0
	notification_label.offset_bottom = -125.0
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 20)
	notification_label.add_theme_color_override("font_outline_color", Color.BLACK)
	notification_label.add_theme_constant_override("outline_size", 8)
	canvas.add_child(notification_label)

	completion_panel = PanelContainer.new()
	completion_panel.anchor_left = 0.5
	completion_panel.anchor_right = 0.5
	completion_panel.anchor_top = 0.5
	completion_panel.anchor_bottom = 0.5
	completion_panel.offset_left = -260.0
	completion_panel.offset_right = 260.0
	completion_panel.offset_top = -95.0
	completion_panel.offset_bottom = 95.0
	completion_panel.visible = false
	var completion_text := Label.new()
	completion_text.text = "BATCH FULLFØRT\n\nDieselen er godkjent og solgt.\nTrykk R for å spille en ny batch."
	completion_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	completion_text.add_theme_font_size_override("font_size", 25)
	completion_panel.add_child(completion_text)
	canvas.add_child(completion_panel)


func _update_user_interface() -> void:
	var heater_state := "AV"
	if process_model.heater_setpoint_c > 0.0:
		heater_state = "%d °C mål" % int(process_model.heater_setpoint_c)
	var quality_status := "VENTER"
	if process_model.diesel_volume_l > 0.0:
		quality_status = "GODKJENT" if process_model.diesel_is_approved() else "OFF-SPEC"

	if build_mode_unlocked:
		hud_label.text = built_refinery_model.summary_text() + "\nPenger        %d kr" % process_model.money
		objective_label.text = "MÅL: Bygg og drift område 02 — selg ≥ 200 L godkjent diesel"
		alarm_label.text = ""
		help_label.text = "WASD  Gå\nMus  Se\nShift  Løp\nSpace  Hopp\nCtrl / C  Huk\nE  Bruk utstyr\nB  Byggemodus\nR  Tøm produkter\nEsc  Frigjør mus"
	else:
		hud_label.text = (
			"CRUDEWORKS — PILOTANLEGG\n\n"
			+ "Råolje       %6.0f / 1000 L\n" % process_model.crude_volume_l
			+ "Pumpe         %s\n" % ("PÅ" if process_model.pump_running else "AV")
			+ "Mateventil    %s\n" % ("ÅPEN" if process_model.feed_valve_open else "STENGT")
			+ "Flow          %6.1f L/s\n" % process_model.flow_lps
			+ "Varme         %s\n" % heater_state
			+ "Temperatur    %6.1f °C\n\n" % process_model.heater_temperature_c
			+ "Diesel        %6.0f L\n" % process_model.diesel_volume_l
			+ "Kvalitet      %6.1f %% — %s\n" % [process_model.diesel_quality_percent, quality_status]
			+ "Penger        %d kr" % process_model.money
		)
		objective_label.text = "MÅL: Produser og selg minst 200 L diesel med ≥ 90 % kvalitet"
		var alarms: Array[String] = process_model.active_alarms()
		alarm_label.text = "\n".join(alarms)
		help_label.text = "WASD  Gå\nMus  Se\nShift  Løp\nSpace  Hopp\nCtrl / C  Huk\nE  Bruk utstyr\nR  Start batch på nytt\nEsc  Frigjør mus"

	var focused = player.focused_unit()
	prompt_label.text = ""
	if focused != null and not build_controller.active:
		if focused.unit_id.begins_with("built_"):
			prompt_label.text = built_refinery_model.interaction_prompt(focused.unit_id)
		else:
			prompt_label.text = focused.interaction_prompt()
	notification_label.visible = notification_time_left > 0.0
	completion_panel.visible = process_model.objective_complete and not build_mode_unlocked
	var operation_ui_visible: bool = not build_controller.active
	hud_label.visible = operation_ui_visible
	objective_label.visible = operation_ui_visible
	alarm_label.visible = operation_ui_visible
	help_label.visible = operation_ui_visible


func _update_unit_statuses() -> void:
	units["raw_tank"].set_status("%.0f / 1000 L" % process_model.crude_volume_l)
	units["pump"].set_status("PÅ" if process_model.pump_running else "AV")
	units["pump"].set_active(process_model.pump_running)
	units["feed_valve"].set_status("ÅPEN" if process_model.feed_valve_open else "STENGT")
	units["feed_valve"].set_active(process_model.feed_valve_open)
	units["heater"].set_status("%.0f °C  |  mål %.0f °C" % [
		process_model.heater_temperature_c,
		process_model.heater_setpoint_c
	])
	units["heater"].set_active(process_model.heater_setpoint_c > 0.0, Color("ff5a35"))
	units["column"].set_status("Flow %.1f L/s" % process_model.flow_lps)
	units["column"].set_active(process_model.flow_lps > 0.0, Color("75ddff"))
	units["light_tank"].set_status("%.0f L" % process_model.light_product_l)
	units["diesel_tank"].set_status("%.0f L  |  %.1f %%" % [
		process_model.diesel_volume_l,
		process_model.diesel_quality_percent
	])
	units["diesel_tank"].set_active(process_model.diesel_is_approved(), Color("78e08f"))
	units["heavy_tank"].set_status("%.0f L" % process_model.heavy_product_l)
	var sales_ready: bool = (
		built_refinery_model.diesel_is_approved()
		if build_mode_unlocked
		else process_model.diesel_is_approved()
	)
	units["sales_terminal"].set_status("KLAR" if sales_ready else "VENTER")
	units["sales_terminal"].set_active(sales_ready, Color("78e08f"))
	for entry in build_controller.registered_units:
		var built_unit = entry["node"]
		if not is_instance_valid(built_unit):
			continue
		built_unit.set_status(built_refinery_model.unit_status(built_unit.unit_id))
		var state: Dictionary = built_refinery_model.equipment.get(built_unit.unit_id, {})
		if state.get("type", "") == "tank":
			built_unit.set_tank_fill(
				state["volume_l"] / state["capacity_l"],
				state["contents"]
			)
			built_unit.set_active(
				state["contents"] == "diesel" and state["quality_percent"] >= BuiltRefineryModelScript.APPROVED_QUALITY_PERCENT,
				Color("78e08f")
			)
		elif state.get("type", "") == "pump":
			built_unit.set_active(state["running"])
		elif state.get("type", "") == "heater":
			built_unit.set_active(state["setpoint_c"] > 0.0, Color("ff5a35"))
		elif state.get("type", "") == "column":
			built_unit.set_active(built_refinery_model.actual_flow_lps > 0.01, Color("75ddff"))


func _update_process_visuals(delta: float) -> void:
	var has_flow: bool = process_model.flow_lps > 0.01
	var normalized_flow: float = clampf(
		process_model.flow_lps / ProcessModelScript.PUMP_CAPACITY_LPS,
		0.0,
		1.0
	)
	_set_flow_group("feed", has_flow, normalized_flow)
	_set_flow_group("light", has_flow, normalized_flow * 0.75)
	_set_flow_group("diesel", has_flow, normalized_flow * 0.85)
	_set_flow_group("heavy", has_flow, normalized_flow * 0.70)

	if is_instance_valid(pump_rotor) and process_model.pump_running:
		pump_rotor.rotation.z -= delta * 7.5
	if is_instance_valid(valve_handle):
		var target_angle := deg_to_rad(90.0) if process_model.feed_valve_open else 0.0
		valve_handle.rotation.y = lerp_angle(
			valve_handle.rotation.y,
			target_angle,
			minf(delta * 8.0, 1.0)
		)

	_set_liquid_level("raw_tank", process_model.crude_volume_l / ProcessModelScript.BATCH_VOLUME_L)
	_set_liquid_level("light_tank", process_model.light_product_l / ProcessModelScript.PRODUCT_TANK_CAPACITY_L)
	_set_liquid_level("diesel_tank", process_model.diesel_volume_l / ProcessModelScript.PRODUCT_TANK_CAPACITY_L)
	_set_liquid_level("heavy_tank", process_model.heavy_product_l / ProcessModelScript.PRODUCT_TANK_CAPACITY_L)


func _set_flow_group(group_name: String, enabled: bool, normalized_rate: float) -> void:
	if not flow_visuals.has(group_name):
		return
	for visual in flow_visuals[group_name]:
		visual.set_flow(enabled, normalized_rate)


func _set_liquid_level(tank_id: String, fill_ratio: float) -> void:
	if not liquid_levels.has(tank_id):
		return
	var data: Dictionary = liquid_levels[tank_id]
	var liquid: MeshInstance3D = data["node"]
	var max_height: float = data["max_height"]
	var bottom_y: float = data["bottom_y"]
	var visible_ratio := clampf(fill_ratio, 0.0, 1.0)
	var display_height := maxf(max_height * visible_ratio, 0.015)
	liquid.scale.y = display_height
	liquid.position.y = bottom_y + display_height * 0.5
	liquid.visible = visible_ratio > 0.001


func _on_unit_interacted(unit_id: String) -> void:
	var message := ""
	match unit_id:
		"pump":
			message = process_model.toggle_pump()
		"feed_valve":
			message = process_model.toggle_feed_valve()
		"heater":
			message = process_model.cycle_heater()
		"sales_terminal":
			if process_model.objective_complete:
				var sale: Dictionary = built_refinery_model.sell_diesel()
				if sale["ok"]:
					process_model.credit(sale["revenue"])
				message = sale["message"]
			else:
				message = process_model.sell_diesel()
		"raw_tank":
			message = "Råolje: %.0f liter, %.1f °C." % [
				process_model.crude_volume_l,
				ProcessModelScript.AMBIENT_TEMPERATURE_C
			]
		"column":
			message = "Destillasjonen bruker temperaturen til å fordele produktene."
		"light_tank":
			message = "Lett produkt: %.0f liter." % process_model.light_product_l
		"diesel_tank":
			message = "Diesel: %.0f liter med %.1f %% kvalitet." % [
				process_model.diesel_volume_l,
				process_model.diesel_quality_percent
			]
		"heavy_tank":
			message = "Tungolje: %.0f liter." % process_model.heavy_product_l
		_:
			if unit_id.begins_with("built_"):
				var result: Dictionary = built_refinery_model.interact(
					unit_id,
					process_model.can_afford(BuiltRefineryModelScript.CRUDE_BATCH_COST)
				)
				if result["ok"] and result["charge"] > 0:
					process_model.purchase(result["charge"])
				message = result["message"]
	_show_notification(message)


func _on_reset_requested() -> void:
	if process_model.objective_complete or build_mode_unlocked:
		var discard_result: Dictionary = built_refinery_model.discard_products()
		_show_notification(discard_result["message"], 6.0)
		return
	process_model.reset_batch()
	_show_notification("Ny batch lastet: 1 000 liter råolje.", 5.0)


func _on_build_placement_requested(
	equipment_type: String,
	position_3d: Vector3,
	rotation_quadrants: int
) -> void:
	var definition: Dictionary = EquipmentCatalogScript.definition(equipment_type)
	var cost: int = definition["cost"]
	if not process_model.purchase(cost):
		_show_notification("Ikke nok penger til %s." % definition["name"])
		return
	build_serial_number += 1
	var unit = BuildableUnitScript.new()
	unit.configure_buildable(equipment_type, build_serial_number)
	unit.position = position_3d
	unit.rotation_quadrants = rotation_quadrants
	unit.rotation.y = deg_to_rad(float(rotation_quadrants * 90))
	add_child(unit)
	var register_result: Dictionary = built_refinery_model.register_unit(
		unit.unit_id,
		unit.equipment_type,
		unit.display_name
	)
	if not register_result["ok"]:
		unit.queue_free()
		process_model.refund(cost)
		_show_notification(register_result["message"])
		return
	build_controller.register_unit(unit)
	_show_notification("%s plassert for %d kr." % [definition["name"], cost])


func _on_build_removal_requested(unit) -> void:
	if not is_instance_valid(unit) or not build_controller.has_registered_unit(unit):
		return
	var removal_check: Dictionary = built_refinery_model.can_remove(unit.unit_id)
	if not removal_check["ok"]:
		_show_notification(removal_check["message"])
		return
	var refund_amount: int = unit.purchase_cost
	var equipment_name: String = EquipmentCatalogScript.definition(unit.equipment_type)["name"]
	built_refinery_model.unregister_unit(unit.unit_id)
	build_controller.remove_registered_unit(unit)
	process_model.refund(refund_amount)
	_show_notification("%s fjernet. %d kr refundert." % [equipment_name, refund_amount])


func _show_notification(message: String, duration := 4.0) -> void:
	notification_label.text = message if is_instance_valid(notification_label) else ""
	notification_time_left = duration


func _create_box_unit(
	unit_id: String,
	display_name: String,
	position_3d: Vector3,
	size: Vector3,
	color: Color
):
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	var unit = InteractiveUnitScript.new()
	unit.configure(unit_id, display_name, mesh, shape, color, size.y * 0.5 + 0.75)
	unit.position = position_3d
	add_child(unit)
	return unit


func _create_cylinder_unit(
	unit_id: String,
	display_name: String,
	position_3d: Vector3,
	radius: float,
	height: float,
	color: Color
):
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var unit = InteractiveUnitScript.new()
	unit.configure(unit_id, display_name, mesh, shape, color, height * 0.5 + 0.75)
	unit.position = position_3d
	add_child(unit)
	return unit


func _create_pipe(
	from: Vector3,
	to: Vector3,
	flow_group: String,
	flow_color: Color
) -> void:
	var direction := to - from
	var length := direction.length()
	var pipe := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, 0.22, 0.22)
	pipe.mesh = mesh
	pipe.position = (from + to) * 0.5
	pipe.rotation.y = -atan2(direction.z, direction.x)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263b40")
	material.metallic = 0.7
	material.roughness = 0.28
	pipe.material_override = material
	add_child(pipe)

	var flow_visual = FlowVisualScript.new()
	flow_visual.configure(from, to, flow_color)
	add_child(flow_visual)
	if not flow_visuals.has(flow_group):
		flow_visuals[flow_group] = []
	flow_visuals[flow_group].append(flow_visual)


func _create_liquid_level(
	tank,
	tank_id: String,
	radius: float,
	max_height: float,
	color: Color
) -> void:
	var liquid := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 32
	liquid.mesh = mesh
	var liquid_material := StandardMaterial3D.new()
	liquid_material.albedo_color = color
	liquid_material.metallic = 0.05
	liquid_material.roughness = 0.18
	liquid_material.emission_enabled = true
	liquid_material.emission = color
	liquid_material.emission_energy_multiplier = 0.18
	liquid.material_override = liquid_material
	tank.add_child(liquid)
	liquid_levels[tank_id] = {
		"node": liquid,
		"max_height": max_height,
		"bottom_y": -max_height * 0.5,
	}


func _create_pump_rotor(pump) -> Node3D:
	var rotor := Node3D.new()
	rotor.position = Vector3(0.0, 0.02, -0.96)
	pump.add_child(rotor)

	var rotor_material := StandardMaterial3D.new()
	rotor_material.albedo_color = Color("d8eeeb")
	rotor_material.metallic = 0.75
	rotor_material.roughness = 0.2

	for angle_degrees in [0.0, 60.0, 120.0]:
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(1.15, 0.13, 0.12)
		spoke.mesh = spoke_mesh
		spoke.rotation.z = deg_to_rad(angle_degrees)
		spoke.material_override = rotor_material
		rotor.add_child(spoke)

	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.20
	hub_mesh.bottom_radius = 0.20
	hub_mesh.height = 0.20
	hub_mesh.radial_segments = 16
	hub.mesh = hub_mesh
	hub.rotation.x = deg_to_rad(90.0)
	hub.material_override = rotor_material
	rotor.add_child(hub)
	return rotor


func _create_valve_handle(valve) -> Node3D:
	var handle_root := Node3D.new()
	handle_root.position = Vector3(0.0, 1.02, 0.0)
	valve.add_child(handle_root)

	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(1.5, 0.13, 0.22)
	handle.mesh = handle_mesh
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color("d83d32")
	handle_material.metallic = 0.4
	handle_material.roughness = 0.3
	handle.material_override = handle_material
	handle_root.add_child(handle)
	return handle_root


func _create_static_box(
	object_name: String,
	position_3d: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var body := StaticBody3D.new()
	body.name = object_name
	body.position = position_3d
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _create_visual_box(position_3d: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = position_3d
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _create_world_label(text_value: String, position_3d: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_3d
	label.font_size = 54
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	return label
