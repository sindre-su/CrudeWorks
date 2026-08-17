extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var failures := 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main.process_model.money = 2800
	main.process_model.objective_complete = true
	main.process_model.diesel_volume_l = 200.0
	main.process_model.diesel_quality_percent = 100.0
	main._process(0.0)
	_expect(main.build_mode_unlocked, "pilot completion unlocks Area 02")
	_expect(main.build_controller.unlocked, "build controller receives the progression unlock")
	main._update_unit_statuses()
	_expect("VENTER" in main.units["sales_terminal"].status_label.text, "terminal readiness switches from sold pilot inventory to built diesel")

	_place_full_refinery(main)
	_expect(main.process_model.money == 400, "full starter refinery costs 2 400 kr from pilot proceeds")
	_connect_full_refinery(main)
	var validation: Dictionary = main.built_refinery_model.network.validate_configuration()
	_expect(validation["valid"], "Main placement and connection hooks create a valid refinery route")

	var source = _unit(main, "built_tank_1")
	var heater = _unit(main, "built_heater_3")
	var pump = _unit(main, "built_pump_2")
	var load_result: Dictionary = main.built_refinery_model.interact(source.unit_id)
	_expect(load_result["ok"] and load_result["charge"] == 0, "first Main-integrated crude load uses the commissioning batch")
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.interact(heater.unit_id)
	main.built_refinery_model.tick(10.0)
	_expect(main.built_refinery_model.interact(pump.unit_id)["ok"], "Main-integrated built pump starts")
	main.built_refinery_model.tick(100.0)
	_expect(main.built_refinery_model.diesel_is_approved(), "Main-integrated refinery produces approved diesel")
	main._update_unit_statuses()
	_expect("KLAR" in main.units["sales_terminal"].status_label.text, "terminal becomes ready for approved built diesel")

	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3200, "built sale credits 2 800 kr through the shared economy")
	_expect(not main.built_refinery_model.diesel_is_approved(), "Main-integrated sale consumes approved diesel")
	main._update_unit_statuses()
	_expect("VENTER" in main.units["sales_terminal"].status_label.text, "terminal returns to waiting after inventory is sold")
	main._on_unit_interacted("sales_terminal")
	_expect(main.process_model.money == 3200, "repeated terminal interaction cannot duplicate built-sale revenue")

	main.process_model.crude_volume_l = 123.0
	main._on_reset_requested()
	_expect(is_equal_approx(main.process_model.crude_volume_l, 123.0), "post-unlock R cannot create another free pilot batch")

	var money_before_removal: int = main.process_model.money
	main._on_build_removal_requested(source)
	main._on_build_removal_requested(source)
	_expect(main.process_model.money == money_before_removal + source.purchase_cost, "same equipment can only be refunded once")

	if failures == 0:
		print("PASS: full Main-integrated CrudeWorks built loop passed")
		quit(0)
	else:
		printerr("FAIL: %d Main integration check(s) failed" % failures)
		quit(1)


func _place_full_refinery(main) -> void:
	main._on_build_placement_requested("tank", Vector3(-10.0, 1.96, 14.0), 0)
	main._on_build_placement_requested("pump", Vector3(-6.0, 0.86, 14.0), 0)
	main._on_build_placement_requested("heater", Vector3(-2.0, 1.66, 14.0), 0)
	main._on_build_placement_requested("column", Vector3(3.0, 3.36, 14.0), 0)
	main._on_build_placement_requested("tank", Vector3(8.0, 1.96, 13.0), 0)
	main._on_build_placement_requested("tank", Vector3(8.0, 1.96, 18.0), 0)
	main._on_build_placement_requested("tank", Vector3(8.0, 1.96, 23.0), 0)


func _connect_full_refinery(main) -> void:
	var source = _unit(main, "built_tank_1")
	var pump = _unit(main, "built_pump_2")
	var heater = _unit(main, "built_heater_3")
	var column = _unit(main, "built_column_4")
	var light_tank = _unit(main, "built_tank_5")
	var diesel_tank = _unit(main, "built_tank_6")
	var heavy_tank = _unit(main, "built_tank_7")
	main.build_controller._connect_ports(source.get_port("output"), pump.get_port("input"))
	main.build_controller._connect_ports(pump.get_port("output"), heater.get_port("input"))
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
