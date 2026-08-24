extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var failures := 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main = MainScene.instantiate()
	main.persistence_enabled = false
	root.add_child(main)
	await process_frame

	main.process_model.money = ProcessModel.PILOT_CONTRACT_MINIMUM_REVENUE
	main.process_model.objective_complete = true
	main.process_model.diesel_volume_l = 200.0
	main.process_model.diesel_quality_percent = 100.0
	main._process(0.0)
	_expect(main.build_mode_unlocked, "pilot completion unlocks Area 02")
	_expect(main.build_controller.unlocked, "build controller receives the progression unlock")
	main._update_unit_statuses()
	_expect("VENTER" in main.units["sales_terminal"].status_label.text, "terminal readiness switches from sold pilot inventory to built diesel")

	_place_full_refinery(main)
	_expect(main.process_model.money == 400, "pilot contract preserves one recovery batch after the 2 600 kr starter refinery")
	_connect_full_refinery(main)
	var validation: Dictionary = main.built_refinery_model.network.validate_configuration()
	_expect(validation["valid"], "Main placement and connection hooks create a valid refinery route")
	_expect(main.build_controller.connections.size() == 7, "Main route creates seven logical and visual connections")
	main._on_unit_interacted("area02_control")
	_expect(not main.control_station_visible and "låses opp" in main.notification_label.text, "LS-201 remains locked until the built refinery is commissioned manually")

	var source = _unit(main, "built_tank_1")
	var valve = _unit(main, "built_valve_3")
	var heater = _unit(main, "built_heater_4")
	var pump = _unit(main, "built_pump_2")
	var load_result: Dictionary = main.built_refinery_model.interact(source.unit_id)
	_expect(load_result["ok"] and load_result["charge"] == 0, "first Main-integrated crude load uses the commissioning batch")
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.tick(10.0)
	_expect(main.built_refinery_model.interact(pump.unit_id)["ok"], "Main-integrated built pump starts")
	var source_before_low_flow: float = main.built_refinery_model.equipment[source.unit_id]["volume_l"]
	main.built_refinery_model.tick(1.0)
	main._update_user_interface()
	_expect(is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], source_before_low_flow) and "LOW FLOW" in main.alarm_label.text, "closed built valve creates a visible LOW FLOW alarm without consuming crude")
	main._update_unit_statuses()
	_expect("STENGT" in valve.status_label.text and is_equal_approx(valve.valve_handle.rotation.y, deg_to_rad(90.0)), "closed valve world status and handle agree")
	main._on_unit_interacted(valve.unit_id)
	main._update_unit_statuses()
	_expect("ÅPEN" in valve.status_label.text and is_equal_approx(valve.valve_handle.rotation.y, 0.0), "opening valve updates world status and handle")
	main.built_refinery_model.tick(100.0)
	_expect(main.built_refinery_model.diesel_is_approved(), "Main-integrated refinery produces approved diesel")
	main._update_unit_statuses()
	_expect("KLAR" in main.units["sales_terminal"].status_label.text, "terminal becomes ready for approved built diesel")

	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3200, "built sale credits 2 800 kr through the shared economy")
	_expect(main.built_refinery_model.commissioning_contract_complete, "first built sale persistently completes Area 02 commissioning")
	_expect(main.batch_report_visible, "successful built sale opens a persistent batch report")
	_expect(main.player.input_blocked and main.build_controller.input_blocked, "batch report blocks movement, interaction and build controls")
	_expect("Råolje behandlet" in main.batch_report_label.text and "Resultat" in main.batch_report_label.text, "batch report explains process yield and economy")
	_expect("LS-201 lokalstasjon" in main.batch_report_label.text, "first commissioning report clearly unlocks the local control station")
	_expect("OMRÅDE 02 FULLFØRT" in main.built_refinery_model.objective_text(), "objective changes after commissioning completion")
	_expect(not main.built_refinery_model.diesel_is_approved(), "Main-integrated sale consumes approved diesel")
	main._update_unit_statuses()
	_expect("PRØVE KREVES" in main.units["sales_terminal"].status_label.text, "terminal keeps diesel LAB state distinct while product inventory remains")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3200, "repeated terminal interaction cannot duplicate built-sale revenue")
	var dismiss_event := InputEventKey.new()
	dismiss_event.keycode = KEY_ENTER
	dismiss_event.pressed = true
	main._unhandled_input(dismiss_event)
	_expect(not main.batch_report_visible and not main.player.input_blocked and not main.build_controller.input_blocked, "Enter dismisses the report and restores gameplay controls")
	main._on_secondary_unit_interacted(heater.unit_id)
	_expect(main.built_refinery_model.equipment[heater.unit_id]["control_mode"] == "auto" and "TIC-201 AUTO" in main.notification_label.text, "commissioned player can enable physical TIC-201 AUTO on the existing heater")
	main._on_unit_interacted("sales_terminal")
	_expect(main.product_dispatch_visible and "NAPHTHALEVERANSE" in main.product_dispatch_label.text and "TUNGRESTLEVERANSE" in main.product_dispatch_label.text, "terminal opens distinct non-diesel product orders after the LAB-controlled diesel delivery")
	var naphtha_event := InputEventKey.new()
	naphtha_event.keycode = KEY_1
	naphtha_event.pressed = true
	main._unhandled_input(naphtha_event)
	main._on_unit_interacted("sales_terminal")
	var residue_event := InputEventKey.new()
	residue_event.keycode = KEY_2
	residue_event.pressed = true
	main._unhandled_input(residue_event)
	_expect(is_equal_approx(main.built_refinery_model.product_volume_l(), 0.0) and main.process_model.money == 5400, "Naphtha and residue orders clear only their stored products and credit distinct revenue")
	main._on_unit_interacted("area02_control")
	_expect(main.control_station_visible and main.player.input_blocked and main.build_controller.input_blocked, "unlocked LS-201 opens a live modal and blocks field/build controls")
	main._update_user_interface()
	_expect("LT-201 NIVÅ" in main.control_station_label.text and "TT-201 TEMPERATUR" in main.control_station_label.text and "TIC-201 KONTROLL" in main.control_station_label.text and "FT-201 FLOW" in main.control_station_label.text, "LS-201 presents explicit level, temperature, control and flow instruments with units")
	_expect("Ingen aktiv råolje" in main.control_station_label.text and "VENTER PÅ RÅOLJE" in main.control_station_label.text, "idle LS-201 clearly waits for crude instead of advertising a zero-degree target")
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
	_expect(main.contract_selection_visible and main.player.input_blocked and main.build_controller.input_blocked, "empty commissioned source opens a modal crude-delivery choice")
	_expect("DIESELLEVERANSE" in main.contract_selection_label.text and "200 L diesel" in main.contract_selection_label.text and "TUNG LEVERANSE" in main.contract_selection_label.text and "600 L" in main.contract_selection_label.text, "delivery modal explains the two distinct product orders before purchase")
	var money_before_cancel: int = main.process_model.money
	var cancel_contract_event := InputEventKey.new()
	cancel_contract_event.keycode = KEY_ESCAPE
	cancel_contract_event.pressed = true
	main._unhandled_input(cancel_contract_event)
	_expect(not main.contract_selection_visible and main.process_model.money == money_before_cancel and is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], 0.0), "Escape cancels crude selection without charging or loading material")
	main._on_unit_interacted(source.unit_id)
	main.process_model.money = 100
	var standard_event := InputEventKey.new()
	standard_event.keycode = KEY_1
	standard_event.pressed = true
	main._unhandled_input(standard_event)
	_expect(main.contract_selection_visible and main.process_model.money == 100 and is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], 0.0), "unaffordable contract stays open and changes neither money nor material")
	main.process_model.money = money_before_cancel
	main._unhandled_input(standard_event)
	_expect(not main.contract_selection_visible and not main.player.input_blocked and not main.build_controller.input_blocked, "contract choice closes cleanly and restores gameplay controls")
	_expect(main.process_model.money == 5100, "second Main-integrated crude batch deducts exactly 300 kr")
	_expect(is_equal_approx(main.built_refinery_model.equipment[source.unit_id]["volume_l"], 1000.0), "paid Main-integrated batch loads exactly 1 000 L")

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
	var source = _unit(main, "built_tank_1")
	main._on_unit_interacted(source.unit_id)
	var heavy_event := InputEventKey.new()
	heavy_event.keycode = KEY_2
	heavy_event.pressed = true
	main._unhandled_input(heavy_event)
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
	_expect("mål 15" in main.control_station_label.text and "HØY" in main.control_station_label.text, "LS-201 distinguishes actual flow from the selected high-flow target")
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
	_expect("ACTIVE ALARMS: 1" in main.control_station_label.text and "LOW FLOW" in main.control_station_label.text and not ("P-201 er startet" in main.control_station_label.text), "LS-201 lists the active LOW FLOW alarm ahead of stale successful-command feedback")
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
	light_tank_state["contents"] = "empty"
	light_tank_state["volume_l"] = 0.0
	main.built_refinery_model.tick(100.0)
	main._update_user_interface()
	_expect("220 / 1000 L" in main.control_station_label.text, "LS-201 live diesel level reaches the exact Heavy yield")
	var close_station := InputEventKey.new()
	close_station.keycode = KEY_ESCAPE
	close_station.pressed = true
	main._unhandled_input(close_station)
	main._update_unit_statuses()
	_expect("PRØVE KREVES" in main.units["sales_terminal"].status_label.text and not main.units["sales_terminal"].material.emission_enabled, "paid Heavy delivery stays unsellable until a physical diesel sample is analyzed")
	main._on_unit_interacted("sales_terminal")
	_expect(not main.lab_analysis_panel.visible and "dieselprøve" in main.notification_label.text, "LAB / SALG directs the player to the active diesel tank when no sample exists")
	main._on_reset_requested()
	_expect(main.discard_confirmation_time_left > 0.0, "paid product can arm the existing two-step disposal warning before sampling")
	main._on_unit_interacted("built_tank_7")
	_expect("P-001" in main.notification_label.text and "PRØVE KREVES" in main.built_refinery_model.unit_status("built_tank_7"), "active Heavy diesel tank creates a carried sample without revealing quality")
	_expect(main.discard_confirmation_time_left <= 0.0, "taking a sample cancels any older disposal confirmation")
	main._on_reset_requested()
	main._on_unit_interacted("sales_terminal")
	_expect(main.lab_analysis_panel.visible and main.player.input_blocked and main.build_controller.input_blocked, "LAB analysis opens a modal and blocks field/build controls")
	_expect(main.discard_confirmation_time_left <= 0.0, "opening a lab analysis also cancels stale disposal intent")
	_expect("P-001 — TUNG" in main.lab_analysis_panel.result_label.text and "TUNG LEVERANSE" in main.lab_analysis_panel.result_label.text and "Tung fraksjon" in main.lab_analysis_panel.result_label.text and "630 L / krav 600 L" in main.lab_analysis_panel.result_label.text and "flow 10.0 L/s" in main.lab_analysis_panel.result_label.text and "GODKJENT" in main.lab_analysis_panel.result_label.text and "2 760 kr" in main.lab_analysis_panel.result_label.text, "Heavy lab separates diesel QC and average flow from the ordered heavy-fraction target")
	var dispatch_event := InputEventKey.new()
	dispatch_event.keycode = KEY_ENTER
	dispatch_event.pressed = true
	main._unhandled_input(dispatch_event)
	_expect(not main.lab_analysis_panel.visible and main.batch_report_visible, "approved lab Enter transitions directly to the existing batch report")
	_expect(main.process_model.money == 3580, "Main Heavy sample dispatch credits 1 760 kr product revenue and one 1 000 kr bonus")
	_expect("BATCH GODKJENT — TUNG LEVERANSE" in main.batch_report_label.text and "Tung fraksjon 630 / 600 L" in main.batch_report_label.text and "flow 10.0 L/s" in main.batch_report_label.text and "Kontraktbonus" in main.batch_report_label.text, "Heavy batch report records the fulfilled order, average flow and its bonus")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3580, "repeated Main terminal use cannot duplicate the Heavy bonus")
	main.queue_free()
	await _test_offspec_lab_through_main()
	await _test_product_header_save_round_trip()


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
	_expect(main.lab_analysis_panel.visible and "OFF-SPEC" in main.lab_analysis_panel.result_label.text and "Råoljetanken er tom" in main.lab_analysis_panel.result_label.text, "completed cold Heavy batch opens a truthful OFF-SPEC lab report")
	_expect("Enter — send" not in main.lab_analysis_panel.result_label.text and "R x2" in main.lab_analysis_panel.result_label.text, "OFF-SPEC modal offers recovery but no dispatch action")
	var blocked_enter := InputEventKey.new()
	blocked_enter.keycode = KEY_ENTER
	blocked_enter.pressed = true
	main._unhandled_input(blocked_enter)
	_expect(main.lab_analysis_panel.visible and main.process_model.money == money_before and is_equal_approx(main.built_refinery_model.product_volume_l(), products_before), "Enter cannot dispatch or mutate an OFF-SPEC analysis")
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
	main._on_build_placement_requested("product_header", Vector3(4.0, 0.96, 27.0), 0)
	main._on_build_placement_requested("tank", Vector3(10.0, 1.96, 28.0), 0)
	var column = _unit(main, "built_column_5")
	var diesel_a = _unit(main, "built_tank_7")
	var header = _unit(main, "built_product_header_9")
	var diesel_b = _unit(main, "built_tank_10")
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
	_expect(restored.build_controller.connections.size() == 9 and restored.build_controller.registered_unit_by_id(header.unit_id) != null, "product-header pipes and placed equipment restore with the refinery")
	_expect(restored.built_refinery_model.product_allocations[header.unit_id].selected_tank_id == diesel_b.unit_id, "save/load preserves the explicitly selected B storage without auto-switching")
	main.queue_free()
	restored.queue_free()


func _place_full_refinery(main) -> void:
	main._on_build_placement_requested("tank", Vector3(-10.0, 1.96, 14.0), 0)
	main._on_build_placement_requested("pump", Vector3(-6.0, 0.86, 14.0), 0)
	main._on_build_placement_requested("valve", Vector3(-3.5, 0.71, 14.0), 0)
	main._on_build_placement_requested("heater", Vector3(-0.5, 1.66, 14.0), 0)
	main._on_build_placement_requested("column", Vector3(4.0, 3.36, 14.0), 0)
	main._on_build_placement_requested("tank", Vector3(9.0, 1.96, 13.0), 0)
	main._on_build_placement_requested("tank", Vector3(9.0, 1.96, 18.0), 0)
	main._on_build_placement_requested("tank", Vector3(9.0, 1.96, 23.0), 0)


func _connect_full_refinery(main) -> void:
	var source = _unit(main, "built_tank_1")
	var pump = _unit(main, "built_pump_2")
	var valve = _unit(main, "built_valve_3")
	var heater = _unit(main, "built_heater_4")
	var column = _unit(main, "built_column_5")
	var light_tank = _unit(main, "built_tank_6")
	var diesel_tank = _unit(main, "built_tank_7")
	var heavy_tank = _unit(main, "built_tank_8")
	main.build_controller._connect_ports(source.get_port("output"), pump.get_port("input"))
	main.build_controller._connect_ports(pump.get_port("output"), valve.get_port("input"))
	main.build_controller._connect_ports(valve.get_port("output"), heater.get_port("input"))
	main.build_controller._connect_ports(heater.get_port("output"), column.get_port("input"))
	main.build_controller._connect_ports(column.get_port("light"), light_tank.get_port("input"))
	main.build_controller._connect_ports(column.get_port("diesel"), diesel_tank.get_port("input"))
	main.build_controller._connect_ports(column.get_port("heavy"), heavy_tank.get_port("input"))


func _unit(main, unit_id: String):
	for entry in main.build_controller.registered_units:
		if entry["node"].unit_id == unit_id:
			return entry["node"]
	return null


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
