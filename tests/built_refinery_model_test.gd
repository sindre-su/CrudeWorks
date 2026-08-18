extends SceneTree

const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")
const CrudeCatalogScript = preload("res://scripts/crude_contract_catalog.gd")

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
	_test_standard_contract_regression()
	_test_heavy_contract_temperature_tradeoff()
	_test_contract_lifecycle_and_bonus_lock()
	_test_control_station_telemetry_and_temperature_guard()
	_test_paid_batch_lab_sampling()


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
	model.equipment["heater"]["setpoint_c"] = 200.0
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
	_take_and_analyze(model)
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
	model.interact("valve")
	for attempt in range(3):
		var load: Dictionary = model.load_crude_batch("source")
		_expect(load["ok"] and load["charge"] == 0, "pre-commission retry %d remains subsidized after a learning failure" % (attempt + 1))
		model.interact("pump")
		model.tick(100.0)
		_expect(not model.sell_diesel()["ok"], "cold commissioning attempt %d is rejected as off-spec" % (attempt + 1))
		var before_discard := _total_tank_volume(model)
		var warning: Dictionary = model.discard_products()
		_expect(warning.get("requires_confirmation", false), "attempt %d still requires explicit disposal confirmation" % (attempt + 1))
		_expect(is_equal_approx(before_discard, _total_tank_volume(model)), "unconfirmed attempt %d does not mutate inventory" % (attempt + 1))
		var discard: Dictionary = model.discard_products(true)
		_expect(discard["ok"] and is_equal_approx(_total_tank_volume(model), 0.0), "confirmed attempt %d clears products without value creation" % (attempt + 1))
		_expect(not model.commissioning_contract_complete and model.commissioning_batch_available, "failed attempt %d preserves a safe route to another free commissioning batch" % (attempt + 1))
		if attempt == 1:
			var restored_model = _complete_model()
			restored_model.apply_saved_state(model.save_state())
			model = restored_model
			_expect(model.commissioning_batch_available, "commissioning retry survives save/load between failures")

	var final_load: Dictionary = model.load_crude_batch("source")
	_expect(final_load["ok"] and final_load["charge"] == 0, "successful commissioning attempt is still subsidized after repeated failures")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("pump")
	model.tick(100.0)
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and model.commissioning_contract_complete, "first approved retry completes commissioning exactly once")
	var paid_after_completion: Dictionary = model.load_crude_batch("source", true)
	_expect(paid_after_completion["ok"] and paid_after_completion["charge"] == BuiltRefineryModelScript.CRUDE_BATCH_COST, "subsidy ends permanently after approved commissioning")


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


func _test_standard_contract_regression() -> void:
	var fractions := CrudeCatalogScript.fractions_for_temperature("standard", 200.0)
	_expect(fractions.is_equal_approx(Vector3(0.30, 0.35, 0.35)), "Standard contract preserves the proven 30/35/35 split at 200 C")
	_expect(is_equal_approx(fractions.x + fractions.y + fractions.z, 1.0), "Standard fractions conserve the complete input")
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	var load: Dictionary = model.load_crude_batch("source", true, "standard")
	_expect(load["ok"] and load["charge"] == 300 and model.active_contract_id == "standard", "paid Standard load locks the correct 300 kr contract")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	_expect(is_equal_approx(model.equipment["light_tank"]["volume_l"], 300.0) and is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 350.0) and is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 350.0), "paid Standard batch keeps the established 300/350/350 L output")
	_take_and_analyze(model)
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["report"]["product_revenue"] == 2800 and sale["report"]["delivery_bonus"] == 0, "Standard sale keeps the established 2 800 kr product revenue without a bonus")
	_expect(sale["report"]["crude_cost"] == 300 and sale["report"]["net_profit"] == 2500, "Standard report preserves exact paid-batch economics")


func _test_heavy_contract_temperature_tradeoff() -> void:
	var ideal_fractions := CrudeCatalogScript.fractions_for_temperature("heavy", 230.0)
	_expect(ideal_fractions.is_equal_approx(Vector3(0.15, 0.22, 0.63)), "Heavy crude has a distinct 15/22/63 split at its 230 C target")
	_expect(is_equal_approx(ideal_fractions.x + ideal_fractions.y + ideal_fractions.z, 1.0), "Heavy fractions conserve the complete input")
	var ideal = _complete_model()
	ideal.commissioning_batch_available = false
	ideal.commissioning_contract_complete = true
	var ideal_load: Dictionary = ideal.load_crude_batch("source", true, "heavy")
	_expect(ideal_load["ok"] and ideal_load["charge"] == 180 and ideal.active_contract_bonus_available, "Heavy delivery costs 180 kr and arms one delivery bonus")
	var no_process_sale: Dictionary = ideal.sell_diesel()
	_expect(not no_process_sale["ok"] and "Ingen diesel" in no_process_sale["message"] and ideal.active_contract_bonus_available, "unprocessed paid contract reports missing diesel without consuming its bonus")
	ideal.equipment["heater"]["temperature_c"] = 240.0
	ideal.tick(0.0)
	_expect("Senk" in ideal.last_status and "senk" in ideal.objective_text() and "HIGH TEMPERATURE" in ideal.alarm_text(), "overheated Heavy feed gives one consistent cool-down instruction")
	ideal.equipment["heater"]["temperature_c"] = 230.0
	ideal.equipment["heater"]["setpoint_c"] = 230.0
	ideal.interact("valve")
	ideal.interact("pump")
	ideal.tick(100.0)
	_expect(is_equal_approx(_total_tank_volume(ideal), 1000.0), "ideal Heavy processing conserves the full 1 000 L batch")
	_expect(is_equal_approx(ideal.equipment["light_tank"]["volume_l"], 150.0) and is_equal_approx(ideal.equipment["diesel_tank"]["volume_l"], 220.0) and is_equal_approx(ideal.equipment["heavy_tank"]["volume_l"], 630.0), "ideal Heavy processing produces the declared 150/220/630 L outputs")
	_expect(ideal.diesel_is_approved() and "HIGH TEMPERATURE" not in ideal.alarm_text(), "Heavy diesel is approved at 230 C without a false high-temperature alarm")
	_take_and_analyze(ideal)
	var ideal_sale: Dictionary = ideal.sell_diesel()
	_expect(ideal_sale["ok"] and ideal_sale["report"]["product_revenue"] == 1760 and ideal_sale["report"]["delivery_bonus"] == 1000 and ideal_sale["revenue"] == 2760, "first approved Heavy delivery pays exact product revenue plus its one-time bonus")
	_expect(ideal_sale["report"]["crude_cost"] == 180 and ideal_sale["report"]["net_profit"] == 2580, "Heavy report calculates exact cost and net profit")
	var repeated: Dictionary = ideal.sell_diesel()
	_expect(not repeated["ok"] and repeated["revenue"] == 0 and not ideal.active_contract_bonus_available, "Heavy product and bonus cannot be sold repeatedly")

	var cold = _complete_model()
	cold.commissioning_batch_available = false
	cold.commissioning_contract_complete = true
	cold.load_crude_batch("source", true, "heavy")
	cold.equipment["heater"]["temperature_c"] = 200.0
	cold.equipment["heater"]["setpoint_c"] = 200.0
	cold.interact("valve")
	cold.interact("pump")
	cold.tick(100.0)
	_expect(is_equal_approx(cold.equipment["diesel_tank"]["volume_l"], 180.0) and is_equal_approx(cold.equipment["diesel_tank"]["quality_percent"], 64.0), "Heavy crude run at the Standard setting yields only 180 L diesel at 64 percent quality")
	var cold_sample: Dictionary = cold.take_diesel_sample("diesel_tank")
	var cold_analysis: Dictionary = cold.analyze_diesel_sample()
	_expect(cold_sample["ok"] and cold_analysis["status"] == "OFF-SPEC" and "Råoljetanken er tom" in cold_analysis["deviation"] and not cold_analysis["approved"], "completed Heavy off-spec result never asks for impossible further production")
	var rejected: Dictionary = cold.sell_diesel()
	_expect(not rejected["ok"] and rejected["revenue"] == 0 and cold.active_contract_bonus_available, "off-spec Heavy product earns no money and cannot consume its pending contract state")


func _test_contract_lifecycle_and_bonus_lock() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.register_unit("hidden_tank", "tank", "T-299")
	model.equipment["hidden_tank"]["contents"] = "crude"
	model.equipment["hidden_tank"]["volume_l"] = 1.0
	_expect(not model.can_choose_contract("source")["ok"] and not model.load_crude_batch("source", true, "heavy")["ok"], "disconnected material blocks a new contract instead of bypassing provenance")
	model.equipment["hidden_tank"]["contents"] = "empty"
	model.equipment["hidden_tank"]["volume_l"] = 0.0
	_expect(model.can_choose_contract("source")["ok"], "a stopped and fully empty refinery may choose a new contract")
	model.load_crude_batch("source", true, "heavy")
	var state_after_load: Dictionary = model.save_state()
	_expect(not model.load_crude_batch("source", true, "standard")["ok"] and model.save_state() == state_after_load, "loaded Heavy provenance cannot be replaced by a second contract")
	model.equipment["heater"]["temperature_c"] = 230.0
	model.equipment["heater"]["setpoint_c"] = 230.0
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	_expect(not model.can_choose_contract("source")["ok"], "stored Heavy products block contract switching after source depletion")
	_take_and_analyze(model)
	model.sell_diesel()
	_expect(model.can_choose_contract("source")["ok"] and model.active_contract_id.is_empty(), "successful dispatch clears the finished contract and enables the next choice")


func _test_control_station_telemetry_and_temperature_guard() -> void:
	var model = _complete_model()
	var locked_snapshot: Dictionary = model.control_snapshot()
	_expect(not locked_snapshot["unlocked"] and not model.remote_toggle_route_pump()["ok"] and not model.remote_cycle_route_heater()["ok"], "LS-201 telemetry and remote commands stay locked before manual commissioning")
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "standard")
	var initial: Dictionary = model.control_snapshot()
	_expect(initial["valid"] and is_equal_approx(initial["source_volume_l"], 1000.0) and is_equal_approx(initial["source_level_percent"], 100.0), "LS-201 source level is derived exactly from the active route tank")
	_expect(not initial["pump_running"] and not initial["valve_open"] and is_equal_approx(initial["actual_flow_lps"], 0.0), "LS-201 distinguishes pump command, manual valve and actual flow")
	var mass_before_blocked_start := _total_tank_volume(model)
	var cold_start: Dictionary = model.remote_toggle_route_pump()
	_expect(not cold_start["ok"] and "START SPERRET" in cold_start["message"] and not model.equipment["pump"]["running"], "temperature guard blocks a cold remote pump start without changing command state")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_blocked_start), "blocked remote start cannot move or create material")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	_expect(model.remote_toggle_route_pump()["ok"], "safe remote pump start uses the active route pump")
	model.tick(1.0)
	var low_flow: Dictionary = model.control_snapshot()
	_expect(low_flow["pump_running"] and is_equal_approx(low_flow["actual_flow_lps"], 0.0) and "LOW FLOW" in low_flow["alarm"], "remote start cannot bypass the closed manual valve or its LOW FLOW lesson")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_blocked_start), "remote LOW FLOW leaves every tank volume unchanged")
	model.interact("valve")
	model.tick(1.0)
	var flowing: Dictionary = model.control_snapshot()
	_expect(is_equal_approx(flowing["source_volume_l"], 990.0) and is_equal_approx(flowing["actual_flow_lps"], 10.0), "live LS-201 telemetry follows actual source loss and flow")
	_expect(is_equal_approx(flowing["light_volume_l"], 3.0) and is_equal_approx(flowing["diesel_volume_l"], 3.5) and is_equal_approx(flowing["heavy_volume_l"], 3.5), "live product instruments match the exact mass-conserving split")
	_expect(model.remote_toggle_route_pump()["ok"] and not model.equipment["pump"]["running"] and is_equal_approx(model.actual_flow_lps, 0.0), "remote stop clears commanded and actual flow immediately")
	model.register_unit("spare_heater_control", "heater", "H-299")
	var spare_target: float = model.equipment["spare_heater_control"]["setpoint_c"]
	var route_target_before: float = model.equipment["heater"]["setpoint_c"]
	_expect(model.remote_cycle_route_heater()["ok"] and model.equipment["heater"]["setpoint_c"] != route_target_before and is_equal_approx(model.equipment["spare_heater_control"]["setpoint_c"], spare_target), "remote heater control affects only the active route heater")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.remote_toggle_route_pump()
	var mass_before_trip := _total_tank_volume(model)
	model.equipment["heater"]["temperature_c"] = 220.0
	model.equipment["heater"]["setpoint_c"] = 220.0
	model.tick(1.0)
	var tripped: Dictionary = model.control_snapshot()
	_expect(not tripped["pump_running"] and "PUMPE STOPPET AV TEMPERATURVERN" in tripped["temperature_trip_message"], "remote temperature guard trips the pump before unsafe processing")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_trip), "temperature trip occurs before another material transfer")
	model.network.disconnect_ports("valve", "output", "heater", "input")
	var invalid_snapshot: Dictionary = model.control_snapshot()
	_expect(not invalid_snapshot["valid"] and not model.remote_toggle_route_pump()["ok"], "invalid topology disables LS-201 control with the graph's readable error")


func _test_paid_batch_lab_sampling() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "standard")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.interact("pump")
	model.tick(20.0)
	_expect(not model.take_diesel_sample("diesel_tank")["ok"], "diesel sampling is blocked while any process pump is running")
	model.interact("pump")
	model.register_unit("spare_sample_tank", "tank", "T-299")
	model.equipment["spare_sample_tank"]["contents"] = "diesel"
	model.equipment["spare_sample_tank"]["volume_l"] = 500.0
	model.equipment["spare_sample_tank"]["quality_percent"] = 42.0
	_expect(not model.take_diesel_sample("spare_sample_tank")["ok"], "disconnected diesel cannot be sampled for the active contract")
	var sample: Dictionary = model.take_diesel_sample("diesel_tank")
	_expect(sample["ok"] and sample["sample_id"] == "P-001", "stopped active-route diesel tank produces a numbered physical sample")
	_expect("IKKE ANALYSERT" in model.summary_text() and "PRØVE KREVES" in model.unit_status("diesel_tank"), "exact paid-batch quality remains hidden before laboratory analysis")
	_expect(not model.sell_diesel()["ok"] and "Analyser" in model.sell_diesel()["message"], "a current but unanalyzed sample cannot authorize dispatch")
	var early_analysis: Dictionary = model.analyze_diesel_sample()
	_expect(early_analysis["ok"] and early_analysis["status"] == "IKKE KLAR" and not early_analysis["approved"], "lab analysis reports the exact missing-volume condition without dispatch")
	_expect("100.0 %" in model.summary_text() and "IKKE KLAR" in model.objective_text(), "analyzed sample reveals quality while retaining the failed volume result")
	_expect("42.0 %" not in model.unit_status("spare_sample_tank") and "42.0 %" not in model.inspect_unit("spare_sample_tank"), "active-route analysis never reveals disconnected diesel quality")
	var inventory_before_failed_sale: float = model.product_volume_l()
	_expect(not model.sell_diesel()["ok"] and is_equal_approx(model.product_volume_l(), inventory_before_failed_sale), "failed analyzed sample consumes no product or contract value")

	model.interact("pump")
	model.tick(1.0)
	model.interact("pump")
	var stale: Dictionary = model.lab_dispatch_status()
	_expect(not stale["sample_current"] and "utdatert" in stale["message"], "new production invalidates the old sample through the inventory revision")
	_expect(not model.sell_diesel()["ok"], "stale sample cannot authorize sale after inventory changes")
	var replacement_sample: Dictionary = model.take_diesel_sample("diesel_tank")
	_expect(replacement_sample["ok"] and replacement_sample["sample_id"] == "P-002", "player can always replace a stale sample without a softlock")
	model.network.disconnect_ports("valve", "output", "heater", "input")
	_expect(not model.analyze_diesel_sample()["ok"], "topology changes invalidate a carried sample before analysis")
	model.network.try_connect("valve", "output", "heater", "input")
	model.take_diesel_sample("diesel_tank")
	model.analyze_diesel_sample()
	var saved_state: Dictionary = model.save_state()
	var restored = _complete_model()
	restored.apply_saved_state(saved_state)
	_expect(not restored.lab_dispatch_status()["sample_current"], "save/load preserves product but never restores transient lab authorization")

	model.interact("pump")
	model.tick(100.0)
	var final_sample: Dictionary = model.take_diesel_sample("diesel_tank")
	var final_analysis: Dictionary = model.analyze_diesel_sample()
	_expect(final_sample["ok"] and final_analysis["approved"] and final_analysis["revenue_preview"] == 2800, "complete Standard batch produces a current approved analysis with exact revenue preview")
	model.interact("valve")
	model.interact("pump")
	var running_status: Dictionary = model.lab_dispatch_status()
	_expect(running_status["approved"] and not running_status["dispatch_ready"] and not model.diesel_is_dispatch_ready(), "analyzed batch cannot advertise dispatch while a closed-valve pump is commanded on")
	_expect(not model.analyze_diesel_sample()["ok"], "LAB refuses analysis while any pump is running, even at zero actual flow")
	model.interact("pump")
	_expect(model.diesel_is_dispatch_ready(), "stopping the pump restores dispatch readiness without invalidating unchanged product")
	var successful_sale: Dictionary = model.sell_diesel()
	_expect(successful_sale["ok"] and successful_sale["revenue"] == 2800 and is_equal_approx(model.product_volume_l(), 0.0), "approved current sample dispatches the existing product batch exactly once")
	_expect(not model.sell_diesel()["ok"] and model.successful_sales == 1, "consumed sample and inventory cannot be dispatched twice")


func _take_and_analyze(model) -> Dictionary:
	var sample: Dictionary = model.take_diesel_sample("diesel_tank")
	if not sample["ok"]:
		return sample
	return model.analyze_diesel_sample()


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
