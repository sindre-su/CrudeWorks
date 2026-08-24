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
	_test_product_header_destination_discovery()
	_test_typed_route_envelope()
	_test_vacuum_route_discovery_and_contract()
	_test_vacuum_route_validation_and_invalidation()
	_test_mixed_atmospheric_and_vacuum_routes()


func _test_valid_topology() -> void:
	var network = _complete_network()
	var validation: Dictionary = network.validate_configuration()
	_expect(validation["valid"], "complete refinery topology is accepted")
	_expect(network.connection_count() == 7, "complete refinery uses seven directed connections including the manual valve")
	_expect(validation["route"]["valve"] == "valve", "complete route exposes the required manual valve")
	_expect(validation["route"].get("process_type", "") == ProcessNetworkScript.ATMOSPHERIC_DISTILLATION, "complete route is explicitly typed as atmospheric distillation")
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


func _test_product_header_destination_discovery() -> void:
	var network = _complete_network()
	_register(network, "diesel_header", "product_header", "PH-201")
	_register(network, "diesel_backup", "tank", "T-205")
	_expect(network.disconnect_ports("column", "diesel", "diesel_tank", "input"), "direct diesel storage can be replaced with a product header")
	_expect(network.try_connect("column", "diesel", "diesel_header", "input")["ok"], "column diesel outlet connects to Product Routing Header IN")
	_expect(network.try_connect("diesel_header", "out_a", "diesel_tank", "input")["ok"], "Product Routing Header OUT A connects to primary diesel storage")
	_expect(network.try_connect("diesel_header", "out_b", "diesel_backup", "input")["ok"], "Product Routing Header OUT B connects to backup diesel storage")
	var validation: Dictionary = network.validate_configuration()
	var route: Dictionary = validation["route"]
	var destinations: Array[Dictionary] = network.destinations_for_product_header("diesel_header")
	_expect(validation["valid"] and route["product_headers"]["diesel"] == "diesel_header", "optional product header keeps the refinery topology valid")
	_expect(destinations.size() == 2 and destinations[0]["tank"] == "diesel_tank" and destinations[1]["tank"] == "diesel_backup", "product header exposes stable physical A/B storage destinations")
	network.disconnect_ports("diesel_header", "out_b", "diesel_backup", "input")
	_expect(network.validate_configuration()["valid"] and network.destinations_for_product_header("diesel_header").size() == 1, "an incomplete sibling storage branch does not invalidate the available product route")


func _test_typed_route_envelope() -> void:
	var network = _complete_network()
	var atmospheric: Dictionary = network.find_complete_route()
	var vacuum := {
		"process_type": ProcessNetworkScript.VACUUM_DISTILLATION,
		"route_id": "vacuum:vdu_pump",
		"source": "heavy_source",
		"pump": "vdu_pump",
		"equipment_ids": ["heavy_source", "vdu_pump", "vdu"],
	}
	_expect(network.is_atmospheric_route(atmospheric), "atmospheric route helper recognizes the current process family")
	_expect(not network.is_atmospheric_route(vacuum), "synthetic vacuum route is not treated as atmospheric")
	_expect(network.get_route_id(vacuum) == "vacuum:vdu_pump" and network.get_route_source(vacuum) == "heavy_source" and network.get_route_primary_pump(vacuum) == "vdu_pump", "route envelope exposes stable generic identity, source and primary pump")
	_expect(network.route_contains_unit(vacuum, "vdu") and not network.route_contains_unit(vacuum, "heater"), "generic route membership does not require atmospheric equipment fields")
	var atmospheric_only: Array[Dictionary] = network.filter_routes_by_process_type([vacuum, atmospheric], ProcessNetworkScript.ATMOSPHERIC_DISTILLATION)
	_expect(atmospheric_only.size() == 1 and atmospheric_only[0]["pump"] == "pump", "atmospheric consumers can explicitly ignore a sparse future route")


func _test_vacuum_route_discovery_and_contract() -> void:
	var network = _complete_vacuum_network()
	var routes: Array[Dictionary] = network.find_complete_routes()
	var route: Dictionary = routes[0] if not routes.is_empty() else {}
	_expect(routes.size() == 1 and network.get_process_type(route) == ProcessNetworkScript.VACUUM_DISTILLATION, "complete Heavy Residue to VDU topology discovers one typed vacuum route")
	_expect(network.get_route_id(route) == "vacuum:vacuum_pump" and network.get_route_source(route) == "vacuum_source" and network.get_route_primary_pump(route) == "vacuum_pump", "vacuum route identity is stable and anchored to its feed pump")
	_expect(route.get("vdu", "") == "vacuum_vdu" and route.get("outputs", {}) == {"vacuum_gas_oil": "vacuum_vgo", "vacuum_residue": "vacuum_residue"}, "vacuum payload exposes only the VDU and its two destinations")
	_expect(not route.has("valve") and not route.has("heater") and not route.has("column") and not route.has("products"), "vacuum route does not inherit atmospheric-only route fields")
	_expect(network.route_contains_unit(route, "vacuum_source") and network.route_contains_unit(route, "vacuum_pump") and network.route_contains_unit(route, "vacuum_vdu") and network.route_contains_unit(route, "vacuum_vgo") and network.route_contains_unit(route, "vacuum_residue"), "vacuum route membership includes every required equipment endpoint")
	_expect(network.tank_intended_material("vacuum_source") == "heavy", "empty Heavy Residue source intent is sufficient for structural vacuum discovery")
	_expect(network.find_complete_routes()[0]["route_id"] == network.get_route_id(route), "vacuum rediscovery retains the same route identity")


func _test_vacuum_route_validation_and_invalidation() -> void:
	var missing_vgo = _complete_vacuum_network()
	missing_vgo.disconnect_ports("vacuum_vdu", "vgo", "vacuum_vgo", "input")
	_expect(missing_vgo.filter_routes_by_process_type(missing_vgo.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "VDU route with only Vacuum Residue storage is incomplete")
	var missing_residue = _complete_vacuum_network()
	missing_residue.disconnect_ports("vacuum_vdu", "vacuum_residue", "vacuum_residue", "input")
	_expect(missing_residue.filter_routes_by_process_type(missing_residue.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "VDU route with only VGO storage is incomplete")
	for feed in ["crude", "light", "diesel", "vacuum_gas_oil", "vacuum_residue"]:
		var wrong_feed = _complete_vacuum_network(feed)
		_expect(wrong_feed.filter_routes_by_process_type(wrong_feed.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "%s cannot become a Heavy Residue vacuum feed route" % feed)
	var missing_pump = _complete_vacuum_network()
	missing_pump.unregister_unit("vacuum_pump")
	_expect(missing_pump.filter_routes_by_process_type(missing_pump.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "removing the vacuum feed pump removes its route safely")
	var missing_vgo_tank = _complete_vacuum_network()
	missing_vgo_tank.unregister_unit("vacuum_vgo")
	_expect(missing_vgo_tank.filter_routes_by_process_type(missing_vgo_tank.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "removing VGO storage removes its route safely")
	var missing_residue_tank = _complete_vacuum_network()
	missing_residue_tank.unregister_unit("vacuum_residue")
	_expect(missing_residue_tank.filter_routes_by_process_type(missing_residue_tank.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "removing Vacuum Residue storage removes its route safely")
	var invalidated = _complete_vacuum_network()
	invalidated.unregister_unit("vacuum_vdu")
	_expect(invalidated.filter_routes_by_process_type(invalidated.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).is_empty(), "removing the VDU removes its route without stale references")


func _test_mixed_atmospheric_and_vacuum_routes() -> void:
	var network = _complete_network()
	_add_vacuum_route(network, "vacuum", "heavy")
	_add_vacuum_route(network, "vacuum_b", "heavy")
	var routes: Array[Dictionary] = network.find_complete_routes()
	var atmospheric: Array[Dictionary] = network.filter_routes_by_process_type(routes, ProcessNetworkScript.ATMOSPHERIC_DISTILLATION)
	var vacuum: Array[Dictionary] = network.filter_routes_by_process_type(routes, ProcessNetworkScript.VACUUM_DISTILLATION)
	_expect(atmospheric.size() == 1 and vacuum.size() == 2, "atmospheric and two independent vacuum trains coexist without route-family confusion")
	_expect(vacuum[0]["route_id"] != vacuum[1]["route_id"], "multiple vacuum trains retain distinct stable identities")
	_expect(network.eligible_routes_for_source("vacuum_source").is_empty(), "Crude Feed allocation ignores a real vacuum route")
	network.unregister_unit("column")
	_expect(network.filter_routes_by_process_type(network.find_complete_routes(), ProcessNetworkScript.VACUUM_DISTILLATION).size() == 2, "an unrelated atmospheric route failure does not invalidate vacuum route discovery")


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
	_register(network, "header", "header", "FH-201")
	_expect(network.disconnect_ports("source", "output", "pump", "input"), "direct source pipe can be replaced by the shared-feed header")
	_expect(network.try_connect("source", "output", "header", "input")["ok"], "shared source connects to the header IN")
	_expect(
		"Crude Feed Header trenger minst én OUT" in network.validate_configuration()["message"],
		"partial shared header explains its missing pump branch"
	)
	_expect(network.try_connect("header", "out_a", "pump", "input")["ok"], "header OUT A connects to Train A pump")
	_register_route(network, "b")
	_expect(network.try_connect("header", "out_b", "b_pump", "input")["ok"], "header OUT B connects to Train B pump")
	for edge in [
		["b_pump", "output", "b_valve", "input"], ["b_valve", "output", "b_heater", "input"], ["b_heater", "output", "b_column", "input"], ["b_column", "light", "b_light", "input"], ["b_column", "diesel", "b_diesel", "input"], ["b_column", "heavy", "b_heavy", "input"],
	]:
		_expect(network.try_connect(edge[0], edge[1], edge[2], edge[3])["ok"], "shared-source test builds Train B downstream structure")
	var routes: Array[Dictionary] = network.eligible_routes_for_source("source")
	_expect(routes.size() == 2 and routes[0]["header"] == "header", "one physical header exposes two complete eligible trains")
	_expect(network.routes_for_header("header")[0]["header_outlet"] == "out_a" and network.routes_for_header("header")[1]["header_outlet"] == "out_b", "header branch identities remain A then B regardless of connection order")
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


func _complete_vacuum_network(source_material := "heavy"):
	var network = ProcessNetworkScript.new()
	_add_vacuum_route(network, "vacuum", source_material)
	return network


func _add_vacuum_route(network, prefix: String, source_material: String) -> void:
	_register(network, prefix + "_source", "tank", prefix.to_upper() + "-T1", source_material)
	_register(network, prefix + "_pump", "pump", prefix.to_upper() + "-P1")
	_register(network, prefix + "_vdu", "vacuum_distillation", prefix.to_upper() + "-VDU")
	_register(network, prefix + "_vgo", "tank", prefix.to_upper() + "-T2", "vacuum_gas_oil")
	_register(network, prefix + "_residue", "tank", prefix.to_upper() + "-T3", "vacuum_residue")
	_expect(network.try_connect(prefix + "_source", "output", prefix + "_pump", "input")["ok"], "vacuum source connects to its feed pump")
	_expect(network.try_connect(prefix + "_pump", "output", prefix + "_vdu", "input")["ok"], "vacuum feed pump connects to VDU IN")
	_expect(network.try_connect(prefix + "_vdu", "vgo", prefix + "_vgo", "input")["ok"], "VDU VGO OUT connects to compatible storage")
	_expect(network.try_connect(prefix + "_vdu", "vacuum_residue", prefix + "_residue", "input")["ok"], "VDU Vacuum Residue OUT connects to compatible storage")


func _register_route(network, prefix: String) -> void:
	_register(network, prefix + "_source", "tank", prefix.to_upper() + "-T1")
	_register(network, prefix + "_pump", "pump", prefix.to_upper() + "-P1")
	_register(network, prefix + "_valve", "valve", prefix.to_upper() + "-V1")
	_register(network, prefix + "_heater", "heater", prefix.to_upper() + "-H1")
	_register(network, prefix + "_column", "column", prefix.to_upper() + "-D1")
	_register(network, prefix + "_light", "tank", prefix.to_upper() + "-T2")
	_register(network, prefix + "_diesel", "tank", prefix.to_upper() + "-T3")
	_register(network, prefix + "_heavy", "tank", prefix.to_upper() + "-T4")


func _register(network, unit_id: String, equipment_type: String, display_name: String, intended_material := "") -> void:
	var result: Dictionary = network.register_unit(unit_id, equipment_type, display_name, intended_material)
	_expect(result["ok"], "%s registers in the process graph" % display_name)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("  OK  %s" % description)
	else:
		failures += 1
		printerr("  ERR %s" % description)
