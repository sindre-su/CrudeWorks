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
	_expect(Catalog.ORDER.size() == 4, "catalog exposes four starter machine types")
	for equipment_type in Catalog.ORDER:
		var definition: Dictionary = Catalog.definition(equipment_type)
		_expect(not definition.is_empty(), "%s has a catalog definition" % equipment_type)
		_expect(definition["cost"] > 0, "%s has a positive price" % equipment_type)


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

	_expect(
		not controller._position_is_valid(Vector3(0.5, 1.0, 20.0), Vector2(2.0, 2.0)),
		"overlapping equipment placement is rejected"
	)
	_expect(
		controller._position_is_valid(Vector3(6.0, 1.0, 20.0), Vector2(2.0, 2.0)),
		"separated equipment placement is accepted"
	)
	_expect(
		not controller._position_is_valid(Vector3(15.0, 1.0, 20.0), Vector2(2.0, 2.0)),
		"placement outside build bounds is rejected"
	)

	var pump = BuildableUnitScript.new()
	pump.configure_buildable("pump", 3)
	pump.position = Vector3(0.0, 0.86, 26.0)
	world.add_child(pump)
	controller.register_unit(pump)
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
