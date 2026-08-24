extends SceneTree

const Catalog = preload("res://scripts/equipment_catalog.gd")
const BuildableUnitScript = preload("res://scripts/buildable_unit.gd")
const BuildControllerScript = preload("res://scripts/build_controller.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var controller = BuildControllerScript.new()
	world.add_child(controller)
	controller.setup(null)
	controller.set_unlocked(true)
	controller.set_build_mode(true)
	controller._update_build_text()
	_expect("BYGGEMODUS" in controller.build_label.text, "build-mode interface renders catalog and controls")
	_expect("Retning: 0°" in controller.build_label.text, "build UI reports selected orientation")
	_expect(controller.ghost.has_node("PreviewInputPort"), "placement preview shows the input port")
	_expect(controller.ghost.has_node("PreviewOutputPort"), "placement preview shows the output port")
	_expect(controller.ghost.has_node("FlowDirection"), "placement preview shows a flow-direction arrow")
	var valve_key := InputEventKey.new()
	valve_key.keycode = KEY_5
	valve_key.pressed = true
	controller._input(valve_key)
	_expect(controller.selected_type == "valve", "key 5 selects the new manual valve without changing keys 1-4")
	_expect(controller.ghost.has_node("PreviewInputPort") and controller.ghost.has_node("PreviewOutputPort"), "manual-valve preview exposes readable IN and OUT ports")
	var treatment_key := InputEventKey.new()
	treatment_key.keycode = KEY_6
	treatment_key.pressed = true
	controller._input(treatment_key)
	_expect(controller.selected_type == "treatment", "key 6 selects the diesel treatment unit")
	var header_key := InputEventKey.new()
	header_key.keycode = KEY_7
	header_key.pressed = true
	controller._input(header_key)
	_expect(controller.selected_type == "header", "key 7 selects the Crude Feed Header")
	_expect(controller.ghost.has_node("PreviewOut APort") and controller.ghost.has_node("PreviewOut BPort"), "header preview exposes both readable branch outlets")
	var product_header_key := InputEventKey.new()
	product_header_key.keycode = KEY_8
	product_header_key.pressed = true
	controller._input(product_header_key)
	_expect(controller.selected_type == "product_header", "key 8 selects the Product Routing Header")
	_expect(controller.ghost.has_node("PreviewOut APort") and controller.ghost.has_node("PreviewOut BPort"), "product-header preview exposes both readable storage outlets")
	var vdu_key := InputEventKey.new()
	vdu_key.keycode = KEY_9
	vdu_key.pressed = true
	controller._input(vdu_key)
	_expect(controller.selected_type == "vacuum_distillation", "key 9 selects the player-buildable VDU-301")
	_expect(_ghost_has_port(controller.ghost, "vgo") and _ghost_has_port(controller.ghost, "vacuum_residue"), "VDU preview exposes both readable secondary-product outlets")
	var power_key := InputEventKey.new()
	power_key.keycode = KEY_0
	power_key.pressed = true
	controller._input(power_key)
	_expect(controller.selected_type == "power_unit", "key 0 selects the player-buildable PU-101")
	_expect(controller.ghost.get_child_count() == 1, "Power Unit preview has no misleading process ports or flow arrow")
	var fcc_key := InputEventKey.new()
	fcc_key.keycode = KEY_MINUS
	fcc_key.pressed = true
	controller._input(fcc_key)
	_expect(controller.selected_type == "catalytic_cracking", "minus key selects the player-buildable FCC-401")
	_expect(_ghost_has_port(controller.ghost, "gasoline") and _ghost_has_port(controller.ghost, "lpg") and _ghost_has_port(controller.ghost, "lco"), "FCC preview exposes its three typed upgraded-product outlets")
	controller.set_build_mode(false)

	_test_catalog()
	_test_units_and_footprints(world)
	_test_placement_and_connections(world, controller)

	if failures == 0:
		print("PASS: all CrudeWorks building-system tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks building-system test(s) failed" % failures)
		quit(1)


func _test_catalog() -> void:
	_expect(Catalog.ORDER.size() == 11, "catalog exposes FCC-401 alongside existing refinery machines and utilities")
	for equipment_type in Catalog.ORDER:
		var definition: Dictionary = Catalog.definition(equipment_type)
		_expect(not definition.is_empty(), "%s has a catalog definition" % equipment_type)
		_expect(definition["cost"] > 0, "%s has a positive price" % equipment_type)
	var vdu_ports: Array[Dictionary] = Catalog.port_definitions("vacuum_distillation")
	_expect(Catalog.ORDER.has("vacuum_distillation") and Catalog.definition("vacuum_distillation")["cost"] > Catalog.definition("pump")["cost"] and vdu_ports.size() == 3, "VDU is a purchasable normal build-menu unit with three typed ports")
	_expect(Catalog.port_definition("vacuum_distillation", "input")["material"] == "heavy" and Catalog.port_definition("vacuum_distillation", "vgo")["material"] == "vacuum_gas_oil" and Catalog.port_definition("vacuum_distillation", "vacuum_residue")["material"] == "vacuum_residue", "VDU skeleton exposes typed Heavy Residue, VGO and Vacuum Residue ports")
	_expect(Catalog.port_definitions("power_unit").is_empty() and Catalog.definition("power_unit")["cost"] > 0, "Power Unit is a normal purchasable utility with no process ports")
	var fcc_ports: Array[Dictionary] = Catalog.port_definitions("catalytic_cracking")
	_expect(Catalog.definition("catalytic_cracking")["cost"] == 2200 and fcc_ports.size() == 4, "FCC-401 is a purchasable normal build-menu unit with one VGO input and three outputs")


func _ghost_has_port(ghost: Node3D, target_port_id: String) -> bool:
	for child in ghost.get_children():
		if child.get("port_id") == target_port_id:
			return true
	return false


func _test_units_and_footprints(world: Node3D) -> void:
	var heater = BuildableUnitScript.new()
	heater.configure_buildable("heater", 1)
	heater.position = Vector3(-8.0, 1.66, 20.0)
	world.add_child(heater)
	_expect(is_instance_valid(heater.input_port), "buildable unit creates an input port")
	_expect(is_instance_valid(heater.output_port), "buildable unit creates an output port")
	var column = BuildableUnitScript.new()
	column.configure_buildable("column", 9)
	world.add_child(column)
	_expect(column.ports_of_kind("output").size() == 3, "distillation column exposes three labelled product outlets")
	_expect(column.get_port("diesel") != null, "column exposes a dedicated diesel outlet")
	var treatment = BuildableUnitScript.new()
	treatment.configure_buildable("treatment", 11)
	world.add_child(treatment)
	_expect(is_instance_valid(treatment.input_port) and is_instance_valid(treatment.output_port), "diesel treatment exposes readable IN and OUT ports")
	var header = BuildableUnitScript.new()
	header.configure_buildable("header", 12)
	world.add_child(header)
	_expect(header.get_port("input") != null and header.get_port("out_a") != null and header.get_port("out_b") != null, "Crude Feed Header exposes IN, OUT A and OUT B ports")
	var product_header = BuildableUnitScript.new()
	product_header.configure_buildable("product_header", 13)
	world.add_child(product_header)
	_expect(product_header.get_port("input") != null and product_header.get_port("out_a") != null and product_header.get_port("out_b") != null, "Product Routing Header exposes IN, OUT A and OUT B ports")
	var vdu = BuildableUnitScript.new()
	vdu.configure_buildable("vacuum_distillation", 14)
	world.add_child(vdu)
	_expect(vdu.get_port("input") != null and vdu.get_port("vgo") != null and vdu.get_port("vacuum_residue") != null, "VDU skeleton uses the normal buildable port and rotation conventions")
	var valve = BuildableUnitScript.new()
	valve.configure_buildable("valve", 10)
	world.add_child(valve)
	_expect(is_instance_valid(valve.valve_handle), "manual valve has a readable physical handle")
	_expect(is_equal_approx(valve.valve_handle.rotation.y, deg_to_rad(90.0)), "new valve handle is perpendicular while closed")
	valve.set_valve_open(true)
	_expect(is_equal_approx(valve.valve_handle.rotation.y, 0.0), "open valve handle aligns with process flow")
	var original := heater.rotated_footprint()
	heater.rotation_quadrants = 1
	var rotated := heater.rotated_footprint()
	_expect(original.x == rotated.y and original.y == rotated.x, "90-degree rotation swaps footprint axes")


func _test_placement_and_connections(world: Node3D, controller) -> void:
	var tank = BuildableUnitScript.new()
	tank.configure_buildable("tank", 2)
	tank.position = Vector3(0.0, 1.96, 20.0)
	world.add_child(tank)
	controller.register_unit(tank)
	_expect(is_instance_valid(tank.liquid_level), "built tank has a visible-fill component")
	tank.set_tank_fill(0.5, "crude")
	_expect(tank.liquid_level.visible, "non-empty built tank displays its liquid level")
	for product_id in ["vacuum_gas_oil", "vacuum_residue", "gasoline_blendstock", "lpg", "light_cycle_oil"]:
		tank.set_tank_fill(0.5, product_id)
		_expect(
			tank.liquid_material.albedo_color.is_equal_approx(BuildableUnitScript.TANK_LIQUID_COLORS[product_id]),
			"%s receives its own physical tank-liquid color" % product_id
		)

	_expect(
		not controller._position_is_valid(Vector3(0.5, 1.0, 20.0), Vector2(2.0, 2.0)),
		"overlapping equipment placement is rejected"
	)
	_expect(
		controller._position_is_valid(Vector3(6.0, 1.0, 20.0), Vector2(2.0, 2.0)),
		"separated equipment placement is accepted"
	)
	_expect(
		controller._position_is_valid(Vector3(17.0, 1.0, 20.0), Vector2(2.0, 2.0)),
		"expanded Area 02 accepts equipment in the new outward build space"
	)
	_expect(
		not controller._position_is_valid(Vector3(21.0, 1.0, 20.0), Vector2(2.0, 2.0)),
		"placement outside build bounds is rejected"
	)

	var pump = BuildableUnitScript.new()
	pump.configure_buildable("pump", 3)
	pump.position = Vector3(0.0, 0.86, 26.0)
	world.add_child(pump)
	controller.register_unit(pump)
	_expect(is_instance_valid(pump.pump_rotor), "built pump has a local physical rotor")
	pump.set_pump_operating(true)
	var rotor_angle_before: float = pump.pump_rotor.rotation.z
	pump._process(0.5)
	_expect(not is_equal_approx(pump.pump_rotor.rotation.z, rotor_angle_before), "running pump animates its local rotor")
	pump.set_pump_operating(false)
	var stopped_rotor_angle: float = pump.pump_rotor.rotation.z
	pump._process(0.5)
	_expect(is_equal_approx(pump.pump_rotor.rotation.z, stopped_rotor_angle), "stopped pump leaves its rotor stationary")
	var result: Dictionary = controller._connect_ports(tank.output_port, pump.input_port)
	_expect(result["ok"], "controller accepts a valid tank-to-pump connection")
	_expect(controller.connections.size() == 1, "OUT-to-IN connection creates one pipe record")
	_expect(controller._connection_exists(tank.output_port, pump.input_port), "created connection can be detected")
	_expect(tank.output_port.connected and pump.input_port.connected, "connected ports retain per-port connection feedback")
	var active_keys := {controller.connections[0]["key"]: true}
	controller.set_process_flow(10.0, 10.0, active_keys)
	_expect(controller.connections[0]["flow_visual"].visible, "active-route pipe displays moving flow markers")
	var duplicate: Dictionary = controller._connect_ports(tank.output_port, pump.input_port)
	_expect(not duplicate["ok"], "controller surfaces logical duplicate-connection rejection")
	_expect(controller._disconnect_port(tank.output_port), "a focused port can disconnect a mistaken pipe")
	_expect(controller.connections.is_empty(), "disconnect removes the visual pipe record")
	_expect(controller.process_network.connection_count() == 0, "disconnect also removes the authoritative graph edge")
	_expect(not tank.output_port.connected and not pump.input_port.connected, "disconnect clears both port connection indicators")


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
