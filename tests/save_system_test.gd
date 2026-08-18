extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveSystemScript = preload("res://scripts/save_system.gd")

const TEST_PATH := "user://crudeworks_save_system_test.json"
const LEGACY_PATH := "user://crudeworks_save_system_legacy_test.json"

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_cleanup_test_files()
	var source_main = await _create_partial_paid_refinery()
	var snapshot: Dictionary = source_main._build_snapshot()
	_test_schema_validation(snapshot, source_main)
	_test_disk_round_trip(snapshot)
	_test_v1_to_v2_contract_migration(snapshot)
	await _test_startup_continue(snapshot)
	await _test_main_round_trip(snapshot, source_main)
	_test_startup_confirmation(source_main)
	_cleanup_test_files()

	if failures == 0:
		print("PASS: all CrudeWorks save-system tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks save-system check(s) failed" % failures)
		quit(1)


func _create_partial_paid_refinery():
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.money = 3000
	main.process_model.objective_complete = true
	main._process(0.0)
	_place_full_refinery(main)
	_connect_full_refinery(main)
	main.built_refinery_model.commissioning_batch_available = false
	var source = main.build_controller.registered_unit_by_id("built_tank_1")
	var heater = main.build_controller.registered_unit_by_id("built_heater_4")
	var valve = main.build_controller.registered_unit_by_id("built_valve_3")
	var pump = main.build_controller.registered_unit_by_id("built_pump_2")
	main._on_unit_interacted(source.unit_id)
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.tick(10.0)
	main.built_refinery_model.interact(valve.unit_id)
	main.built_refinery_model.interact(pump.unit_id)
	main.built_refinery_model.tick(23.7)
	main.player.position = Vector3(-4.0, 0.1, 17.0)
	main.player.rotation.y = 1.25
	return main


func _test_schema_validation(snapshot: Dictionary, live_main) -> void:
	_expect(SaveSystemScript.validate_snapshot(snapshot)["ok"], "current version snapshot passes complete schema and graph validation")

	var future := snapshot.duplicate(true)
	future["format_version"] = SaveSystemScript.FORMAT_VERSION + 1
	_expect(not SaveSystemScript.validate_snapshot(future)["ok"], "future save version is rejected")

	var negative_money := snapshot.duplicate(true)
	negative_money["pilot"]["money"] = -1
	var money_before: int = live_main.process_model.money
	var unit_count_before: int = live_main.build_controller.registered_units.size()
	_expect(not live_main._apply_snapshot(negative_money)["ok"], "invalid snapshot is rejected before Main applies it")
	_expect(live_main.process_model.money == money_before and live_main.build_controller.registered_units.size() == unit_count_before, "rejected load leaves live economy and construction unchanged")

	var bad_edge := snapshot.duplicate(true)
	bad_edge["construction"]["connections"][0]["to_port"] = "missing"
	_expect(not SaveSystemScript.validate_snapshot(bad_edge)["ok"], "connection to an unknown port is rejected")

	var overlapping := snapshot.duplicate(true)
	overlapping["construction"]["units"][1]["position"] = overlapping["construction"]["units"][0]["position"].duplicate()
	_expect(not SaveSystemScript.validate_snapshot(overlapping)["ok"], "overlapping saved equipment is rejected")

	var poisoned_serial := snapshot.duplicate(true)
	poisoned_serial["construction"]["build_serial_number"] = SaveSystemScript.MAX_BUILD_SERIAL + 1
	_expect(not SaveSystemScript.validate_snapshot(poisoned_serial)["ok"], "out-of-range build counter cannot poison the next generated save")
	var fractional_serial := snapshot.duplicate(true)
	fractional_serial["construction"]["units"][0]["serial"] = 1.5
	_expect(not SaveSystemScript.validate_snapshot(fractional_serial)["ok"], "fractional serial numbers are rejected instead of truncated")


func _test_disk_round_trip(snapshot: Dictionary) -> void:
	var write_result: Dictionary = SaveSystemScript.write_snapshot(TEST_PATH, snapshot)
	_expect(write_result["ok"], "validated snapshot writes through a temporary file")
	if not write_result["ok"]:
		printerr("  ERR save write detail: %s" % write_result["message"])
		return
	var read_result: Dictionary = SaveSystemScript.read_snapshot(TEST_PATH)
	_expect(read_result["ok"], "written snapshot reads and validates from disk")
	if not read_result["ok"]:
		printerr("  ERR save read detail: %s" % read_result["message"])
		return
	_expect(read_result["data"]["construction"]["connections"].size() == 7, "disk round trip preserves all seven directed connections")

	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	var absolute_backup := ProjectSettings.globalize_path(TEST_PATH + ".bak")
	DirAccess.rename_absolute(absolute_path, absolute_backup)
	var broken_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if broken_file == null:
		_expect(false, "corrupt-primary fixture can create its test file")
		return
	broken_file.store_string("{broken")
	broken_file.close()
	var recovered: Dictionary = SaveSystemScript.read_snapshot(TEST_PATH)
	_expect(recovered["ok"] and recovered["recovered_from_backup"], "corrupt primary file recovers the last valid backup")
	_expect(SaveSystemScript.write_snapshot(TEST_PATH, snapshot)["ok"], "valid snapshot safely replaces the recovered primary")
	_expect(FileAccess.file_exists(TEST_PATH + ".bak"), "successful replacement retains one last-known-good backup")


func _test_v1_to_v2_contract_migration(snapshot: Dictionary) -> void:
	var legacy := snapshot.duplicate(true)
	legacy["format_version"] = 1
	legacy["built_refinery"].erase("active_contract_id")
	legacy["built_refinery"].erase("active_contract_bonus_available")
	var legacy_file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	if legacy_file == null:
		_expect(false, "legacy migration fixture can create its save file")
		return
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var migrated: Dictionary = SaveSystemScript.read_snapshot(LEGACY_PATH)
	_expect(migrated["ok"], "known v1 save migrates instead of appearing corrupt")
	if not migrated["ok"]:
		return
	var data: Dictionary = migrated["data"]
	_expect(data["format_version"] == 2 and SaveSystemScript.validate_snapshot(data)["ok"], "v1 migration returns a canonical validated v2 snapshot")
	_expect(data["built_refinery"]["active_contract_id"] == "standard", "legacy material is explicitly assigned to the Standard contract")
	_expect(not data["built_refinery"]["active_contract_bonus_available"], "legacy save cannot gain a retroactive delivery bonus")
	_expect(is_equal_approx(data["built_refinery"]["equipment"]["built_tank_1"]["volume_l"], snapshot["built_refinery"]["equipment"]["built_tank_1"]["volume_l"]), "migration preserves partial source inventory exactly")
	_expect(is_equal_approx(data["built_refinery"]["report_crude_cost"], snapshot["built_refinery"]["report_crude_cost"]), "migration preserves proportional paid-crude report accounting")
	var unknown_contract := data.duplicate(true)
	unknown_contract["built_refinery"]["active_contract_id"] = "mystery"
	_expect(not SaveSystemScript.validate_snapshot(unknown_contract)["ok"], "unknown contract IDs are rejected before live state can mutate")

	var pilot_only := legacy.duplicate(true)
	pilot_only["built_refinery"]["report_crude_processed_l"] = 0.0
	pilot_only["built_refinery"]["report_temperature_total"] = 0.0
	pilot_only["built_refinery"]["report_crude_cost"] = 0.0
	for state in pilot_only["built_refinery"]["equipment"].values():
		if state["type"] == "tank":
			state["volume_l"] = 0.0
			state["contents"] = "empty"
			state["quality_percent"] = 0.0
			state["crude_cost_per_l"] = 0.0
	var pilot_migration: Dictionary = SaveSystemScript.migrate_snapshot(pilot_only)
	_expect(pilot_migration["ok"] and pilot_migration["data"]["built_refinery"]["active_contract_id"].is_empty(), "empty legacy refinery migrates without a phantom active batch")


func _test_startup_continue(snapshot: Dictionary) -> void:
	var broken_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if broken_file == null:
		_expect(false, "startup recovery fixture can replace the primary test file")
		return
	broken_file.store_string("{broken again")
	broken_file.close()
	var startup = MainScene.instantiate()
	startup.save_path = TEST_PATH
	root.add_child(startup)
	await process_frame
	_expect(startup.startup_choice_state == "choice" and startup.player.input_blocked and startup.pending_save_recovered, "valid backup opens one Continue/New Game choice and blocks gameplay")
	var continue_event := InputEventKey.new()
	continue_event.keycode = KEY_ENTER
	continue_event.pressed = true
	startup._unhandled_input(continue_event)
	_expect(startup.startup_choice_state.is_empty() and not startup.player.input_blocked, "Enter continues the save and restores gameplay controls")
	_expect("Forrige sikre lagring" in startup.notification_label.text, "Continue clearly reports when an older safe backup was recovered")
	_expect(startup.build_controller.registered_units.size() == snapshot["construction"]["units"].size(), "startup Continue restores the saved construction")
	startup.persistence_enabled = false
	startup.queue_free()


func _test_main_round_trip(snapshot: Dictionary, source_main) -> void:
	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(snapshot)
	_expect(restore_result["ok"], "fresh Main restores a fully validated snapshot")
	_expect(restored.process_model.money == source_main.process_model.money, "load replaces economy exactly without charging or refunding")
	_expect(restored.build_serial_number == 8, "maximum build serial is restored")
	_expect(restored.build_controller.registered_units.size() == 8 and restored.built_refinery_model.equipment.size() == 8, "all built nodes and model states restore once")
	_expect(restored.built_refinery_model.network.connection_count() == 7 and restored.build_controller.connections.size() == 7, "logical topology and seven visual pipes restore together")
	_expect(restored.build_controller.registered_unit_by_id("built_valve_3").rotation_quadrants == 2, "saved equipment rotation and port orientation are preserved")
	_expect(restored.built_refinery_model.equipment["built_valve_3"]["open"], "manual valve state restores")
	_expect(not restored.built_refinery_model.equipment["built_pump_2"]["running"] and is_equal_approx(restored.built_refinery_model.actual_flow_lps, 0.0), "all pumps and derived flow are stopped on load")
	_expect(not restored.control_station_visible, "transient LS-201 panel state is never restored from a save")
	_expect(not restored.lab_analysis_panel.visible and not restored.built_refinery_model.lab_dispatch_status().get("sample_current", false), "transient lab panel and sample authorization are never restored from a save")
	_expect(restored.player.position.is_equal_approx(Vector3(-4.0, 0.1, 17.0)) and is_equal_approx(restored.player.rotation.y, 1.25), "valid player position and direction restore")

	var source_before: float = snapshot["built_refinery"]["equipment"]["built_tank_1"]["volume_l"]
	var restored_source: float = restored.built_refinery_model.equipment["built_tank_1"]["volume_l"]
	_expect(is_equal_approx(restored_source, source_before), "partial source inventory restores without load-time transfer")
	_expect(is_equal_approx(_total_tank_volume(restored), _total_tank_volume(source_main)), "mid-batch total mass is identical after load")
	var money_before_repeat: int = restored.process_model.money
	var units_before_repeat: int = restored.build_controller.registered_units.size()
	_expect(not restored._apply_snapshot(snapshot)["ok"], "a save cannot be applied over a populated live refinery")
	_expect(restored.process_model.money == money_before_repeat and restored.build_controller.registered_units.size() == units_before_repeat, "rejected repeated load is atomic and leaves live state unchanged")

	var restored_pump = restored.build_controller.registered_unit_by_id("built_pump_2")
	restored.built_refinery_model.interact(restored_pump.unit_id)
	var mass_before_tick := _total_tank_volume(restored)
	restored.built_refinery_model.tick(35.0)
	_expect(is_equal_approx(_total_tank_volume(restored), mass_before_tick), "continued processing after load remains mass conserving")
	restored.built_refinery_model.interact(restored_pump.unit_id)
	restored._on_unit_interacted("sales_terminal")
	var report: Dictionary = restored.built_refinery_model.last_batch_report
	_expect(report["crude_processed_l"] > 580.0 and report["crude_processed_l"] < 590.0, "report tracking continues from the pre-save partial batch")
	_expect(report["crude_cost"] == int(round(report["crude_processed_l"] * 0.3)), "paid crude cost accumulator survives the round trip")

	restored.batch_report_visible = false
	restored.player.set_input_blocked(false)
	restored.build_controller.set_input_blocked(false)
	restored._on_build_placement_requested("tank", Vector3(-11.0, 1.96, 28.0), 0)
	_expect(restored.build_controller.registered_unit_by_id("built_tank_9") != null, "next placement uses a non-colliding serial after load")


func _test_startup_confirmation(main) -> void:
	main.pending_save_data = main._build_snapshot()
	main.startup_choice_state = "choice"
	var new_event := InputEventKey.new()
	new_event.keycode = KEY_N
	new_event.pressed = true
	main._handle_startup_input(new_event)
	_expect(main.startup_choice_state == "confirm_new", "new game requires a separate confirmation step")
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE
	cancel_event.pressed = true
	main._handle_startup_input(cancel_event)
	_expect(main.startup_choice_state == "choice" and main.process_model.money == 100, "cancelling new game preserves the loaded progress")
	main.startup_choice_state = ""
	main.pending_save_data = {}


func _place_full_refinery(main) -> void:
	main._on_build_placement_requested("tank", Vector3(-10.0, 1.96, 14.0), 0)
	main._on_build_placement_requested("pump", Vector3(-6.0, 0.86, 14.0), 1)
	main._on_build_placement_requested("valve", Vector3(-3.5, 0.71, 14.0), 2)
	main._on_build_placement_requested("heater", Vector3(-0.5, 1.66, 14.0), 3)
	main._on_build_placement_requested("column", Vector3(4.0, 3.36, 14.0), 0)
	main._on_build_placement_requested("tank", Vector3(9.0, 1.96, 13.0), 1)
	main._on_build_placement_requested("tank", Vector3(9.0, 1.96, 18.0), 2)
	main._on_build_placement_requested("tank", Vector3(9.0, 1.96, 23.0), 3)


func _connect_full_refinery(main) -> void:
	var source = main.build_controller.registered_unit_by_id("built_tank_1")
	var pump = main.build_controller.registered_unit_by_id("built_pump_2")
	var valve = main.build_controller.registered_unit_by_id("built_valve_3")
	var heater = main.build_controller.registered_unit_by_id("built_heater_4")
	var column = main.build_controller.registered_unit_by_id("built_column_5")
	var light_tank = main.build_controller.registered_unit_by_id("built_tank_6")
	var diesel_tank = main.build_controller.registered_unit_by_id("built_tank_7")
	var heavy_tank = main.build_controller.registered_unit_by_id("built_tank_8")
	main.build_controller._connect_ports(source.get_port("output"), pump.get_port("input"))
	main.build_controller._connect_ports(pump.get_port("output"), valve.get_port("input"))
	main.build_controller._connect_ports(valve.get_port("output"), heater.get_port("input"))
	main.build_controller._connect_ports(heater.get_port("output"), column.get_port("input"))
	main.build_controller._connect_ports(column.get_port("light"), light_tank.get_port("input"))
	main.build_controller._connect_ports(column.get_port("diesel"), diesel_tank.get_port("input"))
	main.build_controller._connect_ports(column.get_port("heavy"), heavy_tank.get_port("input"))


func _total_tank_volume(main) -> float:
	var total := 0.0
	for state in main.built_refinery_model.equipment.values():
		if state["type"] == "tank":
			total += state["volume_l"]
	return total


func _cleanup_test_files() -> void:
	for base_path in [TEST_PATH, LEGACY_PATH]:
		for suffix in ["", ".tmp", ".bak", ".corrupt", ".previous", ".bak.previous", ".corrupt.previous"]:
			var path: String = base_path + String(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
