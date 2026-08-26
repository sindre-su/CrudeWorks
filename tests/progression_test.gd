extends SceneTree

const ProcessModelScript = preload("res://scripts/process_model.gd")
const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")
const ProcessNetworkScript = preload("res://scripts/process_network.gd")
const Catalog = preload("res://scripts/equipment_catalog.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_pilot_objectives_follow_real_state()
	_test_area02_intake_progression_persists()
	_test_legacy_progression_inference()
	_test_locked_menu_remains_explanatory()
	_test_starter_economy_is_recoverable()
	if failures == 0:
		print("PASS: first-hour progression checks passed")
		quit(0)
		return
	printerr("FAIL: %d first-hour progression check(s) failed" % failures)
	quit(1)


func _test_pilot_objectives_follow_real_state() -> void:
	var pilot = ProcessModelScript.new()
	_expect("SETT H-101" in pilot.pilot_objective_text(), "new pilot starts with the real heater action")
	pilot.heater_setpoint_c = 200.0
	_expect("VARM RÅOLJE" in pilot.pilot_objective_text(), "pilot waits for actual temperature instead of a key press")
	pilot.heater_temperature_c = 200.0
	_expect("ÅPNE V-101" in pilot.pilot_objective_text(), "pilot advances when heat condition is actually reached")
	pilot.feed_valve_open = true
	_expect("START P-101" in pilot.pilot_objective_text(), "already-open valve is recognized without closing it again")
	pilot.pump_running = true
	pilot.diesel_volume_l = 210.0
	pilot.diesel_quality_percent = 95.0
	_expect("SELG GODKJENT DIESEL" in pilot.pilot_objective_text(), "pilot sale objective follows measured product quality")


func _test_area02_intake_progression_persists() -> void:
	var model: Variant = BuiltRefineryModelScript.new(ProcessNetworkScript.new())
	_expect("CI-101" in model.objective_text(), "Area 02 begins by introducing physical CI-101 intake")
	model.register_unit("ci", "crude_intake")
	model.register_unit("pump", "pump")
	model.register_unit("tank", "tank")
	model.network.try_connect("ci", "output", "pump", "input")
	model.network.try_connect("pump", "output", "tank", "input")
	_expect(model.receive_intake_delivery("standard", true)["ok"] and model.first_intake_received, "first CI-101 delivery records a real onboarding milestone")
	_expect("START PG-101" in model.objective_text().to_upper(), "pending delivery introduces electrical supply before the real intake pump")
	model.toggle_starter_generator()
	_expect("START INNTAKSPUMPEN" in model.objective_text().to_upper(), "energized MCC returns the player to the physical intake transfer")
	var saved: Dictionary = model.save_state()
	var restored: Variant = BuiltRefineryModelScript.new(ProcessNetworkScript.new())
	restored.register_unit("ci", "crude_intake")
	restored.register_unit("pump", "pump")
	restored.register_unit("tank", "tank")
	restored.network.try_connect("ci", "output", "pump", "input")
	restored.network.try_connect("pump", "output", "tank", "input")
	restored.apply_saved_state(saved)
	_expect(restored.first_intake_received and float(restored.pending_intake_delivery["volume_l"]) == 1000.0, "CI-101 onboarding state survives save/load without duplicating crude")


func _test_legacy_progression_inference() -> void:
	var source: Variant = BuiltRefineryModelScript.new(ProcessNetworkScript.new())
	source.register_unit("column", "column")
	source.equipment["column"]["processed_total_l"] = 50.0
	var legacy: Dictionary = source.save_state()
	legacy["site_logistics"] = {"pending_intake_delivery": {"contract_id": "", "volume_l": 0.0}}
	var restored: Variant = BuiltRefineryModelScript.new(ProcessNetworkScript.new())
	restored.register_unit("column", "column")
	restored.apply_saved_state(legacy)
	_expect(restored.first_atmospheric_production, "v0.25 refinery saves infer established atmospheric progression safely")


func _test_locked_menu_remains_explanatory() -> void:
	var text := Catalog.menu_text({"vacuum_distillation": "produser Tung rest"})
	_expect("Vacuum Distillation Unit" in text and "LÅST" in text and "produser Tung rest" in text, "locked build equipment explains the refinery need instead of using XP")


func _test_starter_economy_is_recoverable() -> void:
	var physical_starter_cost := (
		4 * int(Catalog.definition("tank")["cost"])
		+ 3 * int(Catalog.definition("pump")["cost"])
		+ int(Catalog.definition("valve")["cost"])
		+ int(Catalog.definition("heater")["cost"])
		+ int(Catalog.definition("column")["cost"])
	)
	_expect(physical_starter_cost == ProcessModelScript.PILOT_CONTRACT_MINIMUM_REVENUE, "pilot minimum exactly funds the CI-to-PD physical starter line")
	_expect(BuiltRefineryModelScript.CRUDE_BATCH_COST < ProcessModelScript.PILOT_CONTRACT_MINIMUM_REVENUE, "later Standard crude remains affordable after the protected first delivery")


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
