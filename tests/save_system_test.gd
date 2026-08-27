extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SaveSystemScript = preload("res://scripts/save_system.gd")
const ProcessModelScript = preload("res://scripts/process_model.gd")
const MaterialBalanceScript = preload("res://scripts/material_balance.gd")
const WorldLayoutScript = preload("res://scripts/world_layout.gd")

const TEST_PATH := "user://crudeworks_save_system_test.json"
const LEGACY_PATH := "user://crudeworks_save_system_legacy_test.json"
const AUTOSAVE_STRESS_PATH := "user://crudeworks_area02_autosave_stress_test.json"
const PILOT_SAVE_PATH := "user://crudeworks_pilot_quality_save_test.json"
const CANONICAL_STATE_PATH := "user://crudeworks_area02_canonical_state_test.json"

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_cleanup_test_files()
	await _test_pilot_quality_save_states()
	var source_main = await _create_partial_paid_refinery()
	var snapshot: Dictionary = source_main._build_snapshot()
	_test_schema_validation(snapshot, source_main)
	_test_area02_spatial_migration(snapshot)
	_test_v0304_player_recovery(snapshot)
	_test_canonical_area02_save_states(snapshot)
	_test_optional_delivery_report_validation(snapshot)
	_test_disk_round_trip(snapshot)
	await _test_area02_autosave_stress()
	_test_v1_to_v2_contract_migration(snapshot)
	await _test_startup_continue(snapshot)
	await _test_main_round_trip(snapshot, source_main)
	await _test_vacuum_intent_and_processing_round_trip()
	await _test_fcc_processing_round_trip()
	_test_startup_confirmation(source_main)
	_cleanup_test_files()

	if failures == 0:
		print("PASS: all CrudeWorks save-system tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks save-system check(s) failed" % failures)
		quit(1)


func _test_pilot_quality_save_states() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	main.save_path = PILOT_SAVE_PATH
	root.add_child(main)
	await process_frame
	main.persistence_enabled = true
	main.persistence_ready = true

	main.autosave_time_left = 0.0
	main._update_autosave(0.0)
	var empty_read: Dictionary = SaveSystemScript.read_snapshot(PILOT_SAVE_PATH)
	_expect(
		empty_read["ok"]
		and is_zero_approx(float(empty_read["data"]["pilot"]["diesel_volume_l"]))
		and empty_read["data"]["pilot"]["diesel_spec_status"] == ProcessModelScript.DIESEL_SPEC_NO_DIESEL,
		"new game autosaves before Pilot diesel production"
	)

	var legacy_snapshot: Dictionary = empty_read["data"].duplicate(true)
	legacy_snapshot["pilot"].erase("diesel_spec_status")
	_expect(
		SaveSystemScript.validate_snapshot(legacy_snapshot)["ok"],
		"older format-v2 Pilot saves remain valid without a diesel spec status"
	)
	var legacy_model = ProcessModelScript.new()
	legacy_model.apply_saved_state(legacy_snapshot["pilot"])
	_expect(
		legacy_model.diesel_spec_status == ProcessModelScript.DIESEL_SPEC_NO_DIESEL,
		"legacy Pilot status is derived from its numeric state on load"
	)

	main.process_model.cycle_heater()
	main.process_model.cycle_heater()
	main.process_model.toggle_feed_valve()
	main.process_model.toggle_pump()
	_simulate_pilot(main.process_model, 20.0)
	_expect(
		main.process_model.diesel_spec_status == ProcessModelScript.DIESEL_SPEC_OFF_SPEC,
		"opening Pilot processing produces a canonical OFF_SPEC state"
	)
	main.autosave_time_left = 0.0
	main._update_autosave(0.0)
	var off_spec_read: Dictionary = SaveSystemScript.read_snapshot(PILOT_SAVE_PATH)
	_expect(
		off_spec_read["ok"]
		and typeof(off_spec_read["data"]["pilot"]["diesel_quality_percent"]) in [TYPE_INT, TYPE_FLOAT]
		and off_spec_read["data"]["pilot"]["diesel_spec_status"] == ProcessModelScript.DIESEL_SPEC_OFF_SPEC,
		"autosave accepts OFF_SPEC Pilot diesel with separate numeric quality"
	)

	var unknown_snapshot: Dictionary = off_spec_read["data"].duplicate(true)
	unknown_snapshot["pilot"]["diesel_spec_status"] = ProcessModelScript.DIESEL_SPEC_UNKNOWN
	var unknown_quality: float = float(unknown_snapshot["pilot"]["diesel_quality_percent"])
	_expect(
		SaveSystemScript.write_snapshot(PILOT_SAVE_PATH, unknown_snapshot)["ok"],
		"not-sampled Pilot diesel saves with canonical UNKNOWN status"
	)
	var unknown_read: Dictionary = SaveSystemScript.read_snapshot(PILOT_SAVE_PATH)
	var unknown_model = ProcessModelScript.new()
	unknown_model.apply_saved_state(unknown_read["data"]["pilot"])
	_expect(
		unknown_read["ok"]
		and unknown_model.diesel_spec_status == ProcessModelScript.DIESEL_SPEC_UNKNOWN
		and is_equal_approx(unknown_model.diesel_quality_percent, unknown_quality),
		"UNKNOWN status round-trips without replacing the numeric quality"
	)

	var invalid_status: Dictionary = unknown_snapshot.duplicate(true)
	invalid_status["pilot"]["diesel_spec_status"] = "OFF-SPEC"
	_expect(
		not SaveSystemScript.validate_snapshot(invalid_status)["ok"],
		"formatted HUD quality labels are rejected as canonical Pilot status"
	)
	var nan_quality: Dictionary = unknown_snapshot.duplicate(true)
	nan_quality["pilot"]["diesel_quality_percent"] = NAN
	_expect(
		not SaveSystemScript.validate_snapshot(nan_quality)["ok"],
		"NaN Pilot quality is rejected as corrupted"
	)
	var infinite_quality: Dictionary = unknown_snapshot.duplicate(true)
	infinite_quality["pilot"]["diesel_quality_percent"] = INF
	_expect(
		not SaveSystemScript.validate_snapshot(infinite_quality)["ok"],
		"infinite Pilot quality is rejected as corrupted"
	)

	main.process_model.reset_batch()
	main.process_model.cycle_heater()
	main.process_model.cycle_heater()
	_simulate_pilot(main.process_model, 11.0)
	main.process_model.toggle_feed_valve()
	main.process_model.toggle_pump()
	_simulate_pilot(main.process_model, 20.0)
	_expect(
		main.process_model.pump_running
		and main.process_model.diesel_spec_status == ProcessModelScript.DIESEL_SPEC_ON_SPEC,
		"preheated active Pilot batch reaches canonical ON_SPEC state"
	)
	main.autosave_time_left = 0.0
	main._update_autosave(0.0)
	var active_read: Dictionary = SaveSystemScript.read_snapshot(PILOT_SAVE_PATH)
	_expect(
		active_read["ok"]
		and active_read["data"]["pilot"]["diesel_spec_status"] == ProcessModelScript.DIESEL_SPEC_ON_SPEC,
		"autosave accepts ON_SPEC Pilot diesel during active processing"
	)

	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(active_read["data"])
	var crude_before_resume: float = restored.process_model.crude_volume_l
	var saved_pilot: Dictionary = active_read["data"]["pilot"]
	_expect(
		restore_result["ok"]
		and is_equal_approx(restored.process_model.crude_volume_l, float(saved_pilot["crude_volume_l"]))
		and is_equal_approx(restored.process_model.diesel_volume_l, float(saved_pilot["diesel_volume_l"]))
		and is_equal_approx(restored.process_model.diesel_quality_percent, float(saved_pilot["diesel_quality_percent"]))
		and restored.process_model.diesel_spec_status == ProcessModelScript.DIESEL_SPEC_ON_SPEC
		and restored.process_model.feed_valve_open
		and is_equal_approx(restored.process_model.heater_setpoint_c, 200.0)
		and not restored.process_model.pump_running,
		"active Pilot save/load restores batch state and applies the safe stopped-pump policy"
	)
	restored.process_model.toggle_pump()
	restored.process_model.tick(0.1)
	_expect(
		restored.process_model.crude_volume_l < crude_before_resume,
		"restored active Pilot batch resumes processing after deliberate pump restart"
	)
	main.persistence_enabled = false
	main.queue_free()


func _test_area02_spatial_migration(snapshot: Dictionary) -> void:
	var legacy := snapshot.duplicate(true)
	var translation := WorldLayoutScript.legacy_area02_translation()
	legacy["game_version"] = "0.30.2"
	for placement: Dictionary in legacy["construction"]["units"]:
		placement["position"][0] = float(placement["position"][0]) - translation.x
		placement["position"][1] = float(placement["position"][1]) - translation.y
		placement["position"][2] = float(placement["position"][2]) - translation.z
	var migration := SaveSystemScript.migrate_snapshot(legacy)
	_expect(
		migration["ok"]
		and migration["data"].get("spatial_migrations", []).has("area02_v0303")
		and SaveSystemScript.validate_snapshot(migration["data"])["ok"],
		"v0.30.2 construction receives one explicit valid Area 02 spatial migration"
	)
	if migration["ok"]:
		for index in snapshot["construction"]["units"].size():
			_expect(
				migration["data"]["construction"]["units"][index]["position"]
				== snapshot["construction"]["units"][index]["position"],
				"legacy placement %d translates deterministically without changing relative layout" % index
			)
	_expect(
		legacy["player"] == migration["data"]["player"],
		"Area 02 construction migration does not silently move the saved player"
	)


func _test_v0304_player_recovery(snapshot: Dictionary) -> void:
	var old_world_snapshot := snapshot.duplicate(true)
	old_world_snapshot["game_version"] = "0.30.4"
	old_world_snapshot["player"]["position"] = [400.0, 0.1, 0.0]
	old_world_snapshot["player"]["rotation_y"] = 1.75
	var migration := SaveSystemScript.migrate_snapshot(old_world_snapshot)
	_expect(
		migration["ok"]
		and migration["data"].get("spatial_migrations", []).has("world_v0310_player_recovery")
		and migration["data"].get("spatial_migrations", []).has("world_v0311_player_recovery")
		and Vector3(
			float(migration["data"]["player"]["position"][0]),
			float(migration["data"]["player"]["position"][1]),
			float(migration["data"]["player"]["position"][2])
		).is_equal_approx(WorldLayoutScript.NEW_GAME_SPAWN)
		and SaveSystemScript.validate_snapshot(migration["data"])["ok"],
		"valid v0.30.4 broad-world player positions recover to Harbor without discarding refinery state"
	)
	var terraced_world_snapshot := snapshot.duplicate(true)
	terraced_world_snapshot["game_version"] = "0.31.0"
	terraced_world_snapshot["player"]["position"] = [52.0, 16.1, -285.0]
	var terraced_migration := SaveSystemScript.migrate_snapshot(terraced_world_snapshot)
	_expect(
		terraced_migration["ok"]
		and terraced_migration["data"].get("spatial_migrations", []).has("world_v0311_player_recovery")
		and Vector3(
			float(terraced_migration["data"]["player"]["position"][0]),
			float(terraced_migration["data"]["player"]["position"][1]),
			float(terraced_migration["data"]["player"]["position"][2])
		).is_equal_approx(WorldLayoutScript.NEW_GAME_SPAWN),
		"valid v0.31.0 Upper Plant positions recover after the intimacy rescale"
	)
	var corrupt_snapshot := snapshot.duplicate(true)
	corrupt_snapshot["player"]["position"] = [900.0, 0.1, 0.0]
	var corrupt_migration := SaveSystemScript.migrate_snapshot(corrupt_snapshot)
	_expect(
		corrupt_migration["ok"]
		and not SaveSystemScript.validate_snapshot(corrupt_migration["data"])["ok"],
		"unknown positions outside both current and legacy worlds remain rejected as corrupt"
	)


func _simulate_pilot(model, duration_seconds: float) -> void:
	var timestep := 0.1
	var steps := int(ceil(duration_seconds / timestep))
	for step in steps:
		model.tick(timestep)


func _create_partial_paid_refinery():
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	# The persisted fixture includes one standalone Crude Feed Header in addition
	# to the starter train, while keeping the original 100 kr post-load balance.
	main.process_model.money = 3350
	main.process_model.objective_complete = true
	main._process(0.0)
	_place_full_refinery(main)
	_connect_full_refinery(main)
	main._on_unit_interacted("area02_generator")
	main._on_unit_interacted("instrument_air")
	main._on_unit_interacted("cooling_water")
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

	var invalid_flow := snapshot.duplicate(true)
	invalid_flow["built_refinery"]["equipment"]["built_pump_2"]["flow_setpoint_lps"] = 12.0
	_expect(not SaveSystemScript.validate_snapshot(invalid_flow)["ok"], "unknown saved pump flow targets are rejected")
	var invalid_condition := snapshot.duplicate(true)
	invalid_condition["built_refinery"]["equipment"]["built_pump_2"]["condition_percent"] = 101.0
	_expect(not SaveSystemScript.validate_snapshot(invalid_condition)["ok"], "out-of-range saved pump condition is rejected")
	var invalid_flow_history := snapshot.duplicate(true)
	invalid_flow_history["built_refinery"]["report_flow_total"] = 999999.0
	_expect(not SaveSystemScript.validate_snapshot(invalid_flow_history)["ok"], "impossible accumulated flow history is rejected")
	var invalid_fault := snapshot.duplicate(true)
	invalid_fault["built_refinery"]["equipment"]["built_pump_2"]["fault_id"] = "unknown_fault"
	_expect(not SaveSystemScript.validate_snapshot(invalid_fault)["ok"], "unknown saved maintenance faults are rejected")
	var invalid_service_counter := snapshot.duplicate(true)
	invalid_service_counter["built_refinery"]["equipment"]["built_pump_2"]["processed_since_service_l"] = -1.0
	_expect(not SaveSystemScript.validate_snapshot(invalid_service_counter)["ok"], "negative saved maintenance counters are rejected")
	var invalid_heater_mode := snapshot.duplicate(true)
	invalid_heater_mode["built_refinery"]["equipment"]["built_heater_4"]["control_mode"] = "pid"
	_expect(not SaveSystemScript.validate_snapshot(invalid_heater_mode)["ok"], "unknown saved heater control modes are rejected")
	var invalid_heater_output := snapshot.duplicate(true)
	invalid_heater_output["built_refinery"]["equipment"]["built_heater_4"]["output_percent"] = 101.0
	_expect(not SaveSystemScript.validate_snapshot(invalid_heater_output)["ok"], "out-of-range saved heater output is rejected")
	var legacy_flow := snapshot.duplicate(true)
	legacy_flow["built_refinery"].erase("report_flow_total")
	legacy_flow["built_refinery"]["equipment"]["built_pump_2"].erase("flow_setpoint_lps")
	for field in ["condition_percent", "fault_id", "fault_inspected", "fault_triggered", "processed_since_service_l"]:
		legacy_flow["built_refinery"]["equipment"]["built_pump_2"].erase(field)
	_expect(SaveSystemScript.validate_snapshot(legacy_flow)["ok"], "older v2 saves without flow, condition and filter fields remain valid")
	_expect(snapshot["built_refinery"]["equipment"]["built_tank_1"].has("material_intent"), "current tank snapshots persist material intent")
	var legacy_intent := snapshot.duplicate(true)
	for state in legacy_intent["built_refinery"]["equipment"].values():
		if state["type"] == "tank":
			state.erase("material_intent")
	_expect(SaveSystemScript.validate_snapshot(legacy_intent)["ok"], "older saves without material intent remain valid")
	var legacy_utility := snapshot.duplicate(true)
	legacy_utility["built_refinery"].erase("utility_state")
	for state in legacy_utility["built_refinery"]["equipment"].values():
		if state["type"] == "power_unit":
			state.erase("running")
	_expect(SaveSystemScript.validate_snapshot(legacy_utility)["ok"], "legacy v0.26.2 save without generator or MCC state remains valid")
	var invalid_utility := snapshot.duplicate(true)
	invalid_utility["built_refinery"]["utility_state"]["electricity"]["tripped"] = true
	invalid_utility["built_refinery"]["utility_state"]["electricity"]["trip_id"] = "random_failure"
	_expect(not SaveSystemScript.validate_snapshot(invalid_utility)["ok"], "unknown electrical trip state is rejected before live state mutates")
	var invalid_fuel := snapshot.duplicate(true)
	invalid_fuel["built_refinery"]["utility_state"]["generator_fuel_l"] = 101.0
	_expect(not SaveSystemScript.validate_snapshot(invalid_fuel)["ok"], "fuel above GF-101 capacity is rejected before live state mutates")
	var invalid_air := snapshot.duplicate(true)
	invalid_air["built_refinery"]["utility_state"]["instrument_air"]["tripped"] = true
	invalid_air["built_refinery"]["utility_state"]["instrument_air"]["trip_id"] = ""
	_expect(not SaveSystemScript.validate_snapshot(invalid_air)["ok"], "inconsistent instrument-air trip state is rejected")
	var invalid_cooling := snapshot.duplicate(true)
	invalid_cooling["built_refinery"]["utility_state"]["cooling_water_pump_running"] = "yes"
	_expect(not SaveSystemScript.validate_snapshot(invalid_cooling)["ok"], "non-boolean cooling-water machine state is rejected")
	var mismatched_intent := snapshot.duplicate(true)
	mismatched_intent["built_refinery"]["equipment"]["built_tank_1"]["material_intent"] = "diesel"
	_expect(not SaveSystemScript.validate_snapshot(mismatched_intent)["ok"], "saved material intent cannot conflict with non-empty actual tank contents")


func _test_canonical_area02_save_states(snapshot: Dictionary) -> void:
	var no_global_contract := snapshot.duplicate(true)
	no_global_contract["built_refinery"]["active_contract_id"] = ""
	no_global_contract["built_refinery"]["active_contract_bonus_available"] = false
	_expect(
		SaveSystemScript.validate_snapshot(no_global_contract)["ok"],
		"route-owned crude material remains saveable without a global active-contract pointer"
	)
	_expect_snapshot_disk_round_trip(no_global_contract, "no-global-contract Area 02 state")
	var stale_global_contract := snapshot.duplicate(true)
	stale_global_contract["built_refinery"]["active_contract_id"] = "heavy"
	_expect(
		not SaveSystemScript.validate_snapshot(stale_global_contract)["ok"],
		"stale global contract references remain rejected"
	)
	var missing_route_contract := snapshot.duplicate(true)
	missing_route_contract["built_refinery"]["active_contract_id"] = ""
	missing_route_contract["built_refinery"]["active_contract_bonus_available"] = false
	missing_route_contract["built_refinery"]["equipment"]["built_tank_1"]["contract_id"] = ""
	_expect(
		not SaveSystemScript.validate_snapshot(missing_route_contract)["ok"],
		"material that genuinely depends on a crude contract still requires its route-owned reference"
	)
	var unknown_route_contract := snapshot.duplicate(true)
	unknown_route_contract["built_refinery"]["equipment"]["built_tank_1"]["contract_id"] = "mystery"
	_expect(
		not SaveSystemScript.validate_snapshot(unknown_route_contract)["ok"],
		"unknown tank contract references remain rejected"
	)

	var empty_tank := snapshot.duplicate(true)
	var empty_state: Dictionary = empty_tank["built_refinery"]["equipment"]["built_tank_6"]
	empty_state["volume_l"] = 0.0
	empty_state["contents"] = "empty"
	empty_state["temperature_c"] = 20.0
	empty_state["quality_percent"] = 0.0
	empty_state["quality_status"] = "empty"
	_expect(SaveSystemScript.validate_snapshot(empty_tank)["ok"], "empty product tank saves with explicit empty quality state")
	_expect_snapshot_disk_round_trip(empty_tank, "empty product tank")

	var unsampled := snapshot.duplicate(true)
	var diesel_state: Dictionary = unsampled["built_refinery"]["equipment"]["built_tank_7"]
	diesel_state["quality_status"] = "unanalyzed"
	_expect(SaveSystemScript.validate_snapshot(unsampled)["ok"], "unsampled diesel saves with numeric process quality and explicit unanalyzed state")
	_expect_snapshot_disk_round_trip(unsampled, "unsampled product")
	var on_spec := unsampled.duplicate(true)
	on_spec["built_refinery"]["equipment"]["built_tank_7"]["quality_status"] = "on_spec"
	_expect(SaveSystemScript.validate_snapshot(on_spec)["ok"], "analyzed ON_SPEC diesel saves as a canonical enum")
	_expect_snapshot_disk_round_trip(on_spec, "analyzed ON_SPEC product")
	var off_spec := unsampled.duplicate(true)
	off_spec["built_refinery"]["equipment"]["built_tank_7"]["quality_status"] = "off_spec"
	_expect(SaveSystemScript.validate_snapshot(off_spec)["ok"], "analyzed OFF_SPEC diesel saves as a canonical enum")
	_expect_snapshot_disk_round_trip(off_spec, "analyzed OFF_SPEC product")
	var hud_text_status := unsampled.duplicate(true)
	hud_text_status["built_refinery"]["equipment"]["built_tank_7"]["quality_status"] = "IKKE ANALYSERT — PRØVE KREVES"
	_expect(not SaveSystemScript.validate_snapshot(hud_text_status)["ok"], "formatted tank HUD text is rejected as canonical quality state")

	var nan_tank_quality := unsampled.duplicate(true)
	nan_tank_quality["built_refinery"]["equipment"]["built_tank_7"]["quality_percent"] = NAN
	_expect(not SaveSystemScript.validate_snapshot(nan_tank_quality)["ok"], "NaN Area 2 tank quality remains rejected")
	var infinite_tank_temperature := unsampled.duplicate(true)
	infinite_tank_temperature["built_refinery"]["equipment"]["built_tank_7"]["temperature_c"] = INF
	_expect(not SaveSystemScript.validate_snapshot(infinite_tank_temperature)["ok"], "infinite Area 2 tank temperature remains rejected")
	var finite_temperature := unsampled.duplicate(true)
	finite_temperature["built_refinery"]["equipment"]["built_tank_7"]["temperature_c"] = 250.0
	_expect(SaveSystemScript.validate_snapshot(finite_temperature)["ok"], "finite process-product temperature remains valid")
	var tripped_pump := snapshot.duplicate(true)
	tripped_pump["built_refinery"]["equipment"]["built_pump_2"]["trip_reason"] = "cooling_water_loss"
	_expect(SaveSystemScript.validate_snapshot(tripped_pump)["ok"], "canonical pump trip reasons persist as save data")
	var invalid_trip := snapshot.duplicate(true)
	invalid_trip["built_refinery"]["equipment"]["built_pump_2"]["trip_reason"] = "NO FLOW — maybe broken"
	_expect(not SaveSystemScript.validate_snapshot(invalid_trip)["ok"], "formatted or unknown pump trip text is rejected as canonical state")

	var v028_legacy := snapshot.duplicate(true)
	for state in v028_legacy["built_refinery"]["equipment"].values():
		if state["type"] == "tank":
			state.erase("quality_status")
		elif state["type"] == "pump":
			state.erase("trip_reason")
	_expect(SaveSystemScript.validate_snapshot(v028_legacy)["ok"], "v0.28 saves without explicit quality or pump-trip enums remain valid")

	var utility_shutdown := snapshot.duplicate(true)
	var utilities: Dictionary = utility_shutdown["built_refinery"]["utility_state"]
	utilities["starter_generator_running"] = false
	utilities["instrument_air_compressor_running"] = false
	utilities["cooling_water_pump_running"] = false
	_expect(SaveSystemScript.validate_snapshot(utility_shutdown)["ok"], "utility shutdown state remains saveable")
	_expect_snapshot_disk_round_trip(utility_shutdown, "utility shutdown")
	_expect(SaveSystemScript.validate_snapshot(snapshot)["ok"], "utility recovery state remains saveable")
	_expect_snapshot_disk_round_trip(snapshot, "utility recovery")


func _expect_snapshot_disk_round_trip(snapshot: Dictionary, label: String) -> void:
	var write_result: Dictionary = SaveSystemScript.write_snapshot(CANONICAL_STATE_PATH, snapshot)
	var read_result: Dictionary = SaveSystemScript.read_snapshot(CANONICAL_STATE_PATH) if write_result["ok"] else {}
	_expect(
		write_result["ok"] and read_result.get("ok", false),
		"autosave writer and validator round-trip %s" % label
	)


func _test_optional_delivery_report_validation(snapshot: Dictionary) -> void:
	var with_order := snapshot.duplicate(true)
	with_order["built_refinery"]["last_batch_report"] = {
		"contract_id": "standard",
		"contract_name": "Standard råolje",
		"order_name": "DIESELLEVERANSE",
		"delivery_product": "diesel",
		"delivery_product_name": "Diesel",
		"delivery_target_l": 200.0,
		"delivery_volume_l": 350.0,
		"ideal_temperature_c": 200.0,
		"diesel_target_l": 200.0,
		"required_quality_percent": 90.0,
		"crude_processed_l": 1000.0,
		"light_l": 300.0,
		"diesel_l": 350.0,
		"heavy_l": 350.0,
		"diesel_quality_percent": 100.0,
		"spec_status": "GODKJENT",
		"average_temperature_c": 200.0,
		"average_flow_lps": 10.0,
		"product_revenue": 2800,
		"delivery_bonus": 0,
		"revenue": 2800,
		"crude_cost": 300,
		"net_profit": 2500,
	}
	_expect(SaveSystemScript.validate_snapshot(with_order)["ok"], "current save accepts a catalog-derived delivery-order report")
	var bad_report_flow := with_order.duplicate(true)
	bad_report_flow["built_refinery"]["last_batch_report"]["average_flow_lps"] = 16.0
	_expect(not SaveSystemScript.validate_snapshot(bad_report_flow)["ok"], "batch reports reject an impossible average flow")
	var tampered := with_order.duplicate(true)
	tampered["built_refinery"]["last_batch_report"]["delivery_product"] = "heavy"
	_expect(not SaveSystemScript.validate_snapshot(tampered)["ok"], "save validation rejects a report whose ordered product was edited")
	var partial_metadata := with_order.duplicate(true)
	partial_metadata["built_refinery"]["last_batch_report"].erase("delivery_product")
	_expect(not SaveSystemScript.validate_snapshot(partial_metadata)["ok"], "save validation rejects a partially removed delivery-order field set")
	var legacy_report := with_order.duplicate(true)
	for field in ["order_name", "delivery_product", "delivery_product_name", "delivery_target_l", "delivery_volume_l"]:
		legacy_report["built_refinery"]["last_batch_report"].erase(field)
	_expect(SaveSystemScript.validate_snapshot(legacy_report)["ok"], "older v2 reports remain valid without optional order fields")


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


func _test_area02_autosave_stress() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.money = 3000
	main.process_model.objective_complete = true
	main._process(0.0)
	_place_full_refinery(main)
	_connect_full_refinery(main)
	main._on_unit_interacted("area02_generator")
	main._on_unit_interacted("instrument_air")
	main._on_unit_interacted("cooling_water")
	main.save_path = AUTOSAVE_STRESS_PATH
	main.persistence_enabled = true
	main.persistence_ready = true
	main.autosave_time_left = 0.0
	var source = main.build_controller.registered_unit_by_id("built_tank_1")
	var heater = main.build_controller.registered_unit_by_id("built_heater_4")
	var valve = main.build_controller.registered_unit_by_id("built_valve_3")
	var pump = main.build_controller.registered_unit_by_id("built_pump_2")
	main._on_unit_interacted(source.unit_id)
	main._on_unit_interacted(heater.unit_id)
	main._on_unit_interacted(heater.unit_id)
	main._process(10.0)
	main._on_unit_interacted(valve.unit_id)
	main._on_unit_interacted(pump.unit_id)
	for checkpoint in range(4):
		main.autosave_time_left = 0.0
		main._process(10.0)
		var saved: Dictionary = SaveSystemScript.read_snapshot(AUTOSAVE_STRESS_PATH)
		_expect(saved["ok"], "first Area 02 batch autosave %d writes a valid recoverable snapshot: %s" % [checkpoint + 1, saved.get("message", "")])
	var source_volume: float = main.built_refinery_model.equipment[source.unit_id]["volume_l"]
	_expect(is_equal_approx(source_volume, 600.0), "autosave stress reaches the reported mid-batch range with exactly 400 L processed")
	for checkpoint in range(6):
		main.autosave_time_left = 0.0
		main._process(10.0)
		_expect(SaveSystemScript.read_snapshot(AUTOSAVE_STRESS_PATH)["ok"], "continued first-batch autosave %d remains valid" % [checkpoint + 5])
	var heavy_tank = main.build_controller.registered_unit_by_id("built_tank_8")
	var sales_pump_result: Dictionary = main._create_built_unit("pump", _area02_fixture(Vector3(14.0, 0.86, 23.0)), 0, 10, false)
	var sales_pump = sales_pump_result.get("unit")
	var dispatch_terminal = main.build_controller.registered_unit_by_id("built_product_dispatch_0")
	main.build_controller._connect_ports(heavy_tank.get_port("output"), sales_pump.get_port("input"))
	main.build_controller._connect_ports(sales_pump.get_port("output"), dispatch_terminal.get_port("heavy"))
	main.built_refinery_model.interact(sales_pump.unit_id)
	main._on_unit_interacted(dispatch_terminal.unit_id)
	var dispatch_event := InputEventKey.new()
	dispatch_event.keycode = KEY_1
	dispatch_event.pressed = true
	main._unhandled_input(dispatch_event)
	var final_save: Dictionary = main._write_save(false)
	_expect(final_save["ok"], "post-dispatch Area 02 save succeeds after physical Heavy Residue dispatch: %s" % final_save.get("message", ""))
	var final_read: Dictionary = SaveSystemScript.read_snapshot(AUTOSAVE_STRESS_PATH)
	_expect(final_read["ok"] and final_read["data"]["built_refinery"]["equipment"]["built_tank_8"]["volume_l"] <= 0.001, "saved post-dispatch state preserves consumed Heavy Residue without duplicating it")
	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(final_read.get("data", {}))
	_expect(restore_result["ok"], "fresh Main restores the stress-tested Area 02 snapshot atomically")
	main.persistence_enabled = false
	main.queue_free()
	restored.queue_free()


func _test_v1_to_v2_contract_migration(snapshot: Dictionary) -> void:
	var legacy := snapshot.duplicate(true)
	legacy["format_version"] = 1
	legacy["built_refinery"].erase("active_contract_id")
	legacy["built_refinery"].erase("active_contract_bonus_available")
	legacy["built_refinery"].erase("report_flow_total")
	for equipment_state in legacy["built_refinery"]["equipment"].values():
		if equipment_state["type"] == "pump":
			equipment_state.erase("flow_setpoint_lps")
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
	_expect(_player_built_count(startup) == snapshot["construction"]["units"].size(), "startup Continue restores the saved construction")
	startup.persistence_enabled = false
	startup.queue_free()


func _test_main_round_trip(snapshot: Dictionary, source_main) -> void:
	var restored_snapshot := snapshot.duplicate(true)
	restored_snapshot["built_refinery"]["equipment"]["built_pump_2"]["flow_setpoint_lps"] = 15.0
	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(restored_snapshot)
	_expect(restore_result["ok"], "fresh Main restores a fully validated snapshot")
	_expect(restored.process_model.money == source_main.process_model.money, "load replaces economy exactly without charging or refunding")
	_expect(restored.build_serial_number == 9, "maximum build serial is restored")
	_expect(_player_built_count(restored) == 9 and _player_equipment_count(restored) == 9, "all built nodes and model states restore once")
	var restored_intakes: Array[Dictionary] = restored.build_controller.registered_units.filter(
		func(entry: Dictionary): return entry["node"].unit_id == "built_crude_intake_0"
	)
	var restored_dispatches: Array[Dictionary] = restored.build_controller.registered_units.filter(
		func(entry: Dictionary): return entry["node"].unit_id == "built_product_dispatch_0"
	)
	_expect(
		restored_intakes.size() == 1
		and restored_dispatches.size() == 1
		and Vector2(restored_intakes[0]["node"].position.x, restored_intakes[0]["node"].position.z).is_equal_approx(
			WorldLayoutScript.area02_anchor("crude_intake")
		)
		and Vector2(restored_dispatches[0]["node"].position.x, restored_dispatches[0]["node"].position.z).is_equal_approx(
			WorldLayoutScript.area02_anchor("product_dispatch")
		),
		"load keeps exactly one canonical CI-101 and PD-101 instead of duplicating fixed logistics"
	)
	_expect(restored.built_refinery_model.network.connection_count() == 7 and restored.build_controller.connections.size() == 7, "logical topology and seven visual pipes restore together")
	_expect(
		restored.build_controller.registered_unit_by_id("built_header_9") != null
		and "KOBLE IN" in restored.built_refinery_model.unit_status("built_header_9"),
		"unconnected Crude Feed Header placement and its contextual status restore safely"
	)
	_expect(restored.build_controller.registered_unit_by_id("built_valve_3").rotation_quadrants == 2, "saved equipment rotation and port orientation are preserved")
	_expect(restored.built_refinery_model.equipment["built_valve_3"]["open"], "manual valve state restores")
	_expect(restored.built_refinery_model.starter_generator_running and restored.built_refinery_model.power_status()["bus_available"], "PG-101 running state and valid MCC supply survive save/load")
	_expect(not restored.built_refinery_model.equipment["built_pump_2"]["running"] and is_equal_approx(restored.built_refinery_model.actual_flow_lps, 0.0), "all pumps and derived flow are stopped on load")
	_expect(is_equal_approx(restored.built_refinery_model.equipment["built_pump_2"]["flow_setpoint_lps"], 15.0), "saved pump flow target restores while the pump remains stopped")
	_expect(is_equal_approx(restored.built_refinery_model.equipment["built_pump_2"]["condition_percent"], snapshot["built_refinery"]["equipment"]["built_pump_2"]["condition_percent"]), "saved pump condition restores independently of its safe stopped state")
	_expect(not restored.control_station_visible, "transient LS-201 panel state is never restored from a save")
	_expect(not restored.lab_analysis_panel.visible and not restored.built_refinery_model.lab_dispatch_status().get("sample_current", false), "transient lab panel and sample authorization are never restored from a save")
	_expect(restored.player.position.is_equal_approx(Vector3(-4.0, 0.1, 17.0)) and is_equal_approx(restored.player.rotation.y, 1.25), "valid player position and direction restore")

	var source_before: float = snapshot["built_refinery"]["equipment"]["built_tank_1"]["volume_l"]
	var restored_source: float = restored.built_refinery_model.equipment["built_tank_1"]["volume_l"]
	_expect(is_equal_approx(restored_source, source_before), "partial source inventory restores without load-time transfer")
	var load_balance: Dictionary = MaterialBalanceScript.evaluate(
		source_main.built_refinery_model.material_inventory_snapshot(true, true),
		restored.built_refinery_model.material_inventory_snapshot(true, true)
	)
	_expect(load_balance["conserved"], "mid-batch canonical inventory is identical after load")
	var money_before_repeat: int = restored.process_model.money
	var units_before_repeat: int = restored.build_controller.registered_units.size()
	_expect(not restored._apply_snapshot(restored_snapshot)["ok"], "a save cannot be applied over a populated live refinery")
	_expect(restored.process_model.money == money_before_repeat and restored.build_controller.registered_units.size() == units_before_repeat, "rejected repeated load is atomic and leaves live state unchanged")

	var restored_pump = restored.build_controller.registered_unit_by_id("built_pump_2")
	restored.built_refinery_model.interact(restored_pump.unit_id)
	var inventory_before_tick: Dictionary = restored.built_refinery_model.material_inventory_snapshot(false, false)
	restored.built_refinery_model.tick(35.0)
	var continued_balance: Dictionary = MaterialBalanceScript.evaluate(
		inventory_before_tick,
		restored.built_refinery_model.material_inventory_snapshot(false, false)
	)
	_expect(continued_balance["conserved"], "continued processing after load remains mass conserving")
	restored.built_refinery_model.interact(restored_pump.unit_id)
	var restored_sale: Dictionary = restored.built_refinery_model.sell_diesel()
	if restored_sale["ok"]:
		restored.process_model.credit(restored_sale["revenue"])
	var report: Dictionary = restored.built_refinery_model.last_batch_report
	_expect(report["crude_processed_l"] > 760.0 and report["crude_processed_l"] < 765.0, "report tracking continues from the pre-save partial batch at the restored 15 L/s target")
	_expect(report["crude_cost"] == int(round(report["crude_processed_l"] * 0.3)), "paid crude cost accumulator survives the round trip")
	_expect(report["average_flow_lps"] > 13.4 and report["average_flow_lps"] < 13.5, "report preserves legacy 10 L/s history and weights new 15 L/s operation by processed volume")

	restored.batch_report_visible = false
	restored.player.set_input_blocked(false)
	restored.build_controller.set_input_blocked(false)
	restored._on_build_placement_requested("tank", _area02_fixture(Vector3(-11.0, 1.96, 28.0)), 0)
	_expect(restored.build_controller.registered_unit_by_id("built_tank_10") != null, "next placement uses a non-colliding serial after load")


func _test_vacuum_intent_and_processing_round_trip() -> void:
	var source = MainScene.instantiate()
	source.persistence_enabled = false
	root.add_child(source)
	await process_frame
	for entry in [
		["tank", _area02_fixture(Vector3(-11.0, 1.96, 27.0)), 0, 1],
		["pump", _area02_fixture(Vector3(-7.0, 0.86, 27.0)), 0, 2],
		["vacuum_distillation", _area02_fixture(Vector3(-2.0, 2.76, 27.0)), 0, 3],
		["tank", _area02_fixture(Vector3(5.0, 1.96, 22.0)), 0, 4],
		["tank", _area02_fixture(Vector3(5.0, 1.96, 27.0)), 0, 5],
		["power_unit", _area02_fixture(Vector3(-10.0, 1.36, 17.0)), 0, 6],
	]:
		_expect(source._create_built_unit(entry[0], entry[1], entry[2], entry[3], false)["ok"], "headless VDU fixture restores a buildable unit")
	var model = source.built_refinery_model
	model.set_tank_material_intent("built_tank_1", "heavy")
	var feed = source.build_controller.registered_unit_by_id("built_tank_1")
	var pump = source.build_controller.registered_unit_by_id("built_pump_2")
	var vdu = source.build_controller.registered_unit_by_id("built_vacuum_distillation_3")
	var vgo = source.build_controller.registered_unit_by_id("built_tank_4")
	var residue = source.build_controller.registered_unit_by_id("built_tank_5")
	var power = source.build_controller.registered_unit_by_id("built_power_unit_6")
	model.toggle_starter_generator()
	model.interact(power.unit_id)
	_expect(power != null and is_equal_approx(model.power_status()["capacity_kw"], 200.0), "Power Unit participates in normal construction and raises saved refinery capacity")
	source.build_controller._connect_ports(feed.get_port("output"), pump.get_port("input"))
	source.build_controller._connect_ports(pump.get_port("output"), vdu.get_port("input"))
	source.build_controller._connect_ports(vdu.get_port("vgo"), vgo.get_port("input"))
	source.build_controller._connect_ports(vdu.get_port("vacuum_residue"), residue.get_port("input"))
	model.equipment[feed.unit_id]["contents"] = "heavy"
	model.equipment[feed.unit_id]["volume_l"] = 100.0
	model.equipment[feed.unit_id]["quality_status"] = model.TANK_QUALITY_NOT_APPLICABLE
	model.equipment[pump.unit_id]["running"] = true
	model.tick(2.0)
	var snapshot: Dictionary = source._build_snapshot()
	var vdu_validation: Dictionary = SaveSystemScript.validate_snapshot(snapshot)
	_expect(vdu_validation["ok"], "partial VDU inventory with intents validates as a normal save snapshot: %s" % vdu_validation["message"])
	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(snapshot)
	_expect(restore_result["ok"], "fresh Main restores VDU construction and material-intent state")
	var restored_model = restored.built_refinery_model
	_expect(restored_model.network.filter_routes_by_process_type(restored_model.network.find_complete_routes(), "vacuum_distillation").size() == 1 and restored_model.equipment["built_tank_1"]["material_intent"] == "heavy" and restored_model.equipment["built_tank_4"]["material_intent"] == "vacuum_gas_oil" and restored_model.equipment["built_tank_5"]["material_intent"] == "vacuum_residue", "restored VDU routes preserve source and typed-output tank intent without a configuration menu")
	_expect(restored.build_controller.registered_unit_by_id("built_power_unit_6") != null and is_equal_approx(restored_model.power_status()["capacity_kw"], 200.0), "Power Unit placement restores through the normal snapshot path without a separate utility save format")
	_expect(is_equal_approx(restored_model.equipment["built_tank_1"]["volume_l"], 80.0) and is_equal_approx(restored_model.equipment["built_tank_4"]["volume_l"], 12.0) and is_equal_approx(restored_model.equipment["built_tank_5"]["volume_l"], 8.0), "VDU save/load preserves exact partial atomic inventory")
	restored_model.equipment["built_pump_2"]["running"] = true
	var mass_before := _total_tank_volume(restored)
	restored_model.tick(1.0)
	_expect(is_equal_approx(restored_model.equipment["built_tank_1"]["volume_l"], 70.0) and is_equal_approx(restored_model.equipment["built_tank_4"]["volume_l"], 18.0) and is_equal_approx(restored_model.equipment["built_tank_5"]["volume_l"], 12.0) and is_equal_approx(_total_tank_volume(restored), mass_before), "restored VDU route continues with one mass-conserving atomic transaction")
	source.queue_free()
	restored.queue_free()


func _test_fcc_processing_round_trip() -> void:
	var source = MainScene.instantiate()
	source.persistence_enabled = false
	root.add_child(source)
	await process_frame
	for entry in [
		["tank", _area02_fixture(Vector3(-13.0, 1.96, 35.0)), 0, 1],
		["pump", _area02_fixture(Vector3(-9.0, 0.86, 35.0)), 0, 2],
		["catalytic_cracking", _area02_fixture(Vector3(-3.0, 2.86, 35.0)), 0, 3],
		["tank", _area02_fixture(Vector3(5.0, 1.96, 30.0)), 0, 4],
		["tank", _area02_fixture(Vector3(5.0, 1.96, 35.0)), 0, 5],
		["tank", _area02_fixture(Vector3(12.0, 1.96, 30.0)), 0, 6],
	]:
		_expect(source._create_built_unit(entry[0], entry[1], entry[2], entry[3], false)["ok"], "headless FCC fixture creates normal buildable equipment")
	var model = source.built_refinery_model
	model.toggle_starter_generator()
	model.set_tank_material_intent("built_tank_1", "vacuum_gas_oil")
	var feed = source.build_controller.registered_unit_by_id("built_tank_1")
	var pump = source.build_controller.registered_unit_by_id("built_pump_2")
	var fcc = source.build_controller.registered_unit_by_id("built_catalytic_cracking_3")
	var gasoline = source.build_controller.registered_unit_by_id("built_tank_4")
	var lpg = source.build_controller.registered_unit_by_id("built_tank_5")
	var lco = source.build_controller.registered_unit_by_id("built_tank_6")
	source.build_controller._connect_ports(feed.get_port("output"), pump.get_port("input"))
	source.build_controller._connect_ports(pump.get_port("output"), fcc.get_port("input"))
	source.build_controller._connect_ports(fcc.get_port("gasoline"), gasoline.get_port("input"))
	source.build_controller._connect_ports(fcc.get_port("lpg"), lpg.get_port("input"))
	source.build_controller._connect_ports(fcc.get_port("lco"), lco.get_port("input"))
	model.equipment[feed.unit_id]["contents"] = "vacuum_gas_oil"
	model.equipment[feed.unit_id]["volume_l"] = 100.0
	model.equipment[feed.unit_id]["quality_status"] = model.TANK_QUALITY_NOT_APPLICABLE
	model.equipment[pump.unit_id]["running"] = true
	model.tick(2.0)
	var snapshot: Dictionary = source._build_snapshot()
	var validation: Dictionary = SaveSystemScript.validate_snapshot(snapshot)
	_expect(validation["ok"], "partial FCC inventory and typed material intents validate as a normal save snapshot: %s" % validation["message"])
	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var restore_result: Dictionary = restored._apply_snapshot(snapshot)
	_expect(restore_result["ok"], "fresh Main restores FCC construction and VGO upgrading state")
	var restored_model = restored.built_refinery_model
	_expect(restored_model.network.filter_routes_by_process_type(restored_model.network.find_complete_routes(), "catalytic_cracking").size() == 1 and restored_model.equipment["built_tank_1"]["material_intent"] == "vacuum_gas_oil" and restored_model.equipment["built_tank_4"]["material_intent"] == "gasoline_blendstock" and restored_model.equipment["built_tank_5"]["material_intent"] == "lpg" and restored_model.equipment["built_tank_6"]["material_intent"] == "light_cycle_oil", "restored FCC route preserves every typed output destination")
	_expect(is_equal_approx(restored_model.equipment["built_tank_1"]["volume_l"], 80.0) and is_equal_approx(restored_model.equipment["built_tank_4"]["volume_l"], 11.0) and is_equal_approx(restored_model.equipment["built_tank_5"]["volume_l"], 5.0) and is_equal_approx(restored_model.equipment["built_tank_6"]["volume_l"], 4.0), "FCC save/load preserves exact partial 55/25/20 inventory")
	restored_model.equipment["built_pump_2"]["running"] = true
	var mass_before := _total_tank_volume(restored)
	restored_model.tick(1.0)
	_expect(is_equal_approx(restored_model.equipment["built_tank_1"]["volume_l"], 70.0) and is_equal_approx(restored_model.equipment["built_tank_4"]["volume_l"], 16.5) and is_equal_approx(restored_model.equipment["built_tank_5"]["volume_l"], 7.5) and is_equal_approx(restored_model.equipment["built_tank_6"]["volume_l"], 6.0) and is_equal_approx(_total_tank_volume(restored), mass_before), "restored FCC route continues with one mass-conserving atomic transaction")
	source.queue_free()
	restored.queue_free()


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
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(-10.0, 1.96, 14.0)), 0)
	main._on_build_placement_requested("pump", _area02_fixture(Vector3(-6.0, 0.86, 14.0)), 1)
	main._on_build_placement_requested("valve", _area02_fixture(Vector3(-3.5, 0.71, 14.0)), 2)
	main._on_build_placement_requested("heater", _area02_fixture(Vector3(-0.5, 1.66, 14.0)), 3)
	main._on_build_placement_requested("column", _area02_fixture(Vector3(4.0, 3.36, 14.0)), 0)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(9.0, 1.96, 13.0)), 1)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(9.0, 1.96, 18.0)), 2)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(9.0, 1.96, 23.0)), 3)
	main._on_build_placement_requested("header", _area02_fixture(Vector3(-10.0, 0.96, 28.0)), 0)


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


func _player_built_count(main) -> int:
	var count := 0
	for entry in main.build_controller.registered_units:
		if not bool(entry.get("fixed", false)):
			count += 1
	return count


func _player_equipment_count(main) -> int:
	var count := 0
	for state in main.built_refinery_model.equipment.values():
		if not String(state.get("type", "")) in ["crude_intake", "product_dispatch"]:
			count += 1
	return count


func _area02_fixture(legacy_position: Vector3) -> Vector3:
	return legacy_position + WorldLayoutScript.legacy_area02_translation()


func _cleanup_test_files() -> void:
	for base_path in [TEST_PATH, LEGACY_PATH, AUTOSAVE_STRESS_PATH, PILOT_SAVE_PATH, CANONICAL_STATE_PATH]:
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
