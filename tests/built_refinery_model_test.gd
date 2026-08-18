extends SceneTree

const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")

var failures := 0


func _init() -> void:
	_run_tests()
	if failures == 0:
		print("PASS: all CrudeWorks built-refinery tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks built-refinery test(s) failed" % failures)
		quit(1)


func _run_tests() -> void:
	_test_invalid_network_cannot_start()
	_test_manual_valve_low_flow()
	_test_mass_conserving_ideal_batch_and_sale()
	_test_full_tank_backpressure()
	_test_commissioning_and_paid_batches()
	_test_topology_change_stops_flow_and_spare_pump()
	_test_offspec_recovery()
	_test_partial_sale_report()
	_test_route_scoped_alarm()
	_test_disconnected_inventory_is_not_sellable()


func _test_invalid_network_cannot_start() -> void:
	var model = BuiltRefineryModelScript.new()
	model.register_unit("pump", "pump", "P-201")
	var result: Dictionary = model.interact("pump")
	_expect(not result["ok"], "pump cannot start on a disconnected network")
	_expect(not model.equipment["pump"]["running"], "rejected start leaves pump stopped")
	_expect(not result["message"].is_empty(), "rejected start gives actionable player feedback")


func _test_manual_valve_low_flow() -> void:
	var model = _complete_model()
	_expect(not model.equipment["valve"]["open"], "new built valve defaults closed")
	_expect(model.active_connection_keys().size() == 7, "active route exposes all seven valve-inclusive pipe segments")
	_expect("åpne" in model.interaction_prompt("valve"), "closed valve prompt offers the correct action")
	model.register_unit("spare_valve", "valve", "V-299")
	model.interact("spare_valve")
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("pump")
	var mass_before_blocked := _total_tank_volume(model)
	var source_before_blocked: float = model.equipment["source"]["volume_l"]
	model.tick(10.0)
	_expect(model.equipment["pump"]["running"] and is_equal_approx(model.actual_flow_lps, 0.0), "closed valve keeps pump on but blocks all flow")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_blocked) and is_equal_approx(model.equipment["source"]["volume_l"], source_before_blocked), "closed valve consumes and creates no material")
	_expect("LOW FLOW" in model.alarm_text() and "LOW FLOW" in model.objective_text(), "closed active-route valve creates a diagnosable LOW FLOW state")
	_expect(not model.can_remove("valve")["ok"], "closed route valve cannot be removed while its pump is running")
	model.equipment["heater"]["temperature_c"] = 230.0
	_expect("HIGH TEMPERATURE" in model.alarm_text() and "LOW FLOW" in model.alarm_text(), "safety alarm remains visible alongside a simultaneous closed-valve fault")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.tick(0.0)
	_expect("LOW FLOW" in model.alarm_text(), "opening a disconnected spare valve cannot clear the active-route alarm")
	model.interact("valve")
	model.tick(10.0)
	_expect(is_equal_approx(model.actual_flow_lps, 10.0) and is_equal_approx(model.equipment["source"]["volume_l"], 900.0), "opening the route valve restores normal bounded flow")
	model.interact("valve")
	var mass_before_reclose := _total_tank_volume(model)
	model.tick(5.0)
	_expect(is_equal_approx(model.actual_flow_lps, 0.0) and is_equal_approx(_total_tank_volume(model), mass_before_reclose), "closing the valve during production pauses transfer without stopping the pump")
	model.interact("valve")
	model.tick(1.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 890.0), "reopening the valve resumes the still-running route without duplication")


func _test_mass_conserving_ideal_batch_and_sale() -> void:
	var model = _complete_model()
	model.tick(0.0)
	_expect("kildetanken" in model.last_status, "empty valid route tells the player to load crude first")
	_expect("oppstartsbatch" in model.interaction_prompt("source"), "empty source prompt identifies the free startup action")
	var load_result: Dictionary = model.load_crude_batch("source")
	_expect(load_result["ok"] and load_result["charge"] == 0, "first built batch is an explicit free commissioning batch")
	_expect(not model.can_remove("source")["ok"], "non-empty built tanks cannot be removed for a refund")
	model.tick(0.0)
	_expect("Varm" in model.last_status, "loaded cold route tells the player to heat before pumping")
	_expect("råoljetank" in model.interaction_prompt("source"), "loaded source prompt switches to inspection")
	_expect("LETT" in model.interaction_prompt("light_tank"), "product-tank prompt identifies its routed fraction")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["heater"]["temperature_c"], 200.0), "built heater reaches the ideal 200 C setpoint")
	model.interact("valve")
	_expect(model.interact("pump")["ok"], "pump starts on a complete route")
	_expect(not model.can_remove("pump")["ok"], "running built pump cannot be removed")
	var before_mass := _total_tank_volume(model)
	model.tick(10.0)
	var after_mass := _total_tank_volume(model)
	_expect(is_equal_approx(before_mass, after_mass), "transfer conserves total liquid volume")
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 900.0), "100 L of processed crude leaves the source")
	_expect(is_equal_approx(model.equipment["light_tank"]["volume_l"], 30.0), "ideal separation creates 30 percent light product")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 35.0), "ideal separation creates 35 percent diesel")
	_expect(is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 35.0), "ideal separation creates 35 percent heavy product")
	model.tick(90.0)
	_expect(is_equal_approx(_total_tank_volume(model), 1000.0), "complete distillation preserves the 1 000 L batch")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 350.0), "complete ideal batch yields 350 L diesel")
	_expect(model.diesel_is_approved(), "ideal built diesel is approved")
	var approved_disposal_warning: Dictionary = model.discard_products()
	_expect(approved_disposal_warning.get("requires_confirmation", false) and "Godkjent" in approved_disposal_warning["message"], "approved diesel cannot be destroyed by one accidental key press")
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 2800, "approved built diesel sells for the expected revenue")
	_expect(model.commissioning_contract_complete, "first approved built sale completes the Area 02 contract")
	_expect(sale["contract_completed_now"], "first sale reports that commissioning completed now")
	_expect(is_equal_approx(sale["report"]["crude_processed_l"], 1000.0), "batch report records actual processed crude")
	_expect(is_equal_approx(sale["report"]["light_l"] + sale["report"]["diesel_l"] + sale["report"]["heavy_l"], 1000.0), "reported fractions preserve mass balance")
	_expect(sale["report"]["crude_cost"] == 0 and sale["report"]["net_profit"] == 2800, "free startup report shows exact cost and net result")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 0.0), "sale consumes the diesel inventory")
	_expect(is_equal_approx(model.equipment["light_tank"]["volume_l"], 0.0), "successful product dispatch clears light fraction storage")
	_expect(is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 0.0), "successful product dispatch clears heavy fraction storage")
	var repeated_sale: Dictionary = model.sell_diesel()
	_expect(not repeated_sale["ok"] and repeated_sale["revenue"] == 0, "diesel cannot be sold repeatedly without new product")
	_expect(model.successful_sales == 1, "repeated sale cannot duplicate the completion count")
	var paid_load: Dictionary = model.load_crude_batch("source", true)
	model.interact("pump")
	model.tick(100.0)
	var paid_sale: Dictionary = model.sell_diesel()
	_expect(paid_load["charge"] == 300 and paid_sale["report"]["crude_cost"] == 300, "paid batch report includes the exact crude cost")
	_expect(paid_sale["report"]["net_profit"] == 2500, "paid batch report calculates exact net profit")
	_expect(not paid_sale["contract_completed_now"] and model.successful_sales == 2, "later sales do not recomplete the commissioning contract")


func _test_full_tank_backpressure() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.equipment["diesel_tank"]["volume_l"] = 995.0
	model.equipment["diesel_tank"]["contents"] = "diesel"
	model.equipment["diesel_tank"]["quality_percent"] = 100.0
	model.interact("valve")
	model.interact("pump")
	var before_mass := _total_tank_volume(model)
	var before_source: float = model.equipment["source"]["volume_l"]
	model.tick(10.0)
	var source_loss: float = before_source - model.equipment["source"]["volume_l"]
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 1000.0), "partial destination capacity is filled but never exceeded")
	_expect(is_equal_approx(source_loss, 5.0 / 0.35), "all product fractions scale to the limiting destination")
	_expect(is_equal_approx(before_mass, _total_tank_volume(model)), "capacity-limited transfer remains mass conserving")
	var mass_before_blocked_tick := _total_tank_volume(model)
	model.tick(1.0)
	_expect(is_equal_approx(mass_before_blocked_tick, _total_tank_volume(model)), "a full product tank blocks the entire next transfer")
	_expect(is_equal_approx(model.actual_flow_lps, 0.0), "full destination reports zero actual flow")
	_expect("full" in model.last_status, "full destination identifies the blocking problem")


func _test_commissioning_and_paid_batches() -> void:
	var model = _complete_model()
	_expect(model.load_crude_batch("source")["charge"] == 0, "commissioning batch is free once")
	model.equipment["source"]["volume_l"] = 0.0
	model.equipment["source"]["contents"] = "empty"
	var unpaid: Dictionary = model.load_crude_batch("source", false)
	_expect(not unpaid["ok"], "second batch is not created for free")
	var paid: Dictionary = model.load_crude_batch("source", true)
	_expect(paid["ok"] and paid["charge"] == BuiltRefineryModelScript.CRUDE_BATCH_COST, "subsequent crude batch reports its exact purchase cost")


func _test_topology_change_stops_flow_and_spare_pump() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("valve")
	model.interact("pump")
	model.tick(1.0)
	model.network.disconnect_ports("valve", "output", "heater", "input")
	_expect(not model.equipment["pump"]["running"], "disconnecting a live route stops its pump immediately")
	_expect(is_equal_approx(model.actual_flow_lps, 0.0), "topology change clears actual flow immediately")
	model.register_unit("spare_pump", "pump", "P-299")
	model.network.try_connect("valve", "output", "heater", "input")
	_expect(not model.equipment["pump"]["running"], "reconnecting the valve does not auto-restart the route pump")
	var spare_start: Dictionary = model.interact("spare_pump")
	_expect(not spare_start["ok"], "disconnected spare pump cannot start because another route is valid")


func _test_offspec_recovery() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	_expect(not model.sell_diesel()["ok"], "cold commissioning products are rejected as off-spec")
	var before_discard := _total_tank_volume(model)
	var warning: Dictionary = model.discard_products()
	_expect(warning.get("requires_confirmation", false), "first disposal action requires explicit confirmation")
	_expect(is_equal_approx(before_discard, _total_tank_volume(model)), "unconfirmed disposal does not mutate inventory")
	var discard: Dictionary = model.discard_products(true)
	_expect(discard["ok"], "confirmed off-spec products have an explicit safe disposal path")
	_expect(is_equal_approx(_total_tank_volume(model), 0.0), "disposal clears product inventory without creating money")
	_expect(not model.commissioning_contract_complete, "off-spec disposal does not complete the Area 02 contract")
	_expect(model.load_crude_batch("source", true)["ok"], "player can load a paid recovery batch after disposal")


func _test_partial_sale_report() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("valve")
	model.interact("pump")
	model.tick(((BuiltRefineryModelScript.DIESEL_TARGET_L + 0.01) / 0.35) / BuiltRefineryModelScript.PUMP_CAPACITY_LPS)
	var products_while_running: float = model.product_volume_l()
	_expect(not model.sell_diesel()["ok"], "diesel cannot be sold while the process pump is running")
	_expect(not model.discard_products()["ok"] and is_equal_approx(model.product_volume_l(), products_while_running), "products cannot be discarded while the process pump is running")
	model.interact("pump")
	_expect(not model.equipment["pump"]["running"], "running built pump can be stopped manually")
	var source_before_sale: float = model.equipment["source"]["volume_l"]
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 1600, "an early approved sale earns only for the diesel actually produced")
	_expect(absf(sale["report"]["crude_processed_l"] - (200.01 / 0.35)) < 0.1, "partial-batch report uses actual transfer rather than nominal batch size")
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], source_before_sale), "selling products does not erase unprocessed source crude")


func _test_route_scoped_alarm() -> void:
	var model = _complete_model()
	model.register_unit("spare_heater", "heater", "H-299")
	model.equipment["spare_heater"]["temperature_c"] = 230.0
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("valve")
	model.interact("pump")
	model.tick(1.0)
	_expect("HIGH TEMPERATURE" not in model.alarm_text(), "disconnected hot heater cannot create a false process alarm")


func _test_disconnected_inventory_is_not_sellable() -> void:
	var model = _complete_model()
	model.register_unit("spare_tank", "tank", "T-299")
	model.equipment["spare_tank"]["contents"] = "diesel"
	model.equipment["spare_tank"]["volume_l"] = 350.0
	model.equipment["spare_tank"]["quality_percent"] = 100.0
	_expect(not model.diesel_is_approved(), "diesel readiness ignores disconnected legacy inventory")
	_expect(not model.sell_diesel()["ok"], "disconnected legacy diesel cannot complete the active-route contract")


func _complete_model():
	var model = BuiltRefineryModelScript.new()
	model.register_unit("source", "tank", "T-201")
	model.register_unit("pump", "pump", "P-201")
	model.register_unit("valve", "valve", "V-201")
	model.register_unit("heater", "heater", "H-201")
	model.register_unit("column", "column", "D-201")
	model.register_unit("light_tank", "tank", "T-202")
	model.register_unit("diesel_tank", "tank", "T-203")
	model.register_unit("heavy_tank", "tank", "T-204")
	model.network.try_connect("source", "output", "pump", "input")
	model.network.try_connect("pump", "output", "valve", "input")
	model.network.try_connect("valve", "output", "heater", "input")
	model.network.try_connect("heater", "output", "column", "input")
	model.network.try_connect("column", "light", "light_tank", "input")
	model.network.try_connect("column", "diesel", "diesel_tank", "input")
	model.network.try_connect("column", "heavy", "heavy_tank", "input")
	return model


func _total_tank_volume(model) -> float:
	var total := 0.0
	for state in model.equipment.values():
		if state["type"] == "tank":
			total += state["volume_l"]
	return total


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
