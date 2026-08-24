extends SceneTree

const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")
const CrudeCatalogScript = preload("res://scripts/crude_contract_catalog.gd")
const FeedAllocationScript = preload("res://scripts/feed_allocation.gd")

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
	_test_feed_allocation_foundation()
	_test_shared_source_runtime_allocation()
	_test_manual_valve_low_flow()
	_test_automatic_heater_control()
	_test_operator_alarm_lifecycle_and_isolation()
	_test_mass_conserving_ideal_batch_and_sale()
	_test_full_tank_backpressure()
	_test_commissioning_and_paid_batches()
	_test_topology_change_stops_flow_and_spare_pump()
	_test_offspec_recovery()
	_test_partial_sale_report()
	_test_route_scoped_alarm()
	_test_disconnected_inventory_is_not_sellable()
	_test_standard_contract_regression()
	_test_heavy_contract_temperature_tradeoff()
	_test_contract_lifecycle_and_bonus_lock()
	_test_control_station_telemetry_and_temperature_guard()
	_test_paid_batch_lab_sampling()
	_test_independent_process_trains()
	_test_distinct_delivery_order_definitions()
	_test_heavy_delivery_order_volume_gate()
	_test_off_route_product_blocks_dispatch()
	_test_adjustable_pump_flow_and_quality_tradeoff()
	_test_recoverable_pump_filter_fault()
	_test_pump_condition_and_preventive_maintenance()
	_test_sour_crude_requires_treatment()
	_test_product_specific_dispatch()
	_test_product_header_allocation_and_capacity()
	_test_product_header_preserves_treated_diesel_and_save_state()
	_test_sparse_future_route_is_ignored_by_atmospheric_consumers()
	_test_persisted_material_intent()
	_test_atomic_vacuum_distillation()
	_test_vacuum_capacity_and_multi_stage_processing()
	_test_player_facing_vacuum_operation_and_dispatch()
	_test_atomic_fcc_upgrading_and_dispatch()
	_test_secondary_pump_start_and_stop_guards()
	_test_electrical_power_capacity()


func _test_invalid_network_cannot_start() -> void:
	var model = BuiltRefineryModelScript.new()
	model.register_unit("pump", "pump", "P-201")
	var result: Dictionary = model.interact("pump")
	_expect(not result["ok"], "pump cannot start on a disconnected network")
	_expect(not model.equipment["pump"]["running"], "rejected start leaves pump stopped")
	_expect(not result["message"].is_empty(), "rejected start gives actionable player feedback")


func _test_electrical_power_capacity() -> void:
	var model = _vacuum_model(100.0)
	_add_power_atmospheric_route(model, "main")
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	var base_power: Dictionary = model.power_status()
	_expect(is_equal_approx(base_power["capacity_kw"], 100.0) and is_equal_approx(base_power["demand_kw"], 0.0), "Area 02 begins with a small fixed electrical capacity and no idle demand")
	_expect(model.interact("main_pump")["ok"], "a normal atmospheric pump start remains within starter electrical capacity")
	_expect(is_equal_approx(model.power_status()["demand_kw"], 25.0), "a running process pump contributes its stated electrical demand")
	_expect(model.interact("vacuum_pump")["ok"], "VDU feed pump starts when its combined pump and VDU load fits capacity")
	_expect(is_equal_approx(model.power_status()["demand_kw"], 75.0), "a running VDU train adds its auxiliary electrical load exactly once")
	model.register_unit("treatment", "treatment", "HT-201")
	_expect(model.interact("treatment")["ok"], "treatment can start at the exact remaining 25 kW capacity boundary")
	_expect(is_equal_approx(model.power_status()["demand_kw"], 95.0) and model.power_status()["high_load"], "high electrical load is visible without interrupting a safe running refinery")
	_add_power_atmospheric_route(model, "spare")
	var blocked: Dictionary = model.interact("spare_pump")
	_expect(not blocked["ok"] and "INSUFFICIENT POWER CAPACITY" in blocked["message"] and not model.equipment["spare_pump"]["running"], "insufficient power rejects a new pump start atomically without stopping existing equipment")
	model.register_unit("power", "power_unit", "PU-101")
	_expect(is_equal_approx(model.power_status()["capacity_kw"], 200.0), "each placed Power Unit adds one stackable capacity increment")
	_expect(model.interact("spare_pump")["ok"] and model.equipment["spare_pump"]["running"], "added capacity unlocks the previously rejected electrical start")
	_expect(not model.can_remove("power")["ok"], "an in-use Power Unit cannot be removed while remaining capacity would be overloaded")
	model.interact("spare_pump")
	model.interact("treatment")
	model.interact("vacuum_pump")
	model.interact("main_pump")
	_expect(model.can_remove("power")["ok"], "an idle Power Unit can be removed safely after electrical demand is stopped")
	var saved: Dictionary = model.save_state()
	var restored = _vacuum_model(0.0)
	_add_power_atmospheric_route(restored, "main")
	restored.register_unit("treatment", "treatment", "HT-201")
	_add_power_atmospheric_route(restored, "spare")
	restored.register_unit("power", "power_unit", "PU-101")
	restored.apply_saved_state(saved)
	_expect(is_equal_approx(restored.power_status()["capacity_kw"], 200.0) and is_equal_approx(restored.power_status()["demand_kw"], 0.0), "Power Unit construction persists while load restores safely stopped")


func _test_feed_allocation_foundation() -> void:
	var allocation = FeedAllocationScript.new()
	allocation.configure("shared_source", ["pump_a", "pump_b"])
	_expect(allocation.selected_train_id.is_empty(), "shared source allocation starts with no implicit route owner")
	_expect(allocation.select("pump_a", false)["ok"] and allocation.is_selected("pump_a"), "stopped source can allocate feed to Train A")
	var blocked: Dictionary = allocation.select("pump_b", true)
	_expect(not blocked["ok"] and allocation.is_selected("pump_a"), "running source cannot change feed ownership")
	_expect(allocation.select("pump_b", false)["ok"] and allocation.is_selected("pump_b"), "stopped source can deterministically switch to Train B")
	allocation.configure("shared_source", ["pump_a"])
	_expect(allocation.selected_train_id.is_empty(), "invalidated selected train safely clears feed ownership instead of guessing")


func _test_shared_source_runtime_allocation() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	_add_shared_header_route(model)
	var candidates: Array[String] = model.network.eligible_train_ids_for_source("source")
	_expect(candidates == ["b_pump", "pump"], "shared source discovery supplies both stable train identities to allocation")
	_expect(model.interact("header")["ok"] and model.feed_allocations["source"].selected_train_id == "pump", "physical header selects Train A while shared source is stopped")
	_expect(model.load_crude_batch("source", true, "standard")["ok"], "one paid batch loads into the shared source once")
	for heater_id in ["heater", "b_heater"]:
		model.equipment[heater_id]["temperature_c"] = 200.0
		model.equipment[heater_id]["setpoint_c"] = 200.0
	model.equipment["valve"]["open"] = true
	model.equipment["b_valve"]["open"] = true
	model.equipment["b_treatment"]["running"] = true
	_expect(model.interact("pump")["ok"], "selected Train A pump can start from the physical header route")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 900.0) and is_equal_approx(model.equipment["light_tank"]["volume_l"], 30.0) and is_equal_approx(model.equipment["b_light"]["volume_l"], 0.0), "selected Train A alone consumes shared-source crude")
	_expect(not model.interact("header")["ok"] and model.feed_allocations["source"].selected_train_id == "pump", "running Train A pump blocks header switching without changing allocation")
	_expect(model.interact("pump")["ok"], "Train A pump can be stopped before a header switch")
	_expect(model.interact("header")["ok"] and model.feed_allocations["source"].selected_train_id == "b_pump", "stopped header switches deterministically to Train B")
	_expect(not model.interact("pump")["ok"] and model.interact("b_pump")["ok"], "unselected pump remains blocked while selected Train B pump starts")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 800.0) and is_equal_approx(model.equipment["b_light"]["volume_l"], 30.0), "Train B receives only new shared-source material after safe switch")
	_expect(not model.interact("header")["ok"], "running Train B pump also blocks header switching")
	_expect(model.interact("b_pump")["ok"] and model.interact("header")["ok"], "stopped Train B can isolate the header")
	_expect(model.feed_allocations["source"].selected_train_id.is_empty(), "header supports an explicit NONE feed route")
	model.equipment["pump"]["running"] = true
	var source_before_none: float = model.equipment["source"]["volume_l"]
	model.tick(1.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], source_before_none), "NONE header route consumes no shared crude")
	model.equipment["pump"]["running"] = false
	_expect(model.interact("header")["ok"] and model.feed_allocations["source"].selected_train_id == "pump", "header can repeatedly cycle from NONE back to Train A")
	var saved: Dictionary = model.save_state()
	var restored = _complete_model()
	restored.commissioning_batch_available = false
	restored.commissioning_contract_complete = true
	_add_shared_header_route(restored)
	restored.apply_saved_state(saved)
	var restored_allocation = restored.feed_allocations.get("source")
	_expect(restored_allocation != null and restored_allocation.eligible_train_ids == ["b_pump", "pump"] and restored_allocation.selected_train_id == "pump" and "RUTE A" in restored.unit_status("header"), "header route identity, selection and inspection state survive save/load")
	model.unregister_unit("b_pump")
	_expect(model.feed_allocations["source"].selected_train_id == "pump", "deleting an unselected header branch preserves the selected train")
	model.unregister_unit("header")
	_expect(not model.feed_allocations.has("source") and model.network.find_complete_routes().is_empty(), "deleting the header clears allocation and every shared route safely")
	var invalidated = _complete_model()
	invalidated.commissioning_batch_available = false
	invalidated.commissioning_contract_complete = true
	_add_shared_header_route(invalidated)
	invalidated.interact("header")
	invalidated.unregister_unit("pump")
	_expect(
		invalidated.feed_allocations.has("source")
		and invalidated.feed_allocations["source"].selected_train_id.is_empty()
		and "INGEN" in invalidated.unit_status("header"),
		"deleting the selected header branch clears ownership instead of auto-switching"
	)
	var sour_model = _complete_model()
	sour_model.commissioning_batch_available = false
	sour_model.commissioning_contract_complete = true
	_add_shared_header_route(sour_model)
	sour_model.interact("header")
	sour_model.interact("header")
	sour_model.equipment["b_heater"]["temperature_c"] = 200.0
	sour_model.equipment["b_heater"]["setpoint_c"] = 200.0
	sour_model.equipment["b_valve"]["open"] = true
	sour_model.equipment["b_treatment"]["running"] = true
	_expect(sour_model.load_crude_batch("source", true, "sour")["ok"], "shared header can load a Sour crude batch onto its selected branch")
	_expect(sour_model.interact("b_pump")["ok"], "selected Sour header branch starts its own pump")
	sour_model.tick(10.0)
	_expect(
		sour_model.equipment["source"]["contract_id"] == "sour"
		and sour_model.equipment["b_diesel"]["contents"] == "diesel"
		and sour_model.equipment["b_diesel"]["sulfur_ppm"] < float(CrudeCatalogScript.definition("sour")["diesel_sulfur_ppm"])
		and is_equal_approx(sour_model.equipment["diesel_tank"]["volume_l"], 0.0),
		"selected Sour branch preserves crude identity and treatment quality without leaking to its sibling"
	)


func _test_manual_valve_low_flow() -> void:
	var model = _complete_model()
	_expect(not model.equipment["valve"]["open"], "new built valve defaults closed")
	_expect(model.active_connection_keys().is_empty(), "a complete but stopped route exposes no moving pipe segments")
	_expect("åpne" in model.interaction_prompt("valve"), "closed valve prompt offers the correct action")
	model.register_unit("spare_valve", "valve", "V-299")
	model.interact("spare_valve")
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("pump")
	var mass_before_blocked := _total_tank_volume(model)
	var source_before_blocked: float = model.equipment["source"]["volume_l"]
	model.tick(10.0)
	_expect(model.equipment["pump"]["running"] and is_equal_approx(model.actual_flow_lps, 0.0), "closed valve keeps pump on but blocks all flow")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_blocked) and is_equal_approx(model.equipment["source"]["volume_l"], source_before_blocked), "closed valve consumes and creates no material")
	_expect("LOW FLOW" in model.alarm_text() and "LOW FLOW" in model.objective_text(), "closed active-route valve creates a diagnosable LOW FLOW state")
	_expect(not model.can_remove("valve")["ok"], "closed route valve cannot be removed while its pump is running")
	model.equipment["heater"]["temperature_c"] = 230.0
	_expect("HIGH TEMPERATURE" in model.alarm_text() and "LOW FLOW" in model.alarm_text(), "safety alarm remains visible alongside a simultaneous closed-valve fault")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.tick(0.0)
	_expect("LOW FLOW" in model.alarm_text(), "opening a disconnected spare valve cannot clear the active-route alarm")
	model.interact("valve")
	model.tick(10.0)
	_expect(is_equal_approx(model.actual_flow_lps, 10.0) and is_equal_approx(model.equipment["source"]["volume_l"], 900.0), "opening the route valve restores normal bounded flow")
	model.interact("valve")
	var mass_before_reclose := _total_tank_volume(model)
	model.tick(5.0)
	_expect(is_equal_approx(model.actual_flow_lps, 0.0) and is_equal_approx(_total_tank_volume(model), mass_before_reclose), "closing the valve during production pauses transfer without stopping the pump")
	model.interact("valve")
	model.tick(1.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 890.0), "reopening the valve resumes the still-running route without duplication")


func _test_adjustable_pump_flow_and_quality_tradeoff() -> void:
	var locked = _complete_model()
	_expect(
		not locked.cycle_pump_flow("pump")["ok"]
		and is_equal_approx(locked.equipment["pump"]["flow_setpoint_lps"], 10.0),
		"flow selection stays locked through the first Area 02 commissioning batch"
	)

	var losses := []
	var qualities := []
	for desired_flow in [5.0, 10.0, 15.0]:
		var model = _complete_model()
		model.commissioning_batch_available = false
		model.commissioning_contract_complete = true
		while not is_equal_approx(model.equipment["pump"]["flow_setpoint_lps"], desired_flow):
			_expect(model.cycle_pump_flow("pump")["ok"], "active route pump accepts the next flow setting")
		model.load_crude_batch("source", true, "standard")
		model.equipment["heater"]["temperature_c"] = 208.0
		model.equipment["heater"]["setpoint_c"] = 208.0
		model.interact("valve")
		model.interact("pump")
		var mass_before := _total_tank_volume(model)
		model.tick(10.0)
		losses.append(1000.0 - float(model.equipment["source"]["volume_l"]))
		qualities.append(float(model.equipment["diesel_tank"]["quality_percent"]))
		_expect(is_equal_approx(_total_tank_volume(model), mass_before), "every selectable flow setting remains mass conserving")
		_expect(is_equal_approx(model.actual_flow_lps, desired_flow), "actual flow matches the selected pump target when capacity is available")
	_expect(
		is_equal_approx(losses[0], 50.0) and is_equal_approx(losses[1], 100.0) and is_equal_approx(losses[2], 150.0),
		"5, 10 and 15 L/s create visibly different production capacity"
	)
	_expect(
		qualities[0] > qualities[1] and qualities[1] > qualities[2] and qualities[2] < 90.0,
		"higher flow narrows the quality margin at the same off-target temperature"
	)
	var long_tick = _complete_model()
	long_tick.commissioning_batch_available = false
	long_tick.commissioning_contract_complete = true
	long_tick.cycle_pump_flow("pump")
	long_tick.load_crude_batch("source", true, "standard")
	long_tick.equipment["heater"]["temperature_c"] = 208.0
	long_tick.equipment["heater"]["setpoint_c"] = 208.0
	long_tick.interact("valve")
	long_tick.interact("pump")
	long_tick.tick(100.0)
	_expect(
		is_equal_approx(long_tick.equipment["diesel_tank"]["quality_percent"], qualities[2]),
		"a long final tick cannot improve high-flow quality by averaging source depletion over idle time"
	)

	var mixed = _complete_model()
	mixed.commissioning_batch_available = false
	mixed.commissioning_contract_complete = true
	mixed.load_crude_batch("source", true, "standard")
	mixed.equipment["heater"]["temperature_c"] = 200.0
	mixed.equipment["heater"]["setpoint_c"] = 200.0
	mixed.interact("valve")
	mixed.cycle_pump_flow("pump")
	mixed.interact("pump")
	mixed.tick(10.0)
	mixed.cycle_pump_flow("pump")
	mixed.tick(10.0)
	mixed.interact("pump")
	var sample: Dictionary = mixed.take_diesel_sample("diesel_tank")
	var analysis: Dictionary = mixed.analyze_diesel_sample()
	_expect(sample["ok"] and analysis["ok"] and is_equal_approx(analysis["average_flow_lps"], 12.5), "lab records volume-weighted flow after a live 15-to-5 L/s change")
	_expect(is_equal_approx(analysis["quality_percent"], 100.0), "high flow remains viable when temperature is held exactly on target")
	var saved: Dictionary = mixed.save_state()
	_expect(
		is_equal_approx(saved["equipment"]["pump"]["flow_setpoint_lps"], 5.0)
		and is_equal_approx(saved["report_flow_total"], 2500.0),
		"pump target and accumulated flow history are persisted explicitly"
	)

	var guarded = _complete_model()
	guarded.commissioning_batch_available = false
	guarded.commissioning_contract_complete = true
	guarded.load_crude_batch("source", true, "standard")
	guarded.equipment["heater"]["temperature_c"] = 208.0
	guarded.equipment["heater"]["setpoint_c"] = 200.0
	guarded.cycle_pump_flow("pump")
	_expect(not guarded.remote_toggle_route_pump()["ok"], "LS-201 blocks a high-flow remote start outside the narrower safe range")
	guarded.remote_cycle_route_pump_flow()
	_expect(guarded.remote_toggle_route_pump()["ok"], "lowering the flow target widens the guard range without bypassing the process model")


func _test_recoverable_pump_filter_fault() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	_expect(model.load_crude_batch("source", true, "standard")["ok"], "a paid Area 02 batch can begin normal operation before a maintenance fault")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.cycle_pump_flow("pump")
	model.interact("pump")
	model.tick(30.0)
	_expect(model.equipment["pump"]["fault_id"] == "blocked_filter", "sustained paid-batch production triggers one reusable pump restriction state")
	var saved_fault: Dictionary = model.save_state()
	var restored = _complete_model()
	restored.apply_saved_state(saved_fault)
	_expect(restored.equipment["pump"]["fault_id"] == "blocked_filter" and not restored.equipment["pump"]["running"], "a saved pump restriction persists while load safety stops the pump")
	model.tick(1.0)
	_expect(is_equal_approx(model.actual_flow_lps, 5.25), "a blocked filter reduces actual flow without changing the selected 15 L/s target")
	_expect("LOW FLOW" in model.alarm_text(), "restricted pump capacity appears as a diagnosable process symptom")
	var mass_before_service := _total_tank_volume(model)
	var diagnosis: Dictionary = model.inspect_or_service_pump("pump")
	_expect(diagnosis["ok"] and "filterrestriksjon" in diagnosis["message"], "field inspection identifies the likely restriction instead of auto-repairing")
	var running_service: Dictionary = model.inspect_or_service_pump("pump")
	_expect(not running_service["ok"] and "Stopp" in running_service["message"], "filter service is blocked while the pump is still commanded on")
	model.interact("pump")
	var repair: Dictionary = model.inspect_or_service_pump("pump")
	_expect(repair["ok"] and model.equipment["pump"]["fault_id"].is_empty(), "stopped inspected pump can be repaired in the field")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_service), "inspection and repair create or destroy no process material")
	model.interact("pump")
	model.tick(1.0)
	_expect(is_equal_approx(model.actual_flow_lps, 15.0), "repair restores the selected pump capacity without resetting the batch")


func _test_sour_crude_requires_treatment() -> void:
	var untreated = _complete_model()
	untreated.commissioning_batch_available = false
	untreated.commissioning_contract_complete = true
	_expect(untreated.load_crude_batch("source", true, "sour")["charge"] == 120, "Sour crude is a controlled lower-cost feedstock purchase")
	untreated.equipment["heater"]["temperature_c"] = 200.0
	untreated.equipment["heater"]["setpoint_c"] = 200.0
	untreated.interact("valve")
	untreated.interact("pump")
	untreated.tick(100.0)
	_expect(is_equal_approx(untreated.equipment["diesel_tank"]["volume_l"], 350.0), "untreated Sour crude preserves the established mass-conserving fraction volume")
	_expect(is_equal_approx(untreated.equipment["diesel_tank"]["sulfur_ppm"], 500.0), "direct Sour diesel retains its high sulfur state")
	_expect(untreated.dispatch_product("light")["ok"] and untreated.dispatch_product("heavy")["ok"], "Sour crude keeps usable Naphtha and heavy-residue deliveries independent of untreated diesel")
	var untreated_sample: Dictionary = untreated.take_diesel_sample("diesel_tank")
	var untreated_lab: Dictionary = untreated.analyze_diesel_sample()
	_expect(untreated_sample["ok"] and not untreated_lab["approved"] and "Dieselbehandling kreves" in untreated_lab["deviation"], "LAB rejects untreated Sour diesel with a clear treatment requirement")
	_expect(not untreated.sell_diesel()["ok"], "untreated Sour diesel cannot bypass LAB approval or dispatch")

	var treated = _treated_model()
	treated.commissioning_batch_available = false
	treated.commissioning_contract_complete = true
	treated.load_crude_batch("source", true, "sour")
	treated.equipment["heater"]["temperature_c"] = 200.0
	treated.equipment["heater"]["setpoint_c"] = 200.0
	treated.interact("valve")
	treated.interact("treatment")
	treated.interact("pump")
	var mass_before := _total_tank_volume(treated)
	treated.tick(100.0)
	_expect(is_equal_approx(_total_tank_volume(treated), mass_before), "active diesel treatment preserves the Sour batch mass balance")
	_expect(is_equal_approx(treated.equipment["diesel_tank"]["sulfur_ppm"], 10.0), "active treatment reduces Sour diesel sulfur to the approved simplified state")
	_expect(is_equal_approx(treated.equipment["treatment"]["processed_total_l"], 350.0), "treatment records exactly the diesel fraction it processes")
	var treated_sample: Dictionary = treated.take_diesel_sample("diesel_tank")
	var treated_lab: Dictionary = treated.analyze_diesel_sample()
	_expect(treated_sample["ok"] and treated_lab["approved"], "treated Sour diesel becomes sample-approved at LAB-101")
	var sale: Dictionary = treated.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 2800 and is_equal_approx(treated.equipment["diesel_tank"]["volume_l"], 0.0), "treated Sour delivery sells once and consumes its authorized inventory")
	var saved: Dictionary = treated.save_state()
	var restored = _treated_model()
	restored.apply_saved_state(saved)
	_expect(restored.equipment["treatment"]["running"] and is_equal_approx(restored.equipment["diesel_tank"]["sulfur_ppm"], 0.0), "treatment operating state and treated inventory quality survive save/load safely")


func _test_mass_conserving_ideal_batch_and_sale() -> void:
	var model = _complete_model()
	model.tick(0.0)
	_expect("kildetanken" in model.last_status, "empty valid route tells the player to load crude first")
	_expect("oppstartsbatch" in model.interaction_prompt("source"), "empty source prompt identifies the free startup action")
	var load_result: Dictionary = model.load_crude_batch("source")
	_expect(load_result["ok"] and load_result["charge"] == 0, "first built batch is an explicit free commissioning batch")
	_expect(not model.can_remove("source")["ok"], "non-empty built tanks cannot be removed for a refund")
	model.tick(0.0)
	_expect("Varm" in model.last_status, "loaded cold route tells the player to heat before pumping")
	_expect("råoljetank" in model.interaction_prompt("source"), "loaded source prompt switches to inspection")
	_expect("NAPHTHA" in model.interaction_prompt("light_tank"), "product-tank prompt identifies its routed fraction")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["heater"]["temperature_c"], 200.0), "built heater reaches the ideal 200 C setpoint")
	model.interact("valve")
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
	var approved_disposal_warning: Dictionary = model.discard_products()
	_expect(approved_disposal_warning.get("requires_confirmation", false) and "Godkjent" in approved_disposal_warning["message"], "approved diesel cannot be destroyed by one accidental key press")
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 2800, "approved built diesel sells for the expected revenue")
	_expect(model.commissioning_contract_complete, "first approved built sale completes the Area 02 contract")
	_expect(sale["contract_completed_now"], "first sale reports that commissioning completed now")
	_expect(is_equal_approx(sale["report"]["crude_processed_l"], 1000.0), "batch report records actual processed crude")
	_expect(is_equal_approx(sale["report"]["light_l"] + sale["report"]["diesel_l"] + sale["report"]["heavy_l"], 1000.0), "reported fractions preserve mass balance")
	_expect(sale["report"]["crude_cost"] == 0 and sale["report"]["net_profit"] == 2800, "free startup report shows exact cost and net result")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 0.0), "sale consumes the diesel inventory")
	_expect(is_equal_approx(model.equipment["light_tank"]["volume_l"], 300.0), "diesel dispatch preserves Naphtha for its own order")
	_expect(is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 350.0), "diesel dispatch preserves heavy residue for its own order")
	_expect(model.dispatch_product("light")["ok"] and model.dispatch_product("heavy")["ok"], "stored Naphtha and heavy residue can be dispatched separately")
	var repeated_sale: Dictionary = model.sell_diesel()
	_expect(not repeated_sale["ok"] and repeated_sale["revenue"] == 0, "diesel cannot be sold repeatedly without new product")
	_expect(model.successful_sales == 3, "repeated diesel sale cannot duplicate the completion count after two product deliveries")
	var paid_load: Dictionary = model.load_crude_batch("source", true)
	model.interact("pump")
	model.tick(100.0)
	_take_and_analyze(model)
	var paid_sale: Dictionary = model.sell_diesel()
	_expect(paid_load["charge"] == 300 and paid_sale["report"]["crude_cost"] == 300, "paid batch report includes the exact crude cost")
	_expect(paid_sale["report"]["net_profit"] == 2500, "paid batch report calculates exact net profit")
	_expect(not paid_sale["contract_completed_now"] and model.successful_sales == 4, "later sales do not recomplete the commissioning contract")


func _test_full_tank_backpressure() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.equipment["diesel_tank"]["volume_l"] = 995.0
	model.equipment["diesel_tank"]["contents"] = "diesel"
	model.equipment["diesel_tank"]["quality_percent"] = 100.0
	model.interact("valve")
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


func _test_topology_change_stops_flow_and_spare_pump() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("valve")
	model.interact("pump")
	model.tick(1.0)
	model.network.disconnect_ports("valve", "output", "heater", "input")
	_expect(not model.equipment["pump"]["running"], "disconnecting a live route stops its pump immediately")
	_expect(is_equal_approx(model.actual_flow_lps, 0.0), "topology change clears actual flow immediately")
	model.register_unit("spare_pump", "pump", "P-299")
	model.network.try_connect("valve", "output", "heater", "input")
	_expect(not model.equipment["pump"]["running"], "reconnecting the valve does not auto-restart the route pump")
	var spare_start: Dictionary = model.interact("spare_pump")
	_expect(not spare_start["ok"], "disconnected spare pump cannot start because another route is valid")


func _test_offspec_recovery() -> void:
	var model = _complete_model()
	model.interact("valve")
	for attempt in range(3):
		var load: Dictionary = model.load_crude_batch("source")
		_expect(load["ok"] and load["charge"] == 0, "pre-commission retry %d remains subsidized after a learning failure" % (attempt + 1))
		model.interact("pump")
		model.tick(100.0)
		_expect(not model.sell_diesel()["ok"], "cold commissioning attempt %d is rejected as off-spec" % (attempt + 1))
		var before_discard := _total_tank_volume(model)
		var warning: Dictionary = model.discard_products()
		_expect(warning.get("requires_confirmation", false), "attempt %d still requires explicit disposal confirmation" % (attempt + 1))
		_expect(is_equal_approx(before_discard, _total_tank_volume(model)), "unconfirmed attempt %d does not mutate inventory" % (attempt + 1))
		var discard: Dictionary = model.discard_products(true)
		_expect(discard["ok"] and is_equal_approx(_total_tank_volume(model), 0.0), "confirmed attempt %d clears products without value creation" % (attempt + 1))
		_expect(not model.commissioning_contract_complete and model.commissioning_batch_available, "failed attempt %d preserves a safe route to another free commissioning batch" % (attempt + 1))
		if attempt == 1:
			var restored_model = _complete_model()
			restored_model.apply_saved_state(model.save_state())
			model = restored_model
			_expect(model.commissioning_batch_available, "commissioning retry survives save/load between failures")

	var final_load: Dictionary = model.load_crude_batch("source")
	_expect(final_load["ok"] and final_load["charge"] == 0, "successful commissioning attempt is still subsidized after repeated failures")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("pump")
	model.tick(100.0)
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and model.commissioning_contract_complete, "first approved retry completes commissioning exactly once")
	model.dispatch_product("light")
	model.dispatch_product("heavy")
	var paid_after_completion: Dictionary = model.load_crude_batch("source", true)
	_expect(paid_after_completion["ok"] and paid_after_completion["charge"] == BuiltRefineryModelScript.CRUDE_BATCH_COST, "subsidy ends permanently after approved commissioning")


func _test_partial_sale_report() -> void:
	var model = _complete_model()
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("valve")
	model.interact("pump")
	model.tick(((BuiltRefineryModelScript.DIESEL_TARGET_L + 0.01) / 0.35) / BuiltRefineryModelScript.PUMP_CAPACITY_LPS)
	var products_while_running: float = model.product_volume_l()
	_expect(not model.sell_diesel()["ok"], "diesel cannot be sold while the process pump is running")
	_expect(not model.discard_products()["ok"] and is_equal_approx(model.product_volume_l(), products_while_running), "products cannot be discarded while the process pump is running")
	model.interact("pump")
	_expect(not model.equipment["pump"]["running"], "running built pump can be stopped manually")
	var source_before_sale: float = model.equipment["source"]["volume_l"]
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 1600, "an early approved sale earns only for the diesel actually produced")
	_expect(absf(sale["report"]["crude_processed_l"] - (200.01 / 0.35)) < 0.1, "partial-batch report uses actual transfer rather than nominal batch size")
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], source_before_sale), "selling products does not erase unprocessed source crude")


func _test_route_scoped_alarm() -> void:
	var model = _complete_model()
	model.register_unit("spare_heater", "heater", "H-299")
	model.equipment["spare_heater"]["temperature_c"] = 230.0
	model.load_crude_batch("source")
	model.interact("heater")
	model.interact("heater")
	model.tick(10.0)
	model.interact("valve")
	model.interact("pump")
	model.tick(1.0)
	_expect("HIGH TEMPERATURE" not in model.alarm_text(), "disconnected hot heater cannot create a false process alarm")


func _test_disconnected_inventory_is_not_sellable() -> void:
	var model = _complete_model()
	model.register_unit("spare_tank", "tank", "T-299")
	model.equipment["spare_tank"]["contents"] = "diesel"
	model.equipment["spare_tank"]["volume_l"] = 350.0
	model.equipment["spare_tank"]["quality_percent"] = 100.0
	_expect(not model.diesel_is_approved(), "diesel readiness ignores disconnected legacy inventory")
	_expect(not model.sell_diesel()["ok"], "disconnected legacy diesel cannot complete the active-route contract")


func _test_standard_contract_regression() -> void:
	var fractions := CrudeCatalogScript.fractions_for_temperature("standard", 200.0)
	_expect(fractions.is_equal_approx(Vector3(0.30, 0.35, 0.35)), "Standard contract preserves the proven 30/35/35 split at 200 C")
	_expect(is_equal_approx(fractions.x + fractions.y + fractions.z, 1.0), "Standard fractions conserve the complete input")
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	var load: Dictionary = model.load_crude_batch("source", true, "standard")
	_expect(load["ok"] and load["charge"] == 300 and model.active_contract_id == "standard", "paid Standard load locks the correct 300 kr contract")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	_expect(is_equal_approx(model.equipment["light_tank"]["volume_l"], 300.0) and is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 350.0) and is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 350.0), "paid Standard batch keeps the established 300/350/350 L output")
	_take_and_analyze(model)
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["report"]["product_revenue"] == 2800 and sale["report"]["delivery_bonus"] == 0, "Standard sale keeps the established 2 800 kr product revenue without a bonus")
	_expect(sale["report"]["crude_cost"] == 300 and sale["report"]["net_profit"] == 2500, "Standard report preserves exact paid-batch economics")


func _test_heavy_contract_temperature_tradeoff() -> void:
	var ideal_fractions := CrudeCatalogScript.fractions_for_temperature("heavy", 230.0)
	_expect(ideal_fractions.is_equal_approx(Vector3(0.15, 0.22, 0.63)), "Heavy crude has a distinct 15/22/63 split at its 230 C target")
	_expect(is_equal_approx(ideal_fractions.x + ideal_fractions.y + ideal_fractions.z, 1.0), "Heavy fractions conserve the complete input")
	var ideal = _complete_model()
	ideal.commissioning_batch_available = false
	ideal.commissioning_contract_complete = true
	var ideal_load: Dictionary = ideal.load_crude_batch("source", true, "heavy")
	_expect(ideal_load["ok"] and ideal_load["charge"] == 180 and ideal.active_contract_bonus_available, "Heavy delivery costs 180 kr and arms one delivery bonus")
	var no_process_sale: Dictionary = ideal.sell_diesel()
	_expect(not no_process_sale["ok"] and "Ingen diesel" in no_process_sale["message"] and ideal.active_contract_bonus_available, "unprocessed paid contract reports missing diesel without consuming its bonus")
	ideal.equipment["heater"]["temperature_c"] = 240.0
	ideal.tick(0.0)
	_expect("Senk" in ideal.last_status and "senk" in ideal.objective_text() and "HIGH TEMPERATURE" in ideal.alarm_text(), "overheated Heavy feed gives one consistent cool-down instruction")
	ideal.equipment["heater"]["temperature_c"] = 230.0
	ideal.equipment["heater"]["setpoint_c"] = 230.0
	ideal.interact("valve")
	ideal.interact("pump")
	ideal.tick(100.0)
	_expect(is_equal_approx(_total_tank_volume(ideal), 1000.0), "ideal Heavy processing conserves the full 1 000 L batch")
	_expect(is_equal_approx(ideal.equipment["light_tank"]["volume_l"], 150.0) and is_equal_approx(ideal.equipment["diesel_tank"]["volume_l"], 220.0) and is_equal_approx(ideal.equipment["heavy_tank"]["volume_l"], 630.0), "ideal Heavy processing produces the declared 150/220/630 L outputs")
	_expect(ideal.diesel_is_approved() and "HIGH TEMPERATURE" not in ideal.alarm_text(), "Heavy diesel is approved at 230 C without a false high-temperature alarm")
	_take_and_analyze(ideal)
	var ideal_sale: Dictionary = ideal.sell_diesel()
	_expect(ideal_sale["ok"] and ideal_sale["report"]["product_revenue"] == 1760 and ideal_sale["report"]["delivery_bonus"] == 1000 and ideal_sale["revenue"] == 2760, "first approved Heavy delivery pays exact product revenue plus its one-time bonus")
	_expect(ideal_sale["report"]["crude_cost"] == 180 and ideal_sale["report"]["net_profit"] == 2580, "Heavy report calculates exact cost and net profit")
	var repeated: Dictionary = ideal.sell_diesel()
	_expect(not repeated["ok"] and repeated["revenue"] == 0 and not ideal.active_contract_bonus_available, "Heavy product and bonus cannot be sold repeatedly")

	var cold = _complete_model()
	cold.commissioning_batch_available = false
	cold.commissioning_contract_complete = true
	cold.load_crude_batch("source", true, "heavy")
	cold.equipment["heater"]["temperature_c"] = 200.0
	cold.equipment["heater"]["setpoint_c"] = 200.0
	cold.interact("valve")
	cold.interact("pump")
	cold.tick(100.0)
	_expect(is_equal_approx(cold.equipment["diesel_tank"]["volume_l"], 180.0) and is_equal_approx(cold.equipment["diesel_tank"]["quality_percent"], 64.0), "Heavy crude run at the Standard setting yields only 180 L diesel at 64 percent quality")
	var cold_sample: Dictionary = cold.take_diesel_sample("diesel_tank")
	var cold_analysis: Dictionary = cold.analyze_diesel_sample()
	_expect(cold_sample["ok"] and cold_analysis["status"] == "OFF-SPEC" and "Råoljetanken er tom" in cold_analysis["deviation"] and not cold_analysis["approved"], "completed Heavy off-spec result never asks for impossible further production")
	var rejected: Dictionary = cold.sell_diesel()
	_expect(not rejected["ok"] and rejected["revenue"] == 0 and cold.active_contract_bonus_available, "off-spec Heavy product earns no money and cannot consume its pending contract state")


func _test_contract_lifecycle_and_bonus_lock() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.register_unit("hidden_tank", "tank", "T-299")
	model.equipment["hidden_tank"]["contents"] = "crude"
	model.equipment["hidden_tank"]["volume_l"] = 1.0
	_expect(not model.can_choose_contract("source")["ok"] and not model.load_crude_batch("source", true, "heavy")["ok"], "disconnected material blocks a new contract instead of bypassing provenance")
	model.equipment["hidden_tank"]["contents"] = "empty"
	model.equipment["hidden_tank"]["volume_l"] = 0.0
	_expect(model.can_choose_contract("source")["ok"], "a stopped and fully empty refinery may choose a new contract")
	model.load_crude_batch("source", true, "heavy")
	var state_after_load: Dictionary = model.save_state()
	_expect(not model.load_crude_batch("source", true, "standard")["ok"] and model.save_state() == state_after_load, "loaded Heavy provenance cannot be replaced by a second contract")
	model.equipment["heater"]["temperature_c"] = 230.0
	model.equipment["heater"]["setpoint_c"] = 230.0
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	_expect(not model.can_choose_contract("source")["ok"], "stored Heavy products block contract switching after source depletion")
	_take_and_analyze(model)
	model.sell_diesel()
	model.dispatch_product("light")
	_expect(model.can_choose_contract("source")["ok"] and model.active_contract_id.is_empty(), "successful dispatch clears the finished contract and enables the next choice")


func _test_control_station_telemetry_and_temperature_guard() -> void:
	var model = _complete_model()
	var locked_snapshot: Dictionary = model.control_snapshot()
	_expect(not locked_snapshot["unlocked"] and not model.remote_toggle_route_pump()["ok"] and not model.remote_cycle_route_heater()["ok"], "LS-201 telemetry and remote commands stay locked before manual commissioning")
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "standard")
	var initial: Dictionary = model.control_snapshot()
	_expect(initial["valid"] and is_equal_approx(initial["source_volume_l"], 1000.0) and is_equal_approx(initial["source_level_percent"], 100.0), "LS-201 source level is derived exactly from the active route tank")
	_expect(not initial["pump_running"] and not initial["valve_open"] and is_equal_approx(initial["actual_flow_lps"], 0.0), "LS-201 distinguishes pump command, manual valve and actual flow")
	var mass_before_blocked_start := _total_tank_volume(model)
	var cold_start: Dictionary = model.remote_toggle_route_pump()
	_expect(not cold_start["ok"] and "START SPERRET" in cold_start["message"] and not model.equipment["pump"]["running"], "temperature guard blocks a cold remote pump start without changing command state")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_blocked_start), "blocked remote start cannot move or create material")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	_expect(model.remote_toggle_route_pump()["ok"], "safe remote pump start uses the active route pump")
	model.tick(1.0)
	var low_flow: Dictionary = model.control_snapshot()
	_expect(low_flow["pump_running"] and is_equal_approx(low_flow["actual_flow_lps"], 0.0) and "LOW FLOW" in low_flow["alarm"], "remote start cannot bypass the closed manual valve or its LOW FLOW lesson")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_blocked_start), "remote LOW FLOW leaves every tank volume unchanged")
	model.interact("valve")
	model.tick(1.0)
	var flowing: Dictionary = model.control_snapshot()
	_expect(is_equal_approx(flowing["source_volume_l"], 990.0) and is_equal_approx(flowing["actual_flow_lps"], 10.0), "live LS-201 telemetry follows actual source loss and flow")
	_expect(is_equal_approx(flowing["light_volume_l"], 3.0) and is_equal_approx(flowing["diesel_volume_l"], 3.5) and is_equal_approx(flowing["heavy_volume_l"], 3.5), "live product instruments match the exact mass-conserving split")
	_expect(model.remote_toggle_route_pump()["ok"] and not model.equipment["pump"]["running"] and is_equal_approx(model.actual_flow_lps, 0.0), "remote stop clears commanded and actual flow immediately")
	model.register_unit("spare_heater_control", "heater", "H-299")
	var spare_target: float = model.equipment["spare_heater_control"]["setpoint_c"]
	var route_target_before: float = model.equipment["heater"]["setpoint_c"]
	_expect(model.remote_cycle_route_heater()["ok"] and model.equipment["heater"]["setpoint_c"] != route_target_before and is_equal_approx(model.equipment["spare_heater_control"]["setpoint_c"], spare_target), "remote heater control affects only the active route heater")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.remote_toggle_route_pump()
	var mass_before_trip := _total_tank_volume(model)
	model.equipment["heater"]["temperature_c"] = 220.0
	model.equipment["heater"]["setpoint_c"] = 220.0
	model.tick(1.0)
	var tripped: Dictionary = model.control_snapshot()
	_expect(not tripped["pump_running"] and "PUMPE STOPPET AV TEMPERATURVERN" in tripped["temperature_trip_message"], "remote temperature guard trips the pump before unsafe processing")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_trip), "temperature trip occurs before another material transfer")
	model.network.disconnect_ports("valve", "output", "heater", "input")
	var invalid_snapshot: Dictionary = model.control_snapshot()
	_expect(not invalid_snapshot["valid"] and not model.remote_toggle_route_pump()["ok"], "invalid topology disables LS-201 control with the graph's readable error")


func _test_paid_batch_lab_sampling() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "standard")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.interact("pump")
	model.tick(20.0)
	_expect(not model.take_diesel_sample("diesel_tank")["ok"], "diesel sampling is blocked while any process pump is running")
	model.interact("pump")
	model.register_unit("spare_sample_tank", "tank", "T-299")
	model.equipment["spare_sample_tank"]["contents"] = "diesel"
	model.equipment["spare_sample_tank"]["volume_l"] = 500.0
	model.equipment["spare_sample_tank"]["quality_percent"] = 42.0
	_expect(not model.take_diesel_sample("spare_sample_tank")["ok"], "disconnected diesel cannot be sampled for the active contract")
	var sample: Dictionary = model.take_diesel_sample("diesel_tank")
	_expect(sample["ok"] and sample["sample_id"] == "P-001", "stopped active-route diesel tank produces a numbered physical sample")
	_expect("IKKE ANALYSERT" in model.summary_text() and "PRØVE KREVES" in model.unit_status("diesel_tank"), "exact paid-batch quality remains hidden before laboratory analysis")
	_expect(not model.sell_diesel()["ok"] and "Analyser" in model.sell_diesel()["message"], "a current but unanalyzed sample cannot authorize dispatch")
	var early_analysis: Dictionary = model.analyze_diesel_sample()
	_expect(early_analysis["ok"] and early_analysis["status"] == "IKKE KLAR" and not early_analysis["approved"], "lab analysis reports the exact missing-volume condition without dispatch")
	_expect("100.0 % — GODKJENT" in model.summary_text() and "ikke klar" in model.objective_text(), "analyzed sample keeps good diesel quality separate from the incomplete order")
	_expect("42.0 %" not in model.unit_status("spare_sample_tank") and "42.0 %" not in model.inspect_unit("spare_sample_tank"), "active-route analysis never reveals disconnected diesel quality")
	var inventory_before_failed_sale: float = model.product_volume_l()
	_expect(not model.sell_diesel()["ok"] and is_equal_approx(model.product_volume_l(), inventory_before_failed_sale), "failed analyzed sample consumes no product or contract value")
	model.equipment["spare_sample_tank"]["contents"] = "empty"
	model.equipment["spare_sample_tank"]["volume_l"] = 0.0
	model.equipment["spare_sample_tank"]["quality_percent"] = 0.0

	model.interact("pump")
	model.tick(1.0)
	model.interact("pump")
	var stale: Dictionary = model.lab_dispatch_status()
	_expect(not stale["sample_current"] and "utdatert" in stale["message"], "new production invalidates the old sample through the inventory revision")
	_expect(not model.sell_diesel()["ok"], "stale sample cannot authorize sale after inventory changes")
	var replacement_sample: Dictionary = model.take_diesel_sample("diesel_tank")
	_expect(replacement_sample["ok"] and replacement_sample["sample_id"] == "P-002", "player can always replace a stale sample without a softlock")
	model.network.disconnect_ports("valve", "output", "heater", "input")
	_expect(not model.analyze_diesel_sample()["ok"], "topology changes invalidate a carried sample before analysis")
	model.network.try_connect("valve", "output", "heater", "input")
	model.take_diesel_sample("diesel_tank")
	model.analyze_diesel_sample()
	var saved_state: Dictionary = model.save_state()
	var restored = _complete_model()
	restored.apply_saved_state(saved_state)
	_expect(not restored.lab_dispatch_status()["sample_current"], "save/load preserves product but never restores transient lab authorization")

	model.interact("pump")
	model.tick(100.0)
	var final_sample: Dictionary = model.take_diesel_sample("diesel_tank")
	var final_analysis: Dictionary = model.analyze_diesel_sample()
	_expect(final_sample["ok"] and final_analysis["approved"] and final_analysis["revenue_preview"] == 2800, "complete Standard batch produces a current approved analysis with exact revenue preview")
	model.interact("valve")
	model.interact("pump")
	var running_status: Dictionary = model.lab_dispatch_status()
	_expect(running_status["approved"] and not running_status["dispatch_ready"] and not model.diesel_is_dispatch_ready(), "analyzed batch cannot advertise dispatch while a closed-valve pump is commanded on")
	_expect(not model.analyze_diesel_sample()["ok"], "LAB refuses analysis while any pump is running, even at zero actual flow")
	model.interact("pump")
	_expect(model.diesel_is_dispatch_ready(), "stopping the pump restores dispatch readiness without invalidating unchanged product")
	var successful_sale: Dictionary = model.sell_diesel()
	_expect(successful_sale["ok"] and successful_sale["revenue"] == 2800 and is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 0.0), "approved current sample dispatches only its authorized diesel inventory")
	_expect(not model.sell_diesel()["ok"] and model.successful_sales == 1, "consumed sample and inventory cannot be dispatched twice")


func _test_product_specific_dispatch() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "standard")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	var orders: Array[Dictionary] = model.available_product_orders()
	_expect(orders.size() == 2 and orders[0]["product_name"] == "Naphtha" and orders[1]["product_name"] == "Tung rest", "product orders expose clear Naphtha and heavy-residue identities")
	var wrong_product: Dictionary = model.dispatch_product("diesel")
	_expect(not wrong_product["ok"], "diesel cannot bypass its LAB-controlled delivery path")
	var light_sale: Dictionary = model.dispatch_product("light")
	_expect(light_sale["ok"] and light_sale["revenue"] == 1500 and is_equal_approx(model.equipment["light_tank"]["volume_l"], 0.0), "Naphtha dispatch consumes only Naphtha and pays its distinct value")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 350.0) and is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 350.0), "Naphtha delivery cannot consume diesel or heavy residue")
	var repeat_light: Dictionary = model.dispatch_product("light")
	_expect(not repeat_light["ok"] and repeat_light["revenue"] == 0, "empty Naphtha tank cannot be paid repeatedly")
	var heavy_sale: Dictionary = model.dispatch_product("heavy")
	_expect(heavy_sale["ok"] and heavy_sale["revenue"] == 700 and is_equal_approx(model.equipment["heavy_tank"]["volume_l"], 0.0), "heavy-residue delivery consumes inventory and pays its lower value")


func _test_independent_process_trains() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	_add_second_complete_route(model)
	_expect(model.network.find_complete_routes().size() == 2 and model.network.validate_configuration()["valid"], "two disconnected complete process trains are accepted")
	_expect(model.load_crude_batch("source", true, "standard")["ok"] and model.load_crude_batch("b_source", true, "sour")["ok"], "each train can load its own crude contract")
	for heater_id in ["heater", "b_heater"]:
		model.equipment[heater_id]["temperature_c"] = 200.0
		model.equipment[heater_id]["setpoint_c"] = 200.0
	for valve_id in ["valve", "b_valve"]:
		model.interact(valve_id)
	_expect(model.interact("b_treatment")["ok"], "Sour Train B treatment can be started independently")
	_expect(model.interact("pump")["ok"] and model.interact("b_pump")["ok"], "both train pumps can start independently")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 900.0) and is_equal_approx(model.equipment["b_source"]["volume_l"], 900.0), "simultaneous trains consume only their own source tanks")
	_expect(is_equal_approx(model.equipment["light_tank"]["volume_l"], 30.0) and is_equal_approx(model.equipment["b_light"]["volume_l"], 30.0), "each train fills its own Naphtha tank")
	_expect(is_equal_approx(model.equipment["diesel_tank"]["sulfur_ppm"], 10.0) and is_equal_approx(model.equipment["b_diesel"]["sulfur_ppm"], 10.0), "Sour treatment affects only Train B while Standard diesel remains independent")
	model.equipment["light_tank"]["volume_l"] = 1000.0
	model.equipment["light_tank"]["contents"] = "light"
	model.tick(1.0)
	_expect(is_equal_approx(model.equipment["pump"]["actual_flow_lps"], 0.0) and model.equipment["b_pump"]["actual_flow_lps"] > 0.01, "a full Train A product tank blocks only Train A")
	var active_flows: Dictionary = model.active_connection_keys()
	_expect(not active_flows.has("source:output>pump:input") and active_flows.has("b_source:output>b_pump:input") and is_equal_approx(float(active_flows["b_source:output>b_pump:input"]), float(model.equipment["b_pump"]["actual_flow_lps"]) / BuiltRefineryModelScript.PUMP_MAX_FLOW_LPS), "visual flow keys and intensity stay local to the moving Train B when Train A is blocked")
	model.equipment["pump"]["flow_setpoint_lps"] = 15.0
	model.equipment["light_tank"]["volume_l"] = 0.0
	model.equipment["light_tank"]["contents"] = "empty"
	model.tick(20.0)
	_expect(not String(model.equipment["pump"]["fault_id"]).is_empty() and String(model.equipment["b_pump"]["fault_id"]).is_empty(), "pump-filter restriction remains attached to the train that created it")


func _test_automatic_heater_control() -> void:
	var locked = _complete_model()
	locked.equipment["heater"]["setpoint_c"] = 200.0
	_expect(not locked.toggle_heater_auto("heater")["ok"], "temperature AUTO remains earned until Area 02 commissioning is complete")

	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.equipment["heater"]["temperature_c"] = 100.0
	_expect(model.toggle_heater_auto("heater")["ok"] and model.equipment["heater"]["control_mode"] == "auto", "manual heater transfers into TIC-201 AUTO without replacing the heater state")
	var output_before: float = model.equipment["heater"]["output_percent"]
	model.tick(1.0)
	_expect(model.equipment["heater"]["output_percent"] > output_before, "AUTO raises heater output when PV is below SP")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.tick(1.0)
	var near_output: float = model.equipment["heater"]["output_percent"]
	_expect(absf(near_output - 78.26) < 3.0, "AUTO settles near the output needed to hold the 200 C setpoint")
	model.equipment["heater"]["temperature_c"] = 225.0
	model.tick(1.0)
	_expect(model.equipment["heater"]["output_percent"] < near_output, "AUTO reduces heater output when PV rises above SP")
	_expect(model.toggle_heater_auto("heater")["ok"] and model.equipment["heater"]["control_mode"] == "manual", "AUTO returns deterministically to manual control while preserving its current output")

	model.equipment["heater"]["setpoint_c"] = 200.0
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["valve"]["open"] = false
	model.equipment["pump"]["running"] = true
	model.toggle_heater_auto("heater")
	model.tick(1.0)
	_expect(model.equipment["heater"]["auto_blocked"] and is_equal_approx(model.equipment["heater"]["output_percent"], 0.0), "closed-valve LOW FLOW safety blocks AUTO heater output without restarting or moving material")

	var multi = _complete_model()
	multi.commissioning_batch_available = false
	multi.commissioning_contract_complete = true
	_add_second_complete_route(multi)
	multi.equipment["heater"]["setpoint_c"] = 200.0
	multi.equipment["b_heater"]["setpoint_c"] = 230.0
	multi.equipment["heater"]["temperature_c"] = 190.0
	multi.equipment["b_heater"]["temperature_c"] = 190.0
	multi.toggle_heater_auto("heater")
	multi.toggle_heater_auto("b_heater")
	multi.tick(1.0)
	_expect(multi.equipment["heater"]["output_percent"] != multi.equipment["b_heater"]["output_percent"], "independent trains keep separate TIC-201 setpoints and outputs")
	var saved: Dictionary = multi.save_state()
	var restored = _complete_model()
	_add_second_complete_route(restored)
	restored.apply_saved_state(saved)
	_expect(restored.equipment["heater"]["control_mode"] == "auto" and restored.equipment["b_heater"]["control_mode"] == "auto" and is_equal_approx(restored.equipment["b_heater"]["setpoint_c"], 230.0), "AUTO mode, setpoint and heater ownership survive save/load by stable equipment ID")

	var quality_model = _complete_model()
	quality_model.commissioning_batch_available = false
	quality_model.commissioning_contract_complete = true
	quality_model.load_crude_batch("source", true, "standard")
	quality_model.equipment["heater"]["setpoint_c"] = 200.0
	quality_model.equipment["heater"]["temperature_c"] = 200.0
	quality_model.toggle_heater_auto("heater")
	quality_model.interact("valve")
	quality_model.interact("pump")
	quality_model.tick(10.0)
	_expect(is_equal_approx(quality_model.equipment["diesel_tank"]["quality_percent"], 100.0), "AUTO uses the existing temperature-quality rules without an artificial quality bonus")


func _test_operator_alarm_lifecycle_and_isolation() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "standard")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.equipment["pump"]["running"] = true
	model.tick(1.0)
	var blocked_alarms: Array[Dictionary] = model.operator_alarms()
	_expect(_has_operator_alarm(blocked_alarms, "low_flow", "pump") and not ("filter" in model.alarm_text().to_lower()), "closed valve creates a symptom-only LOW FLOW operator alarm")
	model.toggle_heater_auto("heater")
	model.tick(1.0)
	_expect("HEAT PERMISSIVE: BLOCKED" in model.inspect_unit("heater"), "heater inspection exposes the LOW FLOW safety interlock without a second alarm")
	model.interact("valve")
	model.tick(1.0)
	_expect(not _has_operator_alarm(model.operator_alarms(), "low_flow", "pump"), "restored valve flow clears the derived LOW FLOW alarm")
	model.equipment["heater"]["temperature_c"] = 240.0
	_expect(_has_operator_alarm(model.operator_alarms(), "high_temperature", "heater"), "excess process temperature raises a high-priority heater alarm")
	model.equipment["diesel_tank"]["contents"] = "diesel"
	model.equipment["diesel_tank"]["volume_l"] = 900.0
	_expect(_has_operator_alarm(model.operator_alarms(), "high_level", "diesel_tank"), "a routed product tank warns at high level before it is full")
	model.equipment["diesel_tank"]["volume_l"] = 1000.0
	_expect(_has_operator_alarm(model.operator_alarms(), "tank_full", "diesel_tank"), "a routed full product tank raises a tank-full operator alarm")
	var restored = _complete_model()
	restored.apply_saved_state(model.save_state())
	_expect(_has_operator_alarm(restored.operator_alarms(), "tank_full", "diesel_tank"), "saved physical tank state reconstructs alarms without stale alarm storage")

	var multi = _complete_model()
	multi.commissioning_batch_available = false
	multi.commissioning_contract_complete = true
	_add_second_complete_route(multi)
	for source_id in ["source", "b_source"]:
		multi.equipment[source_id]["contents"] = "crude"
		multi.equipment[source_id]["volume_l"] = 100.0
		multi.equipment[source_id]["contract_id"] = "standard"
	for heater_id in ["heater", "b_heater"]:
		multi.equipment[heater_id]["temperature_c"] = 200.0
		multi.equipment[heater_id]["setpoint_c"] = 200.0
	for valve_id in ["valve", "b_valve"]:
		multi.equipment[valve_id]["open"] = true
	for pump_id in ["pump", "b_pump"]:
		multi.equipment[pump_id]["running"] = true
	multi.equipment["b_treatment"]["running"] = true
	multi.equipment["b_pump"]["fault_id"] = "blocked_filter"
	multi.tick(1.0)
	var multi_alarms: Array[Dictionary] = multi.operator_alarms()
	_expect(_has_operator_alarm(multi_alarms, "low_flow", "b_pump") and not _has_operator_alarm(multi_alarms, "low_flow", "pump"), "a restricted Train B pump raises only its own LOW FLOW alarm")
	var overview: Dictionary = multi.operations_snapshot()
	_expect(overview["trains"].size() == 2 and overview["trains"][0]["pump_id"] != overview["trains"][1]["pump_id"], "operations snapshot discovers stable independent refinery trains")
	var a_target: float = multi.equipment["heater"]["setpoint_c"]
	_expect(multi.remote_cycle_heater("b_pump")["ok"] and multi.equipment["b_heater"]["setpoint_c"] != 200.0 and is_equal_approx(multi.equipment["heater"]["setpoint_c"], a_target), "selected remote TIC command changes only its own train heater")
	_expect(multi.remote_cycle_pump_flow("b_pump")["ok"] and not is_equal_approx(multi.equipment["b_pump"]["flow_setpoint_lps"], multi.equipment["pump"]["flow_setpoint_lps"]), "selected remote flow command stays isolated to its train pump")


func _has_operator_alarm(alarms: Array[Dictionary], alarm_id: String, equipment_id: String) -> bool:
	for alarm in alarms:
		if alarm["id"] == alarm_id and alarm["equipment_id"] == equipment_id:
			return true
	return false


func _add_second_complete_route(model) -> void:
	for entry in [
		["b_source", "tank", "B-T1"], ["b_pump", "pump", "B-P1"], ["b_valve", "valve", "B-V1"], ["b_heater", "heater", "B-H1"], ["b_column", "column", "B-D1"], ["b_treatment", "treatment", "B-HT1"], ["b_light", "tank", "B-T2"], ["b_diesel", "tank", "B-T3"], ["b_heavy", "tank", "B-T4"],
	]:
		model.register_unit(entry[0], entry[1], entry[2])
	model.network.try_connect("b_source", "output", "b_pump", "input")
	model.network.try_connect("b_pump", "output", "b_valve", "input")
	model.network.try_connect("b_valve", "output", "b_heater", "input")
	model.network.try_connect("b_heater", "output", "b_column", "input")
	model.network.try_connect("b_column", "light", "b_light", "input")
	model.network.try_connect("b_column", "diesel", "b_treatment", "input")
	model.network.try_connect("b_treatment", "output", "b_diesel", "input")
	model.network.try_connect("b_column", "heavy", "b_heavy", "input")


func _add_shared_header_route(model) -> void:
	_add_second_complete_route(model)
	model.register_unit("header", "header", "FH-201")
	model.network.disconnect_ports("source", "output", "pump", "input")
	model.network.disconnect_ports("b_source", "output", "b_pump", "input")
	model.network.try_connect("source", "output", "header", "input")
	model.network.try_connect("header", "out_a", "pump", "input")
	model.network.try_connect("header", "out_b", "b_pump", "input")


func _test_ambiguous_routes_block_operation_atomically() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	_add_malformed_second_route(model, "b")
	var validation: Dictionary = model.network.validate_configuration()
	_expect(not validation["valid"] and validation["route"].is_empty(), "two complete built routes expose no arbitrary active route")
	var entitlement_before: bool = model.commissioning_batch_available
	var load_a: Dictionary = model.load_crude_batch("source", true, "standard")
	var load_b: Dictionary = model.load_crude_batch("b_source", true, "standard")
	_expect(not load_a["ok"] and not load_b["ok"] and load_a.get("charge", 0) == 0 and load_b.get("charge", 0) == 0, "ambiguous source loading is rejected without charging either line")
	_expect(model.commissioning_batch_available == entitlement_before and is_equal_approx(_total_tank_volume(model), 0.0), "ambiguous loading preserves entitlement and creates no material")
	_expect(not model.interact("pump")["ok"] and not model.interact("b_pump")["ok"], "neither ambiguous pump can be started")
	model.equipment["source"]["contents"] = "crude"
	model.equipment["source"]["volume_l"] = 100.0
	model.equipment["pump"]["running"] = true
	model.equipment["b_pump"]["running"] = true
	var mass_before_tick := _total_tank_volume(model)
	model.tick(1.0)
	_expect(not model.equipment["pump"]["running"] and not model.equipment["b_pump"]["running"] and is_equal_approx(model.actual_flow_lps, 0.0), "ambiguous tick stops all pump commands and reports zero flow")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before_tick), "ambiguous tick cannot consume or duplicate material")
	_expect(model.active_connection_keys().is_empty() and not model.diesel_is_approved(), "ambiguous route exposes no active pipe visuals or diesel readiness")
	_expect("FLERE LINJER" in model.summary_text() and "koble fra" in model.objective_text(), "HUD explains how to recover from an ambiguous imported topology")
	var station: Dictionary = model.control_snapshot()
	_expect(not station["valid"] and station.get("ambiguous_routes", false) and not model.remote_toggle_route_pump()["ok"], "LS-201 identifies ambiguity and blocks remote commands")
	_expect(not model.take_diesel_sample("diesel_tank")["ok"] and not model.sell_diesel()["ok"], "ambiguous topology cannot authorize sampling or product dispatch")
	model.network.disconnect_ports("b_column", "heavy", "b_heavy", "input")
	_expect(model.network.validate_configuration()["valid"] and model.network.find_complete_route()["source"] == "source", "disconnecting the spare route restores the original built line")


func _test_distinct_delivery_order_definitions() -> void:
	var standard := CrudeCatalogScript.definition("standard")
	var heavy := CrudeCatalogScript.definition("heavy")
	_expect(standard["delivery_product"] == "diesel" and is_equal_approx(standard["delivery_target_l"], 200.0), "Standard remains a 200 L diesel delivery order")
	_expect(heavy["delivery_product"] == "heavy" and is_equal_approx(heavy["delivery_target_l"], 600.0), "Heavy is a distinct 600 L heavy-fraction delivery order")
	_expect(standard["order_name"] != heavy["order_name"] and heavy["delivery_bonus"] == 1000, "delivery packages have distinct player names and preserve the Heavy reward")


func _test_heavy_delivery_order_volume_gate() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.load_crude_batch("source", true, "heavy")
	model.equipment["heater"]["temperature_c"] = 230.0
	model.equipment["heater"]["setpoint_c"] = 230.0
	model.interact("valve")
	model.interact("pump")
	model.tick(91.0)
	model.interact("pump")
	model.take_diesel_sample("diesel_tank")
	var early: Dictionary = model.analyze_diesel_sample()
	_expect(early["quality_ready"] and early["sample_volume_ready"] and not early["delivery_ready"], "Heavy diesel QC may pass before its heavy-fraction order volume")
	_expect(not early["approved"] and early["status"] == "IKKE KLAR" and "tung fraksjon" in early["deviation"], "Heavy analysis explains the missing ordered fraction instead of dispatching on the old diesel gate")
	_expect("100.0 % — GODKJENT" in model.summary_text() and "tøm" not in model.objective_text(), "good Heavy diesel remains good while recoverable order guidance avoids destructive disposal")
	var inventory_before_rejection: float = model.product_volume_l()
	_expect(not model.sell_diesel()["ok"] and is_equal_approx(model.product_volume_l(), inventory_before_rejection) and model.active_contract_bonus_available, "incomplete Heavy order mutates no product or bonus")
	model.interact("pump")
	model.tick(5.0)
	model.interact("pump")
	_expect(not model.lab_dispatch_status()["sample_current"], "new production invalidates the early order analysis")
	model.take_diesel_sample("diesel_tank")
	var approved: Dictionary = model.analyze_diesel_sample()
	_expect(approved["approved"] and is_equal_approx(approved["delivery_volume_l"], 604.8) and approved["revenue_preview"] == 2690, "fresh Heavy sample approves 604.8 L ordered product with exact dispatch value")
	var sale: Dictionary = model.sell_diesel()
	_expect(sale["ok"] and sale["revenue"] == 2690 and sale["report"]["delivery_product"] == "heavy" and is_equal_approx(sale["report"]["delivery_volume_l"], 604.8), "Heavy delivery report records the actual ordered fraction and pays once")
	_expect(sale["report"]["product_revenue"] == 1690 and sale["report"]["delivery_bonus"] == 1000 and sale["report"]["crude_cost"] == 173 and sale["report"]["net_profit"] == 2517, "partial Heavy order preserves exact base, bonus, proportional cost and net result")
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], 40.0) and not model.sell_diesel()["ok"] and not model.active_contract_bonus_available, "dispatch preserves unprocessed crude and cannot repeat its order bonus")


func _test_off_route_product_blocks_dispatch() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	model.register_unit("legacy_product", "tank", "T-299")
	model.load_crude_batch("source", true, "standard")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	model.interact("pump")
	model.tick(100.0)
	model.equipment["legacy_product"]["contents"] = "heavy"
	model.equipment["legacy_product"]["volume_l"] = 100.0
	model.take_diesel_sample("diesel_tank")
	var analysis: Dictionary = model.analyze_diesel_sample()
	_expect(not analysis["approved"] and "frakoblet produkt" in analysis["deviation"], "LAB identifies disconnected product before an active order can be dispatched")
	var active_before: float = model.product_volume_l()
	var revision_before: int = model.product_inventory_revision
	var sale: Dictionary = model.sell_diesel()
	_expect(not sale["ok"] and is_equal_approx(model.product_volume_l(), active_before) and model.product_inventory_revision == revision_before, "blocked dispatch clears neither active nor disconnected product")
	_expect(is_equal_approx(model.equipment["legacy_product"]["volume_l"], 100.0) and model.successful_sales == 0, "disconnected legacy inventory cannot be silently erased or credited")


func _test_product_header_allocation_and_capacity() -> void:
	var model = _complete_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	_add_diesel_product_header(model)
	_expect(model.interact("diesel_header")["ok"], "physical Product Routing Header selects storage A from NONE")
	_expect(model.product_allocations["diesel_header"].selected_tank_id == "diesel_tank", "first header selection owns diesel output A")
	_expect(model.load_crude_batch("source", true, "standard")["ok"], "standard crude can load into a refinery with optional product routing")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.interact("valve")
	_expect(model.interact("pump")["ok"], "selected product storage lets the upstream pump start")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 35.0) and is_equal_approx(model.equipment["diesel_backup"]["volume_l"], 0.0), "only selected diesel tank A receives new production")
	_expect(not model.interact("diesel_header")["ok"], "running process cannot switch product ownership")
	model.interact("pump")
	_expect(model.interact("diesel_header")["ok"] and model.product_allocations["diesel_header"].selected_tank_id == "diesel_backup", "stopped process switches Product Routing Header safely to tank B")
	model.interact("pump")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 35.0) and is_equal_approx(model.equipment["diesel_backup"]["volume_l"], 35.0), "switching product route preserves tank A inventory and sends later diesel only to B")
	_expect(is_equal_approx(_total_tank_volume(model), 1000.0), "product-header routing preserves total material mass")
	model.interact("pump")
	_expect(model.interact("diesel_header")["ok"] and model.product_allocations["diesel_header"].selected_tank_id.is_empty(), "header supports an explicit NONE product route")
	_expect(not model.interact("pump")["ok"], "pump cannot restart while a required product header has no selected storage")
	_expect(model.interact("diesel_header")["ok"] and model.product_allocations["diesel_header"].selected_tank_id == "diesel_tank", "header cycles safely from NONE back to tank A")
	model.unregister_unit("diesel_backup")
	_expect(model.product_allocations["diesel_header"].selected_tank_id == "diesel_tank", "deleting an unselected sibling tank preserves the selected storage route")
	model.unregister_unit("diesel_tank")
	_expect(model.product_allocations["diesel_header"].selected_tank_id.is_empty(), "deleting the selected product tank clears allocation without auto-fallback")

	var capacity_model = _complete_model()
	capacity_model.commissioning_batch_available = false
	capacity_model.commissioning_contract_complete = true
	_add_diesel_product_header(capacity_model)
	capacity_model.interact("diesel_header")
	capacity_model.load_crude_batch("source", true, "standard")
	capacity_model.equipment["heater"]["temperature_c"] = 200.0
	capacity_model.equipment["heater"]["setpoint_c"] = 200.0
	capacity_model.equipment["valve"]["open"] = true
	capacity_model.equipment["diesel_tank"]["contents"] = "diesel"
	capacity_model.equipment["diesel_tank"]["volume_l"] = 1000.0
	var source_before: float = capacity_model.equipment["source"]["volume_l"]
	capacity_model.interact("pump")
	capacity_model.tick(1.0)
	_expect(is_equal_approx(capacity_model.equipment["source"]["volume_l"], source_before), "a full selected tank blocks production without consuming source material or spilling to B")
	capacity_model.interact("pump")
	capacity_model.interact("diesel_header")
	capacity_model.interact("pump")
	capacity_model.tick(1.0)
	_expect(is_equal_approx(capacity_model.equipment["diesel_backup"]["volume_l"], 3.5), "operator-selected backup tank receives diesel after a safe shutdown and route switch")


func _test_product_header_preserves_treated_diesel_and_save_state() -> void:
	var model = _treated_model()
	model.commissioning_batch_available = false
	model.commissioning_contract_complete = true
	_add_diesel_product_header(model, true)
	model.interact("diesel_header")
	model.load_crude_batch("source", true, "sour")
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.equipment["valve"]["open"] = true
	model.interact("treatment")
	model.interact("pump")
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["diesel_tank"]["volume_l"], 35.0) and is_equal_approx(model.equipment["diesel_tank"]["sulfur_ppm"], 10.0), "treated Sour diesel retains treated sulfur state through Product Routing Header A")
	model.interact("pump")
	model.interact("diesel_header")
	var saved: Dictionary = model.save_state()
	var restored = _treated_model()
	_add_diesel_product_header(restored, true)
	restored.apply_saved_state(saved)
	_expect(restored.product_allocations["diesel_header"].selected_tank_id == "diesel_backup", "selected Product Routing Header destination survives save/load")
	_expect(is_equal_approx(restored.equipment["diesel_tank"]["sulfur_ppm"], 10.0) and is_equal_approx(restored.equipment["diesel_tank"]["volume_l"], 35.0), "saved routed diesel preserves volume and treatment quality")


func _test_sparse_future_route_is_ignored_by_atmospheric_consumers() -> void:
	var model = _complete_model()
	model.register_unit("vacuum_source", "tank", "VT-201")
	model.register_unit("vacuum_pump", "pump", "VP-201")
	var vacuum_route := {
		"process_type": model.network.VACUUM_DISTILLATION,
		"route_id": "vacuum:vacuum_pump",
		"source": "vacuum_source",
		"pump": "vacuum_pump",
		"equipment_ids": ["vacuum_source", "vacuum_pump", "vdu"],
	}
	_expect(not model._route_has_feed_access(vacuum_route), "feed allocation refuses a sparse non-atmospheric route")
	_expect(model._operator_alarms_for_route(vacuum_route).is_empty(), "operator alarms ignore a sparse non-atmospheric route without reading atmospheric fields")
	_expect(model._resolved_route(vacuum_route).is_empty(), "atmospheric product routing does not resolve a future route without its own semantics")
	_expect(model.operations_snapshot()["trains"].size() == 1, "LS-201 exposes only the supported atmospheric train set")


func _test_persisted_material_intent() -> void:
	var model = _vacuum_model(0.0)
	_expect(model.equipment["vacuum_source"]["material_intent"] == "heavy" and model.network.tank_intended_material("vacuum_source") == "heavy", "planned Heavy Residue source stores explicit material intent at zero volume")
	var saved: Dictionary = model.save_state()
	var restored = _vacuum_model(0.0)
	restored.apply_saved_state(saved)
	_expect(restored.equipment["vacuum_source"]["material_intent"] == "heavy" and restored.network.filter_routes_by_process_type(restored.network.find_complete_routes(), restored.network.VACUUM_DISTILLATION).size() == 1, "empty planned vacuum source retains intent and discovery after save/load")
	var legacy_saved: Dictionary = _vacuum_model(1.0).save_state()
	for state in legacy_saved["equipment"].values():
		if state["type"] == "tank":
			state.erase("material_intent")
	var legacy_restored = _vacuum_model(0.0)
	legacy_restored.apply_saved_state(legacy_saved)
	_expect(legacy_restored.equipment["vacuum_source"]["material_intent"] == "heavy" and legacy_restored.network.filter_routes_by_process_type(legacy_restored.network.find_complete_routes(), legacy_restored.network.VACUUM_DISTILLATION).is_empty(), "legacy non-empty material is inferred while empty unassigned destinations do not create a vacuum route")
	model.equipment["vacuum_source"]["contents"] = "heavy"
	model.equipment["vacuum_source"]["volume_l"] = 1.0
	_expect(not model.set_tank_material_intent("vacuum_source", "diesel")["ok"], "non-empty tank rejects incompatible material-intent reassignment")
	model.equipment["vacuum_source"]["volume_l"] = 0.0
	model.equipment["vacuum_source"]["contents"] = "empty"
	_expect(model.equipment["vacuum_source"]["material_intent"] == "heavy", "emptying a tank does not erase its planned material intent")


func _test_atomic_vacuum_distillation() -> void:
	var stopped = _vacuum_model(100.0)
	stopped.tick(10.0)
	_expect(is_equal_approx(stopped.equipment["vacuum_source"]["volume_l"], 100.0) and is_equal_approx(stopped.equipment["vgo_tank"]["volume_l"], 0.0), "stopped VDU feed pump consumes and produces nothing")
	stopped.equipment["vacuum_pump"]["running"] = true
	var mass_before := _total_tank_volume(stopped)
	stopped.tick(10.0)
	_expect(is_equal_approx(stopped.equipment["vacuum_source"]["volume_l"], 0.0) and is_equal_approx(stopped.equipment["vgo_tank"]["volume_l"], 60.0) and is_equal_approx(stopped.equipment["vacuum_residue_tank"]["volume_l"], 40.0), "running VDU pump applies the fixed 60/40 VGO and Vacuum Residue split")
	_expect(is_equal_approx(_total_tank_volume(stopped), mass_before) and stopped.equipment["vgo_tank"]["contents"] == "vacuum_gas_oil" and stopped.equipment["vacuum_residue_tank"]["contents"] == "vacuum_residue", "atomic VDU transfer conserves mass and preserves output identities")
	var empty = _vacuum_model(0.0)
	empty.equipment["vacuum_pump"]["running"] = true
	empty.tick(1.0)
	_expect(empty.network.filter_routes_by_process_type(empty.network.find_complete_routes(), empty.network.VACUUM_DISTILLATION).size() == 1 and is_equal_approx(_total_tank_volume(empty), 0.0), "empty planned VDU source remains valid but produces no material")
	var wrong_material = _vacuum_model(10.0)
	wrong_material.equipment["vacuum_source"]["contents"] = "diesel"
	wrong_material.equipment["vacuum_pump"]["running"] = true
	wrong_material.tick(1.0)
	_expect(is_equal_approx(wrong_material.equipment["vacuum_source"]["volume_l"], 10.0) and is_equal_approx(_total_tank_volume(wrong_material), 10.0), "wrong actual VDU feed is rejected defensively without consumption or output")
	var saved: Dictionary = stopped.save_state()
	var restored = _vacuum_model(0.0)
	restored.apply_saved_state(saved)
	_expect(restored.equipment["vgo_tank"]["material_intent"] == "vacuum_gas_oil" and restored.equipment["vacuum_residue_tank"]["material_intent"] == "vacuum_residue" and is_equal_approx(_total_tank_volume(restored), 100.0), "VDU inventories and all material intents survive save/load")


func _test_vacuum_capacity_and_multi_stage_processing() -> void:
	var vgo_limited = _vacuum_model(100.0)
	vgo_limited.equipment["vgo_tank"]["contents"] = "vacuum_gas_oil"
	vgo_limited.equipment["vgo_tank"]["volume_l"] = 970.0
	vgo_limited.equipment["vacuum_pump"]["running"] = true
	var mass_before := _total_tank_volume(vgo_limited)
	vgo_limited.tick(10.0)
	_expect(is_equal_approx(vgo_limited.equipment["vacuum_source"]["volume_l"], 50.0) and is_equal_approx(vgo_limited.equipment["vgo_tank"]["volume_l"], 1000.0) and is_equal_approx(vgo_limited.equipment["vacuum_residue_tank"]["volume_l"], 20.0), "VGO capacity limits the complete atomic VDU transaction to 50 L feed")
	_expect(is_equal_approx(_total_tank_volume(vgo_limited), mass_before), "capacity-limited VDU processing does not lose or duplicate material")
	var residue_limited = _vacuum_model(100.0)
	residue_limited.equipment["vacuum_residue_tank"]["contents"] = "vacuum_residue"
	residue_limited.equipment["vacuum_residue_tank"]["volume_l"] = 980.0
	residue_limited.equipment["vacuum_pump"]["running"] = true
	residue_limited.tick(10.0)
	_expect(is_equal_approx(residue_limited.equipment["vacuum_source"]["volume_l"], 50.0) and is_equal_approx(residue_limited.equipment["vgo_tank"]["volume_l"], 30.0) and is_equal_approx(residue_limited.equipment["vacuum_residue_tank"]["volume_l"], 1000.0), "Vacuum Residue capacity independently limits both proportional outputs")
	var exact_capacity = _vacuum_model(100.0)
	exact_capacity.equipment["vgo_tank"]["contents"] = "vacuum_gas_oil"
	exact_capacity.equipment["vgo_tank"]["volume_l"] = 940.0
	exact_capacity.equipment["vacuum_residue_tank"]["contents"] = "vacuum_residue"
	exact_capacity.equipment["vacuum_residue_tank"]["volume_l"] = 960.0
	exact_capacity.equipment["vacuum_pump"]["running"] = true
	exact_capacity.tick(10.0)
	_expect(is_equal_approx(exact_capacity.equipment["vacuum_source"]["volume_l"], 0.0) and is_equal_approx(exact_capacity.equipment["vgo_tank"]["volume_l"], 1000.0) and is_equal_approx(exact_capacity.equipment["vacuum_residue_tank"]["volume_l"], 1000.0), "exact VDU output capacities fill without overflow or extra source consumption")
	var zero_capacity = _vacuum_model(10.0)
	zero_capacity.equipment["vacuum_residue_tank"]["contents"] = "vacuum_residue"
	zero_capacity.equipment["vacuum_residue_tank"]["volume_l"] = 1000.0
	zero_capacity.equipment["vacuum_pump"]["running"] = true
	zero_capacity.tick(10.0)
	_expect(is_equal_approx(zero_capacity.equipment["vacuum_source"]["volume_l"], 10.0) and is_equal_approx(zero_capacity.equipment["vgo_tank"]["volume_l"], 0.0), "full VDU destination blocks both outputs and leaves feed untouched")
	var tiny_steps = _vacuum_model(1.0)
	tiny_steps.equipment["vacuum_pump"]["flow_setpoint_lps"] = 5.0
	tiny_steps.equipment["vacuum_pump"]["running"] = true
	for step in 20:
		tiny_steps.tick(0.01)
	_expect(is_equal_approx(tiny_steps.equipment["vacuum_source"]["volume_l"], 0.0) and is_equal_approx(tiny_steps.equipment["vgo_tank"]["volume_l"], 0.6) and is_equal_approx(tiny_steps.equipment["vacuum_residue_tank"]["volume_l"], 0.4), "tiny repeated VDU ticks retain the fixed split without rounding drift")
	var staged = _complete_model()
	staged.set_tank_material_intent("heavy_tank", "heavy")
	_add_vacuum_route(staged, "heavy_tank")
	staged.load_crude_batch("source")
	staged.equipment["heater"]["temperature_c"] = 200.0
	staged.equipment["valve"]["open"] = true
	staged.equipment["pump"]["running"] = true
	staged.tick(10.0)
	var heavy_before: float = staged.equipment["heavy_tank"]["volume_l"]
	staged.equipment["vacuum_pump"]["running"] = true
	staged.tick(1.0)
	_expect(heavy_before > 0.001 and is_equal_approx(staged.equipment["source"]["volume_l"], 890.0) and staged.equipment["heavy_tank"]["volume_l"] < heavy_before and is_equal_approx(staged.equipment["vgo_tank"]["volume_l"], 6.0) and is_equal_approx(staged.equipment["vacuum_residue_tank"]["volume_l"], 4.0), "atmospheric Heavy Residue in the same physical tank can feed VDU during simultaneous typed processing without a hidden batch")
	_expect(staged.operations_snapshot()["trains"].size() == 1 and staged.active_connection_keys().size() == 11, "vacuum operation keeps LS-201 atmospheric-only while its running pipes receive flow feedback")
	var blocked_vdu = _complete_model()
	blocked_vdu.set_tank_material_intent("heavy_tank", "heavy")
	_add_vacuum_route(blocked_vdu, "heavy_tank")
	blocked_vdu.load_crude_batch("source")
	blocked_vdu.equipment["heater"]["temperature_c"] = 200.0
	blocked_vdu.equipment["valve"]["open"] = true
	blocked_vdu.equipment["pump"]["running"] = true
	blocked_vdu.equipment["vacuum_pump"]["running"] = true
	blocked_vdu.equipment["vgo_tank"]["contents"] = "vacuum_gas_oil"
	blocked_vdu.equipment["vgo_tank"]["volume_l"] = 1000.0
	blocked_vdu.tick(1.0)
	var blocked_vdu_flows: Dictionary = blocked_vdu.active_connection_keys()
	_expect(blocked_vdu.equipment["pump"]["actual_flow_lps"] > 0.01 and is_equal_approx(blocked_vdu.equipment["vacuum_pump"]["actual_flow_lps"], 0.0) and blocked_vdu_flows.has("source:output>pump:input") and not blocked_vdu_flows.has("heavy_tank:output>vacuum_pump:input"), "a blocked VDU stays visually still while a concurrent atmospheric route moves")


func _test_player_facing_vacuum_operation_and_dispatch() -> void:
	var model = _vacuum_model(1000.0)
	model.commissioning_contract_complete = true
	var start: Dictionary = model.interact("vacuum_pump")
	_expect(start["ok"] and model.equipment["vacuum_pump"]["running"], "a complete player VDU route starts through its ordinary feed-pump interaction")
	model.tick(100.0)
	_expect(model.unit_status("vdu") == "NO FEED" and "60 % Vacuum Gas Oil" in model.inspect_unit("vdu"), "VDU inspection explains its simplified feed, yields and status")
	var orders: Array[Dictionary] = model.available_product_orders()
	_expect(orders.size() == 2 and orders[0]["product"] == "vacuum_gas_oil" and orders[1]["product"] == "vacuum_residue", "VGO and Vacuum Residue appear as distinct physical product deliveries")
	var vgo_sale: Dictionary = model.dispatch_product_from_tank("vgo_tank")
	var residue_sale: Dictionary = model.dispatch_product_from_tank("vacuum_residue_tank")
	_expect(vgo_sale["ok"] and vgo_sale["revenue"] == 2400 and residue_sale["ok"] and residue_sale["revenue"] == 400, "VDU products dispatch once from their own tanks at the provisional 4 and 1 kr/L values")
	_expect(not model.dispatch_product_from_tank("vgo_tank")["ok"], "empty VGO inventory cannot be dispatched repeatedly")


func _test_atomic_fcc_upgrading_and_dispatch() -> void:
	var model = _fcc_model(1000.0)
	model.commissioning_contract_complete = true
	var start: Dictionary = model.interact("fcc_pump")
	_expect(start["ok"] and model.equipment["fcc_pump"]["running"], "a complete FCC route starts through its ordinary VGO feed-pump interaction")
	_expect(is_equal_approx(model.power_status()["demand_kw"], 65.0), "a running FCC train adds its 40 kW auxiliary load to the 25 kW feed pump")
	var mass_before := _total_tank_volume(model)
	model.tick(100.0)
	_expect(is_equal_approx(model.equipment["fcc_source"]["volume_l"], 0.0) and is_equal_approx(model.equipment["gasoline_tank"]["volume_l"], 550.0) and is_equal_approx(model.equipment["lpg_tank"]["volume_l"], 250.0) and is_equal_approx(model.equipment["lco_tank"]["volume_l"], 200.0), "running FCC converts VGO with the fixed 55/25/20 Gasoline Blendstock, LPG and LCO yields")
	_expect(is_equal_approx(_total_tank_volume(model), mass_before) and model.equipment["gasoline_tank"]["contents"] == "gasoline_blendstock" and model.equipment["lpg_tank"]["contents"] == "lpg" and model.equipment["lco_tank"]["contents"] == "light_cycle_oil", "FCC transfer conserves mass and preserves each upgraded product identity")
	var blocked = _fcc_model(20.0)
	blocked.equipment["lpg_tank"]["contents"] = "lpg"
	blocked.equipment["lpg_tank"]["volume_l"] = 1000.0
	blocked.equipment["fcc_pump"]["running"] = true
	blocked.tick(10.0)
	_expect(is_equal_approx(blocked.equipment["fcc_source"]["volume_l"], 20.0) and is_equal_approx(blocked.equipment["gasoline_tank"]["volume_l"], 0.0) and "full" in blocked.last_status.to_lower(), "one full FCC destination blocks the entire atomic upgrade without consuming VGO")
	var orders: Array[Dictionary] = model.available_product_orders()
	_expect(orders.size() == 3 and orders[0]["product"] == "gasoline_blendstock" and orders[1]["product"] == "lpg" and orders[2]["product"] == "light_cycle_oil", "FCC products appear as three distinct physical deliveries")
	var gasoline_sale: Dictionary = model.dispatch_product_from_tank("gasoline_tank")
	var lpg_sale: Dictionary = model.dispatch_product_from_tank("lpg_tank")
	var lco_sale: Dictionary = model.dispatch_product_from_tank("lco_tank")
	_expect(gasoline_sale["ok"] and gasoline_sale["revenue"] == 3850 and lpg_sale["ok"] and lpg_sale["revenue"] == 1250 and lco_sale["ok"] and lco_sale["revenue"] == 600, "FCC products dispatch once from their own tanks at 7, 5 and 3 kr/L")
	var saved: Dictionary = _fcc_model(10.0).save_state()
	var restored = _fcc_model(0.0)
	restored.apply_saved_state(saved)
	_expect(restored.equipment["fcc_source"]["material_intent"] == "vacuum_gas_oil" and restored.network.filter_routes_by_process_type(restored.network.find_complete_routes(), restored.network.CATALYTIC_CRACKING).size() == 1, "FCC equipment, VGO intent and typed route survive save/load")


func _test_secondary_pump_start_and_stop_guards() -> void:
	var empty_vdu = _vacuum_model(0.0)
	var empty_vdu_start: Dictionary = empty_vdu.interact("vacuum_pump")
	_expect(not empty_vdu_start["ok"] and not empty_vdu.equipment["vacuum_pump"]["running"] and is_equal_approx(empty_vdu.power_status()["demand_kw"], 0.0) and is_equal_approx(_total_tank_volume(empty_vdu), 0.0) and empty_vdu_start["charge"] == 0, "empty VDU feed rejects start without material, money, or electrical state changes")
	var full_vdu = _vacuum_model(10.0)
	full_vdu.equipment["vgo_tank"]["contents"] = "vacuum_gas_oil"
	full_vdu.equipment["vgo_tank"]["volume_l"] = 1000.0
	var full_vdu_start: Dictionary = full_vdu.interact("vacuum_pump")
	_expect(not full_vdu_start["ok"] and not full_vdu.equipment["vacuum_pump"]["running"] and is_equal_approx(full_vdu.equipment["vacuum_source"]["volume_l"], 10.0) and is_equal_approx(full_vdu.power_status()["demand_kw"], 0.0), "full VDU output rejects start without consuming Heavy Residue or holding power")
	var blocked_vdu = _vacuum_model(10.0)
	blocked_vdu.interact("vacuum_pump")
	blocked_vdu.equipment["vgo_tank"]["contents"] = "vacuum_gas_oil"
	blocked_vdu.equipment["vgo_tank"]["volume_l"] = 1000.0
	blocked_vdu.tick(1.0)
	_expect(not blocked_vdu.equipment["vacuum_pump"]["running"] and is_equal_approx(blocked_vdu.equipment["vacuum_source"]["volume_l"], 10.0) and is_equal_approx(blocked_vdu.power_status()["demand_kw"], 0.0), "a VDU output becoming full during operation safely stops the pump without transfer")
	var running_vdu = _vacuum_model(10.0)
	_expect(running_vdu.interact("vacuum_pump")["ok"], "a valid VDU route can start normally")
	running_vdu.tick(10.0)
	_expect(not running_vdu.equipment["vacuum_pump"]["running"] and is_equal_approx(running_vdu.equipment["vacuum_pump"]["actual_flow_lps"], 0.0) and is_equal_approx(running_vdu.power_status()["demand_kw"], 0.0), "depleted VDU feed safely stops the pump and releases its power load")
	running_vdu.equipment["vacuum_source"]["contents"] = "heavy"
	running_vdu.equipment["vacuum_source"]["volume_l"] = 10.0
	_expect(not running_vdu.equipment["vacuum_pump"]["running"] and running_vdu.interact("vacuum_pump")["ok"] and running_vdu.equipment["vacuum_pump"]["running"], "VDU recovery requires an explicit valid restart")

	var empty_fcc = _fcc_model(0.0)
	var empty_fcc_start: Dictionary = empty_fcc.interact("fcc_pump")
	_expect(not empty_fcc_start["ok"] and not empty_fcc.equipment["fcc_pump"]["running"] and is_equal_approx(empty_fcc.power_status()["demand_kw"], 0.0) and is_equal_approx(_total_tank_volume(empty_fcc), 0.0) and empty_fcc_start["charge"] == 0, "empty FCC feed rejects start without material, money, or electrical state changes")
	var incompatible_fcc = _fcc_model(10.0)
	incompatible_fcc.equipment["lpg_tank"]["contents"] = "diesel"
	incompatible_fcc.equipment["lpg_tank"]["volume_l"] = 1.0
	var incompatible_fcc_start: Dictionary = incompatible_fcc.interact("fcc_pump")
	_expect(not incompatible_fcc_start["ok"] and not incompatible_fcc.equipment["fcc_pump"]["running"] and is_equal_approx(incompatible_fcc.equipment["fcc_source"]["volume_l"], 10.0) and is_equal_approx(incompatible_fcc.power_status()["demand_kw"], 0.0), "incompatible FCC output rejects start without consuming VGO or holding power")
	var blocked_fcc = _fcc_model(10.0)
	blocked_fcc.interact("fcc_pump")
	blocked_fcc.equipment["lpg_tank"]["contents"] = "diesel"
	blocked_fcc.equipment["lpg_tank"]["volume_l"] = 1.0
	blocked_fcc.tick(1.0)
	_expect(not blocked_fcc.equipment["fcc_pump"]["running"] and is_equal_approx(blocked_fcc.equipment["fcc_source"]["volume_l"], 10.0) and is_equal_approx(blocked_fcc.power_status()["demand_kw"], 0.0), "an FCC output becoming incompatible during operation safely stops the pump without transfer")
	var running_fcc = _fcc_model(10.0)
	_expect(running_fcc.interact("fcc_pump")["ok"], "a valid FCC route can start normally")
	running_fcc.tick(10.0)
	_expect(not running_fcc.equipment["fcc_pump"]["running"] and is_equal_approx(running_fcc.equipment["fcc_pump"]["actual_flow_lps"], 0.0) and is_equal_approx(running_fcc.power_status()["demand_kw"], 0.0), "depleted FCC feed safely stops the pump and releases its power load")
	running_fcc.equipment["fcc_source"]["contents"] = "vacuum_gas_oil"
	running_fcc.equipment["fcc_source"]["volume_l"] = 10.0
	_expect(not running_fcc.equipment["fcc_pump"]["running"] and running_fcc.interact("fcc_pump")["ok"] and running_fcc.equipment["fcc_pump"]["running"], "FCC recovery requires an explicit valid restart")


func _test_pump_condition_and_preventive_maintenance() -> void:
	var low_flow_model = _complete_model()
	var high_flow_model = _complete_model()
	low_flow_model.equipment["pump"]["flow_setpoint_lps"] = 5.0
	high_flow_model.equipment["pump"]["flow_setpoint_lps"] = 15.0
	low_flow_model._degrade_pump_condition(low_flow_model.equipment["pump"], 1000.0)
	high_flow_model._degrade_pump_condition(high_flow_model.equipment["pump"], 1000.0)
	_expect(float(high_flow_model.equipment["pump"]["condition_percent"]) < float(low_flow_model.equipment["pump"]["condition_percent"]), "higher selected flow wears a pump faster for the same moved volume")

	var model = _complete_model()
	model.commissioning_contract_complete = true
	model.equipment["source"]["contents"] = "crude"
	model.equipment["source"]["volume_l"] = 1000.0
	model.equipment["source"]["contract_id"] = "standard"
	model.equipment["valve"]["open"] = true
	model.equipment["heater"]["temperature_c"] = 200.0
	model.equipment["heater"]["setpoint_c"] = 200.0
	model.equipment["pump"]["flow_setpoint_lps"] = 15.0
	model.equipment["pump"]["condition_percent"] = 60.0
	_expect(model.interact("pump")["ok"], "a worn pump can still be started for preventive-maintenance diagnosis")
	model.tick(1.0)
	_expect(is_equal_approx(model.equipment["pump"]["actual_flow_lps"], 12.0), "worn condition reduces actual atmospheric flow without changing the selected target")
	model.equipment["pump"]["running"] = false
	model.equipment["pump"]["condition_percent"] = 30.0
	model.equipment["pump"]["running"] = true
	model.tick(1.0)
	_expect(is_equal_approx(model.equipment["pump"]["actual_flow_lps"], 8.25) and "low flow" in model.alarm_text().to_lower(), "poor condition creates a physical LOW FLOW symptom at a high flow target")
	model.equipment["pump"]["running"] = false
	var stopped_volume := float(model.equipment["source"]["volume_l"])
	model.tick(10.0)
	_expect(is_equal_approx(model.equipment["source"]["volume_l"], stopped_volume), "stopped pumps gain no hidden condition wear")
	model.equipment["pump"]["condition_percent"] = 0.0
	_expect(not model.interact("pump")["ok"] and "maintenance" in model.last_status.to_lower(), "zero-condition pump blocks a start with a maintenance explanation")
	model.equipment["pump"]["condition_percent"] = 42.0
	model.equipment["pump"]["running"] = true
	_expect(not model.inspect_or_service_pump("pump")["ok"], "pump condition cannot be serviced while the pump is running")
	model.equipment["pump"]["running"] = false
	var condition_before_unaffordable := float(model.equipment["pump"]["condition_percent"])
	_expect(not model.inspect_or_service_pump("pump", false)["ok"] and is_equal_approx(model.equipment["pump"]["condition_percent"], condition_before_unaffordable), "unaffordable condition service leaves the pump unchanged")
	var service: Dictionary = model.inspect_or_service_pump("pump", true)
	_expect(service["ok"] and service.get("charge", 0) == BuiltRefineryModelScript.PUMP_SERVICE_COST and is_equal_approx(model.equipment["pump"]["condition_percent"], 100.0), "stopped pump service restores condition and charges the defined maintenance cost")
	model.equipment["pump"]["condition_percent"] = 42.0
	model.equipment["pump"]["fault_id"] = "blocked_filter"
	model.equipment["pump"]["fault_inspected"] = true
	_expect(model.inspect_or_service_pump("pump")["ok"] and is_equal_approx(model.equipment["pump"]["condition_percent"], 42.0), "filter service clears only the filter fault and does not reset pump condition")
	_expect(model.inspect_or_service_pump("pump")["ok"] and is_equal_approx(model.equipment["pump"]["condition_percent"], 100.0), "condition service remains separate from the filter repair")

	var vdu = _vacuum_model(100.0)
	vdu.equipment["vacuum_pump"]["condition_percent"] = 60.0
	vdu.equipment["vacuum_pump"]["running"] = true
	vdu.tick(1.0)
	_expect(is_equal_approx(vdu.equipment["vacuum_pump"]["actual_flow_lps"], 8.0), "pump condition limits VDU throughput independently")
	var fcc = _fcc_model(100.0)
	fcc.equipment["fcc_pump"]["condition_percent"] = 30.0
	fcc.equipment["fcc_pump"]["running"] = true
	fcc.tick(1.0)
	_expect(is_equal_approx(fcc.equipment["fcc_pump"]["actual_flow_lps"], 5.5), "pump condition limits FCC throughput independently")
	model.equipment["pump"]["condition_percent"] = 42.0
	var saved: Dictionary = model.save_state()
	var restored = _complete_model()
	restored.apply_saved_state(saved)
	_expect(is_equal_approx(restored.equipment["pump"]["condition_percent"], 42.0) and not restored.equipment["pump"]["running"], "pump condition persists while load safety keeps pumps stopped")


func _take_and_analyze(model) -> Dictionary:
	var sample: Dictionary = model.take_diesel_sample("diesel_tank")
	if not sample["ok"]:
		return sample
	return model.analyze_diesel_sample()


func _complete_model():
	var model = BuiltRefineryModelScript.new()
	model.register_unit("source", "tank", "T-201")
	model.register_unit("pump", "pump", "P-201")
	model.register_unit("valve", "valve", "V-201")
	model.register_unit("heater", "heater", "H-201")
	model.register_unit("column", "column", "D-201")
	model.register_unit("light_tank", "tank", "T-202")
	model.register_unit("diesel_tank", "tank", "T-203")
	model.register_unit("heavy_tank", "tank", "T-204")
	model.network.try_connect("source", "output", "pump", "input")
	model.network.try_connect("pump", "output", "valve", "input")
	model.network.try_connect("valve", "output", "heater", "input")
	model.network.try_connect("heater", "output", "column", "input")
	model.network.try_connect("column", "light", "light_tank", "input")
	model.network.try_connect("column", "diesel", "diesel_tank", "input")
	model.network.try_connect("column", "heavy", "heavy_tank", "input")
	return model


func _treated_model():
	var model = _complete_model()
	model.register_unit("treatment", "treatment", "HT-201")
	model.network.disconnect_ports("column", "diesel", "diesel_tank", "input")
	model.network.try_connect("column", "diesel", "treatment", "input")
	model.network.try_connect("treatment", "output", "diesel_tank", "input")
	return model


func _vacuum_model(feed_l := 0.0):
	var model = BuiltRefineryModelScript.new()
	model.register_unit("vacuum_source", "tank", "VT-201", "heavy")
	model.register_unit("vacuum_pump", "pump", "VP-201")
	model.register_unit("vdu", "vacuum_distillation", "VDU-301")
	model.register_unit("vgo_tank", "tank", "VT-202", "vacuum_gas_oil")
	model.register_unit("vacuum_residue_tank", "tank", "VT-203", "vacuum_residue")
	model.network.try_connect("vacuum_source", "output", "vacuum_pump", "input")
	model.network.try_connect("vacuum_pump", "output", "vdu", "input")
	model.network.try_connect("vdu", "vgo", "vgo_tank", "input")
	model.network.try_connect("vdu", "vacuum_residue", "vacuum_residue_tank", "input")
	if feed_l > 0.0:
		model.equipment["vacuum_source"]["contents"] = "heavy"
		model.equipment["vacuum_source"]["volume_l"] = feed_l
	return model


func _fcc_model(feed_l := 0.0):
	var model = BuiltRefineryModelScript.new()
	model.register_unit("fcc_source", "tank", "VT-301", "vacuum_gas_oil")
	model.register_unit("fcc_pump", "pump", "FP-401")
	model.register_unit("fcc", "catalytic_cracking", "FCC-401")
	model.register_unit("gasoline_tank", "tank", "FT-401", "gasoline_blendstock")
	model.register_unit("lpg_tank", "tank", "FT-402", "lpg")
	model.register_unit("lco_tank", "tank", "FT-403", "light_cycle_oil")
	model.network.try_connect("fcc_source", "output", "fcc_pump", "input")
	model.network.try_connect("fcc_pump", "output", "fcc", "input")
	model.network.try_connect("fcc", "gasoline", "gasoline_tank", "input")
	model.network.try_connect("fcc", "lpg", "lpg_tank", "input")
	model.network.try_connect("fcc", "lco", "lco_tank", "input")
	if feed_l > 0.0:
		model.equipment["fcc_source"]["contents"] = "vacuum_gas_oil"
		model.equipment["fcc_source"]["volume_l"] = feed_l
	return model


func _add_vacuum_route(model, source_id: String) -> void:
	model.register_unit("vacuum_pump", "pump", "VP-201")
	model.register_unit("vdu", "vacuum_distillation", "VDU-301")
	model.register_unit("vgo_tank", "tank", "VT-205", "vacuum_gas_oil")
	model.register_unit("vacuum_residue_tank", "tank", "VT-206", "vacuum_residue")
	model.network.try_connect(source_id, "output", "vacuum_pump", "input")
	model.network.try_connect("vacuum_pump", "output", "vdu", "input")
	model.network.try_connect("vdu", "vgo", "vgo_tank", "input")
	model.network.try_connect("vdu", "vacuum_residue", "vacuum_residue_tank", "input")


func _add_power_atmospheric_route(model, prefix: String) -> void:
	model.register_unit(prefix + "_source", "tank", prefix + " T-201")
	model.register_unit(prefix + "_pump", "pump", prefix + " P-201")
	model.register_unit(prefix + "_valve", "valve", prefix + " V-201")
	model.register_unit(prefix + "_heater", "heater", prefix + " H-201")
	model.register_unit(prefix + "_column", "column", prefix + " D-201")
	model.register_unit(prefix + "_light", "tank", prefix + " T-202")
	model.register_unit(prefix + "_diesel", "tank", prefix + " T-203")
	model.register_unit(prefix + "_heavy", "tank", prefix + " T-204")
	model.network.try_connect(prefix + "_source", "output", prefix + "_pump", "input")
	model.network.try_connect(prefix + "_pump", "output", prefix + "_valve", "input")
	model.network.try_connect(prefix + "_valve", "output", prefix + "_heater", "input")
	model.network.try_connect(prefix + "_heater", "output", prefix + "_column", "input")
	model.network.try_connect(prefix + "_column", "light", prefix + "_light", "input")
	model.network.try_connect(prefix + "_column", "diesel", prefix + "_diesel", "input")
	model.network.try_connect(prefix + "_column", "heavy", prefix + "_heavy", "input")


func _add_diesel_product_header(model, after_treatment := false) -> void:
	model.register_unit("diesel_header", "product_header", "PH-201")
	model.register_unit("diesel_backup", "tank", "T-205")
	if after_treatment:
		model.network.disconnect_ports("treatment", "output", "diesel_tank", "input")
		model.network.try_connect("treatment", "output", "diesel_header", "input")
	else:
		model.network.disconnect_ports("column", "diesel", "diesel_tank", "input")
		model.network.try_connect("column", "diesel", "diesel_header", "input")
	model.network.try_connect("diesel_header", "out_a", "diesel_tank", "input")
	model.network.try_connect("diesel_header", "out_b", "diesel_backup", "input")


func _add_malformed_second_route(model, prefix: String) -> void:
	model.register_unit(prefix + "_source", "tank", "B-T1")
	model.register_unit(prefix + "_pump", "pump", "B-P1")
	model.register_unit(prefix + "_valve", "valve", "B-V1")
	model.register_unit(prefix + "_heater", "heater", "B-H1")
	model.register_unit(prefix + "_column", "column", "B-D1")
	model.register_unit(prefix + "_light", "tank", "B-T2")
	model.register_unit(prefix + "_diesel", "tank", "B-T3")
	model.register_unit(prefix + "_heavy", "tank", "B-T4")
	model.network.try_connect(prefix + "_source", "output", prefix + "_pump", "input")
	model.network.try_connect(prefix + "_pump", "output", prefix + "_valve", "input")
	model.network.try_connect(prefix + "_valve", "output", prefix + "_heater", "input")
	model.network.try_connect(prefix + "_heater", "output", prefix + "_column", "input")
	model.network.try_connect(prefix + "_column", "light", prefix + "_light", "input")
	model.network.try_connect(prefix + "_column", "diesel", prefix + "_diesel", "input")
	# Deliberately bypass the public API to model a manipulated or legacy save.
	model.network.connections.append({
		"from_unit": prefix + "_column",
		"from_port": "heavy",
		"to_unit": prefix + "_heavy",
		"to_port": "input",
	})


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
