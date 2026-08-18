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
	_expect("OMRÅDE 02 FULLFØRT" in main.built_refinery_model.objective_text(), "objective changes after commissioning completion")
	_expect(not main.built_refinery_model.diesel_is_approved(), "Main-integrated sale consumes approved diesel")
	main._update_unit_statuses()
	_expect("VENTER" in main.units["sales_terminal"].status_label.text, "terminal returns to waiting after inventory is sold")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3200, "repeated terminal interaction cannot duplicate built-sale revenue")
	var dismiss_event := InputEventKey.new()
	dismiss_event.keycode = KEY_ENTER
	dismiss_event.pressed = true
	main._unhandled_input(dismiss_event)
	_expect(not main.batch_report_visible and not main.player.input_blocked and not main.build_controller.input_blocked, "Enter dismisses the report and restores gameplay controls")
	main._on_unit_interacted(source.unit_id)
	_expect(main.contract_selection_visible and main.player.input_blocked and main.build_controller.input_blocked, "empty commissioned source opens a modal crude-delivery choice")
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
	_expect(main.process_model.money == 2900, "second Main-integrated crude batch deducts exactly 300 kr")
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
	main.built_refinery_model.equipment[heater.unit_id]["temperature_c"] = 230.0
	main.built_refinery_model.equipment[heater.unit_id]["setpoint_c"] = 230.0
	main._on_unit_interacted(valve.unit_id)
	main._on_unit_interacted(pump.unit_id)
	main.built_refinery_model.tick(100.0)
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3580, "Main Heavy sale credits 1 760 kr product revenue and one 1 000 kr bonus")
	_expect("BATCH GODKJENT — TUNG" in main.batch_report_label.text and "Kontraktbonus" in main.batch_report_label.text, "Heavy batch report names the feed and explains its bonus")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3580, "repeated Main terminal use cannot duplicate the Heavy bonus")
	main.queue_free()


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
