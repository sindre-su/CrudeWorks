extends SceneTree

const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")
const ProcessNetworkScript = preload("res://scripts/process_network.gd")
const MaterialBalanceScript = preload("res://scripts/material_balance.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_intake_route_and_persistence()
	_test_product_dispatch_route()
	if failures == 0:
		print("PASS: physical logistics checks passed")
		quit(0)
	else:
		printerr("FAIL: %d physical logistics check(s) failed" % failures)
		quit(1)


func _test_intake_route_and_persistence() -> void:
	var model: Variant = _new_model()
	_register(model, "ci", "crude_intake")
	_register(model, "intake_pump", "pump")
	_register(model, "crude_tank", "tank")
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	var delivery: Dictionary = model.receive_intake_delivery("standard", true)
	_expect(delivery["ok"] and delivery["charge"] == 300, "paid Standard delivery uses canonical 300 kr contract charge")
	model.tick(20.0)
	_expect(
		is_zero_approx(model.equipment["crude_tank"]["volume_l"])
		and is_equal_approx(float(model.pending_intake_delivery["volume_l"]), 1000.0),
		"Harbor claim remains pending and cannot auto-fill the first unconnected tank"
	)
	_expect(model.network.try_connect("ci", "output", "intake_pump", "input")["ok"], "CI-201 connects only through a pump input")
	_expect(model.network.try_connect("intake_pump", "output", "crude_tank", "input")["ok"], "intake pump connects to crude storage")
	_expect(not model.network.can_connect("ci", "output", "crude_tank", "input")["ok"], "CI-201 cannot bypass the required transfer pump")
	_expect(model.interact("intake_pump")["ok"], "intake transfer pump starts with a pending delivery")
	var before_transfer: Dictionary = model.material_inventory_snapshot(true, false)
	model.tick(20.0)
	_expect(is_equal_approx(model.equipment["crude_tank"]["volume_l"], 200.0) and is_equal_approx(float(model.pending_intake_delivery["volume_l"]), 800.0) and model.active_contract_id == "standard" and model.equipment["crude_tank"]["contract_id"] == "standard", "CI-101 transfer conserves material and establishes route-owned plus active contract state")
	_expect(MaterialBalanceScript.evaluate(before_transfer, model.material_inventory_snapshot(true, false))["conserved"], "shared invariant verifies partial CI-101 transfer into canonical tank hold-up")
	var saved: Dictionary = model.save_state()
	var restored: Variant = _new_model()
	_register(restored, "ci", "crude_intake")
	_register(restored, "intake_pump", "pump")
	_register(restored, "crude_tank", "tank")
	restored.network.try_connect("ci", "output", "intake_pump", "input")
	restored.network.try_connect("intake_pump", "output", "crude_tank", "input")
	restored.apply_saved_state(saved)
	_expect(is_equal_approx(restored.equipment["crude_tank"]["volume_l"], 200.0) and is_equal_approx(float(restored.pending_intake_delivery["volume_l"]), 800.0), "intake inventory and pending CI-101 delivery persist exactly")
	_expect(MaterialBalanceScript.evaluate(model.material_inventory_snapshot(true, false), restored.material_inventory_snapshot(true, false))["conserved"], "partially completed physical transfer round-trips without changing site material")
	restored.equipment["crude_tank"]["volume_l"] = restored.equipment["crude_tank"]["capacity_l"]
	restored.equipment["intake_pump"]["running"] = true
	var before_full_block: Dictionary = restored.material_inventory_snapshot(true, false)
	restored.tick(1.0)
	_expect(restored.equipment["intake_pump"]["running"] and is_zero_approx(restored.equipment["intake_pump"]["actual_flow_lps"]) and "BLOCKED" in restored.pump_state_text("intake_pump") and float(restored.pending_intake_delivery["volume_l"]) > 0.001, "full crude storage blocks flow without erasing the intake-pump RUN command")
	_expect(MaterialBalanceScript.evaluate(before_full_block, restored.material_inventory_snapshot(true, false))["conserved"], "full CI-101 destination destroys no pending or stored crude")
	restored.equipment["crude_tank"]["volume_l"] = 900.0
	var pending_before_resume: float = float(restored.pending_intake_delivery["volume_l"])
	restored.tick(1.0)
	_expect(restored.equipment["intake_pump"]["running"] and restored.equipment["intake_pump"]["actual_flow_lps"] > 0.01 and float(restored.pending_intake_delivery["volume_l"]) < pending_before_resume, "clearing a normal intake blockage resumes flow without an arbitrary restart")


func _test_product_dispatch_route() -> void:
	var model: Variant = _new_model()
	_register(model, "product_tank", "tank", "", "vacuum_gas_oil")
	_register(model, "sales_pump", "pump")
	_register(model, "pd", "product_dispatch")
	_expect(model.network.try_connect("product_tank", "output", "sales_pump", "input")["ok"], "product storage connects to a physical sales pump")
	_expect(model.network.try_connect("sales_pump", "output", "pd", "vacuum_gas_oil")["ok"], "sales pump connects to the matching PD-101 typed inlet")
	model.equipment["product_tank"]["contents"] = "vacuum_gas_oil"
	model.equipment["product_tank"]["volume_l"] = 100.0
	var before_tie_in_inspection := float(model.equipment["product_tank"]["volume_l"])
	model.interact("pd")
	_expect(
		is_equal_approx(float(model.equipment["product_tank"]["volume_l"]), before_tie_in_inspection),
		"local PD-201 tie-in inspection is not a second sale terminal"
	)
	_expect(model.available_physical_dispatch_orders("pd").size() == 1, "PD-101 discovers the compatible filled product line")
	_expect(not model.dispatch_product_from_terminal("pd", "product_tank")["ok"], "PD-101 refuses dispatch until its sales pump is running")
	_expect(model.interact("sales_pump")["ok"], "physical sales pump starts on a valid product line")
	var before_dispatch: Dictionary = model.material_inventory_snapshot(false, false)
	var dispatch: Dictionary = model.dispatch_product_from_terminal("pd", "product_tank")
	_expect(dispatch["ok"] and dispatch["revenue"] == 400 and dispatch.get("first_physical_dispatch_now", false) and is_equal_approx(model.equipment["product_tank"]["volume_l"], 0.0), "PD-101 dispatch consumes exactly its connected VGO tank once and records the first physical dispatch")
	_expect(MaterialBalanceScript.evaluate(before_dispatch, model.material_inventory_snapshot(false, false), 0.0, dispatch.get("material_output_l", 0.0))["conserved"], "PD-101 reports its physical product as an explicit boundary output")
	_expect(not model.dispatch_product_from_terminal("pd", "product_tank")["ok"], "repeated physical dispatch cannot generate duplicate revenue")
	model.equipment["sales_pump"]["running"] = true
	model.tick(1.0)
	_expect(model.equipment["sales_pump"]["running"] and "NO FEED" in model.pump_state_text("sales_pump"), "empty dispatch feed is an understandable running wait state rather than an automatic stop")


func _new_model():
	var model = BuiltRefineryModelScript.new(ProcessNetworkScript.new())
	model.toggle_starter_generator()
	return model


func _register(model, unit_id: String, equipment_type: String, display_name := "", intended_material := "") -> void:
	_expect(model.register_unit(unit_id, equipment_type, display_name, intended_material)["ok"], "%s registers for physical logistics" % unit_id)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
