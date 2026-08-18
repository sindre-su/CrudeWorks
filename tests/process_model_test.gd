extends SceneTree

const ProcessModelScript = preload("res://scripts/process_model.gd")
const EquipmentCatalog = preload("res://scripts/equipment_catalog.gd")
const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")

var failures := 0


func _init() -> void:
	_test_successful_batch()
	_test_low_flow_alarm()
	_test_cold_batch_is_rejected()
	_test_high_temperature_alarm()
	_test_building_economy()
	_test_minimum_pilot_contract_funds_area_two()

	if failures == 0:
		print("PASS: all CrudeWorks process-model tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks process-model test(s) failed" % failures)
		quit(1)


func _test_successful_batch() -> void:
	var model = ProcessModelScript.new()
	model.cycle_heater() # 170 °C
	model.cycle_heater() # 200 °C
	_simulate(model, 11.0)
	_expect(absf(model.heater_temperature_c - 200.0) < 0.1, "heater reaches 200 °C")

	model.toggle_feed_valve()
	model.toggle_pump()
	_simulate(model, 100.5)

	_expect(model.crude_volume_l == 0.0, "successful batch consumes 1 000 L crude")
	_expect(model.diesel_volume_l >= 349.0, "successful batch produces about 350 L diesel")
	_expect(model.diesel_quality_percent >= 99.0, "preheated batch has approved quality")
	_expect(model.diesel_is_approved(), "successful batch is approved")
	var sale_message: String = model.sell_diesel()
	_expect(model.objective_complete, "selling approved diesel completes objective")
	_expect(model.money > 0, "selling approved diesel earns money")
	_expect("solgt" in sale_message, "sale returns clear player feedback")


func _test_low_flow_alarm() -> void:
	var model = ProcessModelScript.new()
	model.toggle_pump()
	model.tick(0.1)
	_expect(model.flow_lps == 0.0, "closed valve prevents flow")
	_expect(model.active_alarms().size() == 1, "closed valve raises one low-flow alarm")
	_expect("LOW FLOW" in model.active_alarms()[0], "alarm identifies low flow")


func _test_cold_batch_is_rejected() -> void:
	var model = ProcessModelScript.new()
	model.toggle_feed_valve()
	model.toggle_pump()
	_simulate(model, 100.5)
	_expect(not model.diesel_is_approved(), "cold processing does not produce approved diesel")
	_expect(model.diesel_volume_l < ProcessModelScript.DIESEL_TARGET_L, "cold batch misses diesel target")
	var sale_message: String = model.sell_diesel()
	_expect(not model.objective_complete, "rejected diesel cannot complete objective")
	_expect("For lite" in sale_message, "terminal explains cold batch rejection")


func _test_high_temperature_alarm() -> void:
	var model = ProcessModelScript.new()
	model.cycle_heater()
	model.cycle_heater()
	model.cycle_heater() # 230 °C
	_simulate(model, 13.0)
	var alarms: Array[String] = model.active_alarms()
	_expect(alarms.size() == 1, "230 °C raises one alarm")
	_expect("HIGH TEMPERATURE" in alarms[0], "alarm identifies high temperature")


func _test_building_economy() -> void:
	var model = ProcessModelScript.new()
	model.money = 1000
	_expect(model.purchase(400), "affordable equipment can be purchased")
	_expect(model.money == 600, "purchase deducts exact equipment cost")
	_expect(not model.purchase(700), "unaffordable equipment is rejected")
	_expect(model.money == 600, "rejected purchase does not change money")
	model.refund(400)
	_expect(model.money == 1000, "removed equipment can be fully refunded")


func _test_minimum_pilot_contract_funds_area_two() -> void:
	var model = ProcessModelScript.new()
	model.diesel_volume_l = ProcessModelScript.DIESEL_TARGET_L
	model.diesel_quality_percent = 100.0
	model.sell_diesel()
	var minimum_refinery_cost: int = (
		EquipmentCatalog.definition("tank")["cost"] * 4
		+ EquipmentCatalog.definition("pump")["cost"]
		+ EquipmentCatalog.definition("valve")["cost"]
		+ EquipmentCatalog.definition("heater")["cost"]
		+ EquipmentCatalog.definition("column")["cost"]
	)
	_expect(
		model.money >= minimum_refinery_cost + BuiltRefineryModelScript.CRUDE_BATCH_COST,
		"minimum pilot contract funds Area 02 plus one off-spec recovery batch"
	)


func _simulate(model, duration_seconds: float) -> void:
	var timestep := 0.1
	var steps := int(ceil(duration_seconds / timestep))
	for step in steps:
		model.tick(timestep)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
