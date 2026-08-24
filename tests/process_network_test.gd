extends SceneTree

const ProcessNetworkScript = preload("res://scripts/process_network.gd")

var failures := 0


func _init() -> void:
	_run_tests()
	if failures == 0:
		print("PASS: all CrudeWorks process-network tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks process-network test(s) failed" % failures)
		quit(1)


func _run_tests() -> void:
	_test_valid_topology()
	_test_direction_and_order()
	_test_occupied_ports_and_duplicates()
	_test_cycle_rejection()
	_test_removal_cleanup()
	_test_actionable_missing_connection()
	_test_second_complete_route_is_accepted()
	_test_shared_source_candidate_discovery()
	_test_optional_diesel_treatment_route()


func _test_valid_topology() -> void:
	var network = _complete_network()
	var validation: Dictionary = network.validate_configuration()
	_expect(validation["valid"], "complete refinery topology is accepted")
	_expect(network.connection_count() == 7, "complete refinery uses seven directed connections including the manual valve")
	_expect(validation["route"]["valve"] == "valve", "complete route exposes the required manual valve")
	_expect(validation["route"]["products"].size() == 3, "route resolves three distinct product tanks")


func _test_optional_diesel_treatment_route() -> void:
	var network = _complete_network()
	_register(network, "treatment", "treatment", "HT-201")
	_expect(network.disconnect_ports("column", "diesel", "diesel_tank", "input"), "direct diesel branch can be rerouted through treatment")
	_expect(network.try_connect("column", "diesel", "treatment", "input")["ok"], "column diesel outlet accepts the treatment input")
	_expect(network.try_connect("treatment", "output", "diesel_tank", "input")["ok"], "treatment outlet accepts the final diesel tank")
	var validation: Dictionary = network.validate_configuration()
	_expect(validation["valid"] and validation["route"]["treatment"] == "treatment", "a treatment branch is a valid single refinery route")
	_expect(network.connection_count() == 8, "treatment route adds one directed connection without duplicating a product path")


func _test_direction_and_order() -> void:
	var network = ProcessNetworkScript.new()
	_register(network, "tank", "tank", "T-201")
	_register(network, "pump", "pump", "P-201")
	_register(network, "valve", "valve", "V-201")
	_register(network, "column", "column", "D-201")
	var wrong_direction: Dictionary = network.try_connect("pump", "input", "tank", "input")
	_expect(not wrong_direction["ok"], "input-to-input connection is rejected")
	_expect("OUT" in wrong_direction["message"] and "IN" in wrong_direction["message"], "direction error explains OUT-to-IN")
	var wrong_order: Dictionary = network.try_connect("tank", "output", "column", "input")
	_expect(not wrong_order["ok"], "unheated tank-to-column process order is rejected")
	var heater = ProcessNetworkScript.new()
	_register(heater, "pump", "pump", "P-202")
	_register(heater, "heater", "heater", "H-202")
	var valve_bypass: Dictionary = heater.try_connect("pump", "output", "heater", "input")
	_expect(not valve_bypass["ok"] and "ventil" in valve_bypass["message"], "pump-to-heater bypass is rejected with a manual-valve explanation")
	_expect(network.connection_count() == 0, "rejected connections do not mutate the graph")


func _test_occupied_ports_and_duplicates() -> void:
	var network = ProcessNetworkScript.new()
	_register(network, "source_a", "tank", "T-201")
	_register(network, "source_b", "tank", "T-202")
	_register(network, "pump_a", "pump", "P-201")
	_register(network, "pump_b", "pump", "P-202")
	_expect(network.try_connect("source_a", "output", "pump_a", "input")["ok"], "first legal connection succeeds")
	_expect(not network.try_connect("source_a", "output", "pump_a", "input")["ok"], "exact duplicate is rejected")
	_expect(not network.try_connect("source_a", "output", "pump_b", "input")["ok"], "one output cannot feed two connections")
	_expect(not network.try_connect("source_b", "output", "pump_a", "input")["ok"], "one input cannot receive two connections")
	_expect(network.connection_count() == 1, "occupied-port failures leave the original edge unchanged")


func _test_cycle_rejection() -> void:
	var network = ProcessNetworkScript.new()
	_register(network, "pump", "pump", "P-201")
	_register(network, "valve", "valve", "V-201")
	_register(network, "heater", "heater", "H-201")
	_register(network, "column", "column", "D-201")
	_register(network, "tank", "tank", "T-201")
	_expect(network.try_connect("pump", "output", "valve", "input")["ok"], "cycle fixture connects pump to valve")
	_expect(network.try_connect("valve", "output", "heater", "input")["ok"], "cycle fixture connects valve to heater")
	_expect(network.try_connect("heater", "output", "column", "input")["ok"], "cycle fixture connects heater to column")
	_expect(network.try_connect("column", "light", "tank", "input")["ok"], "cycle fixture connects column to tank")
	var cycle: Dictionary = network.try_connect("tank", "output", "pump", "input")
	_expect(not cycle["ok"], "connection that closes a directed cycle is rejected")
	_expect("løkke" in cycle["message"], "cycle rejection gives player-readable feedback")
	_expect(network.connection_count() == 4, "cycle rejection is atomic")


func _test_removal_cleanup() -> void:
	var network = _complete_network()
	network.unregister_unit("valve")
	_expect(network.connection_count() == 5, "removing the valve removes both incident connections")
	_expect(not network.validate_configuration()["valid"], "removed manual valve invalidates the route")


func _test_actionable_missing_connection() -> void:
	var network = ProcessNetworkScript.new()
	_register(network, "source", "tank", "T-201")
	_register(network, "pump", "pump", "P-201")
	_expect(network.try_connect("source", "output", "pump", "input")["ok"], "partial route fixture connects source and pump")
	var validation: Dictionary = network.validate_configuration()
	_expect(not validation["valid"], "partial refinery is not reported as ready")
	_expect("P-201" in validation["message"] and "ventil" in validation["message"], "validation identifies the missing manual valve")


func _test_second_complete_route_is_accepted() -> void:
	var network = _complete_network()
	_register_route(network, "b")
	_expect(network.try_connect("b_source", "output", "b_pump", "input")["ok"], "second route may be assembled while it is still incomplete")
	_expect(network.try_connect("b_pump", "output", "b_valve", "input")["ok"], "second route pump and valve may be inspected before completion")
	_expect(network.try_connect("b_valve", "output", "b_heater", "input")["ok"], "second route valve and heater may be inspected before completion")
	_expect(network.try_connect("b_heater", "output", "b_column", "input")["ok"], "second route column feed may be inspected before completion")
	_expect(network.try_connect("b_column", "light", "b_light", "input")["ok"], "second light branch may be connected")
	_expect(network.try_connect("b_column", "diesel", "b_diesel", "input")["ok"], "second diesel branch may be connected")
	var completed: Dictionary = network.try_connect("b_column", "heavy", "b_heavy", "input")
	_expect(completed["ok"], "connection that completes a second independent route is accepted")
	_expect(network.connection_count() == 14 and network.find_complete_routes().size() == 2, "two complete routes are retained independently")
	var validation: Dictionary = network.validate_configuration()
	_expect(validation["valid"] and validation["routes"].size() == 2, "validation reports both complete process trains")
	_expect(network.find_complete_route()["source"] == "source" and network.find_route_for_unit("b_pump")["source"] == "b_source", "route lookup keeps equipment ownership deterministic")
	network.disconnect_ports("b_column", "heavy", "b_heavy", "input")
	_expect(network.validate_configuration()["valid"] and network.find_complete_route()["source"] == "source", "disconnecting one route restores the sole complete route")


func _test_shared_source_candidate_discovery() -> void:
	var network = _complete_network()
	_register_route(network, "b")
	for edge in [
		["b_pump", "output", "b_valve", "input"], ["b_valve", "output", "b_heater", "input"], ["b_heater", "output", "b_column", "input"], ["b_column", "light", "b_light", "input"], ["b_column", "diesel", "b_diesel", "input"], ["b_column", "heavy", "b_heavy", "input"],
	]:
		_expect(network.try_connect(edge[0], edge[1], edge[2], edge[3])["ok"], "shared-source test builds Train B downstream structure")
	# Test-only structural fixture: normal construction still protects a tank OUT
	# from branching until a physical header is deliberately implemented.
	network.connections.append({"from_unit": "source", "from_port": "output", "to_unit": "b_pump", "to_port": "input"})
	var routes: Array[Dictionary] = network.eligible_routes_for_source("source")
	_expect(routes.size() == 2, "one shared source exposes two complete eligible trains")
	_expect(network.eligible_train_ids_for_source("source") == ["b_pump", "pump"], "eligible train identities are stable pump IDs rather than route indexes")
	network.disconnect_ports("b_column", "heavy", "b_heavy", "input")
	_expect(network.eligible_train_ids_for_source("source") == ["pump"], "an incomplete sibling branch does not invalidate the complete eligible train")


func _complete_network():
	var network = ProcessNetworkScript.new()
	_register(network, "source", "tank", "T-201")
	_register(network, "pump", "pump", "P-201")
	_register(network, "valve", "valve", "V-201")
	_register(network, "heater", "heater", "H-201")
	_register(network, "column", "column", "D-201")
	_register(network, "light_tank", "tank", "T-202")
	_register(network, "diesel_tank", "tank", "T-203")
	_register(network, "heavy_tank", "tank", "T-204")
	network.try_connect("source", "output", "pump", "input")
	network.try_connect("pump", "output", "valve", "input")
	network.try_connect("valve", "output", "heater", "input")
	network.try_connect("heater", "output", "column", "input")
	network.try_connect("column", "light", "light_tank", "input")
	network.try_connect("column", "diesel", "diesel_tank", "input")
	network.try_connect("column", "heavy", "heavy_tank", "input")
	return network


func _register_route(network, prefix: String) -> void:
	_register(network, prefix + "_source", "tank", prefix.to_upper() + "-T1")
	_register(network, prefix + "_pump", "pump", prefix.to_upper() + "-P1")
	_register(network, prefix + "_valve", "valve", prefix.to_upper() + "-V1")
	_register(network, prefix + "_heater", "heater", prefix.to_upper() + "-H1")
	_register(network, prefix + "_column", "column", prefix.to_upper() + "-D1")
	_register(network, prefix + "_light", "tank", prefix.to_upper() + "-T2")
	_register(network, prefix + "_diesel", "tank", prefix.to_upper() + "-T3")
	_register(network, prefix + "_heavy", "tank", prefix.to_upper() + "-T4")


func _register(network, unit_id: String, equipment_type: String, display_name: String) -> void:
	var result: Dictionary = network.register_unit(unit_id, equipment_type, display_name)
	_expect(result["ok"], "%s registers in the process graph" % display_name)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
