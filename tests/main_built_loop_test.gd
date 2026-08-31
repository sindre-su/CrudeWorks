extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const WorldLayoutScript = preload("res://scripts/world_layout.gd")
const EquipmentCatalogScript = preload("res://scripts/equipment_catalog.gd")
const MaterialBalanceScript = preload("res://scripts/material_balance.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	_expect(
		main.objective_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
		and main.alarm_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
		and main.objective_label.offset_bottom <= main.hud_label.position.y
		and main.alarm_label.offset_bottom <= main.hud_label.position.y,
		"1280x720 top objective/alarm band wraps text and stays above the HUD"
	)
	_expect(
		main.notification_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
		and main.notification_label.offset_bottom <= main.prompt_label.offset_top
		and main.prompt_label.offset_bottom <= -54.0
		and main.notification_label.offset_top <= -218.0,
		"1280x720 notifications and two-line contextual power prompts use separate bottom bands"
	)
	_expect(
		main.objective_label.offset_left >= -320.0
		and main.objective_label.offset_right <= 320.0
		and main.alarm_label.offset_left >= -360.0
		and main.alarm_label.offset_right <= 360.0
		and main.help_label.position.x >= 0.0
		and main.help_label.position.x + main.help_label.size.x <= 1280.0,
		"1280x720 HUD bands keep objective, alarms and controls inside the reference viewport"
	)
	main._process(0.0)
	_expect(
		main.liquid_levels["raw_tank"]["node"].visible
		and not main.liquid_levels["diesel_tank"]["node"].visible,
		"new Pilot visuals derive from the initial canonical crude and product volumes"
	)
	var raw_shell: CylinderMesh = main.units["raw_tank"].mesh_instance.mesh
	var fuel_shell: CylinderMesh = main.units["generator_fuel"].mesh_instance.mesh
	_expect(
		not raw_shell.cap_top and not raw_shell.cap_bottom
		and not fuel_shell.cap_top and not fuel_shell.cap_bottom
		and main.liquid_levels["raw_tank"]["node"].get_meta("tank_liquid_render_path") == "canonical_cylinder"
		and main.liquid_levels["generator_fuel"]["node"].get_meta("tank_liquid_render_path") == "canonical_cylinder",
		"Pilot and GF-101 use one shared liquid path inside open transparent shells without triangulated shell caps"
	)
	_expect(
		main.liquid_levels["generator_fuel"]["node"].visible
		and is_equal_approx(
			main.liquid_levels["generator_fuel"]["node"].scale.y / main.liquid_levels["generator_fuel"]["max_height"],
			main.built_refinery_model.generator_fuel_l / main.built_refinery_model.GENERATOR_FUEL_CAPACITY_L
		),
		"GF-101 visible fill is derived from its canonical generator-fuel inventory"
	)
	for ratio in [0.0, 0.1, 0.5, 0.9, 1.0]:
		main._set_liquid_level("raw_tank", ratio)
		_expect(
			main.liquid_levels["raw_tank"]["node"].visible == (ratio > 0.001)
			and is_equal_approx(
				main.liquid_levels["raw_tank"]["node"].scale.y / main.liquid_levels["raw_tank"]["max_height"],
				ratio if ratio > 0.001 else 0.015 / main.liquid_levels["raw_tank"]["max_height"]
			),
			"fixed tank liquid path remains deterministic at %.0f%% fill" % (ratio * 100.0)
		)
	main._update_process_visuals(0.0)
	main.process_model.crude_volume_l = 500.0
	main.process_model.light_product_l = 100.0
	main.process_model.diesel_volume_l = ProcessModel.DIESEL_TARGET_L
	main.process_model.heavy_product_l = 100.0
	main.process_model.diesel_quality_percent = 100.0
	main.process_model.diesel_spec_status = ProcessModel.DIESEL_SPEC_ON_SPEC
	main._update_process_visuals(0.0)
	_expect(
		is_equal_approx(main.liquid_levels["raw_tank"]["node"].scale.y / main.liquid_levels["raw_tank"]["max_height"], 0.5)
		and main.liquid_levels["light_tank"]["node"].visible
		and main.liquid_levels["diesel_tank"]["node"].visible
		and main.liquid_levels["heavy_tank"]["node"].visible,
		"active Pilot batch visual fill follows each canonical tank volume"
	)
	main.process_model.sell_diesel()
	main._update_process_visuals(0.0)
	_expect(
		is_zero_approx(main.process_model.diesel_volume_l)
		and not main.liquid_levels["diesel_tank"]["node"].visible
		and main.liquid_levels["light_tank"]["node"].visible
		and main.liquid_levels["heavy_tank"]["node"].visible,
		"Pilot completion consumes sold diesel visually while preserving canonical unsold fractions"
	)
	var pilot_snapshot: Dictionary = main._build_snapshot()
	var pilot_restored = MainScene.instantiate()
	pilot_restored.persistence_enabled = false
	root.add_child(pilot_restored)
	await process_frame
	var pilot_restore_result: Dictionary = pilot_restored._apply_snapshot(pilot_snapshot)
	pilot_restored._update_process_visuals(0.0)
	_expect(
		pilot_restore_result["ok"]
		and not pilot_restored.liquid_levels["diesel_tank"]["node"].visible
		and pilot_restored.liquid_levels["light_tank"]["node"].visible,
		"Pilot save/load rebuilds tank visuals from restored canonical inventory"
	)
	pilot_restored.queue_free()
	main.process_model.reset_batch()
	main._update_process_visuals(0.0)
	_expect(
		main.liquid_levels["raw_tank"]["node"].visible
		and not main.liquid_levels["light_tank"]["node"].visible
		and not main.liquid_levels["diesel_tank"]["node"].visible
		and not main.liquid_levels["heavy_tank"]["node"].visible,
		"Pilot restart creates no stale product fill"
	)
	main._process(0.0)
	var intake_marker = main.build_controller.registered_unit_by_id(EquipmentCatalogScript.CRUDE_TERMINAL_ID)
	var dispatch_marker = main.build_controller.registered_unit_by_id(EquipmentCatalogScript.PRODUCT_TERMINAL_ID)
	_expect(intake_marker.guidance_label.visible and not dispatch_marker.guidance_label.visible, "first Area 02 objective highlights CI-101 without prematurely highlighting PD-101")
	main.built_refinery_model.first_intake_received = true
	main._process(0.0)
	_expect(not intake_marker.guidance_label.visible, "CI-101 onboarding marker reduces after the first delivery is received")
	main.built_refinery_model.first_atmospheric_production = true
	main._process(0.0)
	_expect(dispatch_marker.guidance_label.visible, "first atmospheric production highlights PD-101 for the first physical dispatch")
	main.built_refinery_model.first_physical_dispatch_completed = true
	main._process(0.0)
	_expect(not dispatch_marker.guidance_label.visible, "PD-101 marker reduces after the first physical dispatch")
	main.built_refinery_model.first_intake_received = false
	main.built_refinery_model.first_atmospheric_production = false
	main.built_refinery_model.first_physical_dispatch_completed = false

	main.process_model.money = ProcessModel.PILOT_CONTRACT_MINIMUM_REVENUE
	main.process_model.objective_complete = true
	main._process(0.0)
	_expect(main.build_mode_unlocked, "pilot completion unlocks Area 02")
	_expect(main.build_controller.unlocked, "build controller receives the progression unlock")
	main._update_unit_statuses()
	_expect("VENTER" in main.units["sales_terminal"].status_label.text, "terminal readiness switches from sold pilot inventory to built diesel")

	_place_full_refinery(main)
	_expect(main.process_model.money == 400, "pilot contract preserves one recovery batch after the starter refinery")
	_connect_full_refinery(main)
	var validation: Dictionary = main.built_refinery_model.network.validate_configuration()
	_expect(validation["valid"], "Main placement and connection hooks create a valid refinery route")
	_expect(main.build_controller.connections.size() == 13, "Main route creates process and PD-101 dispatch connections")
	main._on_unit_interacted("area02_control")
	_expect(not main.control_station_visible and "låses opp" in main.notification_label.text, "LS-201 remains locked until the built refinery is commissioned manually")

	var source = _unit(main, "built_tank_1")
	var valve = _unit(main, "built_valve_3")
	var heater = _unit(main, "built_heater_4")
	var pump = _unit(main, "built_pump_2")
	var load_result: Dictionary = main.built_refinery_model.interact(source.unit_id)
	_expect(load_result["ok"] and load_result["charge"] == 0, "first Main-integrated crude load uses the commissioning batch")
	var no_power_start: Dictionary = main.built_refinery_model.interact(pump.unit_id)
	_expect(not no_power_start["ok"] and "NO POWER" in no_power_start["message"], "new Area 02 pump clearly refuses its first start while PG-101 is off")
	_expect("NO POWER" in main.built_refinery_model.interaction_prompt(pump.unit_id) and "start PG-101" in main.built_refinery_model.interaction_prompt(pump.unit_id), "focused unpowered pump exposes its recovery action before a repeated failed start")
	main._on_unit_interacted("area02_generator")
	main._update_unit_statuses()
	_expect(main.built_refinery_model.starter_generator_running and "FUEL" in main.units["area02_generator"].status_label.text and "NORMAL" in main.units["area02_mcc"].status_label.text and "RESERVE" in main.units["area02_mcc"].status_label.text, "physical PG-101 and MCC-101 world labels expose fuel, bus state and reserve before process startup")
	main._on_unit_interacted("area02_mcc")
	_expect("MCC-101 — BUS ENERGIZED" in main.notification_label.text and "Reserve" in main.notification_label.text, "MCC inspection uses the temporary feedback band for a concise load diagnosis")
	main._on_unit_interacted("instrument_air")
	main._on_unit_interacted("cooling_water")
	main._update_unit_statuses()
	_expect(
		main.built_refinery_model.instrument_air_available()
		and main.built_refinery_model.cooling_water_available()
		and "NORMAL" in main.units["instrument_air"].status_label.text
		and "NORMAL" in main.units["cooling_water"].status_label.text,
		"physical IA-101 and CWP-101 complete the utility startup before CDU operation"
	)
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.tick(10.0)
	_expect(main.built_refinery_model.interact(pump.unit_id)["ok"], "Main-integrated built pump starts")
	main._update_unit_statuses()
	_expect(pump.pump_rotor_running, "Main status refresh runs the built pump's physical rotor only while commanded on")
	var source_before_low_flow: float = main.built_refinery_model.equipment[source.unit_id]["volume_l"]
	main.built_refinery_model.tick(1.0)
	main._update_user_interface()
	_expect(is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], source_before_low_flow) and "LOW FLOW" in main.alarm_label.text, "closed built valve creates a visible LOW FLOW alarm without consuming crude")
	main._update_unit_statuses()
	_expect(pump.alarm_severity == "MEDIUM" and pump.alarm_beacon.visible and valve.alarm_severity.is_empty(), "route-local LOW FLOW marks only the affected built pump, not adjacent Train A equipment")
	_expect("STENGT" in valve.status_label.text and is_equal_approx(valve.valve_handle.rotation.y, deg_to_rad(90.0)), "closed valve world status and handle agree")
	main._on_unit_interacted(valve.unit_id)
	main.built_refinery_model.equipment[heater.unit_id]["temperature_c"] = 300.0
	main._update_unit_statuses()
	_expect(heater.alarm_severity == "HIGH" and heater.alarm_beacon.visible, "existing HIGH TEMPERATURE marks the route heater with the highest local severity")
	main.built_refinery_model.equipment[heater.unit_id]["temperature_c"] = 200.0
	_expect("ÅPEN" in valve.status_label.text and is_equal_approx(valve.valve_handle.rotation.y, 0.0), "opening valve updates world status and handle")
	main.built_refinery_model.tick(100.0)
	main._on_unit_interacted("built_tank_7")
	main._on_unit_interacted("sales_terminal")
	var close_lab_event := InputEventKey.new()
	close_lab_event.keycode = KEY_ENTER
	close_lab_event.pressed = true
	main._unhandled_input(close_lab_event)
	_expect(main.built_refinery_model.diesel_is_approved(), "Main-integrated refinery produces LAB-approved diesel")
	main._update_unit_statuses()
	_expect(pump.alarm_severity.is_empty() and heater.alarm_severity.is_empty(), "restored route conditions clear derived pump and heater beacons automatically")
	_expect("KLAR" in main.units["sales_terminal"].status_label.text, "terminal becomes ready for approved built diesel")
	var diesel_visual = _unit(main, "built_tank_7")
	_expect(
		diesel_visual.liquid_level.visible
		and is_equal_approx(
			diesel_visual.liquid_level.scale.y / diesel_visual.liquid_max_height,
			main.built_refinery_model.equipment["built_tank_7"]["volume_l"] / main.built_refinery_model.equipment["built_tank_7"]["capacity_l"]
		),
		"built tank fill is derived from canonical stored volume before dispatch"
	)

	var money_before_lab: int = main.process_model.money
	var diesel_before_lab: float = main.built_refinery_model.equipment["built_tank_7"]["volume_l"]
	main._on_unit_interacted("sales_terminal")
	_expect(
		main.process_model.money == money_before_lab
		and is_equal_approx(main.built_refinery_model.equipment["built_tank_7"]["volume_l"], diesel_before_lab)
		and main.lab_analysis_panel.visible,
		"LAB-101 does not sell the commissioning batch directly"
	)
	main._unhandled_input(close_lab_event)
	_dispatch_main_product(main, "diesel")
	_expect(main.process_model.money == 2000, "PD-101 credits exactly 200 L of commissioning diesel through the shared economy")
	_expect(diesel_visual.liquid_level.visible and is_equal_approx(main.built_refinery_model.equipment["built_tank_7"]["volume_l"], 150.0), "PD-101 contract delivery preserves excess diesel in canonical inventory")
	_expect(main.built_refinery_model.commissioning_contract_complete, "first built sale persistently completes Area 02 commissioning")
	_expect(not main.batch_report_visible and not main.player.input_blocked and not main.build_controller.input_blocked, "contract completion returns directly to physical play without a legacy batch-report modal")
	_expect("OMRÅDE 02 FULLFØRT" in main.built_refinery_model.objective_text(), "objective changes after commissioning completion")
	_expect(main.built_refinery_model.diesel_is_approved(), "contract delivery preserves the approved excess diesel")
	main._update_unit_statuses()
	_expect("PRØVE KREVES" in main.units["sales_terminal"].status_label.text, "terminal keeps diesel LAB state distinct while product inventory remains")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 2000 and "dieselprøve" in main.notification_label.text, "repeated LAB-101 interaction cannot duplicate PD-101 sale revenue")
	_dispatch_main_product(main, "diesel")
	_expect(main.process_model.money == 3200 and is_zero_approx(main.built_refinery_model.equipment["built_tank_7"]["volume_l"]), "explicit diesel spotsalg clears only the excess inventory")
	var heavy_tank = _unit(main, "built_tank_8")
	var heavy_before_direct_interaction: float = main.built_refinery_model.equipment[heavy_tank.unit_id]["volume_l"]
	main._on_unit_interacted(heavy_tank.unit_id)
	_expect(
		is_equal_approx(main.built_refinery_model.equipment[heavy_tank.unit_id]["volume_l"], heavy_before_direct_interaction)
		and main.process_model.money == 3200,
		"product-tank interaction is inspect/connect only and cannot sell inventory"
	)
	_dispatch_main_product(main, "heavy")
	_expect(main.process_model.money == 3900 and is_zero_approx(main.built_refinery_model.equipment[heavy_tank.unit_id]["volume_l"]), "PD-101 dispatches Heavy Residue once at canonical pricing")
	main._on_secondary_unit_interacted(heater.unit_id)
	_expect(main.built_refinery_model.equipment[heater.unit_id]["control_mode"] == "auto" and "TIC-201 AUTO" in main.notification_label.text, "commissioned player can enable physical TIC-201 AUTO on the existing heater")
	_dispatch_main_product(main, "light")
	_expect(is_equal_approx(main.built_refinery_model.product_volume_l(), 0.0) and main.process_model.money == 5400, "PD-101 dispatches the remaining Naphtha and credits its canonical revenue")
	main._on_unit_interacted("area02_control")
	_expect(main.control_station_visible and main.player.input_blocked and main.build_controller.input_blocked, "unlocked LS-201 opens a live modal and blocks field/build controls")
	main._update_user_interface()
	_expect("REFINERY OPERATIONS" in main.control_station_label.text and "POWER" in main.control_station_label.text and "PG-101: RUNNING" in main.control_station_label.text and "PU-101: NOT INSTALLED" in main.control_station_label.text and "MCC-101: ENERGIZED — NORMAL" in main.control_station_label.text and "Pumpe:" in main.control_station_label.text and "TIC:" in main.control_station_label.text, "operations console presents a concise source, MCC, flow and temperature overview")
	_expect("Feed: INGEN" in main.control_station_label.text and "ATTENTION" in main.control_station_label.text and "TRIPPED — DRY RUN" in main.control_station_label.text, "idle operations console preserves the completed batch dry-run trip")
	main._update_unit_statuses()
	_expect("VENTER — RÅOLJE" in main.units["area02_control"].status_label.text, "idle LS-201 world status points the player toward the next delivery")
	var empty_remote_start := InputEventKey.new()
	empty_remote_start.keycode = KEY_1
	empty_remote_start.pressed = true
	main._unhandled_input(empty_remote_start)
	_expect(main.control_station_visible and "START SPERRET" in main.control_station_feedback, "LS-201 keeps the panel open and explains an empty-source remote start rejection")
	var close_control_event := InputEventKey.new()
	close_control_event.keycode = KEY_ESCAPE
	close_control_event.pressed = true
	main._unhandled_input(close_control_event)
	_expect(not main.control_station_visible and not main.player.input_blocked and not main.build_controller.input_blocked, "Escape closes LS-201 without issuing another process command")
	main._on_unit_interacted(source.unit_id)
	_expect("CI-101" in main.notification_label.text, "empty commissioned source directs the player to physical CI-101 intake")
	var money_before_intake: int = main.process_model.money
	var paid_load: Dictionary = main.built_refinery_model.load_crude_batch(source.unit_id, true, "standard")
	main.process_model.purchase(int(paid_load.get("charge", 0)))
	_expect(paid_load["ok"] and main.process_model.money == money_before_intake - 300, "legacy fixture loads one paid batch through the canonical purchase calculation")
	_expect(is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], 1000.0), "paid fixture batch loads exactly 1 000 L")

	main.built_refinery_model.interact(pump.unit_id)
	main.built_refinery_model.tick(10.0)
	main.built_refinery_model.interact(pump.unit_id)
	var products_before_warning: float = main.built_refinery_model.product_volume_l()
	var source_before_disposal: float = main.built_refinery_model.equipment[source.unit_id]["volume_l"]
	main.process_model.crude_volume_l = 123.0
	main._on_reset_requested()
	_expect(is_equal_approx(main.built_refinery_model.product_volume_l(), products_before_warning), "first R only arms product disposal")
	_expect(main.discard_confirmation_time_left > 0.0, "first R opens a timed disposal confirmation")
	main._process(4.1)
	main._on_reset_requested()
	_expect(is_equal_approx(main.built_refinery_model.product_volume_l(), products_before_warning), "expired confirmation cannot destroy products")
	main.built_refinery_model.interact(pump.unit_id)
	main.built_refinery_model.tick(1.0)
	main.built_refinery_model.interact(pump.unit_id)
	var products_after_revision: float = main.built_refinery_model.product_volume_l()
	source_before_disposal = main.built_refinery_model.equipment[source.unit_id]["volume_l"]
	main._on_reset_requested()
	_expect(is_equal_approx(main.built_refinery_model.product_volume_l(), products_after_revision), "new production invalidates an older disposal confirmation")
	main._on_reset_requested()
	_expect(is_equal_approx(main.process_model.crude_volume_l, 123.0), "post-unlock R cannot create another free pilot batch")
	_expect(is_equal_approx(main.built_refinery_model.product_volume_l(), 0.0), "second confirmed R clears built products (%s)" % main.notification_label.text)
	_expect(is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], source_before_disposal), "product disposal does not erase or duplicate source crude")

	var removable_tank = _unit(main, "built_tank_6")
	var money_before_removal: int = main.process_model.money
	main._on_build_removal_requested(removable_tank)
	main._on_build_removal_requested(removable_tank)
	_expect(main.process_model.money == money_before_removal + removable_tank.purchase_cost, "same equipment can only be refunded once")
	await _test_heavy_contract_through_main()
	await _test_out_of_bounds_recovery()

	if failures == 0:
		print("PASS: full Main-integrated CrudeWorks built loop passed")
		quit(0)
	else:
		printerr("FAIL: %d Main integration check(s) failed" % failures)
		quit(1)


func _test_heavy_contract_through_main() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.money = 3600
	main.process_model.objective_complete = true
	main._process(0.0)
	_place_full_refinery(main)
	_connect_full_refinery(main)
	main.built_refinery_model.commissioning_batch_available = false
	main.built_refinery_model.commissioning_contract_complete = true
	main._on_unit_interacted("area02_generator")
	main._on_unit_interacted("instrument_air")
	main._on_unit_interacted("cooling_water")
	var source = _unit(main, "built_tank_1")
	var heavy_load: Dictionary = main.built_refinery_model.load_crude_batch(source.unit_id, true, "heavy")
	main.process_model.purchase(int(heavy_load.get("charge", 0)))
	_expect(main.process_model.money == 820 and main.built_refinery_model.active_contract_id == "heavy", "Main Heavy choice charges exactly 180 kr and locks the selected feed")
	var heater = _unit(main, "built_heater_4")
	var valve = _unit(main, "built_valve_3")
	var pump = _unit(main, "built_pump_2")
	main.player.secondary_interacted.emit(pump.unit_id)
	_expect(
		is_equal_approx(main.built_refinery_model.equipment[pump.unit_id]["flow_setpoint_lps"], 15.0)
		and "mindre temperaturmargin" in main.notification_label.text,
		"field Q interaction selects high flow and explains its quality tradeoff"
	)
	main.built_refinery_model.equipment[heater.unit_id]["temperature_c"] = 230.0
	main.built_refinery_model.equipment[heater.unit_id]["setpoint_c"] = 230.0
	main._on_unit_interacted("area02_control")
	_expect("mål 15.0 L/s" in main.control_station_label.text and "Pumpe:" in main.control_station_label.text, "operations console distinguishes pump state from the selected high-flow target")
	var remote_flow := InputEventKey.new()
	remote_flow.keycode = KEY_3
	remote_flow.pressed = true
	main._unhandled_input(remote_flow)
	main._unhandled_input(remote_flow)
	_expect(is_equal_approx(main.built_refinery_model.equipment[pump.unit_id]["flow_setpoint_lps"], 10.0), "LS-201 key 3 cycles the same pump target back to normal flow")
	var remote_start := InputEventKey.new()
	remote_start.keycode = KEY_1
	remote_start.pressed = true
	main._unhandled_input(remote_start)
	_expect(main.built_refinery_model.equipment[pump.unit_id]["running"], "Main Heavy batch can start its active-route pump from LS-201")
	main.built_refinery_model.tick(1.0)
	main._update_user_interface()
	_expect("LOW FLOW" in main.control_station_label.text and not ("P-201 er startet" in main.control_station_label.text), "operations console lists the active LOW FLOW alarm ahead of stale successful-command feedback")
	var close_for_valve := InputEventKey.new()
	close_for_valve.keycode = KEY_ESCAPE
	close_for_valve.pressed = true
	main._unhandled_input(close_for_valve)
	main._on_unit_interacted(valve.unit_id)
	main._on_unit_interacted("area02_control")
	var light_tank_state: Dictionary = main.built_refinery_model.equipment["built_tank_6"]
	light_tank_state["contents"] = "light"
	light_tank_state["volume_l"] = light_tank_state["capacity_l"]
	main.built_refinery_model.tick(1.0)
	main._update_user_interface()
	_expect("TANK FULL" in main.control_station_label.text and not ("P-201 er startet" in main.control_station_label.text), "current tank-full alarm outranks cached remote-start feedback")
	main._update_unit_statuses()
	_expect(_unit(main, "built_tank_6").alarm_severity == "MEDIUM" and _unit(main, "built_tank_7").alarm_severity.is_empty(), "existing TANK FULL marks only its affected product tank")
	light_tank_state["contents"] = "empty"
	light_tank_state["volume_l"] = 0.0
	main.built_refinery_model.tick(100.0)
	main._update_user_interface()
	main._update_unit_statuses()
	_expect(_unit(main, "built_tank_6").alarm_severity.is_empty(), "clearing the product-level alarm hides its tank beacon automatically")
	_expect("220/1000 L" in main.control_station_label.text, "operations console live diesel storage reaches the exact Heavy yield")
	var close_station := InputEventKey.new()
	close_station.keycode = KEY_ESCAPE
	close_station.pressed = true
	main._unhandled_input(close_station)
	main._update_unit_statuses()
	_expect("PRØVE KREVES" in main.units["sales_terminal"].status_label.text and not main.units["sales_terminal"].material.emission_enabled, "paid Heavy delivery stays unsellable until a physical diesel sample is analyzed")
	main._on_unit_interacted("sales_terminal")
	_expect(not main.lab_analysis_panel.visible and "dieselprøve" in main.notification_label.text, "LAB-101 directs the player to the active diesel tank when no sample exists")
	main._on_reset_requested()
	_expect(main.discard_confirmation_time_left > 0.0, "paid product can arm the existing two-step disposal warning before sampling")
	main._on_unit_interacted("built_tank_7")
	_expect("P-001" in main.notification_label.text and "PRØVE KREVES" in main.built_refinery_model.unit_status("built_tank_7"), "active Heavy diesel tank creates a carried sample without revealing quality")
	_expect(main.discard_confirmation_time_left <= 0.0, "taking a sample cancels any older disposal confirmation")
	main._on_reset_requested()
	main._on_unit_interacted("sales_terminal")
	_expect(main.lab_analysis_panel.visible and main.player.input_blocked and main.build_controller.input_blocked, "LAB analysis opens a modal and blocks field/build controls")
	_expect(main.discard_confirmation_time_left <= 0.0, "opening a lab analysis also cancels stale disposal intent")
	_expect("P-001 — TUNG RÅOLJE" in main.lab_analysis_panel.result_label.text and "Diesel i tank" in main.lab_analysis_panel.result_label.text and "flow 10.0 L/s" in main.lab_analysis_panel.result_label.text and "GODKJENT" in main.lab_analysis_panel.result_label.text and "kontrakt og spotsalg" in main.lab_analysis_panel.result_label.text, "Heavy LAB view reports analytical quality without a crude-coupled delivery target")
	var heavy_money_before_lab_enter: int = main.process_model.money
	var dispatch_event := InputEventKey.new()
	dispatch_event.keycode = KEY_ENTER
	dispatch_event.pressed = true
	main._unhandled_input(dispatch_event)
	_expect(not main.lab_analysis_panel.visible and not main.batch_report_visible and main.process_model.money == heavy_money_before_lab_enter, "approved LAB-101 Enter closes analysis without selling product")
	_dispatch_main_product(main, "diesel")
	_expect(not main.batch_report_visible and main.process_model.money == 2420 and is_equal_approx(main.built_refinery_model.equipment["built_tank_7"]["volume_l"], 20.0), "PD-101 fulfills the independent 200 L diesel contract without a crude-selection bonus")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 2420, "repeated LAB-101 use cannot duplicate contract revenue")
	main.built_refinery_model.equipment[pump.unit_id]["condition_percent"] = 42.0
	var money_before_pump_service: int = main.process_model.money
	main._on_maintenance_unit_interacted(pump.unit_id)
	_expect(
		is_equal_approx(main.built_refinery_model.equipment[pump.unit_id]["condition_percent"], 100.0)
		and main.process_model.money == money_before_pump_service - BuiltRefineryModel.PUMP_SERVICE_COST,
		"physical preventive pump service restores condition and charges the shared economy once"
	)
	main.queue_free()
	await _test_offspec_lab_through_main()
	await _test_product_header_save_round_trip()
	await _test_ci_first_batch_entitlement()
	await _test_local_intake_boundary()


func _test_offspec_lab_through_main() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.money = 3600
	main.process_model.objective_complete = true
	main._process(0.0)
	_place_full_refinery(main)
	_connect_full_refinery(main)
	main.built_refinery_model.commissioning_batch_available = false
	main.built_refinery_model.commissioning_contract_complete = true
	main._on_unit_interacted("area02_generator")
	main._on_unit_interacted("instrument_air")
	main._on_unit_interacted("cooling_water")
	var load: Dictionary = main.built_refinery_model.load_crude_batch("built_tank_1", true, "heavy")
	main.process_model.purchase(load["charge"])
	main.built_refinery_model.equipment["built_heater_4"]["temperature_c"] = 200.0
	main.built_refinery_model.equipment["built_heater_4"]["setpoint_c"] = 200.0
	main.built_refinery_model.interact("built_valve_3")
	main.built_refinery_model.interact("built_pump_2")
	main.built_refinery_model.tick(100.0)
	main._on_unit_interacted("built_tank_7")
	var money_before: int = main.process_model.money
	var products_before: float = main.built_refinery_model.product_volume_l()
	main._on_unit_interacted("sales_terminal")
	_expect(main.lab_analysis_panel.visible and "OFF-SPEC" in main.lab_analysis_panel.result_label.text and "Dieselkvaliteten" in main.lab_analysis_panel.result_label.text, "completed cold Heavy batch opens a truthful analytical OFF-SPEC report")
	_expect("Enter — send" not in main.lab_analysis_panel.result_label.text and "R x2" in main.lab_analysis_panel.result_label.text, "OFF-SPEC modal offers recovery but no dispatch action")
	var blocked_enter := InputEventKey.new()
	blocked_enter.keycode = KEY_ENTER
	blocked_enter.pressed = true
	main._unhandled_input(blocked_enter)
	_expect(not main.lab_analysis_panel.visible and main.process_model.money == money_before and is_equal_approx(main.built_refinery_model.product_volume_l(), products_before), "LAB-101 Enter closes an OFF-SPEC analysis without dispatching or mutating inventory")
	var close_event := InputEventKey.new()
	close_event.keycode = KEY_ESCAPE
	close_event.pressed = true
	main._unhandled_input(close_event)
	_expect(not main.lab_analysis_panel.visible and not main.player.input_blocked and not main.build_controller.input_blocked, "Escape closes OFF-SPEC analysis and restores field controls")
	main.queue_free()


func _test_product_header_save_round_trip() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.money = 10000
	main.process_model.objective_complete = true
	main._process(0.0)
	_place_full_refinery(main)
	_connect_full_refinery(main)
	main._on_build_placement_requested("product_header", _area02_fixture(Vector3(4.0, 0.96, 27.0)), 0)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(10.0, 1.96, 28.0)), 0)
	var column = _unit(main, "built_column_5")
	var diesel_a = _unit(main, "built_tank_7")
	var header = _unit(main, "built_product_header_12")
	var diesel_b = _unit(main, "built_tank_13")
	main.build_controller._disconnect_port(column.get_port("diesel"))
	main.build_controller._connect_ports(column.get_port("diesel"), header.get_port("input"))
	main.build_controller._connect_ports(header.get_port("out_a"), diesel_a.get_port("input"))
	main.build_controller._connect_ports(header.get_port("out_b"), diesel_b.get_port("input"))
	_expect(main.built_refinery_model.network.validate_configuration()["valid"], "physical Product Routing Header keeps the Main refinery valid")
	_expect(main.built_refinery_model.interact(header.unit_id)["ok"] and main.built_refinery_model.interact(header.unit_id)["ok"], "physical header can select its B destination while the process is stopped")
	_expect(main.built_refinery_model.product_allocations[header.unit_id].selected_tank_id == diesel_b.unit_id, "Main stores selected product destination by stable tank identity")
	var snapshot: Dictionary = main._build_snapshot()
	var restored = MainScene.instantiate()
	restored.persistence_enabled = false
	root.add_child(restored)
	await process_frame
	var applied: Dictionary = restored._apply_snapshot(snapshot)
	_expect(applied["ok"], "saved Product Routing Header construction restores atomically (%s)" % applied["message"])
	if not applied["ok"]:
		main.queue_free()
		restored.queue_free()
		return
	_expect(restored.build_controller.connections.size() == 15 and restored.build_controller.registered_unit_by_id(header.unit_id) != null, "product-header pipes and placed equipment restore with the refinery")
	_expect(restored.built_refinery_model.product_allocations[header.unit_id].selected_tank_id == diesel_b.unit_id, "save/load preserves the explicitly selected B storage without auto-switching")
	main.queue_free()
	restored.queue_free()


func _test_ci_first_batch_entitlement() -> void:
	var zero_money_main = MainScene.instantiate()
	zero_money_main.persistence_enabled = false
	root.add_child(zero_money_main)
	await process_frame
	zero_money_main.process_model.objective_complete = true
	zero_money_main._process(0.0)
	var before_claim: Dictionary = zero_money_main._build_snapshot()
	var before_restored = MainScene.instantiate()
	before_restored.persistence_enabled = false
	root.add_child(before_restored)
	await process_frame
	var before_restore: Dictionary = before_restored._apply_snapshot(before_claim)
	_expect(
		before_restore["ok"] and before_restored.built_refinery_model.commissioning_batch_available,
		"save/load before CI-101 claim preserves the free-first-batch entitlement"
	)
	zero_money_main._open_contract_selection(EquipmentCatalogScript.CRUDE_TERMINAL_ID)
	_expect(
		"FIRST BATCH FREE / 0 kr" in zero_money_main.contract_selection_label.text,
		"CI-101 clearly displays the free first Standard batch price"
	)
	zero_money_main._select_contract("standard")
	_expect(
		zero_money_main.process_model.money == 0
		and is_equal_approx(float(zero_money_main.built_refinery_model.pending_intake_delivery["volume_l"]), 1000.0)
		and not zero_money_main.built_refinery_model.commissioning_batch_available,
		"0 kr player can claim the first free CI-101 batch without a deduction"
	)
	var after_claim: Dictionary = zero_money_main._build_snapshot()
	var after_restored = MainScene.instantiate()
	after_restored.persistence_enabled = false
	root.add_child(after_restored)
	await process_frame
	var after_restore: Dictionary = after_restored._apply_snapshot(after_claim)
	_expect(
		after_restore["ok"]
		and not after_restored.built_refinery_model.commissioning_batch_available
		and is_equal_approx(float(after_restored.built_refinery_model.pending_intake_delivery["volume_l"]), 1000.0),
		"save/load after CI-101 claim preserves the consumed entitlement and delivery"
	)
	var duplicate: Dictionary = zero_money_main.built_refinery_model.receive_intake_delivery("standard", true)
	_expect(
		not duplicate["ok"] and not zero_money_main.built_refinery_model.commissioning_batch_available,
		"the free CI-101 batch cannot be claimed twice while its delivery is pending"
	)

	zero_money_main.built_refinery_model.pending_intake_delivery = {"contract_id": "", "volume_l": 0.0}
	zero_money_main._open_contract_selection(EquipmentCatalogScript.CRUDE_TERMINAL_ID)
	zero_money_main._select_contract("standard")
	_expect(
		is_zero_approx(float(zero_money_main.built_refinery_model.pending_intake_delivery["volume_l"]))
		and "mangler 300 kr" in zero_money_main.contract_selection_label.text,
		"second Standard batch requires the normal 300 kr affordability check"
	)
	zero_money_main.process_model.money = 300
	zero_money_main._select_contract("standard")
	_expect(
		zero_money_main.process_model.money == 0
		and is_equal_approx(float(zero_money_main.built_refinery_model.pending_intake_delivery["volume_l"]), 1000.0),
		"second Standard CI-101 batch deducts the normal 300 kr price"
	)

	var two_hundred_main = MainScene.instantiate()
	two_hundred_main.persistence_enabled = false
	root.add_child(two_hundred_main)
	await process_frame
	two_hundred_main.process_model.objective_complete = true
	two_hundred_main.process_model.money = 200
	two_hundred_main._process(0.0)
	two_hundred_main._open_contract_selection(EquipmentCatalogScript.CRUDE_TERMINAL_ID)
	two_hundred_main._select_contract("standard")
	_expect(
		two_hundred_main.process_model.money == 200
		and is_equal_approx(float(two_hundred_main.built_refinery_model.pending_intake_delivery["volume_l"]), 1000.0)
		and not two_hundred_main.built_refinery_model.commissioning_batch_available,
		"200 kr player can claim the first free CI-101 batch without a deduction"
	)
	zero_money_main.queue_free()
	before_restored.queue_free()
	after_restored.queue_free()
	two_hundred_main.queue_free()


func _test_local_intake_boundary() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.objective_complete = true
	main._process(0.0)
	var pump_result: Dictionary = main._create_built_unit(
		"pump", Vector3(86.0, WorldLayoutScript.placement_center_y(1.4), -10.0), 3, 1, false
	)
	var tank_result: Dictionary = main._create_built_unit(
		"tank", Vector3(90.0, WorldLayoutScript.placement_center_y(3.6), -10.0), 3, 2, false
	)
	var intake_pump = pump_result["unit"]
	var crude_tank = tank_result["unit"]
	var tie_in = _unit(main, EquipmentCatalogScript.CRUDE_TIE_IN_ID)
	_expect(
		main.build_controller._connect_ports(tie_in.get_port("output"), intake_pump.get_port("input"))["ok"]
		and main.build_controller._connect_ports(intake_pump.get_port("output"), crude_tank.get_port("input"))["ok"],
		"fresh Main connects CI-201 → local intake pump → player crude tank with short Area 02 pipes"
	)
	main._open_contract_selection(EquipmentCatalogScript.CRUDE_TERMINAL_ID)
	main._select_contract("standard")
	main.built_refinery_model.tick(5.0)
	_expect(
		is_zero_approx(float(main.built_refinery_model.equipment[crude_tank.unit_id]["volume_l"]))
		and is_equal_approx(float(main.built_refinery_model.pending_intake_delivery["volume_l"]), 1000.0),
		"claimed crude remains at the zero-hold-up boundary until the player starts the local pump"
	)
	main._on_unit_interacted("area02_generator")
	_expect(main.built_refinery_model.interact(intake_pump.unit_id)["ok"], "local CI-201 transfer pump starts from field interaction")
	var before_transfer: Dictionary = main.built_refinery_model.material_inventory_snapshot(true, false)
	main.built_refinery_model.tick(10.0)
	_expect(
		is_equal_approx(float(main.built_refinery_model.equipment[crude_tank.unit_id]["volume_l"]), 100.0)
		and is_equal_approx(float(main.built_refinery_model.pending_intake_delivery["volume_l"]), 900.0)
		and MaterialBalanceScript.evaluate(
			before_transfer, main.built_refinery_model.material_inventory_snapshot(true, false)
		)["conserved"],
		"CI-201 transfer moves exactly 100 L into canonical storage without duplicate crude"
	)
	var snapshot: Dictionary = main._build_snapshot()
	var has_harbor_process_edge := false
	for edge: Dictionary in snapshot["construction"]["connections"]:
		if (
			edge["from_unit"] == EquipmentCatalogScript.CRUDE_TERMINAL_ID
			or edge["to_unit"] == EquipmentCatalogScript.CRUDE_TERMINAL_ID
			or edge["from_unit"] == EquipmentCatalogScript.PRODUCT_TERMINAL_ID
			or edge["to_unit"] == EquipmentCatalogScript.PRODUCT_TERMINAL_ID
		):
			has_harbor_process_edge = true
			break
	_expect(
		not has_harbor_process_edge,
		"current saves contain no direct Harbor process endpoints or giant replacement pipes"
	)
	main.queue_free()


func _test_out_of_bounds_recovery() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame
	main.process_model.money = 1234
	main.built_refinery_model.commissioning_contract_complete = true
	main.player.global_position = Vector3(0.0, -25.0, 0.0)
	main.player.velocity = Vector3(3.0, -8.0, 2.0)
	main._process(0.0)
	_expect(
		main.player.global_position.is_equal_approx(main.PLAYER_SAFE_SPAWN_POSITION)
		and main.player.velocity.is_zero_approx()
		and main.process_model.money == 1234
		and main.built_refinery_model.commissioning_contract_complete,
		"out-of-bounds recovery respawns safely without changing economy or progression"
	)
	main.queue_free()


func _place_full_refinery(main) -> void:
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(-10.0, 1.96, 14.0)), 0)
	main._on_build_placement_requested("pump", _area02_fixture(Vector3(-6.0, 0.86, 14.0)), 0)
	main._on_build_placement_requested("valve", _area02_fixture(Vector3(-3.5, 0.71, 14.0)), 0)
	main._on_build_placement_requested("heater", _area02_fixture(Vector3(-0.5, 1.66, 14.0)), 0)
	main._on_build_placement_requested("column", _area02_fixture(Vector3(4.0, 3.36, 14.0)), 0)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(9.0, 1.96, 13.0)), 0)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(9.0, 1.96, 18.0)), 0)
	main._on_build_placement_requested("tank", _area02_fixture(Vector3(9.0, 1.96, 23.0)), 0)
	main._create_built_unit("pump", _area02_fixture(Vector3(14.0, 0.86, 13.0)), 0, 9, false)
	main._create_built_unit("pump", _area02_fixture(Vector3(14.0, 0.86, 18.0)), 0, 10, false)
	main._create_built_unit("pump", _area02_fixture(Vector3(14.0, 0.86, 23.0)), 0, 11, false)


func _connect_full_refinery(main) -> void:
	var source = _unit(main, "built_tank_1")
	var pump = _unit(main, "built_pump_2")
	var valve = _unit(main, "built_valve_3")
	var heater = _unit(main, "built_heater_4")
	var column = _unit(main, "built_column_5")
	var light_tank = _unit(main, "built_tank_6")
	var diesel_tank = _unit(main, "built_tank_7")
	var heavy_tank = _unit(main, "built_tank_8")
	var light_sales_pump = _unit(main, "built_pump_9")
	var diesel_sales_pump = _unit(main, "built_pump_10")
	var heavy_sales_pump = _unit(main, "built_pump_11")
	var dispatch = _unit(main, EquipmentCatalogScript.PRODUCT_TIE_IN_ID)
	main.build_controller._connect_ports(source.get_port("output"), pump.get_port("input"))
	main.build_controller._connect_ports(pump.get_port("output"), valve.get_port("input"))
	main.build_controller._connect_ports(valve.get_port("output"), heater.get_port("input"))
	main.build_controller._connect_ports(heater.get_port("output"), column.get_port("input"))
	main.build_controller._connect_ports(column.get_port("light"), light_tank.get_port("input"))
	main.build_controller._connect_ports(column.get_port("diesel"), diesel_tank.get_port("input"))
	main.build_controller._connect_ports(column.get_port("heavy"), heavy_tank.get_port("input"))
	main.build_controller._connect_ports(light_tank.get_port("output"), light_sales_pump.get_port("input"))
	main.build_controller._connect_ports(light_sales_pump.get_port("output"), dispatch.get_port("light"))
	main.build_controller._connect_ports(diesel_tank.get_port("output"), diesel_sales_pump.get_port("input"))
	main.build_controller._connect_ports(diesel_sales_pump.get_port("output"), dispatch.get_port("diesel"))
	main.build_controller._connect_ports(heavy_tank.get_port("output"), heavy_sales_pump.get_port("input"))
	main.build_controller._connect_ports(heavy_sales_pump.get_port("output"), dispatch.get_port("heavy"))


func _dispatch_main_product(main, product_id: String) -> void:
	var orders: Array[Dictionary] = main.built_refinery_model.available_physical_dispatch_orders(EquipmentCatalogScript.PRODUCT_TIE_IN_ID)
	for index in orders.size():
		var order: Dictionary = orders[index]
		if String(order["product"]) != product_id:
			continue
		main.built_refinery_model.interact(String(order["pump_id"]))
		main._on_unit_interacted(EquipmentCatalogScript.PRODUCT_TERMINAL_ID)
		var event := InputEventKey.new()
		event.keycode = KEY_1 + index
		event.pressed = true
		main._unhandled_input(event)
		return
	_expect(false, "PD-101 exposes a physical route for %s" % product_id)


func _unit(main, unit_id: String):
	for entry in main.build_controller.registered_units:
		if entry["node"].unit_id == unit_id:
			return entry["node"]
	return null


func _area02_fixture(legacy_position: Vector3) -> Vector3:
	return legacy_position + WorldLayoutScript.legacy_area02_translation()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
