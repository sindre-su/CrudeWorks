extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveSystemScript = preload("res://scripts/save_system.gd")
const WorldLayoutScript = preload("res://scripts/world_layout.gd")

const TEST_PATH := "user://crudeworks_pilot_world_integration_test.json"

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_cleanup_test_files()
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	main.save_path = TEST_PATH
	root.add_child(main)
	await process_frame

	_test_fresh_world_context(main)
	_test_pilot_troubleshooting(main)
	_test_successful_pilot_operation(main)
	_test_post_sale_building(main)
	await _test_disk_round_trip_and_resume(main)

	main.queue_free()
	_cleanup_test_files()
	if failures == 0:
		print("PASS: all CrudeWorks functional Pilot integration tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks functional Pilot integration check(s) failed" % failures)
		quit(1)


func _test_fresh_world_context(main) -> void:
	var spawn := WorldLayoutScript.NEW_GAME_SPAWN
	_expect(
		is_equal_approx(main.player.position.x, spawn.x)
		and is_equal_approx(main.player.position.z, spawn.z)
		and main.player.position.y >= -0.05
		and WorldLayoutScript.area_id_at(Vector2(spawn.x, spawn.z)) == "pilot_plant",
		"fresh game starts grounded at the canonical southwest Pilot spawn"
	)
	_expect(
		main.world_builder.orientation_nodes.has("starter_site")
		and main.world_builder.orientation_nodes.has("crude_intake")
		and main.world_builder.orientation_nodes.has("pilot_process_chain")
		and main.world_builder.orientation_nodes.has("main_refinery_gate"),
		"starter region has physical Pilot/Crude orientation and a Main Refinery gate"
	)
	_expect(
		main.world_builder.build_visual_nodes.all(func(node: Node3D) -> bool: return not node.visible),
		"fresh Pilot operation hides construction-only ground and boundary visualization"
	)
	_expect(
		main.world_builder.area_labels.all(func(label: Label3D) -> bool: return not label.visible),
		"fresh human-test view starts without distant area-label clutter"
	)
	var area_label_toggle := InputEventKey.new()
	area_label_toggle.keycode = KEY_F8
	area_label_toggle.pressed = true
	main._unhandled_input(area_label_toggle)
	_expect(main.world_builder.area_labels_visible, "F8 enables area labels independently for development inspection")
	main._unhandled_input(area_label_toggle)
	_expect(not main.world_builder.area_labels_visible, "F8 restores the uncluttered area-label view")
	var debug_was_visible: bool = main.world_debug_label.visible
	var core_debug_toggle := InputEventKey.new()
	core_debug_toggle.keycode = KEY_F7
	core_debug_toggle.pressed = true
	main._unhandled_input(core_debug_toggle)
	_expect(main.world_debug_label.visible != debug_was_visible, "F7 toggles core coordinates and bounds independently")
	main._unhandled_input(core_debug_toggle)
	var expected_ids := [
		"raw_tank", "pump", "feed_valve", "heater", "column",
		"light_tank", "diesel_tank", "heavy_tank", "sales_terminal",
	]
	for unit_id: String in expected_ids:
		_expect(main.units.has(unit_id), "stable Pilot equipment ID %s exists" % unit_id)
		if main.units.has(unit_id):
			var unit = main.units[unit_id]
			_expect(
				WorldLayoutScript.area_rect(WorldLayoutScript.area_by_id("pilot_plant")).has_point(
					Vector2(unit.position.x, unit.position.z)
				),
				"%s remains inside the canonical Pilot footprint" % unit_id
			)
	_expect(
		not main.build_mode_unlocked and not main.build_controller.unlocked,
		"Main Refinery construction remains locked during the fresh Pilot loop"
	)
	_expect(
		main.process_model.crude_volume_l == 1000.0
		and main.liquid_levels["raw_tank"]["node"].visible,
		"starter crude is physically represented in the existing feed tank"
	)


func _test_pilot_troubleshooting(main) -> void:
	main._on_unit_interacted("pump")
	main._process(0.1)
	_expect(
		main.process_model.pump_running
		and is_zero_approx(main.process_model.flow_lps)
		and "LOW FLOW" in main.alarm_label.text,
		"starting P-101 against the closed V-101 preserves the readable LOW FLOW lesson"
	)
	main._on_unit_interacted("pump")
	_expect(not main.process_model.pump_running, "player can deliberately stop P-101 after diagnosis")


func _test_successful_pilot_operation(main) -> void:
	main._on_unit_interacted("heater")
	main._on_unit_interacted("heater")
	_simulate_main(main, 11.0)
	_expect(
		is_equal_approx(main.process_model.heater_setpoint_c, 200.0)
		and main.process_model.heater_temperature_c >= 195.0,
		"physical H-101 interaction preheats the Pilot to its approved operating range"
	)
	main._on_unit_interacted("feed_valve")
	main._on_unit_interacted("pump")
	_simulate_main(main, 61.0)
	main._update_process_visuals(0.0)
	_expect(
		main.process_model.feed_valve_open
		and main.process_model.pump_running
		and main.process_model.diesel_is_approved(),
		"Tank → Pump → Valve → Heater → separation produces approved Pilot diesel"
	)
	_expect(
		main.process_model.light_product_l > 0.0
		and main.process_model.diesel_volume_l > 200.0
		and main.process_model.heavy_product_l > 0.0
		and main.liquid_levels["light_tank"]["node"].visible
		and main.liquid_levels["diesel_tank"]["node"].visible
		and main.liquid_levels["heavy_tank"]["node"].visible,
		"all separated products are received in visible canonical Pilot storage"
	)
	main._on_unit_interacted("sales_terminal")
	var sale_feedback: String = main.notification_label.text
	main._process(0.0)
	_expect(
		main.process_model.objective_complete
		and main.process_model.batch_sold
		and main.process_model.money >= 3000
		and "solgt" in sale_feedback,
		"physical Pilot sale returns clear feedback and the established starter economy result"
	)
	_expect(
		main.build_mode_unlocked and main.build_controller.unlocked,
		"successful Pilot sale leaves the player ready for later Main Refinery progression"
	)
	_expect(
		"PILOT COMPLETE" in main.objective_label.text
		and "CI-101" not in main.objective_label.text
		and "next development stage" in main.objective_label.text,
		"default human-test stage ends coherently without directing the player into unmigrated Area 02"
	)
	main.playable_stage = "main_refinery"
	main._update_user_interface()
	_expect(
		"CI-101" in main.objective_label.text,
		"advancing the configured playable stage restores the preserved Area 02 progression"
	)
	main.playable_stage = "pilot_slice"
	main._update_user_interface()
	main.build_controller.set_build_mode(true)
	main._process(0.0)
	_expect(
		main.world_builder.build_visual_nodes.all(func(node: Node3D) -> bool: return node.visible),
		"Build Mode reveals the retained construction pad and bounds"
	)
	main.build_controller.set_build_mode(false)
	main._process(0.0)
	_expect(
		main.world_builder.build_visual_nodes.all(func(node: Node3D) -> bool: return not node.visible),
		"leaving Build Mode hides construction visualization again"
	)


func _test_post_sale_building(main) -> void:
	var tank_position := Vector3(-10.0, 1.96, 17.0)
	var pump_position := Vector3(-5.0, 0.86, 17.0)
	_expect(
		main.build_controller._position_is_valid(tank_position, Vector2(3.6, 3.6)),
		"active prototype build pad accepts a relevant starter tank in the enlarged world"
	)
	main._on_build_placement_requested("tank", tank_position, 1)
	main._on_build_placement_requested("pump", pump_position, 2)
	var tank = main.build_controller.registered_unit_by_id("built_tank_1")
	var pump = main.build_controller.registered_unit_by_id("built_pump_2")
	_expect(
		is_instance_valid(tank) and is_instance_valid(pump)
		and tank.rotation_quadrants == 1 and pump.rotation_quadrants == 2,
		"post-Pilot construction places and rotates starter equipment with stable IDs"
	)
	if is_instance_valid(tank) and is_instance_valid(pump):
		main.build_controller._connect_ports(tank.get_port("output"), pump.get_port("input"))
	_expect(
		main.built_refinery_model.network.connection_count() == 1,
		"player-built OUT-to-IN connection works in the retained active build area"
	)
	_expect(
		not main.build_controller._position_is_valid(Vector3(-10.0, 1.96, 17.0), Vector2(3.6, 3.6))
		and not main.build_controller._position_is_valid(Vector3(30.0, 1.96, 17.0), Vector2(3.6, 3.6)),
		"placement feedback still rejects overlap and out-of-bounds construction"
	)


func _test_disk_round_trip_and_resume(main) -> void:
	main.player.position = Vector3(4.0, 0.1, 17.0)
	main.player.rotation.y = 0.75
	var snapshot: Dictionary = main._build_snapshot()
	_expect(
		not snapshot.has("playable_stage") and not snapshot.has("build_visualization_visible"),
		"development-stage and construction-overlay visibility do not pollute gameplay saves"
	)
	var write_result: Dictionary = SaveSystemScript.write_snapshot(TEST_PATH, snapshot)
	var read_result: Dictionary = SaveSystemScript.read_snapshot(TEST_PATH)
	_expect(write_result["ok"] and read_result["ok"], "active Pilot state writes and reads through the real save system")
	if not read_result["ok"]:
		return

	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(read_result["data"])
	var restored_tank = restored.build_controller.registered_unit_by_id("built_tank_1")
	var restored_pump = restored.build_controller.registered_unit_by_id("built_pump_2")
	_expect(restore_result["ok"], "fresh Main instance accepts the Pilot world snapshot")
	_expect(
		is_instance_valid(restored_tank) and is_instance_valid(restored_pump)
		and restored_tank.position.is_equal_approx(Vector3(-10.0, 1.96, 17.0))
		and restored_pump.position.is_equal_approx(Vector3(-5.0, 0.86, 17.0))
		and restored_tank.rotation_quadrants == 1
		and restored_pump.rotation_quadrants == 2,
		"equipment IDs, absolute positions and rotations restore without relocation or duplication"
	)
	_expect(
		restored.built_refinery_model.network.connection_count() == 1
		and restored.build_serial_number == 2,
		"process connection and construction identity sequence persist exactly once"
	)
	_expect(
		restored.player.position.is_equal_approx(Vector3(4.0, 0.1, 17.0))
		and is_equal_approx(restored.player.rotation.y, 0.75),
		"player position and facing persist inside canonical world bounds"
	)
	_expect(
		restored.process_model.objective_complete and restored.process_model.batch_sold,
		"Pilot completion and sold-batch progression survive reload"
	)
	_expect(
		restored.world_builder.build_visual_nodes.all(func(node: Node3D) -> bool: return not node.visible),
		"construction visualization restores hidden until Build Mode is deliberately activated"
	)
	_expect(
		restored.process_model.money == int(snapshot["pilot"]["money"]),
		"post-sale economy and construction spending survive reload"
	)
	_expect(
		is_equal_approx(restored.process_model.crude_volume_l, float(snapshot["pilot"]["crude_volume_l"]))
		and is_equal_approx(restored.process_model.light_product_l, float(snapshot["pilot"]["light_product_l"]))
		and is_equal_approx(restored.process_model.heavy_product_l, float(snapshot["pilot"]["heavy_product_l"])),
		"remaining Pilot feed and stored light/heavy products survive reload"
	)
	_expect(
		restored.process_model.feed_valve_open
		and is_equal_approx(restored.process_model.heater_setpoint_c, 200.0)
		and not restored.process_model.pump_running,
		"Pilot operating state restores with the established safe stopped-pump policy"
	)
	var crude_before_resume: float = restored.process_model.crude_volume_l
	restored._on_unit_interacted("pump")
	_simulate_main(restored, 5.0)
	_expect(
		restored.process_model.crude_volume_l < crude_before_resume
		and restored.process_model.diesel_volume_l > 0.0,
		"reloaded Pilot resumes successful physical processing after deliberate restart"
	)
	_expect(
		SaveSystemScript.write_snapshot(TEST_PATH, restored._build_snapshot())["ok"],
		"continued post-reload operation remains save-valid"
	)
	restored.queue_free()


func _simulate_main(main, duration_seconds: float) -> void:
	var timestep := 0.1
	var steps := int(ceil(duration_seconds / timestep))
	for step in steps:
		main._process(timestep)


func _cleanup_test_files() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak", TEST_PATH + ".corrupt"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		printerr("FAIL: %s" % description)
