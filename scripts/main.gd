extends Node3D

const ProcessModelScript = preload("res://scripts/process_model.gd")
const PlayerScript = preload("res://scripts/player.gd")
const InteractiveUnitScript = preload("res://scripts/interactive_unit.gd")
const FlowVisualScript = preload("res://scripts/flow_visual.gd")
const BuildControllerScript = preload("res://scripts/build_controller.gd")
const BuildableUnitScript = preload("res://scripts/buildable_unit.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment_catalog.gd")
const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")
const SaveSystemScript = preload("res://scripts/save_system.gd")
const CrudeCatalogScript = preload("res://scripts/crude_contract_catalog.gd")
const LabAnalysisPanelScript = preload("res://scripts/lab_analysis_panel.gd")
const WorldLayoutScript = preload("res://scripts/world_layout.gd")
const WorldBuilderScript = preload("res://scripts/world_builder.gd")
const TankLiquidVisualScript = preload("res://scripts/tank_liquid_visual.gd")

const AUTOSAVE_INTERVAL_SECONDS := 12.0
const SAVE_DEBOUNCE_SECONDS := 1.0
const PLAYER_SAFE_SPAWN_POSITION := WorldLayoutScript.NEW_GAME_SPAWN
const PLAYER_SAFE_SPAWN_YAW := deg_to_rad(WorldLayoutScript.NEW_GAME_YAW_DEGREES)
const PLAYER_RECOVERY_COOLDOWN_SECONDS := 1.0

@export var persistence_enabled := true
@export var save_path := SaveSystemScript.DEFAULT_PATH
@export_enum("pilot_slice", "main_refinery") var playable_stage := "main_refinery"

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
var world_builder

var hud_label: Label
var objective_label: Label
var alarm_label: Label
var prompt_label: Label
var notification_label: Label
var help_label: Label
var completion_panel: PanelContainer
var batch_report_panel: PanelContainer
var batch_report_label: Label
var contract_selection_panel: PanelContainer
var contract_selection_label: Label
var product_dispatch_panel: PanelContainer
var product_dispatch_label: Label
var control_station_panel: PanelContainer
var control_station_label: Label
var lab_analysis_panel
var startup_panel: PanelContainer
var startup_label: Label
var world_debug_label: Label
var notification_time_left := 0.0
var batch_report_visible := false
var contract_selection_visible := false
var contract_selection_source_id := ""
var product_dispatch_visible := false
var physical_dispatch_terminal_id := ""
var control_station_visible := false
var control_station_feedback := ""
var control_station_feedback_is_error := false
var control_station_train_index := 0
var discard_confirmation_time_left := 0.0
var discard_confirmation_revision := -1
var startup_choice_state := ""
var pending_save_data: Dictionary = {}
var pending_save_recovered := false
var persistence_ready := false
var save_debounce_time_left := -1.0
var autosave_time_left := AUTOSAVE_INTERVAL_SECONDS
var save_feedback_requested := false
var suppress_save_requests := false
var player_recovery_cooldown := 0.0


func _ready() -> void:
	process_model = ProcessModelScript.new()
	built_refinery_model = BuiltRefineryModelScript.new()
	_build_environment()
	_build_process_area()
	_build_player()
	_build_build_system()
	_build_site_logistics()
	_build_user_interface()
	_update_process_visuals(0.0)
	if persistence_enabled:
		built_refinery_model.network.topology_changed.connect(_schedule_save)
		_initialize_persistence()
	else:
		persistence_ready = false
		_show_notification("Varm opp anlegget før du starter flowen.", 7.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F7:
		world_debug_label.visible = not world_debug_label.visible
		_update_world_debug_overlay()
		_show_notification("World debug: %s" % ("PÅ" if world_debug_label.visible else "AV"), 2.0)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_F8:
		world_builder.set_area_labels_visible(not world_builder.area_labels_visible)
		_show_notification("Area labels: %s" % ("PÅ" if world_builder.area_labels_visible else "AV"), 2.0)
		get_viewport().set_input_as_handled()
		return
	if not startup_choice_state.is_empty():
		_handle_startup_input(event)
		get_viewport().set_input_as_handled()
		return
	if contract_selection_visible:
		_handle_contract_selection_input(event)
		get_viewport().set_input_as_handled()
		return
	if product_dispatch_visible:
		_handle_product_dispatch_input(event)
		get_viewport().set_input_as_handled()
		return
	if control_station_visible:
		_handle_control_station_input(event)
		get_viewport().set_input_as_handled()
		return
	if lab_analysis_panel != null and lab_analysis_panel.visible:
		_handle_lab_analysis_input(event)
		get_viewport().set_input_as_handled()
		return
	if batch_report_visible and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		_dismiss_batch_report()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and discard_confirmation_time_left > 0.0:
		discard_confirmation_time_left = 0.0
		discard_confirmation_revision = -1
		_show_notification("Tømming avbrutt.")


func _process(delta: float) -> void:
	process_model.tick(delta)
	built_refinery_model.tick(delta)
	player_recovery_cooldown = maxf(player_recovery_cooldown - delta, 0.0)
	if player_recovery_cooldown <= 0.0 and WorldLayoutScript.player_requires_recovery(player.global_position):
		_recover_player_from_out_of_bounds()
	notification_time_left = maxf(notification_time_left - delta, 0.0)
	discard_confirmation_time_left = maxf(discard_confirmation_time_left - delta, 0.0)
	if discard_confirmation_time_left <= 0.0:
		discard_confirmation_revision = -1
	_update_autosave(delta)
	build_controller.set_available_money(process_model.money)
	build_controller.set_locked_equipment(_starter_equipment_locks())
	build_controller.set_hidden_equipment(_starter_equipment_hidden())
	build_controller.set_process_flow(
		built_refinery_model.actual_flow_lps,
		BuiltRefineryModelScript.PUMP_MAX_FLOW_LPS,
		built_refinery_model.active_connection_keys()
	)
	if process_model.objective_complete and not build_mode_unlocked:
		build_mode_unlocked = true
		build_controller.set_unlocked(true)
		_show_notification(
			"PILOT COMPLETE — Area 02 commissioning unlocked. Receive the free Standard delivery at Harbor CI-101.",
			8.0
		)
		_schedule_save()
	world_builder.set_build_visualization_visible(build_controller.active)
	_update_process_visuals(delta)
	_update_user_interface()
	_update_world_debug_overlay()
	_update_unit_statuses()


func _starter_equipment_locks() -> Dictionary:
	# Basic tanks, pumps, valve, heater and column are always free-build tools.
	# The remaining units become available when their process problem is visible.
	var locks := {}
	if not built_refinery_model.commissioning_contract_complete:
		locks["treatment"] = "fullfør første Area 02-leveranse"
		locks["header"] = "produser første batch"
		locks["product_header"] = "produser første batch"
		locks["power_unit"] = "etabler første prosesstog"
		locks["vacuum_distillation"] = "produser Tung rest"
		locks["catalytic_cracking"] = "produser Vacuum Gas Oil"
		return locks
	if not built_refinery_model.first_atmospheric_production:
		locks["header"] = "produser første batch"
		locks["product_header"] = "produser første batch"
		locks["power_unit"] = "etabler første prosesstog"
		locks["vacuum_distillation"] = "produser Tung rest"
		locks["catalytic_cracking"] = "produser Vacuum Gas Oil"
		return locks
	var vgo_seen := false
	for state in built_refinery_model.equipment.values():
		if state["type"] == "vacuum_distillation" and float(state.get("processed_total_l", 0.0)) > 0.001:
			vgo_seen = true
			break
	if not vgo_seen:
		locks["catalytic_cracking"] = "produser Vacuum Gas Oil i VDU-301"
	return locks


func _starter_equipment_hidden() -> Dictionary:
	# Headers only add value after the player has one atmospheric product route
	# and can understand why a second train or storage destination matters.
	if not built_refinery_model.first_atmospheric_production:
		return {
			"header": true,
			"product_header": true,
		}
	return {}


func _build_environment() -> void:
	world_builder = WorldBuilderScript.new()
	world_builder.name = "GrayboxWorld"
	add_child(world_builder)
	world_builder.build_world()


func _build_process_area() -> void:
	var raw_tank = _create_cylinder_unit(
		"raw_tank", "RÅOLJETANK", Vector3(-12.0, 2.1, 0.0),
		2.1, 4.2, Color("343b3d")
	)
	units[raw_tank.unit_id] = raw_tank
	TankLiquidVisualScript.open_transparent_shell(raw_tank.mesh_instance.mesh as CylinderMesh)
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
	TankLiquidVisualScript.open_transparent_shell(light_tank.mesh_instance.mesh as CylinderMesh)
	light_tank.make_transparent(0.42)
	_create_liquid_level(light_tank, "light_tank", 1.30, 3.15, Color("a8e5dc"))

	var diesel_tank = _create_cylinder_unit(
		"diesel_tank", "DIESEL", Vector3(10.7, 1.8, 0.0),
		1.55, 3.6, Color("d2b541")
	)
	units[diesel_tank.unit_id] = diesel_tank
	TankLiquidVisualScript.open_transparent_shell(diesel_tank.mesh_instance.mesh as CylinderMesh)
	diesel_tank.make_transparent(0.42)
	_create_liquid_level(diesel_tank, "diesel_tank", 1.30, 3.15, Color("e8bd22"))

	var heavy_tank = _create_cylinder_unit(
		"heavy_tank", "TUNGOLJE", Vector3(9.3, 1.8, 4.5),
		1.55, 3.6, Color("494146")
	)
	units[heavy_tank.unit_id] = heavy_tank
	TankLiquidVisualScript.open_transparent_shell(heavy_tank.mesh_instance.mesh as CylinderMesh)
	heavy_tank.make_transparent(0.42)
	_create_liquid_level(heavy_tank, "heavy_tank", 1.30, 3.15, Color("241c20"))

	var terminal = _create_box_unit(
		"sales_terminal", "LAB-101", Vector3(13.0, 1.1, -4.6),
		Vector3(1.5, 2.2, 1.4), Color("295c7a")
	)
	units[terminal.unit_id] = terminal

	var control_station = _create_box_unit(
		"area02_control", "LS-201 LOKALSTASJON", Vector3(-16.0, 1.1, 13.0),
		Vector3(1.6, 2.2, 1.2), Color("263943")
	)
	units[control_station.unit_id] = control_station

	_create_pipe(Vector3(-10.0, 0.7, 0.0), Vector3(-8.9, 0.7, 0.0), "feed", Color("6c3b24"))
	_create_pipe(Vector3(-6.9, 0.7, 0.0), Vector3(-6.15, 0.7, 0.0), "feed", Color("6c3b24"))
	_create_pipe(Vector3(-4.85, 0.7, 0.0), Vector3(-3.7, 0.7, 0.0), "feed", Color("6c3b24"))
	_create_pipe(Vector3(-0.7, 0.7, 0.0), Vector3(1.85, 0.7, 0.0), "feed", Color("d47a36"))
	_create_pipe(Vector3(4.95, 2.4, 0.0), Vector3(8.8, 2.4, -4.0), "light", Color("a8e5dc"))
	_create_pipe(Vector3(4.95, 2.4, 0.0), Vector3(9.15, 2.4, 0.0), "diesel", Color("f3c62f"))
	_create_pipe(Vector3(4.95, 2.4, 0.0), Vector3(8.8, 2.4, 4.0), "heavy", Color("5b3844"))


func _build_player() -> void:
	player = PlayerScript.new()
	player.position = PLAYER_SAFE_SPAWN_POSITION
	player.rotation.y = PLAYER_SAFE_SPAWN_YAW
	add_child(player)
	player.interacted.connect(_on_unit_interacted)
	player.secondary_interacted.connect(_on_secondary_unit_interacted)
	player.maintenance_interacted.connect(_on_maintenance_unit_interacted)
	player.reset_requested.connect(_on_reset_requested)


func _recover_player_from_out_of_bounds() -> void:
	player.global_position = PLAYER_SAFE_SPAWN_POSITION
	player.rotation.y = PLAYER_SAFE_SPAWN_YAW
	player.velocity = Vector3.ZERO
	player_recovery_cooldown = PLAYER_RECOVERY_COOLDOWN_SECONDS
	_show_notification("Du falt utenfor anlegget og ble flyttet til et trygt sted.", 4.0)


func _build_build_system() -> void:
	build_controller = BuildControllerScript.new()
	add_child(build_controller)
	build_controller.setup(player, built_refinery_model.network)
	build_controller.placement_requested.connect(_on_build_placement_requested)
	build_controller.removal_requested.connect(_on_build_removal_requested)
	build_controller.notification_requested.connect(_show_notification)


func _build_site_logistics() -> void:
	_create_harbor_logistics_terminal(
		"crude_intake", "crude_intake_terminal",
		EquipmentCatalogScript.CRUDE_TERMINAL_ID, "CI-101 CRUDE INTAKE"
	)
	_create_harbor_logistics_terminal(
		"product_dispatch", "product_dispatch_terminal",
		EquipmentCatalogScript.PRODUCT_TERMINAL_ID, "PD-101 PRODUCT DISPATCH"
	)
	_create_process_boundary_tie_in(
		"crude_intake", EquipmentCatalogScript.CRUDE_TIE_IN_ID,
		"CI-201 CRUDE FEED TIE-IN"
	)
	_create_process_boundary_tie_in(
		"product_dispatch", EquipmentCatalogScript.PRODUCT_TIE_IN_ID,
		"PD-201 PRODUCT EXPORT TIE-IN"
	)
	var generator = _create_box_unit(
		"area02_generator", "PG-101 GENERATOR", Vector3(-24.0, 1.2, 19.0),
		Vector3(2.6, 2.4, 2.2), Color("c99b32")
	)
	units[generator.unit_id] = generator
	var mcc = _create_box_unit(
		"area02_mcc", "MCC-101 POWER", Vector3(-24.0, 1.35, 23.0),
		Vector3(2.4, 2.7, 1.8), Color("394d59")
	)
	units[mcc.unit_id] = mcc
	var fuel_tank = _create_cylinder_unit(
		"generator_fuel", "GF-101 DIESEL DAY TANK", Vector3(-19.5, 1.5, 19.0),
		1.15, 3.0, Color("8a7134")
	)
	units[fuel_tank.unit_id] = fuel_tank
	TankLiquidVisualScript.open_transparent_shell(fuel_tank.mesh_instance.mesh as CylinderMesh)
	fuel_tank.make_transparent(0.72)
	_create_liquid_level(
		fuel_tank, "generator_fuel", 0.96, 2.58,
		BuildableUnitScript.TANK_LIQUID_COLORS["diesel"]
	)
	fuel_tank.create_alarm_beacon(Vector3(0.0, 1.72, 0.0))
	var instrument_air = _create_box_unit(
		"instrument_air", "IA-101 INSTRUMENT AIR", Vector3(-16.0, 1.1, 19.0),
		Vector3(2.4, 2.2, 2.0), Color("47768a")
	)
	units[instrument_air.unit_id] = instrument_air
	instrument_air.create_alarm_beacon(Vector3(0.0, 1.32, 0.0))
	var cooling_tower = _create_cylinder_unit(
		"cooling_tower", "CT-101 COOLING TOWER", Vector3(-19.5, 2.0, 24.5),
		1.45, 4.0, Color("587d75")
	)
	units[cooling_tower.unit_id] = cooling_tower
	var cooling_pump = _create_box_unit(
		"cooling_water", "CWP-101 COOLING WATER", Vector3(-16.0, 0.85, 24.5),
		Vector3(2.2, 1.7, 2.0), Color("356c78")
	)
	units[cooling_pump.unit_id] = cooling_pump
	cooling_pump.create_alarm_beacon(Vector3(0.0, 1.07, 0.0))


func _create_harbor_logistics_terminal(
	area_id: String,
	equipment_type: String,
	unit_id: String,
	display_name: String
) -> void:
	var definition := EquipmentCatalogScript.definition(equipment_type)
	var unit = BuildableUnitScript.new()
	unit.configure_buildable(equipment_type, 0, unit_id, display_name)
	unit.remove_from_group("player_built")
	unit.add_to_group("fixed_site")
	unit.position = WorldLayoutScript.harbor_logistics_position(
		area_id, float(definition["size"].y)
	)
	var local_process_facing := Vector2(0.0, -1.0) if area_id == "crude_intake" else Vector2(0.0, 1.0)
	unit.rotation_quadrants = WorldLayoutScript.cardinal_rotation_quadrants(
		local_process_facing,
		WorldLayoutScript.harbor_process_direction(area_id)
	)
	unit.rotation.y = deg_to_rad(float(unit.rotation_quadrants * 90))
	unit.set_meta("canonical_area_id", area_id)
	unit.set_meta("canonical_anchor_id", area_id)
	unit.set_meta("logistics_terminal_only", true)
	unit.set_meta(
		"process_route_target_id",
		WorldLayoutScript.area_by_id(area_id).get("process_route_target_id", "")
	)
	add_child(unit)
	build_controller.register_fixed_unit(unit)


func _create_process_boundary_tie_in(
	equipment_type: String,
	unit_id: String,
	display_name: String
) -> void:
	var definition := EquipmentCatalogScript.definition(equipment_type)
	var spec := WorldLayoutScript.process_boundary_spec(equipment_type)
	var unit = BuildableUnitScript.new()
	unit.configure_buildable(equipment_type, 0, unit_id, display_name)
	unit.remove_from_group("player_built")
	unit.add_to_group("fixed_site")
	unit.position = WorldLayoutScript.process_boundary_position(
		equipment_type, float(definition["size"].y)
	)
	var local_process_facing := (
		Vector2(0.0, -1.0) if equipment_type == "crude_intake" else Vector2(0.0, 1.0)
	)
	unit.rotation_quadrants = WorldLayoutScript.cardinal_rotation_quadrants(
		local_process_facing, spec["process_facing"]
	)
	unit.rotation.y = deg_to_rad(float(unit.rotation_quadrants * 90))
	unit.set_meta("process_boundary", true)
	unit.set_meta("zero_hold_up", true)
	unit.set_meta("boundary_side", spec["side"])
	add_child(unit)
	built_refinery_model.register_unit(unit.unit_id, unit.equipment_type, unit.display_name)
	build_controller.register_fixed_unit(unit)


func _build_user_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	hud_label = Label.new()
	hud_label.position = Vector2(22.0, 185.0)
	hud_label.size = Vector2(430.0, 290.0)
	hud_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_label.add_theme_font_size_override("font_size", 19)
	hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	hud_label.add_theme_constant_override("outline_size", 7)
	canvas.add_child(hud_label)

	objective_label = Label.new()
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.offset_left = -320.0
	objective_label.offset_right = 320.0
	objective_label.offset_top = 18.0
	objective_label.offset_bottom = 88.0
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	alarm_label.offset_top = 94.0
	alarm_label.offset_bottom = 166.0
	alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alarm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alarm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	help_label.offset_top = 185.0
	help_label.offset_bottom = 390.0
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	prompt_label.offset_top = -128.0
	prompt_label.offset_bottom = -54.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	notification_label.offset_top = -218.0
	notification_label.offset_bottom = -140.0
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	batch_report_panel = PanelContainer.new()
	batch_report_panel.anchor_left = 0.5
	batch_report_panel.anchor_right = 0.5
	batch_report_panel.anchor_top = 0.5
	batch_report_panel.anchor_bottom = 0.5
	batch_report_panel.offset_left = -330.0
	batch_report_panel.offset_right = 330.0
	batch_report_panel.offset_top = -260.0
	batch_report_panel.offset_bottom = 260.0
	batch_report_panel.visible = false
	batch_report_label = Label.new()
	batch_report_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	batch_report_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	batch_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	batch_report_label.add_theme_font_size_override("font_size", 21)
	batch_report_label.add_theme_color_override("font_color", Color("fff3bd"))
	batch_report_label.add_theme_constant_override("line_spacing", 4)
	batch_report_panel.add_child(batch_report_label)
	canvas.add_child(batch_report_panel)

	contract_selection_panel = PanelContainer.new()
	contract_selection_panel.anchor_left = 0.5
	contract_selection_panel.anchor_right = 0.5
	contract_selection_panel.anchor_top = 0.5
	contract_selection_panel.anchor_bottom = 0.5
	contract_selection_panel.offset_left = -350.0
	contract_selection_panel.offset_right = 350.0
	contract_selection_panel.offset_top = -235.0
	contract_selection_panel.offset_bottom = 235.0
	contract_selection_panel.visible = false
	contract_selection_label = Label.new()
	contract_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contract_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contract_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_selection_label.add_theme_font_size_override("font_size", 22)
	contract_selection_label.add_theme_color_override("font_color", Color("fff3bd"))
	contract_selection_label.add_theme_constant_override("line_spacing", 5)
	contract_selection_panel.add_child(contract_selection_label)
	canvas.add_child(contract_selection_panel)

	product_dispatch_panel = PanelContainer.new()
	product_dispatch_panel.anchor_left = 0.5
	product_dispatch_panel.anchor_right = 0.5
	product_dispatch_panel.anchor_top = 0.5
	product_dispatch_panel.anchor_bottom = 0.5
	product_dispatch_panel.offset_left = -330.0
	product_dispatch_panel.offset_right = 330.0
	product_dispatch_panel.offset_top = -195.0
	product_dispatch_panel.offset_bottom = 195.0
	product_dispatch_panel.visible = false
	product_dispatch_label = Label.new()
	product_dispatch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	product_dispatch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	product_dispatch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	product_dispatch_label.add_theme_font_size_override("font_size", 22)
	product_dispatch_label.add_theme_color_override("font_color", Color("d9f4ff"))
	product_dispatch_panel.add_child(product_dispatch_label)
	canvas.add_child(product_dispatch_panel)

	control_station_panel = PanelContainer.new()
	control_station_panel.anchor_left = 0.5
	control_station_panel.anchor_right = 0.5
	control_station_panel.anchor_top = 0.5
	control_station_panel.anchor_bottom = 0.5
	control_station_panel.offset_left = -390.0
	control_station_panel.offset_right = 390.0
	control_station_panel.offset_top = -300.0
	control_station_panel.offset_bottom = 300.0
	control_station_panel.visible = false
	control_station_label = Label.new()
	control_station_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_station_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	control_station_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_station_label.add_theme_font_size_override("font_size", 20)
	control_station_label.add_theme_color_override("font_color", Color("c9f4ff"))
	control_station_label.add_theme_constant_override("line_spacing", 3)
	control_station_panel.add_child(control_station_label)
	canvas.add_child(control_station_panel)

	lab_analysis_panel = LabAnalysisPanelScript.new()
	canvas.add_child(lab_analysis_panel)

	startup_panel = PanelContainer.new()
	startup_panel.anchor_left = 0.5
	startup_panel.anchor_right = 0.5
	startup_panel.anchor_top = 0.5
	startup_panel.anchor_bottom = 0.5
	startup_panel.offset_left = -310.0
	startup_panel.offset_right = 310.0
	startup_panel.offset_top = -155.0
	startup_panel.offset_bottom = 155.0
	startup_panel.visible = false
	startup_label = Label.new()
	startup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	startup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	startup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	startup_label.add_theme_font_size_override("font_size", 24)
	startup_label.add_theme_color_override("font_color", Color("fff3bd"))
	startup_panel.add_child(startup_label)
	canvas.add_child(startup_panel)

	world_debug_label = Label.new()
	world_debug_label.anchor_left = 1.0
	world_debug_label.anchor_right = 1.0
	world_debug_label.anchor_top = 1.0
	world_debug_label.anchor_bottom = 1.0
	world_debug_label.offset_left = -360.0
	world_debug_label.offset_right = -18.0
	world_debug_label.offset_top = -132.0
	world_debug_label.offset_bottom = -18.0
	world_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	world_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	world_debug_label.add_theme_font_size_override("font_size", 14)
	world_debug_label.add_theme_color_override("font_color", Color("ccebf2"))
	world_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	world_debug_label.add_theme_constant_override("outline_size", 5)
	world_debug_label.visible = OS.is_debug_build()
	canvas.add_child(world_debug_label)


func _update_world_debug_overlay() -> void:
	if world_debug_label == null or not world_debug_label.visible:
		return
	var position_3d: Vector3 = player.global_position
	var bounds: Rect2 = WorldLayoutScript.WORLD_BOUNDS
	var area_id := WorldLayoutScript.area_id_at(Vector2(position_3d.x, position_3d.z))
	world_debug_label.text = (
		"WORLD DEBUG  •  area: %s\n" % area_id
		+ "XYZ  %7.1f  %5.1f  %7.1f\n" % [position_3d.x, position_3d.y, position_3d.z]
		+ "bounds  X %.0f..%.0f  Z %.0f..%.0f\n" % [
			bounds.position.x, bounds.end.x, bounds.position.y, bounds.end.y,
		]
		+ "spawn  %.0f, %.1f, %.0f" % [
			WorldLayoutScript.NEW_GAME_SPAWN.x,
			WorldLayoutScript.NEW_GAME_SPAWN.y,
			WorldLayoutScript.NEW_GAME_SPAWN.z,
		]
	)


func _update_user_interface() -> void:
	var heater_state := "AV"
	if process_model.heater_setpoint_c > 0.0:
		heater_state = "%d °C mål" % int(process_model.heater_setpoint_c)
	var quality_status := "VENTER"
	match process_model.diesel_spec_status:
		ProcessModelScript.DIESEL_SPEC_UNKNOWN:
			quality_status = "IKKE ANALYSERT"
		ProcessModelScript.DIESEL_SPEC_ON_SPEC:
			quality_status = "GODKJENT"
		ProcessModelScript.DIESEL_SPEC_OFF_SPEC:
			quality_status = "OFF-SPEC"

	if build_mode_unlocked and playable_stage == "main_refinery":
		hud_label.text = built_refinery_model.summary_text() + "\nPenger        %d kr" % process_model.money
		objective_label.text = built_refinery_model.objective_text()
		alarm_label.text = built_refinery_model.alarm_text()
		help_label.text = (
			"WASD  Gå\nMus  Se\nShift  Løp\nSpace  Hopp\nCtrl / C  Huk\nE  Bruk utstyr"
			+ ("\nQ  Endre pumpeflow" if built_refinery_model.commissioning_contract_complete else "")
			+ "\nB  Byggemodus\nR x2  Sikker produkttømming\nEsc  Frigjør mus"
		)
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
		objective_label.text = process_model.pilot_objective_text()
		if process_model.objective_complete:
			objective_label.text = (
				"PILOT COMPLETE\n"
				+ "Area 02 commissioning becomes available in the next development stage."
			)
		var alarms: Array[String] = process_model.active_alarms()
		alarm_label.text = "\n".join(alarms)
		if build_mode_unlocked and not built_refinery_model.alarm_text().is_empty():
			# The Pilot-stage cap hides only the premature Area 02 objective. It
			# must not suppress real alarms from equipment the player builds for
			# construction validation after the Pilot sale.
			alarm_label.text = built_refinery_model.alarm_text()
		help_label.text = (
			"WASD  Gå\nMus  Se\nShift  Løp\nSpace  Hopp\nCtrl / C  Huk\nE  Bruk utstyr"
			+ ("\nB  Byggemodus" if build_mode_unlocked else "")
			+ "\nR  Start batch på nytt\nEsc  Frigjør mus"
		)

	var focused = player.focused_unit()
	prompt_label.text = ""
	if (
		focused != null
		and not build_controller.active
		and not batch_report_visible
		and not contract_selection_visible
		and not product_dispatch_visible
		and not control_station_visible
		and not lab_analysis_panel.visible
		and startup_choice_state.is_empty()
	):
		if focused.unit_id == "area02_generator":
			prompt_label.text = built_refinery_model.generator_context_prompt()
		elif focused.unit_id == "area02_mcc":
			prompt_label.text = built_refinery_model.mcc_context_prompt()
		elif focused.unit_id == "generator_fuel":
			prompt_label.text = "GF-101 %.1f / %.0f L | use %.2f L/min\nE — transfer up to %.0f L stored diesel" % [
				built_refinery_model.generator_fuel_l, BuiltRefineryModelScript.GENERATOR_FUEL_CAPACITY_L,
				built_refinery_model.current_generator_fuel_use_lpm(), BuiltRefineryModelScript.GENERATOR_REFUEL_BATCH_L,
			]
		elif focused.unit_id == "instrument_air":
			prompt_label.text = "IA-101 %s | %.0f kW | TIC-201 FAIL CLOSED\nE — %s compressor" % [
				"NORMAL" if built_refinery_model.instrument_air_available() else "LOST",
				built_refinery_model.utility_power_demand_kw("instrument_air"),
				"stop" if built_refinery_model.instrument_air_compressor_running else "start",
			]
		elif focused.unit_id in ["cooling_tower", "cooling_water"]:
			prompt_label.text = "CT-101 / CWP-101 %s | %.0f kW\nE — %s cooling-water pump" % [
				"NORMAL" if built_refinery_model.cooling_water_available() else "LOST",
				built_refinery_model.utility_power_demand_kw("cooling_water"),
				"stop" if built_refinery_model.cooling_water_pump_running else "start",
			]
		elif focused.unit_id.begins_with("built_"):
			prompt_label.text = built_refinery_model.interaction_prompt(focused.unit_id)
		elif focused.unit_id == "sales_terminal" and built_refinery_model.commissioning_contract_complete:
			var lab_status: Dictionary = built_refinery_model.lab_dispatch_status()
			if not built_refinery_model.can_use_site_consumer("lab")["ok"]:
				prompt_label.text = "LAB-101 — POWER LOST"
			elif lab_status.get("sample_current", false):
				var sample_id: String = String(lab_status.get("sample_id", "dieselprøve"))
				if lab_status.get("analyzed", false):
					if lab_status.get("dispatch_ready", false):
						prompt_label.text = "E — vis analyseresultat; send ved PD-101"
					elif lab_status.get("approved", false):
						prompt_label.text = "E — vis resultat — stopp pumpen"
					else:
						prompt_label.text = "E — vis analyseresultat %s" % sample_id
				else:
					prompt_label.text = "E — analyser %s" % sample_id
			else:
				prompt_label.text = (
					"LAB-101 — venter på diesel"
					if built_refinery_model.product_volume_l() <= 0.001
					else "LAB — ta prøve ved den aktive dieseltanken"
				)
		elif focused.unit_id == "area02_control" and not built_refinery_model.commissioning_contract_complete:
			prompt_label.text = "LS-201 — LÅST: fullfør oppstarten av Område 02"
		else:
			prompt_label.text = focused.interaction_prompt()
	notification_label.visible = notification_time_left > 0.0
	completion_panel.visible = process_model.objective_complete and not build_mode_unlocked
	batch_report_panel.visible = batch_report_visible and not build_controller.active
	contract_selection_panel.visible = contract_selection_visible and not build_controller.active
	product_dispatch_panel.visible = product_dispatch_visible and not build_controller.active
	control_station_panel.visible = control_station_visible and not build_controller.active
	if control_station_visible:
		_update_control_station_text()
	startup_panel.visible = not startup_choice_state.is_empty()
	var operation_ui_visible: bool = not build_controller.active
	var regular_ui_visible: bool = (
		operation_ui_visible
		and not batch_report_visible
		and not contract_selection_visible
		and not product_dispatch_visible
		and not control_station_visible
		and not lab_analysis_panel.visible
		and startup_choice_state.is_empty()
	)
	hud_label.visible = regular_ui_visible
	objective_label.visible = regular_ui_visible
	alarm_label.visible = regular_ui_visible
	help_label.visible = regular_ui_visible


func _update_unit_statuses() -> void:
	var power: Dictionary = built_refinery_model.power_status()
	units["area02_generator"].set_status(
		"RUNNING | %.0f kW\nFUEL %.1f L | %.2f L/min" % [
			BuiltRefineryModelScript.STARTER_GENERATOR_CAPACITY_KW,
			built_refinery_model.generator_fuel_l,
			built_refinery_model.current_generator_fuel_use_lpm(),
		]
		if built_refinery_model.starter_generator_running
		else "STOPPED | 0 kW\nFUEL %.1f L" % built_refinery_model.generator_fuel_l
	)
	units["area02_generator"].set_active(
		built_refinery_model.starter_generator_running, Color("f6cf63")
	)
	units["area02_mcc"].set_status(
		"TRIPPED — %s\n%.0f > %.0f kW" % [
			"OVERLOAD" if power["trip_id"] == "overload" else "SUPPLY LOSS",
			power["last_trip_demand_kw"], power["last_trip_capacity_kw"],
		]
		if power["tripped"]
		else "GEN %.0f | LOAD %.0f\n%s | RESERVE %.0f" % [
			power["capacity_kw"], power["demand_kw"],
			"ENERGIZED — %s" % power["status"] if power["bus_available"] else "BUS OFFLINE",
			power["reserve_kw"],
		]
	)
	units["area02_mcc"].set_active(
		power["tripped"] or not power["bus_available"],
		Color("ff4d4d") if power["tripped"] else Color("ffb347")
	)
	units["generator_fuel"].set_status("%.1f / %.0f L\nUSE %.2f L/min" % [
		built_refinery_model.generator_fuel_l, BuiltRefineryModelScript.GENERATOR_FUEL_CAPACITY_L,
		built_refinery_model.current_generator_fuel_use_lpm(),
	])
	units["generator_fuel"].set_active(built_refinery_model.generator_fuel_l <= 5.0, Color("ff6b5f"))
	units["instrument_air"].set_status("%s | %.0f kW\nTIC-201 FAIL CLOSED" % [
		"NORMAL" if built_refinery_model.instrument_air_available() else "LOST",
		built_refinery_model.utility_power_demand_kw("instrument_air"),
	])
	units["instrument_air"].set_active(built_refinery_model.instrument_air_available(), Color("7fc8ff"))
	units["cooling_tower"].set_status("READY\nCDU HEAT REJECTION")
	units["cooling_tower"].set_active(built_refinery_model.cooling_water_available(), Color("75ddff"))
	units["cooling_water"].set_status("%s | %.0f kW\nCDU COOLING" % [
		"NORMAL" if built_refinery_model.cooling_water_available() else "LOST",
		built_refinery_model.utility_power_demand_kw("cooling_water"),
	])
	units["cooling_water"].set_active(built_refinery_model.cooling_water_available(), Color("75ddff"))
	var fixed_alarm_severities := _built_alarm_severities()
	units["generator_fuel"].set_alarm_severity(String(fixed_alarm_severities.get("generator_fuel", "")))
	units["instrument_air"].set_alarm_severity(String(fixed_alarm_severities.get("instrument_air", "")))
	units["cooling_water"].set_alarm_severity(String(fixed_alarm_severities.get("cooling_water", "")))
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
	var sales_ready: bool = process_model.diesel_is_approved()
	var sales_status := "KLAR" if sales_ready else "VENTER"
	if build_mode_unlocked:
		sales_ready = built_refinery_model.diesel_is_dispatch_ready()
		if built_refinery_model.commissioning_contract_complete:
			var lab_status: Dictionary = built_refinery_model.lab_dispatch_status()
			if not power["bus_available"]:
				sales_status = "POWER LOST"
			elif built_refinery_model.product_volume_l() <= 0.001:
				sales_status = "VENTER"
			elif lab_status.get("sample_current", false) and not lab_status.get("analyzed", false):
				sales_status = "PRØVE KLAR"
			elif lab_status.get("analyzed", false):
				if lab_status.get("dispatch_ready", false):
					sales_status = "GODKJENT — SEND"
				elif lab_status.get("approved", false):
					sales_status = "GODKJENT — STOPP PUMPE"
				else:
					sales_status = String(lab_status.get("status", "OFF-SPEC"))
			else:
				sales_status = "PRØVE KREVES"
		else:
			sales_status = "KLAR" if sales_ready else "VENTER"
	units["sales_terminal"].set_status(sales_status)
	units["sales_terminal"].set_active(sales_ready, Color("78e08f"))
	var control_snapshot: Dictionary = built_refinery_model.control_snapshot()
	var control_status := "LÅST"
	var control_alarm := false
	if control_snapshot.get("unlocked", false):
		if not power["bus_available"]:
			control_alarm = true
			control_status = "POWER LOST"
		elif control_snapshot.get("valid", false):
			control_alarm = (
				not String(control_snapshot.get("alarm", "")).is_empty()
				or not String(control_snapshot.get("temperature_trip_message", "")).is_empty()
			)
			control_status = (
				"ALARM"
				if control_alarm
				else (
					"VENTER — RÅOLJE"
					if float(control_snapshot.get("ideal_temperature_c", 0.0)) <= 0.0
					else "KLAR  |  %.1f L/s" % float(control_snapshot["actual_flow_lps"])
				)
			)
		else:
			control_status = (
				"UGYLDIG — FLERE LINJER"
				if control_snapshot.get("ambiguous_routes", false)
				else "VENTER — NETTVERK"
			)
	units["area02_control"].set_status(control_status)
	units["area02_control"].set_active(
		control_station_visible or control_alarm,
		Color("ff6b5f") if control_alarm else Color("75ddff")
	)
	var active_route: Dictionary = built_refinery_model.active_runtime_route()
	var built_alarm_severities := _built_alarm_severities()
	for entry in build_controller.registered_units:
		var built_unit = entry["node"]
		if not is_instance_valid(built_unit):
			continue
		if built_unit.unit_id == EquipmentCatalogScript.CRUDE_TERMINAL_ID:
			built_unit.set_status(built_refinery_model.unit_status(EquipmentCatalogScript.CRUDE_TIE_IN_ID))
			built_unit.set_onboarding_guidance(not built_refinery_model.first_intake_received)
		elif built_unit.unit_id == EquipmentCatalogScript.PRODUCT_TERMINAL_ID:
			built_unit.set_status(built_refinery_model.unit_status(EquipmentCatalogScript.PRODUCT_TIE_IN_ID))
			built_unit.set_onboarding_guidance(
				built_refinery_model.first_atmospheric_production
				and not built_refinery_model.first_physical_dispatch_completed
			)
		else:
			built_unit.set_status(built_refinery_model.unit_status(built_unit.unit_id))
		built_unit.set_alarm_severity(String(built_alarm_severities.get(built_unit.unit_id, "")))
		var state: Dictionary = built_refinery_model.equipment.get(built_unit.unit_id, {})
		if state.get("type", "") == "tank":
			built_unit.set_tank_fill(
				state["volume_l"] / state["capacity_l"],
				state["contents"]
			)
			built_unit.set_active(
				state["contents"] == "diesel"
				and active_route.get("products", {}).get("diesel", "") == built_unit.unit_id
				and built_refinery_model.diesel_is_dispatch_ready(),
				Color("78e08f")
			)
		elif state.get("type", "") == "pump":
			built_unit.set_active(state["running"])
			built_unit.set_pump_operating(state["running"])
		elif state.get("type", "") == "valve":
			built_unit.set_valve_open(state["open"])
			built_unit.set_active(state["open"], Color("78e08f"))
		elif state.get("type", "") == "heater":
			built_unit.set_active(state["output_percent"] > 0.0, Color("ff5a35"))
		elif state.get("type", "") == "column":
			built_unit.set_active(
				built_refinery_model.actual_flow_lps > 0.01
				and active_route.get("column", "") == built_unit.unit_id,
				Color("75ddff")
			)
		elif state.get("type", "") == "catalytic_cracking":
			built_unit.set_active(
				built_refinery_model.unit_status(built_unit.unit_id) == "RUNNING",
				Color("f0a866")
			)
		elif state.get("type", "") == "treatment":
			built_unit.set_active(state["running"], Color("7fc8ff"))
		elif state.get("type", "") == "header":
			built_unit.set_active("RUTE " in built_refinery_model.unit_status(built_unit.unit_id), Color("75ddff"))
		elif state.get("type", "") == "product_header":
			built_unit.set_active("RUTE " in built_refinery_model.unit_status(built_unit.unit_id), Color("ffc975"))
		elif state.get("type", "") == "power_unit":
			built_unit.set_active(state.get("running", false), Color("f6cf63"))


func _built_alarm_severities() -> Dictionary:
	var severities := {}
	for alarm in built_refinery_model.operator_alarms():
		var unit_id := String(alarm.get("equipment_id", ""))
		var severity := String(alarm.get("severity", "")).to_upper()
		if unit_id.is_empty() or _alarm_severity_rank(severity) <= _alarm_severity_rank(String(severities.get(unit_id, ""))):
			continue
		severities[unit_id] = severity
	return severities


func _alarm_severity_rank(severity: String) -> int:
	return {"LOW": 1, "MEDIUM": 2, "HIGH": 3}.get(severity.to_upper(), 0)


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
	_set_liquid_level(
		"generator_fuel",
		built_refinery_model.generator_fuel_l / BuiltRefineryModelScript.GENERATOR_FUEL_CAPACITY_L
	)


func _set_flow_group(group_name: String, enabled: bool, normalized_rate: float) -> void:
	if not flow_visuals.has(group_name):
		return
	for visual in flow_visuals[group_name]:
		visual.set_flow(enabled, normalized_rate)


func _set_liquid_level(tank_id: String, fill_ratio: float) -> void:
	if not liquid_levels.has(tank_id):
		return
	var data: Dictionary = liquid_levels[tank_id]
	TankLiquidVisualScript.set_fill(data, fill_ratio, data["material"].albedo_color)


func _on_unit_interacted(unit_id: String) -> void:
	if batch_report_visible or contract_selection_visible or product_dispatch_visible or control_station_visible or (lab_analysis_panel != null and lab_analysis_panel.visible):
		return
	var message := ""
	var pilot_state_before: Dictionary = process_model.save_state()
	var built_state_before: Dictionary = built_refinery_model.save_state()
	match unit_id:
		"pump":
			message = process_model.toggle_pump()
		"feed_valve":
			message = process_model.toggle_feed_valve()
		"heater":
			message = process_model.cycle_heater()
		"sales_terminal":
			if process_model.objective_complete:
				if built_refinery_model.commissioning_contract_complete:
					var lab_status: Dictionary = built_refinery_model.lab_dispatch_status()
					if lab_status.get("sample_current", false):
						var lab_power: Dictionary = built_refinery_model.can_use_site_consumer("lab")
						if not lab_power["ok"]:
							message = lab_power["message"]
						else:
							var analysis: Dictionary = built_refinery_model.analyze_diesel_sample()
							if analysis["ok"]:
								_open_lab_analysis(analysis)
								return
							message = analysis["message"]
					else:
						message = lab_status["message"]
				else:
					message = "Første Område 02-produkt sendes fra PD-101. Koble en produkttank via salgspumpe."
			else:
				message = process_model.sell_diesel()
		"area02_control":
			if not built_refinery_model.commissioning_contract_complete:
				message = "LS-201 låses opp etter første godkjente Område 02-batch."
			elif not built_refinery_model.can_use_site_consumer("control_station")["ok"]:
				message = built_refinery_model.can_use_site_consumer("control_station")["message"]
			else:
				_open_control_station()
				return
		"area02_generator":
			var generator_result: Dictionary = built_refinery_model.toggle_starter_generator()
			message = generator_result["message"]
		"area02_mcc":
			var mcc_result: Dictionary = built_refinery_model.reset_electrical_bus()
			message = mcc_result["message"]
		"generator_fuel":
			message = built_refinery_model.refuel_generator_day_tank()["message"]
		"instrument_air":
			message = built_refinery_model.toggle_instrument_air_compressor()["message"]
		"cooling_tower", "cooling_water":
			message = built_refinery_model.toggle_cooling_water_pump()["message"]
		EquipmentCatalogScript.CRUDE_TERMINAL_ID:
			_open_contract_selection(unit_id)
			return
		EquipmentCatalogScript.PRODUCT_TERMINAL_ID:
			_open_physical_product_dispatch(unit_id)
			return
		EquipmentCatalogScript.CRUDE_TIE_IN_ID, EquipmentCatalogScript.PRODUCT_TIE_IN_ID:
			message = built_refinery_model.inspect_unit(unit_id)
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
				var contract_choice: Dictionary = built_refinery_model.can_choose_contract(unit_id)
				if contract_choice["ok"]:
					_show_notification("Velg råoljeleveranse ved CI-101.")
					return
				var result: Dictionary = built_refinery_model.interact(
					unit_id,
					process_model.can_afford(BuiltRefineryModelScript.CRUDE_BATCH_COST)
				)
				var charge: int = int(result.get("charge", 0))
				if result["ok"] and charge > 0:
					process_model.purchase(charge)
				if result["ok"] and int(result.get("revenue", 0)) > 0:
					process_model.credit(int(result["revenue"]))
				if result.get("sample_id", "") != "":
					discard_confirmation_time_left = 0.0
					discard_confirmation_revision = -1
				message = result["message"]
	_show_notification(message)
	var changed_persistent_state: bool = (
		pilot_state_before != process_model.save_state()
		or built_state_before != built_refinery_model.save_state()
	)
	if changed_persistent_state:
		_schedule_save()


func _on_secondary_unit_interacted(unit_id: String) -> void:
	if not unit_id.begins_with("built_"):
		return
	var before: Dictionary = built_refinery_model.save_state()
	var result: Dictionary = (
		built_refinery_model.toggle_heater_auto(unit_id)
		if built_refinery_model.equipment.get(unit_id, {}).get("type", "") == "heater"
		else built_refinery_model.cycle_pump_flow(unit_id)
	)
	_show_notification(result["message"])
	if result["ok"] and before != built_refinery_model.save_state():
		_schedule_save()


func _on_maintenance_unit_interacted(unit_id: String) -> void:
	if not unit_id.begins_with("built_"):
		return
	var before: Dictionary = built_refinery_model.save_state()
	var money_before: Dictionary = process_model.save_state()
	var result: Dictionary = built_refinery_model.inspect_or_service_pump(
		unit_id,
		process_model.can_afford(BuiltRefineryModel.PUMP_SERVICE_COST)
	)
	if result["ok"] and int(result.get("charge", 0)) > 0:
		process_model.purchase(int(result["charge"]))
	_show_notification(result["message"], 6.0)
	if result["ok"] and (before != built_refinery_model.save_state() or money_before != process_model.save_state()):
		_schedule_save()


func _on_reset_requested() -> void:
	if process_model.objective_complete or build_mode_unlocked:
		if batch_report_visible:
			_show_notification("Trykk Enter for å lukke batchrapporten først.")
			return
		var confirmation_is_current: bool = (
			discard_confirmation_time_left > 0.0
			and discard_confirmation_revision == built_refinery_model.product_inventory_revision
		)
		var discard_result: Dictionary = built_refinery_model.discard_products(confirmation_is_current)
		if discard_result.get("requires_confirmation", false):
			discard_confirmation_time_left = 4.0
			discard_confirmation_revision = built_refinery_model.product_inventory_revision
		elif discard_result["ok"]:
			discard_confirmation_time_left = 0.0
			discard_confirmation_revision = -1
		_show_notification(discard_result["message"], 6.0)
		if discard_result["ok"]:
			_schedule_save()
		return
	process_model.reset_batch()
	_show_notification("Ny batch lastet: 1 000 liter råolje.", 5.0)
	_schedule_save()


func _on_build_placement_requested(
	equipment_type: String,
	position_3d: Vector3,
	rotation_quadrants: int
) -> void:
	var result: Dictionary = _create_built_unit(
		equipment_type,
		position_3d,
		rotation_quadrants,
		build_serial_number + 1,
		true
	)
	_show_notification(result["message"])
	if result["ok"]:
		_schedule_save()


func _create_built_unit(
	equipment_type: String,
	position_3d: Vector3,
	rotation_quadrants: int,
	serial_number: int,
	charge_cost: bool
) -> Dictionary:
	var definition: Dictionary = EquipmentCatalogScript.definition(equipment_type)
	if serial_number < 1 or serial_number > SaveSystemScript.MAX_BUILD_SERIAL:
		return {"ok": false, "message": "Maksimalt antall byggeserier er nådd."}
	var cost: int = definition["cost"]
	if charge_cost and not process_model.purchase(cost):
		return {"ok": false, "message": "Ikke nok penger til %s." % definition["name"]}
	var unit = BuildableUnitScript.new()
	unit.configure_buildable(equipment_type, serial_number)
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
		if charge_cost:
			process_model.refund(cost)
		return register_result
	build_controller.register_unit(unit)
	build_serial_number = maxi(build_serial_number, serial_number)
	return {
		"ok": true,
		"message": (
			"%s plassert for %d kr." % [definition["name"], cost]
			if charge_cost
			else "%s gjenopprettet." % definition["name"]
		),
		"unit": unit,
	}


func _on_build_removal_requested(unit) -> void:
	if not is_instance_valid(unit) or not build_controller.has_registered_unit(unit):
		return
	if unit.equipment_type in ["crude_intake", "product_dispatch"]:
		_show_notification("Dette er et fast anleggspunkt og kan ikke fjernes.")
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
	_schedule_save()


func _show_notification(message: String, duration := 4.0) -> void:
	notification_label.text = message if is_instance_valid(notification_label) else ""
	notification_time_left = duration


func _show_batch_report(report: Dictionary, completed_now: bool) -> void:
	var contract_name: String = String(report.get("contract_name", "Standard råolje"))
	var short_name := contract_name.trim_suffix(" råolje").to_upper()
	var order_name: String = String(report.get("order_name", short_name))
	var heading := "OMRÅDE 02 — OPPSTART GODKJENT" if completed_now else "BATCH GODKJENT — %s" % order_name
	var temperature: float = report.get("average_temperature_c", 0.0)
	var average_flow: float = report.get("average_flow_lps", BuiltRefineryModelScript.PUMP_CAPACITY_LPS)
	var process_result := "Prosessdata ikke tilgjengelig"
	if temperature > 0.0:
		process_result = "snitt %.0f / mål %.0f °C  |  flow %.1f L/s" % [
			temperature, float(report.get("ideal_temperature_c", 200.0)), average_flow,
		]
	var net_profit: int = report["net_profit"]
	var net_text := "+%d kr" % net_profit if net_profit >= 0 else "%d kr" % net_profit
	batch_report_label.text = (
		heading + "\n\n"
		+ "Råolje                %s\n" % contract_name
		+ "Råolje behandlet      %7.0f L\n" % report["crude_processed_l"]
		+ "Lett fraksjon         %7.0f L\n" % report["light_l"]
		+ "Diesel                %7.0f L\n" % report["diesel_l"]
		+ "Tung fraksjon         %7.0f L\n\n" % report["heavy_l"]
		+ "Dieselkvalitet        %6.1f %% — %s\n" % [
			report["diesel_quality_percent"],
			report["spec_status"],
		]
		+ "Ordre                 %s %.0f / %.0f L — OPPFYLT\n" % [
			report.get("delivery_product_name", "Diesel"),
			report.get("delivery_volume_l", report["diesel_l"]),
			report.get("delivery_target_l", report["diesel_target_l"]),
		]
		+ "Prosess               %s\n\n" % process_result
		+ "Dieselsalg            %7d kr\n" % int(report.get("product_revenue", report["revenue"]))
		+ ("Kontraktbonus        %7d kr\n" % int(report.get("delivery_bonus", 0)) if int(report.get("delivery_bonus", 0)) > 0 else "")
		+ "Råoljekostnad         %7d kr\n" % report["crude_cost"]
		+ "Resultat              %s\n\n" % net_text
		+ ("NYTT: LS-201 lokalstasjon låst opp på vestsiden av byggeområdet.\n\n" if completed_now else "")
		+ "Enter — fortsett"
	)
	batch_report_visible = true
	player.set_input_blocked(true)
	build_controller.set_input_blocked(true)


func _dismiss_batch_report() -> void:
	batch_report_visible = false
	player.set_input_blocked(false)
	build_controller.set_input_blocked(false)
	var route: Dictionary = built_refinery_model.active_route()
	var remaining_crude := 0.0
	if not route.is_empty():
		var source: Dictionary = built_refinery_model.equipment[route["source"]]
		if source["contents"] == "crude":
			remaining_crude = source["volume_l"]
	var message := "Godkjent levering. Velg neste råolje ved kildetanken."
	if built_refinery_model.successful_sales == 1:
		message = "LS-201 LÅST OPP på vestsiden av byggeområdet."
		if remaining_crude > 0.001:
			message += " %.0f L råolje gjenstår." % remaining_crude
	elif remaining_crude > 0.001:
		message = "Godkjent levering. %.0f L råolje gjenstår i kildetanken." % remaining_crude
	_show_notification(message, 6.0)


func _open_lab_analysis(analysis: Dictionary) -> void:
	lab_analysis_panel.show_analysis(analysis)
	notification_time_left = 0.0
	discard_confirmation_time_left = 0.0
	discard_confirmation_revision = -1
	player.set_input_blocked(true)
	build_controller.set_input_blocked(true)


func _close_lab_analysis() -> void:
	lab_analysis_panel.close_panel()
	player.set_input_blocked(false)
	build_controller.set_input_blocked(false)


func _handle_lab_analysis_input(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_close_lab_analysis()
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_close_lab_analysis()
		_show_notification("LAB-101 analyserer produktet. Send godkjent produkt fra PD-101.", 6.0)


func _open_contract_selection(source_id: String) -> void:
	contract_selection_visible = true
	contract_selection_source_id = source_id
	notification_time_left = 0.0
	_update_contract_selection_text()
	player.set_input_blocked(true)
	build_controller.set_input_blocked(true)


func _update_contract_selection_text(error_text := "") -> void:
	var standard := CrudeCatalogScript.definition("standard")
	var heavy := CrudeCatalogScript.definition("heavy")
	var sour := CrudeCatalogScript.definition("sour")
	var intake_mode := contract_selection_source_id == EquipmentCatalogScript.CRUDE_TERMINAL_ID
	var standard_price := (
		"FIRST BATCH FREE / 0 kr"
		if built_refinery_model.commissioning_batch_available
		else "%d kr" % standard["purchase_cost"]
	)
	contract_selection_label.text = (
		("RÅOLJEINNTAK CI-101 — VELG 1 000 L\nPenger: %d kr\n\n" if intake_mode else "LEVERINGSORDRE — VELG 1 000 L\nPenger: %d kr\n\n") % process_model.money
		+ "1 %s / %s — %s\n  %s\n\n" % [
			standard["order_name"], standard["short_name"], standard_price, standard["description"],
		]
		+ "2 %s / %s — %d kr\n  %s • bonus +%d kr\n\n" % [
			heavy["order_name"], heavy["short_name"], heavy["purchase_cost"], heavy["description"], heavy["delivery_bonus"],
		]
		+ "3 %s / %s — %d kr\n  %s\n\n" % [
			sour["order_name"], sour["short_name"], sour["purchase_cost"], sour["description"],
		]
		+ (error_text + "\n\n" if not error_text.is_empty() else "")
		+ ("1 / 2 / 3 — kjøp og motta    Esc — avbryt" if intake_mode else "1 / 2 / 3 — kjøp og last    Esc — avbryt")
	)


func _handle_contract_selection_input(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_close_contract_selection()
		_show_notification("Råoljevalg avbrutt.")
	elif event.keycode == KEY_1:
		_select_contract("standard")
	elif event.keycode == KEY_2:
		_select_contract("heavy")
	elif event.keycode == KEY_3:
		_select_contract("sour")


func _select_contract(contract_id: String) -> void:
	var cost: int = built_refinery_model.effective_contract_cost(contract_id)
	if not process_model.can_afford(cost):
		_update_contract_selection_text("Ikke nok penger — mangler %d kr." % (cost - process_model.money))
		return
	var result: Dictionary = (
		built_refinery_model.receive_intake_delivery(contract_id, true)
		if contract_selection_source_id == EquipmentCatalogScript.CRUDE_TERMINAL_ID
		else built_refinery_model.load_crude_batch(contract_selection_source_id, true, contract_id)
	)
	if not result["ok"]:
		_update_contract_selection_text(result["message"])
		return
	if result["charge"] > 0 and not process_model.purchase(result["charge"]):
		_update_contract_selection_text("Kjøpet kunne ikke fullføres.")
		return
	_close_contract_selection()
	_show_notification(result["message"], 7.0)
	_schedule_save()


func _close_contract_selection() -> void:
	contract_selection_visible = false
	contract_selection_source_id = ""
	player.set_input_blocked(false)
	build_controller.set_input_blocked(false)


func _open_physical_product_dispatch(terminal_id: String) -> void:
	physical_dispatch_terminal_id = terminal_id
	product_dispatch_visible = true
	notification_time_left = 0.0
	_update_product_dispatch_text()
	player.set_input_blocked(true)
	build_controller.set_input_blocked(true)


func _update_product_dispatch_text(error_text := "") -> void:
	var orders: Array[Dictionary] = built_refinery_model.available_physical_dispatch_orders(
		EquipmentCatalogScript.PRODUCT_TIE_IN_ID
	)
	var rows: Array[String] = []
	for index in orders.size():
		var order: Dictionary = orders[index]
		var state := "KLAR" if order["ready"] else "MANGLER %.0f L" % maxf(0.0, float(order["target_l"]) - float(order["volume_l"]))
		rows.append("%d %s\n  %.0f / %.0f L • %d kr • %s" % [
			index + 1, order["order_name"], order["volume_l"], order["target_l"],
			order["revenue_preview"], state,
		])
	if rows.is_empty():
		rows.append("Ingen produktlinje er koblet til PD-101.\nKoble tank → salgspumpe → riktig PD-101-inngang.")
	product_dispatch_label.text = (
		"PD-101 — PRODUKTDISPATCH\n\n"
		+ "\n\n".join(rows)
		+ ("\n\n" + error_text if not error_text.is_empty() else "")
		+ ("\n\n1–%d — send produkt    Esc — avbryt" % orders.size() if not orders.is_empty() else "\n\nEsc — avbryt")
	)


func _handle_product_dispatch_input(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_close_product_dispatch()
		_show_notification("Produktleveranse avbrutt.")
		return
	var index := -1
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		index = int(event.keycode) - int(KEY_1)
	var orders: Array[Dictionary] = built_refinery_model.available_physical_dispatch_orders(
		EquipmentCatalogScript.PRODUCT_TIE_IN_ID
	)
	if index < 0 or index >= orders.size():
		return
	var result: Dictionary = built_refinery_model.dispatch_product_from_terminal(
		EquipmentCatalogScript.PRODUCT_TIE_IN_ID, String(orders[index]["tank_id"])
	)
	if not result["ok"]:
		_update_product_dispatch_text(result["message"])
		return
	process_model.credit(result["revenue"])
	_sync_built_tank_fill_levels()
	_close_product_dispatch()
	if result.has("report"):
		discard_confirmation_time_left = 0.0
		discard_confirmation_revision = -1
		_show_batch_report(result["report"], bool(result.get("contract_completed_now", false)))
		_schedule_save()
		return
	_show_notification(
		"FØRSTE OMRÅDE 02-LEVERANSE FULLFØRT — +%d kr. Refinery operations established." % result["revenue"]
		if result.get("first_physical_dispatch_now", false)
		else result["message"],
		7.0 if result.get("first_physical_dispatch_now", false) else 6.0
	)
	_schedule_save()


func _close_product_dispatch() -> void:
	product_dispatch_visible = false
	physical_dispatch_terminal_id = ""
	player.set_input_blocked(false)
	build_controller.set_input_blocked(false)


func _sync_built_tank_fill_levels() -> void:
	for entry in build_controller.registered_units:
		var built_unit = entry["node"]
		if not is_instance_valid(built_unit):
			continue
		var state: Dictionary = built_refinery_model.equipment.get(built_unit.unit_id, {})
		if state.get("type", "") == "tank":
			built_unit.set_tank_fill(
				float(state["volume_l"]) / float(state["capacity_l"]),
				String(state["contents"])
			)


func _open_control_station() -> void:
	control_station_visible = true
	control_station_feedback = ""
	control_station_feedback_is_error = false
	control_station_train_index = 0
	notification_time_left = 0.0
	player.set_input_blocked(true)
	build_controller.set_input_blocked(true)
	_update_control_station_text()


func _close_control_station() -> void:
	control_station_visible = false
	control_station_feedback = ""
	control_station_feedback_is_error = false
	player.set_input_blocked(false)
	build_controller.set_input_blocked(false)


func _handle_control_station_input(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_close_control_station()
		return
	var control_power: Dictionary = built_refinery_model.can_use_site_consumer("control_station")
	if not control_power["ok"]:
		control_station_feedback = control_power["message"]
		control_station_feedback_is_error = true
		_update_control_station_text()
		return
	var overview: Dictionary = built_refinery_model.operations_snapshot()
	var trains: Array = overview.get("trains", [])
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		if not trains.is_empty():
			var direction := -1 if event.keycode == KEY_LEFT else 1
			control_station_train_index = posmod(control_station_train_index + direction, trains.size())
			control_station_feedback = ""
		_update_control_station_text()
		return
	if trains.is_empty():
		control_station_feedback = "Ingen komplett prosesslinje å styre."
		control_station_feedback_is_error = true
		_update_control_station_text()
		return
	control_station_train_index = clampi(control_station_train_index, 0, trains.size() - 1)
	var selected: Dictionary = trains[control_station_train_index]
	var result := {}
	if event.keycode == KEY_1:
		result = built_refinery_model.remote_toggle_pump(selected["pump_id"])
	elif event.keycode == KEY_2:
		result = built_refinery_model.remote_cycle_heater(selected["pump_id"])
	elif event.keycode == KEY_3:
		result = built_refinery_model.remote_cycle_pump_flow(selected["pump_id"])
	else:
		return
	control_station_feedback = result["message"]
	control_station_feedback_is_error = not result["ok"]
	if result["ok"]:
		_schedule_save()
	_update_control_station_text()


func _update_control_station_text() -> void:
	var overview: Dictionary = built_refinery_model.operations_snapshot()
	var trains: Array = overview.get("trains", [])
	if not trains.is_empty():
		control_station_train_index = clampi(control_station_train_index, 0, trains.size() - 1)
		var selected: Dictionary = trains[control_station_train_index]
		var power_line: String = built_refinery_model.power_overview_text() + "\n"
		var overview_lines := ""
		for train in trains:
			overview_lines += "%s  %s  %d ALARMER\n" % [train["name"], train["status"], train["alarms"].size()]
		var product_lines := ""
		for product_id in ["light", "diesel", "heavy"]:
			product_lines += "%s: %s\n" % [product_id.to_upper(), selected["products"].get(product_id, "INGEN RUTE")]
		var selected_alarms := "INGEN"
		if not selected["alarms"].is_empty():
			selected_alarms = "\n".join(selected["alarms"].map(func(alarm): return "%s — %s" % [alarm["equipment_name"], alarm["message"]]))
		control_station_label.text = (
			"REFINERY OPERATIONS\n\n" + power_line + overview_lines + "\n"
			+ "VALGT TOG: %s — %s\n" % [selected["name"], selected["status"]]
			+ "Feed: %s  |  %.0f/%.0f L  |  rute %s\n" % [selected["crude_name"], selected["source_volume_l"], selected["source_capacity_l"], selected["feed_route"]]
			+ "Pumpe: %s  |  mål %.1f L/s\n" % [selected["pump_state"], selected["target_flow_lps"]]
			+ "TIC: %s  PV %.0f  SP %.0f  UT %.0f %%%s\n" % [String(selected["heater_mode"]).to_upper(), selected["heater_pv_c"], selected["heater_sp_c"], selected["heater_output_percent"], " — HEAT BLOCKED" if selected["heater_blocked"] else ""]
			+ product_lines + "ALARMS: " + selected_alarms + "\n\n"
			+ (control_station_feedback if not control_station_feedback.is_empty() else "Feltventiler, ruter, prøver og service betjenes ute i anlegget.") + "\n\n"
			+ "←/→ velg tog   1 start/stopp   2 temperaturmål   3 flowmål\nEsc — lukk"
		)
		return
	var snapshot: Dictionary = built_refinery_model.control_snapshot()
	var power_overview: String = built_refinery_model.power_overview_text()
	if not snapshot.get("valid", false):
		control_station_label.text = (
			"LS-201 — LOKALSTASJON\n\n"
			+ power_overview + "\n\n"
			+ "NETTVERK UFULLSTENDIG\n%s\n\n" % snapshot.get("message", "Ingen gyldig prosesslinje.")
			+ "Esc — lukk"
		)
		return
	var temperature_state := "VENTER"
	if snapshot["ideal_temperature_c"] > 0.0:
		var safe_range := Vector2(
			float(snapshot["approved_temperature_min_c"]),
			float(snapshot["approved_temperature_max_c"])
		)
		if snapshot["heater_temperature_c"] < safe_range.x:
			temperature_state = "LAV"
		elif snapshot["heater_temperature_c"] > safe_range.y:
			temperature_state = "HØY"
		else:
			temperature_state = "KLAR"
	var flow_state := "STOPPED"
	if not String(snapshot.get("pump_trip_reason", "")).is_empty():
		flow_state = "TRIPPED"
	elif snapshot["pump_running"] and snapshot["actual_flow_lps"] <= 0.01:
		flow_state = "ATTENTION"
	elif snapshot["actual_flow_lps"] > 0.01:
		flow_state = "NORMAL"
	var process_message: String = String(snapshot.get("temperature_trip_message", ""))
	if process_message.is_empty() and control_station_feedback_is_error:
		process_message = control_station_feedback
	if process_message.is_empty():
		process_message = String(snapshot.get("alarm", ""))
	if process_message.is_empty():
		process_message = String(snapshot.get("status", ""))
	if process_message.is_empty():
		process_message = control_station_feedback
	var alarm_section := "ACTIVE ALARMS: 0\n"
	var alarms: Array = snapshot.get("operator_alarms", [])
	if not alarms.is_empty():
		alarm_section = "ACTIVE ALARMS: %d\n" % alarms.size()
		for alarm in alarms.slice(0, 3):
			alarm_section += "[%s] %s — %s\n" % [
				alarm["severity"], alarm["equipment_name"], alarm["message"],
			]
	var crude_heading := "Ingen aktiv råolje  |  driftsmål —"
	if snapshot["ideal_temperature_c"] > 0.0:
		crude_heading = "%s råolje  |  driftsmål %.0f °C" % [
			snapshot["crude_name"], snapshot["ideal_temperature_c"],
		]
	var guard_state := "VENTER PÅ RÅOLJE"
	if not String(snapshot.get("temperature_trip_message", "")).is_empty():
		guard_state = "UTLØST"
	elif snapshot["temperature_guard_active"]:
		guard_state = "AKTIV"
	elif snapshot["pump_running"]:
		guard_state = "IKKE AKTIV — FELTSTART"
	elif snapshot["ideal_temperature_c"] > 0.0:
		guard_state = "ARMERES VED FJERNSTART"
	control_station_label.text = (
		"LS-201 — LOKALSTASJON\n"
		+ crude_heading + "\n\n"
		+ alarm_section + "\n"
		+ "LT-201 NIVÅ, KILDE     %4.0f / %4.0f L    %3.0f %%\n" % [
			snapshot["source_volume_l"], snapshot["source_capacity_l"],
			snapshot["source_level_percent"],
		]
		+ "TT-201 TEMPERATUR      %4.0f °C / mål %3.0f °C    %s\n" % [
			snapshot["heater_temperature_c"], snapshot["heater_setpoint_c"], temperature_state,
		]
		+ "TIC-201 KONTROLL       %s | UT %3.0f %%%s\n" % [
			String(snapshot["heater_control_mode"]).to_upper(), snapshot["heater_output_percent"],
			" — BLOKKERT" if snapshot["heater_auto_blocked"] else "",
		]
		+ "FT-201 FLOW            %5.1f L/s | mål %2.0f   %s\n" % [
			snapshot["actual_flow_lps"], snapshot["pump_flow_setpoint_lps"], flow_state,
		]
		+ "LT-202 NIVÅ, DIESEL    %4.0f / 1000 L\n\n" % snapshot["diesel_volume_l"]
		+ "P-201 PUMPE            %s\n" % snapshot["pump_state"]
		+ "FLOWMODUS              %s\n" % built_refinery_model.flow_mode_text(snapshot["pump_flow_setpoint_lps"])
		+ "V-201 VENTIL           %s — FELT\n" % ("ÅPEN" if snapshot["valve_open"] else "STENGT")
		+ "TEMPERATURVERN         %s\n\n" % guard_state
		+ process_message + "\n\n"
		+ "1 — start/stopp pumpe\n"
		+ "2 — endre temperaturmål\n"
		+ "3 — endre flowmål\n"
		+ "Ventilen betjenes ute i anlegget\n"
		+ "Esc — lukk"
	)


func _initialize_persistence() -> void:
	var load_result: Dictionary = SaveSystemScript.read_snapshot(save_path)
	if load_result.get("missing", false):
		persistence_ready = true
		_show_notification("Varm opp anlegget før du starter flowen.", 7.0)
		return
	if load_result["ok"]:
		pending_save_data = load_result["data"]
		pending_save_recovered = bool(load_result.get("recovered_from_backup", false))
		startup_choice_state = "choice"
		startup_label.text = (
			"CRUDEWORKS\n\nLagret spill funnet.\n\n"
			+ "Enter — fortsett\nN — nytt spill"
		)
	else:
		startup_choice_state = "corrupt"
		startup_label.text = (
			"LAGRINGEN KAN IKKE LESES\n\n"
			+ "Filen er beholdt og blir ikke overskrevet.\n\n"
			+ "N — start et nytt spill"
		)
	_set_startup_blocked(true)


func _handle_startup_input(event: InputEventKey) -> void:
	if startup_choice_state == "choice":
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_continue_saved_game()
		elif event.keycode == KEY_N:
			_show_new_game_confirmation()
	elif startup_choice_state == "corrupt":
		if event.keycode == KEY_N:
			_show_new_game_confirmation()
	elif startup_choice_state == "confirm_new":
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_start_new_game()
		elif event.keycode == KEY_ESCAPE:
			startup_choice_state = "choice" if not pending_save_data.is_empty() else "corrupt"
			if startup_choice_state == "choice":
				startup_label.text = "CRUDEWORKS\n\nLagret spill funnet.\n\nEnter — fortsett\nN — nytt spill"
			else:
				startup_label.text = "LAGRINGEN KAN IKKE LESES\n\nFilen er beholdt og blir ikke overskrevet.\n\nN — start et nytt spill"


func _show_new_game_confirmation() -> void:
	startup_choice_state = "confirm_new"
	startup_label.text = (
		"STARTE NYTT SPILL?\n\n"
		+ "Lagret fremgang blir arkivert og erstattet.\n\n"
		+ "Enter — start på nytt\nEsc — avbryt"
	)


func _continue_saved_game() -> void:
	var result: Dictionary = _apply_snapshot(pending_save_data)
	if not result["ok"]:
		pending_save_data = {}
		startup_choice_state = "corrupt"
		startup_label.text = "LAGRINGEN KAN IKKE LASTES\n\n%s\n\nN — start et nytt spill" % result["message"]
		return
	startup_choice_state = ""
	pending_save_data = {}
	var recovered_message := pending_save_recovered
	pending_save_recovered = false
	persistence_ready = true
	autosave_time_left = AUTOSAVE_INTERVAL_SECONDS
	_set_startup_blocked(false)
	_show_notification(
		"Forrige sikre lagring ble lastet. Alle pumper er stoppet av sikkerhetshensyn."
		if recovered_message
		else "Spill lastet. Alle pumper er stoppet av sikkerhetshensyn.",
		7.0
	)


func _start_new_game() -> void:
	var archive_result: Dictionary = SaveSystemScript.archive_snapshot(save_path)
	if not archive_result["ok"]:
		startup_label.text = "NYTT SPILL KAN IKKE STARTES\n\n%s\n\nEsc — avbryt" % archive_result["message"]
		return
	startup_choice_state = ""
	pending_save_data = {}
	pending_save_recovered = false
	persistence_ready = true
	autosave_time_left = AUTOSAVE_INTERVAL_SECONDS
	_set_startup_blocked(false)
	_show_notification("Nytt spill startet. Forrige lagring er arkivert.", 6.0)
	_schedule_save()


func _set_startup_blocked(value: bool) -> void:
	player.set_input_blocked(value)
	build_controller.set_input_blocked(value)


func _schedule_save(show_feedback := false) -> void:
	if not persistence_enabled or not persistence_ready or suppress_save_requests:
		return
	save_debounce_time_left = SAVE_DEBOUNCE_SECONDS
	save_feedback_requested = save_feedback_requested or show_feedback


func _update_autosave(delta: float) -> void:
	if not persistence_enabled or not persistence_ready:
		return
	if save_debounce_time_left >= 0.0:
		save_debounce_time_left -= delta
		if save_debounce_time_left <= 0.0:
			_write_save(save_feedback_requested)
			save_debounce_time_left = -1.0
			save_feedback_requested = false
	autosave_time_left -= delta
	if autosave_time_left <= 0.0:
		_write_save(false)


func _write_save(show_feedback: bool) -> Dictionary:
	if not persistence_enabled or not persistence_ready:
		return {"ok": false, "message": "Lagring er ikke klar."}
	var result: Dictionary = SaveSystemScript.write_snapshot(save_path, _build_snapshot())
	if result["ok"]:
		autosave_time_left = AUTOSAVE_INTERVAL_SECONDS
		if show_feedback:
			_show_notification("LAGRET", 1.2)
	else:
		_show_notification("Kunne ikke lagre: %s" % String(result.get("message", "ukjent feil")), 10.0)
	return result


func _build_snapshot() -> Dictionary:
	var placements: Array[Dictionary] = []
	for entry in build_controller.registered_units:
		if bool(entry.get("fixed", false)):
			continue
		var unit = entry["node"]
		if not is_instance_valid(unit):
			continue
		placements.append({
			"type": unit.equipment_type,
			"serial": unit.serial_number,
			"position": [unit.position.x, unit.position.y, unit.position.z],
			"rotation_quadrants": unit.rotation_quadrants,
		})
	placements.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["serial"]) < int(right["serial"])
	)
	return {
		"format_version": SaveSystemScript.FORMAT_VERSION,
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"pilot": process_model.save_state(),
		"construction": {
			"build_serial_number": build_serial_number,
			"units": placements,
			"connections": built_refinery_model.network.connections.duplicate(true),
		},
		"built_refinery": built_refinery_model.save_state(),
		"player": {
			"position": [player.position.x, player.position.y, player.position.z],
			"rotation_y": player.rotation.y,
		},
	}


func _apply_snapshot(snapshot: Dictionary) -> Dictionary:
	var validation: Dictionary = SaveSystemScript.validate_snapshot(snapshot)
	if not validation["ok"]:
		return validation
	var placed_units := false
	for entry in build_controller.registered_units:
		if not bool(entry.get("fixed", false)):
			placed_units = true
	if placed_units or built_refinery_model.network.connection_count() > 0:
		return {"ok": false, "message": "Lagring kan bare gjenopprettes fra oppstartsskjermen."}
	suppress_save_requests = true
	var construction: Dictionary = snapshot["construction"]
	for placement in construction["units"]:
		var create_result: Dictionary = _create_built_unit(
			placement["type"],
			Vector3(
				float(placement["position"][0]),
				float(placement["position"][1]),
				float(placement["position"][2])
			),
			int(placement["rotation_quadrants"]),
			int(placement["serial"]),
			false
		)
		if not create_result["ok"]:
			_rollback_loaded_construction()
			suppress_save_requests = false
			return create_result
	for edge in construction["connections"]:
		var connect_result: Dictionary = build_controller.restore_connection(edge)
		if not connect_result["ok"]:
			_rollback_loaded_construction()
			suppress_save_requests = false
			return connect_result
	build_serial_number = int(construction["build_serial_number"])
	built_refinery_model.apply_saved_state(snapshot["built_refinery"])
	process_model.apply_saved_state(snapshot["pilot"])
	build_mode_unlocked = process_model.objective_complete
	build_controller.set_unlocked(build_mode_unlocked)
	world_builder.set_build_visualization_visible(build_controller.active)
	player.position = Vector3(
		float(snapshot["player"]["position"][0]),
		float(snapshot["player"]["position"][1]),
		float(snapshot["player"]["position"][2])
	)
	player.rotation.y = float(snapshot["player"]["rotation_y"])
	batch_report_visible = false
	contract_selection_visible = false
	contract_selection_source_id = ""
	control_station_visible = false
	control_station_feedback = ""
	control_station_feedback_is_error = false
	lab_analysis_panel.close_panel()
	discard_confirmation_time_left = 0.0
	discard_confirmation_revision = -1
	_update_unit_statuses()
	_update_user_interface()
	suppress_save_requests = false
	return {"ok": true, "message": "Lagret spill er gjenopprettet."}


func _rollback_loaded_construction() -> void:
	for index in range(build_controller.registered_units.size() - 1, -1, -1):
		var unit = build_controller.registered_units[index]["node"]
		if not is_instance_valid(unit):
			continue
		built_refinery_model.unregister_unit(unit.unit_id)
		build_controller.remove_registered_unit(unit)
	build_serial_number = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and persistence_enabled and persistence_ready:
		_write_save(false)


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
	liquid_levels[tank_id] = TankLiquidVisualScript.create(
		tank, radius, max_height, color, 32
	)


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
