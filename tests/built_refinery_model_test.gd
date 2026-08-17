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
	_test_mass_conserving_ideal_batch_and_sale()
	_test_full_tank_backpressure()
	_test_commissioning_and_paid_batches()


func _test_invalid_network_cannot_start() -> void:
	var model = BuiltRefineryModelScript.new()
	model.register_unit("pump", "pump", "P-201")
	var result: Dictionary = model.interact("pump")
	_expect(not result["ok"], "pump cannot start on a disconnected network")
	_expect(not model.equipment["pump"]["running"], "rejected start leaves pump stopped")
	_expect(not result["message"].is_empty(), "rejected start gives actionable player feedback")


func _test_mass_conserving_ideal_batch_and_sale() -> void:
	var model = _complete_model()
	var load_result: Dictionary = model.load_crude_batch("source")
	_expect(load_result["ok"] and load_result["charge"] == 0, "first built batch is an explicit free commissioning batch")
	_expect(not model.can_remove("source")["ok"], "non-empty built tanks cannot be removed for a refund")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["heater"]["temperature_c"], 200.0), "built heater reaches the ideal 200 C setpoint")
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
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 2800, "approved built diesel sells for the expected revenue")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 0.0), "sale consumes the diesel inventory")
	var repeated_sale: Dictionary = model.sell_diesel()
	_expect(not repeated_sale["ok"] and repeated_sale["revenue"] == 0, "diesel cannot be sold repeatedly without new product")


func _test_full_tank_backpressure() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.equipment["diesel_tank"]["volume_l"] = 995.0
	model.equipment["diesel_tank"]["contents"] = "diesel"
	model.equipment["diesel_tank"]["quality_percent"] = 100.0
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


func _complete_model():
	var model = BuiltRefineryModelScript.new()
	model.register_unit("source", "tank", "T-201")
	model.register_unit("pump", "pump", "P-201")
	model.register_unit("heater", "heater", "H-201")
	model.register_unit("column", "column", "D-201")
	model.register_unit("light_tank", "tank", "T-202")
	model.register_unit("diesel_tank", "tank", "T-203")
	model.register_unit("heavy_tank", "tank", "T-204")
	model.network.try_connect("source", "output", "pump", "input")
	model.network.try_connect("pump", "output", "heater", "input")
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
