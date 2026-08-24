extends SceneTree

const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")
const ProcessNetworkScript = preload("res://scripts/process_network.gd")

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
	_expect(model.network.try_connect("ci", "output", "intake_pump", "input")["ok"], "CI-101 connects only through a pump input")
	_expect(model.network.try_connect("intake_pump", "output", "crude_tank", "input")["ok"], "intake pump connects to crude storage")
	_expect(not model.network.can_connect("ci", "output", "crude_tank", "input")["ok"], "CI-101 cannot bypass the required transfer pump")
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	var delivery: Dictionary = model.receive_intake_delivery("standard", true)
	_expect(delivery["ok"] and delivery["charge"] == 300, "paid Standard delivery uses canonical 300 kr contract charge")
	_expect(model.interact("intake_pump")["ok"], "intake transfer pump starts with a pending delivery")
	model.tick(20.0)
	_expect(is_equal_approx(model.equipment["crude_tank"]["volume_l"], 200.0) and is_equal_approx(float(model.pending_intake_delivery["volume_l"]), 800.0), "CI-101 transfer conserves 200 L into the selected crude tank")
	var saved: Dictionary = model.save_state()
	var restored: Variant = _new_model()
	_register(restored, "ci", "crude_intake")
	_register(restored, "intake_pump", "pump")
	_register(restored, "crude_tank", "tank")
	restored.network.try_connect("ci", "output", "intake_pump", "input")
	restored.network.try_connect("intake_pump", "output", "crude_tank", "input")
	restored.apply_saved_state(saved)
	_expect(is_equal_approx(restored.equipment["crude_tank"]["volume_l"], 200.0) and is_equal_approx(float(restored.pending_intake_delivery["volume_l"]), 800.0), "intake inventory and pending CI-101 delivery persist exactly")
	restored.equipment["crude_tank"]["volume_l"] = restored.equipment["crude_tank"]["capacity_l"]
	restored.equipment["intake_pump"]["running"] = true
	restored.tick(1.0)
	_expect(not restored.equipment["intake_pump"]["running"] and float(restored.pending_intake_delivery["volume_l"]) > 0.001, "full crude storage stops CI-101 transfer without losing pending material")


func _test_product_dispatch_route() -> void:
	var model: Variant = _new_model()
	_register(model, "product_tank", "tank", "", "vacuum_gas_oil")
	_register(model, "sales_pump", "pump")
	_register(model, "pd", "product_dispatch")
	_expect(model.network.try_connect("product_tank", "output", "sales_pump", "input")["ok"], "product storage connects to a physical sales pump")
	_expect(model.network.try_connect("sales_pump", "output", "pd", "vacuum_gas_oil")["ok"], "sales pump connects to the matching PD-101 typed inlet")
	model.equipment["product_tank"]["contents"] = "vacuum_gas_oil"
	model.equipment["product_tank"]["volume_l"] = 100.0
	_expect(model.available_physical_dispatch_orders("pd").size() == 1, "PD-101 discovers the compatible filled product line")
	_expect(not model.dispatch_product_from_terminal("pd", "product_tank")["ok"], "PD-101 refuses dispatch until its sales pump is running")
	_expect(model.interact("sales_pump")["ok"], "physical sales pump starts on a valid product line")
	var dispatch: Dictionary = model.dispatch_product_from_terminal("pd", "product_tank")
	_expect(dispatch["ok"] and dispatch["revenue"] == 400 and is_equal_approx(model.equipment["product_tank"]["volume_l"], 0.0), "PD-101 dispatch consumes exactly its connected VGO tank once")
	_expect(not model.dispatch_product_from_terminal("pd", "product_tank")["ok"], "repeated physical dispatch cannot generate duplicate revenue")


func _new_model():
	return BuiltRefineryModelScript.new(ProcessNetworkScript.new())


func _register(model, unit_id: String, equipment_type: String, display_name := "", intended_material := "") -> void:
	_expect(model.register_unit(unit_id, equipment_type, display_name, intended_material)["ok"], "%s registers for physical logistics" % unit_id)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
