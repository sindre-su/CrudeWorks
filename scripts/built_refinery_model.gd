class_name BuiltRefineryModel
extends RefCounted

const ProcessNetworkScript = preload("res://scripts/process_network.gd")
const CrudeCatalog = preload("res://scripts/crude_contract_catalog.gd")
const FeedAllocationScript = preload("res://scripts/feed_allocation.gd")

const AMBIENT_TEMPERATURE_C := 20.0
const TANK_CAPACITY_L := 1000.0
const BATCH_VOLUME_L := 1000.0
const CRUDE_BATCH_COST := 300
const PUMP_CAPACITY_LPS := 10.0
const PUMP_MAX_FLOW_LPS := 15.0
const PUMP_FLOW_STEPS := [5.0, 10.0, 15.0]
const FILTER_RESTRICTION_FACTOR := 0.35
const FIRST_FILTER_FAULT_AFTER_L := 300.0
const TREATED_DIESEL_SULFUR_PPM := 10.0
const DIESEL_TARGET_L := 200.0
const APPROVED_QUALITY_PERCENT := 90.0
const DIESEL_PRICE_PER_L := 8.0

var network
var equipment: Dictionary = {}
var feed_allocations: Dictionary = {}
var commissioning_batch_available := true
var commissioning_contract_complete := false
var successful_sales := 0
var active_contract_id := ""
var active_contract_bonus_available := false
var last_batch_report: Dictionary = {}
var product_inventory_revision := 0
var actual_flow_lps := 0.0
var last_status := "Bygg og valider prosesslinjen."
var _report_crude_processed_l := 0.0
var _report_temperature_total := 0.0
var _report_flow_total := 0.0
var _report_crude_cost := 0.0
var _remote_guard_pump_id := ""
var _remote_guard_trip_message := ""
var _diesel_sample: Dictionary = {}
var _sample_sequence := 0


func _init(p_network = null) -> void:
	network = p_network if p_network != null else ProcessNetworkScript.new()
	network.topology_changed.connect(_on_topology_changed)


func save_state() -> Dictionary:
	var saved_equipment := {}
	for unit_id in equipment:
		var state: Dictionary = equipment[unit_id]
		var saved_state := {"type": state["type"]}
		match state["type"]:
			"tank":
				for field in ["volume_l", "contents", "temperature_c", "quality_percent", "sulfur_ppm", "crude_cost_per_l", "contract_id", "contract_bonus_available", "report_crude_processed_l", "report_temperature_total", "report_flow_total", "report_crude_cost"]:
					saved_state[field] = state[field]
			"valve":
				saved_state["open"] = state["open"]
			"pump":
				saved_state["flow_setpoint_lps"] = state["flow_setpoint_lps"]
				for field in ["fault_id", "fault_inspected", "fault_triggered", "processed_since_service_l"]:
					saved_state[field] = state[field]
			"heater":
				saved_state["setpoint_c"] = state["setpoint_c"]
				saved_state["temperature_c"] = state["temperature_c"]
			"column":
				saved_state["processed_total_l"] = state["processed_total_l"]
			"treatment":
				saved_state["running"] = state["running"]
				saved_state["processed_total_l"] = state["processed_total_l"]
		saved_equipment[unit_id] = saved_state
	return {
		"commissioning_batch_available": commissioning_batch_available,
		"commissioning_contract_complete": commissioning_contract_complete,
		"successful_sales": successful_sales,
		"active_contract_id": active_contract_id,
		"active_contract_bonus_available": active_contract_bonus_available,
		"last_batch_report": last_batch_report.duplicate(true),
		"product_inventory_revision": product_inventory_revision,
		"report_crude_processed_l": _report_crude_processed_l,
		"report_temperature_total": _report_temperature_total,
		"report_flow_total": _report_flow_total,
		"report_crude_cost": _report_crude_cost,
		"feed_allocations": _save_feed_allocations(),
		"equipment": saved_equipment,
	}


func apply_saved_state(state: Dictionary) -> void:
	commissioning_batch_available = bool(state["commissioning_batch_available"])
	commissioning_contract_complete = bool(state["commissioning_contract_complete"])
	successful_sales = int(state["successful_sales"])
	active_contract_id = String(state["active_contract_id"])
	active_contract_bonus_available = bool(state["active_contract_bonus_available"])
	last_batch_report = state["last_batch_report"].duplicate(true)
	product_inventory_revision = int(state["product_inventory_revision"])
	_report_crude_processed_l = float(state["report_crude_processed_l"])
	_report_temperature_total = float(state["report_temperature_total"])
	_report_flow_total = float(state.get(
		"report_flow_total",
		_report_crude_processed_l * PUMP_CAPACITY_LPS
	))
	_report_crude_cost = float(state["report_crude_cost"])
	_restore_feed_allocations(state.get("feed_allocations", {}))
	var saved_equipment: Dictionary = state["equipment"]
	for unit_id in equipment:
		var target: Dictionary = equipment[unit_id]
		var saved: Dictionary = saved_equipment[unit_id]
		match target["type"]:
			"tank":
				for field in ["volume_l", "contents", "temperature_c", "quality_percent", "sulfur_ppm", "crude_cost_per_l", "contract_id", "contract_bonus_available", "report_crude_processed_l", "report_temperature_total", "report_flow_total", "report_crude_cost"]:
					target[field] = saved.get(field, 0.0 if field == "sulfur_ppm" else target[field])
			"pump":
				target["running"] = false
				target["actual_flow_lps"] = 0.0
				target["flow_setpoint_lps"] = float(saved.get(
					"flow_setpoint_lps",
					PUMP_CAPACITY_LPS
				))
				target["fault_id"] = String(saved.get("fault_id", ""))
				target["fault_inspected"] = bool(saved.get("fault_inspected", false))
				target["fault_triggered"] = bool(saved.get("fault_triggered", false))
				target["processed_since_service_l"] = float(saved.get("processed_since_service_l", 0.0))
			"valve":
				target["open"] = bool(saved["open"])
			"heater":
				target["setpoint_c"] = float(saved["setpoint_c"])
				target["temperature_c"] = float(saved["temperature_c"])
			"column":
				target["processed_total_l"] = float(saved["processed_total_l"])
			"treatment":
				target["running"] = bool(saved.get("running", false))
				target["processed_total_l"] = float(saved.get("processed_total_l", 0.0))
	actual_flow_lps = 0.0
	_remote_guard_pump_id = ""
	_remote_guard_trip_message = ""
	_diesel_sample = {}
	_sample_sequence = 0
	last_status = "Spill lastet. Alle pumper er stoppet av sikkerhetshensyn."


func register_unit(unit_id: String, equipment_type: String, display_name := "") -> Dictionary:
	var graph_result: Dictionary = network.register_unit(unit_id, equipment_type, display_name)
	if not graph_result["ok"]:
		return graph_result
	var state := {
		"type": equipment_type,
		"name": display_name if not display_name.is_empty() else unit_id,
	}
	match equipment_type:
		"tank":
			state.merge({
				"capacity_l": TANK_CAPACITY_L,
				"volume_l": 0.0,
				"contents": "empty",
				"temperature_c": AMBIENT_TEMPERATURE_C,
				"quality_percent": 0.0,
				"sulfur_ppm": 0.0,
				"crude_cost_per_l": 0.0,
				"contract_id": "",
				"contract_bonus_available": false,
				"report_crude_processed_l": 0.0,
				"report_temperature_total": 0.0,
				"report_flow_total": 0.0,
				"report_crude_cost": 0.0,
			})
		"pump":
			state.merge({
				"running": false,
				"max_flow_lps": PUMP_MAX_FLOW_LPS,
				"flow_setpoint_lps": PUMP_CAPACITY_LPS,
				"actual_flow_lps": 0.0,
				"fault_id": "",
				"fault_inspected": false,
				"fault_triggered": false,
				"processed_since_service_l": 0.0,
			})
		"valve":
			state["open"] = false
		"heater":
			state.merge({
				"setpoint_c": 0.0,
				"temperature_c": AMBIENT_TEMPERATURE_C,
			})
		"column":
			state["processed_total_l"] = 0.0
		"treatment":
			state.merge({"running": false, "processed_total_l": 0.0})
		"header":
			pass
	equipment[unit_id] = state
	return {"ok": true, "message": "%s er klar for tilkobling." % state["name"]}


func unregister_unit(unit_id: String) -> void:
	var removed_type := String(equipment.get(unit_id, {}).get("type", ""))
	var header_source: String = network.source_for_header(unit_id) if removed_type == "header" else ""
	_diesel_sample = {}
	equipment.erase(unit_id)
	network.unregister_unit(unit_id)
	if not header_source.is_empty():
		feed_allocations.erase(header_source)
	actual_flow_lps = 0.0
	last_status = network.validate_configuration()["message"]


func _on_topology_changed() -> void:
	_refresh_feed_allocations()
	# A new, incomplete train must not interrupt an unrelated running train.
	# Stop only pumps that no longer belong to a complete route.
	var valid_pumps := {}
	for route in network.find_complete_routes():
		valid_pumps[route["pump"]] = true
	for unit_id in equipment:
		var state: Dictionary = equipment[unit_id]
		if state["type"] == "pump" and state["running"] and not valid_pumps.has(unit_id):
			state["running"] = false
			state["actual_flow_lps"] = 0.0
	actual_flow_lps = 0.0
	_remote_guard_trip_message = ""
	_diesel_sample = {}
	last_status = network.validate_configuration()["message"]


func configure_feed_allocation(source_id: String, eligible_train_ids: Array[String]) -> Dictionary:
	if not equipment.has(source_id) or equipment[source_id]["type"] != "tank":
		return _result(false, "Fôringsallokering må knyttes til en råoljetank.")
	var allocation = feed_allocations.get(source_id)
	if allocation == null:
		allocation = FeedAllocationScript.new()
		feed_allocations[source_id] = allocation
	allocation.configure(source_id, eligible_train_ids)
	return _result(true, "Fôringsruter er oppdatert.")


func discover_feed_allocation(source_id: String) -> Dictionary:
	# FeedAllocation owns route selection. The network only discovers the
	# complete trains that a physical shared-source system can make eligible.
	return configure_feed_allocation(
		source_id,
		network.eligible_train_ids_for_source(source_id)
	)


func select_feed_train(source_id: String, train_pump_id: String) -> Dictionary:
	if not feed_allocations.has(source_id):
		return _result(false, "Denne råoljetanken har ingen delte fôringsruter.")
	var allocation = feed_allocations[source_id]
	var result: Dictionary = allocation.select(train_pump_id, _source_has_running_pump(source_id))
	if result["ok"]:
		last_status = result["message"]
	return result


func cycle_feed_header(header_id: String) -> Dictionary:
	if not equipment.has(header_id) or equipment[header_id]["type"] != "header":
		return _result(false, "Ukjent fôringsheader.")
	var source_id: String = network.source_for_header(header_id)
	var routes: Array[Dictionary] = network.routes_for_header(header_id)
	if source_id.is_empty() or routes.is_empty():
		return _result(false, "Koble headerens IN til en råoljetank og minst én OUT til en komplett pumpevei.")
	var discovery := discover_feed_allocation(source_id)
	if not discovery["ok"]:
		return discovery
	var branch_pumps: Array[String] = []
	for route in routes:
		branch_pumps.append(route["pump"])
	var allocation = feed_allocations[source_id]
	var choices: Array[String] = [""]
	choices.append_array(branch_pumps)
	var current_index := choices.find(allocation.selected_train_id)
	var next_train: String = choices[(current_index + 1) % choices.size()]
	var result := select_feed_train(source_id, next_train)
	if result["ok"]:
		last_status = _feed_header_selection_text(header_id)
		result["message"] = last_status
	return result


func _source_has_running_pump(source_id: String) -> bool:
	for route in network.find_complete_routes():
		if route["source"] == source_id and bool(equipment[route["pump"]]["running"]):
			return true
	return false


func _route_for_source_operation(source_id: String) -> Dictionary:
	var shared_routes: Array[Dictionary] = []
	for route in network.eligible_routes_for_source(source_id):
		if not String(route.get("header", "")).is_empty():
			shared_routes.append(route)
	if shared_routes.is_empty():
		return network.find_route_for_unit(source_id)
	if not feed_allocations.has(source_id):
		return {}
	var selected_train: String = feed_allocations[source_id].selected_train_id
	for route in shared_routes:
		if route["pump"] == selected_train:
			return route
	return {}


func _save_feed_allocations() -> Dictionary:
	var saved := {}
	for source_id in feed_allocations:
		saved[source_id] = feed_allocations[source_id].save_state()
	return saved


func _restore_feed_allocations(saved: Dictionary) -> void:
	feed_allocations = {}
	for source_id in saved:
		var data = saved[source_id]
		if typeof(data) != TYPE_DICTIONARY or not equipment.has(source_id):
			continue
		var allocation = FeedAllocationScript.new()
		allocation.configure(source_id, network.eligible_train_ids_for_source(source_id))
		allocation.select(String(data.get("selected_train_id", "")), false)
		feed_allocations[source_id] = allocation
	_refresh_feed_allocations()


func _refresh_feed_allocations() -> void:
	for source_id in feed_allocations:
		var allocation = feed_allocations[source_id]
		# Keep a valid explicit selection when a sibling train is added. If its
		# selected route disappears, FeedAllocation clears instead of guessing.
		allocation.configure(source_id, network.eligible_train_ids_for_source(source_id))


func _feed_header_selection_text(header_id: String) -> String:
	var source_id: String = network.source_for_header(header_id)
	var selected_train := ""
	if feed_allocations.has(source_id):
		selected_train = feed_allocations[source_id].selected_train_id
	if selected_train.is_empty():
		return "%s isolert — ingen fôringsrute er valgt." % equipment[header_id]["name"]
	for route in network.routes_for_header(header_id):
		if route["pump"] == selected_train:
			return "%s: rute %s til %s er valgt." % [
				equipment[header_id]["name"],
				"A" if route["header_outlet"] == "out_a" else "B",
				equipment[selected_train]["name"],
			]
	return "%s: valgt fôringsrute er ikke tilgjengelig." % equipment[header_id]["name"]


func can_remove(unit_id: String) -> Dictionary:
	if not equipment.has(unit_id):
		return _result(false, "Utstyret er ikke registrert.")
	var state: Dictionary = equipment[unit_id]
	if state["type"] == "tank" and state["volume_l"] > 0.001:
		return _result(false, "Tøm %s før den fjernes." % state["name"])
	if state["type"] == "pump" and state["running"]:
		return _result(false, "Stopp %s før den fjernes." % state["name"])
	if state["type"] == "treatment" and state["running"]:
		return _result(false, "Stopp %s før den fjernes." % state["name"])
	if _any_pump_running() or actual_flow_lps > 0.01:
		return _result(false, "Stopp prosessen før utstyr fjernes.")
	return _result(true, "%s kan fjernes." % state["name"])


func interact(unit_id: String, can_pay_for_crude := false) -> Dictionary:
	if not equipment.has(unit_id):
		return _result(false, "Ukjent bygd utstyr.")
	match equipment[unit_id]["type"]:
		"pump":
			var pump_result := _toggle_pump(unit_id)
			if pump_result["ok"]:
				_remote_guard_trip_message = ""
				if not equipment[unit_id]["running"]:
					_remote_guard_pump_id = ""
			return pump_result
		"valve":
			return _toggle_valve(unit_id)
		"heater":
			return _cycle_heater(unit_id)
		"treatment":
			return _toggle_treatment(unit_id)
		"header":
			return cycle_feed_header(unit_id)
		"tank":
			if _is_route_source(unit_id) and equipment[unit_id]["volume_l"] <= 0.001:
				if commissioning_contract_complete and can_choose_contract(unit_id)["ok"]:
					return _result(false, "Velg råoljeleveranse før kildetanken lastes.")
				return load_crude_batch(unit_id, can_pay_for_crude)
			if commissioning_contract_complete and _product_role_for_tank(unit_id) == "diesel":
				return take_diesel_sample(unit_id)
			if commissioning_contract_complete and _product_role_for_tank(unit_id) in ["light", "heavy"]:
				return dispatch_product_from_tank(unit_id)
	return _result(true, inspect_unit(unit_id))


func interaction_prompt(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return ""
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"pump":
			var prompt := (
				"E — start/stopp pumpe  |  Q — endre flowmål (%.0f L/s)" % state["flow_setpoint_lps"]
				if commissioning_contract_complete
				else "E — start/stopp bygd pumpe"
			)
			if not String(state["fault_id"]).is_empty():
				prompt += "  |  F — %s" % (
					"rens filter" if state["fault_inspected"] and not state["running"] else "inspiser driftsavvik"
				)
			return prompt
		"valve":
			return "E — %s %s" % [
				"steng" if state["open"] else "åpne",
				state["name"],
			]
		"heater":
			return "E — endre temperaturmål"
		"treatment":
			return "E — %s dieselbehandler" % ("stopp" if state["running"] else "start")
		"header":
			return "E — bytt fôringsrute (A → B → ingen)"
		"column":
			return "E — inspiser destillasjon"
		"tank":
			if _is_route_source(unit_id):
				if _route_for_source_operation(unit_id).is_empty():
					return "Velg fôringsrute på Crude Feed Header"
				if state["volume_l"] <= 0.001:
					if commissioning_contract_complete:
						if _route_product_volume_l(network.find_route_for_unit(unit_id)) <= 0.001 and String(state.get("contract_id", "")).is_empty():
							return "E — velg råoljeleveranse"
						return "Selg eller tøm produktene før ny levering"
					return (
						"E — last gratis oppstartsbatch"
						if commissioning_batch_available
						else "E — kjøp 1 000 L råolje (%d kr)" % CRUDE_BATCH_COST
					)
				return "E — inspiser %s råoljetank" % CrudeCatalog.definition(String(state.get("contract_id", CrudeCatalog.DEFAULT_ID)))["short_name"]
			var product_role: String = _product_role_for_tank(unit_id)
			if not product_role.is_empty():
				if commissioning_contract_complete and product_role == "diesel" and state["volume_l"] > 0.001:
					if _route_pump_running(network.find_route_for_unit(unit_id)):
						return "DIESELPRØVE — stopp pumpen først"
					return (
						"E — ta ny dieselprøve"
						if _sample_is_current()
						else "E — ta dieselprøve"
					)
				if commissioning_contract_complete and product_role in ["light", "heavy"] and state["volume_l"] > 0.001:
					return "E — send %s" % _contents_name(product_role)
				return "E — inspiser %s-tank" % _contents_name(product_role)
			return "E — inspiser tank"
	return "E — inspiser bygd utstyr"


func discard_products(confirmed := false) -> Dictionary:
	var discarded_l := product_volume_l()
	if discarded_l <= 0.001:
		return _result(false, "Ingen bygde produkter å tømme.")
	if _any_pump_running():
		return _result(false, "Stopp pumpen før produktene kan tømmes.")
	if not confirmed:
		var warning := "Trykk R igjen innen 4 sek for å sende %.0f L produkt til sikker avfallshåndtering." % discarded_l
		if commissioning_contract_complete and not lab_dispatch_status().get("analyzed", false):
			warning = "ADVARSEL: Uanalysert diesel blir destruert. Ta prøve, eller trykk R igjen innen 4 sek."
		elif diesel_is_approved():
			warning = "ADVARSEL: Godkjent diesel blir destruert. Selg ved LAB / SALG, eller trykk R igjen innen 4 sek."
		return {
			"ok": false,
			"message": warning,
			"charge": 0,
			"revenue": 0,
			"requires_confirmation": true,
			"product_volume_l": discarded_l,
		}
	for state in equipment.values():
		if state["type"] != "tank" or state["contents"] not in ["light", "diesel", "heavy"]:
			continue
		state["volume_l"] = 0.0
		state["contents"] = "empty"
		state["quality_percent"] = 0.0
		state["sulfur_ppm"] = 0.0
	_stop_all_pumps()
	product_inventory_revision += 1
	_diesel_sample = {}
	_reset_report_tracking()
	_clear_contract_if_empty()
	if not commissioning_contract_complete and _material_volume_l() <= 0.001:
		commissioning_batch_available = true
	last_status = "%.0f L produkt sendt til sikker avfallshåndtering. Ingen betaling mottatt." % discarded_l
	return _result(true, last_status)


func can_choose_contract(unit_id: String) -> Dictionary:
	if not commissioning_contract_complete:
		return _result(false, "Fullfør oppstartskontrakten først.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route: Dictionary = _route_for_source_operation(unit_id)
	if route.is_empty() or route["source"] != unit_id:
		return _result(false, "Velg en gyldig fôringsrute på Crude Feed Header før råoljeleveranse.")
	if _route_pump_running(route):
		return _result(false, "Stopp pumpen før en ny råoljeleveranse velges.")
	var unassigned_message := _unassigned_material_message()
	if not unassigned_message.is_empty():
		return _result(false, unassigned_message)
	var source: Dictionary = equipment[unit_id]
	if _route_product_volume_l(route) > 0.001 or float(source["report_crude_processed_l"]) > 0.001:
		return _result(false, "Denne prosesslinjens tanker må være tomme før en ny leveranse velges.")
	if not String(source["contract_id"]).is_empty():
		return _result(false, "Forrige råoljebatch må avsluttes før en ny leveranse velges.")
	return _result(true, "Velg råoljeleveranse.")


func contract_definition(contract_id := "") -> Dictionary:
	var resolved_id: String = contract_id if not contract_id.is_empty() else active_contract_id
	if resolved_id.is_empty():
		resolved_id = CrudeCatalog.DEFAULT_ID
	return CrudeCatalog.definition(resolved_id)


func contract_cost(contract_id: String) -> int:
	var data := CrudeCatalog.definition(contract_id)
	return int(data.get("purchase_cost", 0))


func _contract_id_for_route(route: Dictionary) -> String:
	if route.is_empty() or not equipment.has(route.get("source", "")):
		return ""
	return String(equipment[route["source"]].get("contract_id", ""))


func _contract_for_route(route: Dictionary) -> Dictionary:
	var contract_id := _contract_id_for_route(route)
	return CrudeCatalog.definition(contract_id) if CrudeCatalog.is_valid(contract_id) else {}


func _reset_route_report(source: Dictionary) -> void:
	for field in ["report_crude_processed_l", "report_temperature_total", "report_flow_total", "report_crude_cost"]:
		source[field] = 0.0


func load_crude_batch(
	unit_id: String,
	paid_batch := false,
	contract_id := CrudeCatalog.DEFAULT_ID
) -> Dictionary:
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route: Dictionary = _route_for_source_operation(unit_id)
	if route.is_empty() or route["source"] != unit_id:
		return _result(false, "Velg en gyldig fôringsrute på Crude Feed Header før råolje lastes.")
	if not CrudeCatalog.is_valid(contract_id):
		return _result(false, "Ukjent råoljeleveranse.")
	if not commissioning_contract_complete and contract_id != CrudeCatalog.DEFAULT_ID:
		return _result(false, "Tung råolje låses opp etter oppstartskontrakten.")
	if _route_pump_running(route):
		return _result(false, "Stopp pumpen før råolje lastes.")
	var unassigned_message := _unassigned_material_message()
	if not unassigned_message.is_empty():
		return _result(false, unassigned_message)
	_clear_contract_if_empty()
	var tank: Dictionary = equipment[unit_id]
	if tank["volume_l"] > 0.001:
		return _result(false, "%s er ikke tom." % tank["name"])
	if _route_product_volume_l(route) > 0.001 or float(tank["report_crude_processed_l"]) > 0.001:
		return _result(false, "Denne prosesslinjens produkter må leveres eller tømmes før ny batch lastes.")
	if not String(tank["contract_id"]).is_empty():
		return _result(false, "Forrige råoljebatch er ikke avsluttet.")
	var selected_id: String = contract_id
	var charge := 0
	if commissioning_batch_available:
		selected_id = CrudeCatalog.DEFAULT_ID
		commissioning_batch_available = false
	elif paid_batch:
		charge = contract_cost(selected_id)
	else:
		return _result(false, "%s koster %d kr." % [
			CrudeCatalog.definition(selected_id)["display_name"],
			contract_cost(selected_id),
		])
	var profile := CrudeCatalog.definition(selected_id)
	_diesel_sample = {}
	active_contract_id = selected_id
	active_contract_bonus_available = int(profile["delivery_bonus"]) > 0
	tank["contract_id"] = selected_id
	tank["contract_bonus_available"] = int(profile["delivery_bonus"]) > 0
	_reset_route_report(tank)
	tank["volume_l"] = BATCH_VOLUME_L
	tank["contents"] = "crude"
	tank["temperature_c"] = AMBIENT_TEMPERATURE_C
	tank["quality_percent"] = 0.0
	tank["sulfur_ppm"] = 0.0
	tank["crude_cost_per_l"] = float(charge) / BATCH_VOLUME_L
	last_status = "1 000 L %s lastet. Varm mot ca. %.0f °C." % [
		profile["short_name"], profile["ideal_temperature_c"],
	]
	var message := "Gratis oppstartsbatch: 1 000 L %s, mål ca. %.0f °C." % [
		profile["short_name"], profile["ideal_temperature_c"],
	]
	if charge > 0:
		message = "%s lastet for %d kr. Temperaturmål ca. %.0f °C." % [
			profile["display_name"], charge, profile["ideal_temperature_c"],
		]
	return {"ok": true, "message": message, "charge": charge, "contract_id": selected_id}


func tick(delta: float) -> void:
	actual_flow_lps = 0.0
	for state in equipment.values():
		if state["type"] == "pump":
			state["actual_flow_lps"] = 0.0
	var routes: Array[Dictionary] = network.find_complete_routes()
	_update_heaters(delta, routes)
	if routes.is_empty():
		_stop_all_pumps()
		last_status = network.validate_configuration()["message"]
		return
	for route in routes:
		_tick_route(route, delta)


func _tick_route(route: Dictionary, delta: float) -> void:
	var pump: Dictionary = equipment[route["pump"]]
	var source: Dictionary = equipment[route["source"]]
	if feed_allocations.has(route["source"]):
		var allocation = feed_allocations[route["source"]]
		if allocation.selected_train_id.is_empty():
			pump["actual_flow_lps"] = 0.0
			last_status = "NO VALID FEED ROUTE — velg en prosesslinje før pumpen startes."
			return
		if not allocation.is_selected(route["pump"]):
			pump["actual_flow_lps"] = 0.0
			return
	var valve: Dictionary = equipment[route["valve"]]
	var heater: Dictionary = equipment[route["heater"]]
	var treatment: Dictionary = equipment[route["treatment"]] if not String(route.get("treatment", "")).is_empty() else {}
	var contract_id := _contract_id_for_route(route)
	var profile := _contract_for_route(route)
	if pump["running"] and _remote_guard_pump_id == route["pump"]:
		var safe_range := CrudeCatalog.approved_temperature_range(
			contract_id,
			pump["flow_setpoint_lps"],
			PUMP_CAPACITY_LPS
		)
		if (
			not CrudeCatalog.is_valid(contract_id)
			or heater["temperature_c"] < safe_range.x
			or heater["temperature_c"] > safe_range.y
		):
			pump["running"] = false
			pump["actual_flow_lps"] = 0.0
			actual_flow_lps = 0.0
			_remote_guard_pump_id = ""
			_remote_guard_trip_message = "PUMPE STOPPET AV TEMPERATURVERN — TT-201 %.0f °C." % heater["temperature_c"]
			last_status = _remote_guard_trip_message
			return
	if not pump["running"]:
		if source["volume_l"] <= 0.001 or source["contents"] != "crude":
			last_status = (
				"Linjen er klar. Trykk E på kildetanken for å velge råolje."
				if commissioning_contract_complete
				else "Linjen er klar. Trykk E på kildetanken for å laste råolje."
			)
		elif not CrudeCatalog.is_valid(contract_id):
			last_status = "Råoljebatchen mangler gyldig type. Last en sikker lagring eller tøm batchen."
		elif heater["temperature_c"] < CrudeCatalog.approved_temperature_range(
			contract_id, pump["flow_setpoint_lps"], PUMP_CAPACITY_LPS
		).x:
			last_status = "%s lastet. Varm anlegget til ca. %.0f °C før pumpen startes." % [
				profile["short_name"], profile["ideal_temperature_c"],
			]
		elif heater["temperature_c"] > CrudeCatalog.approved_temperature_range(
			contract_id, pump["flow_setpoint_lps"], PUMP_CAPACITY_LPS
		).y:
			last_status = "Temperaturen er for høy. Senk %s mot ca. %.0f °C." % [
				profile["short_name"], profile["ideal_temperature_c"],
			]
		else:
			last_status = "Temperaturen er klar. Trykk E på pumpen for å starte flow."
		return
	if source["volume_l"] <= 0.001 or source["contents"] != "crude":
		pump["running"] = false
		_remote_guard_pump_id = ""
		last_status = "LOW FLOW — råoljetanken er tom."
		return
	if not CrudeCatalog.is_valid(contract_id):
		pump["running"] = false
		last_status = "Produksjonen er stoppet: råoljens batchdata er ugyldige."
		return
	if not valve["open"]:
		last_status = "Kontroller utstyret mellom pumpen og varmeenheten."
		return
	if not treatment.is_empty() and not treatment["running"]:
		last_status = "DIESELBEHANDLING STOPPET — start %s før sour diesel kan gå til tank." % treatment["name"]
		return

	var fractions := fractions_for_temperature(heater["temperature_c"], contract_id)
	var effective_capacity_lps := _effective_pump_flow_lps(pump)
	var safe_input := minf(source["volume_l"], effective_capacity_lps * delta)
	var products: Dictionary = route["products"]
	for product_name in ["light", "diesel", "heavy"]:
		var tank: Dictionary = equipment[products[product_name]]
		if tank["contents"] != "empty" and tank["contents"] != product_name:
			last_status = "%s inneholder allerede et annet produkt." % tank["name"]
			return
		var remaining: float = tank["capacity_l"] - tank["volume_l"]
		var fraction := _fraction_value(fractions, product_name)
		safe_input = minf(safe_input, remaining / fraction)
	if safe_input <= 0.0001:
		last_status = _full_product_message(route)
		return

	var process_flow_lps := safe_input / delta if delta > 0.0 else 0.0
	_process_input(
		route,
		safe_input,
		fractions,
		heater["temperature_c"],
		pump["flow_setpoint_lps"], contract_id
	)
	var fault_triggered_now := _update_pump_fault_progress(pump, safe_input)
	actual_flow_lps += process_flow_lps
	pump["actual_flow_lps"] = process_flow_lps
	last_status = (
		"FLOW FALLER — observer faktisk flow og inspiser P-201."
		if fault_triggered_now
		else "Produksjon %.1f L/s ved %.0f °C." % [actual_flow_lps, heater["temperature_c"]]
	)
	if source["volume_l"] <= 0.001:
		source["volume_l"] = 0.0
		source["contents"] = "empty"
		pump["running"] = false
		pump["actual_flow_lps"] = 0.0
		_remote_guard_pump_id = ""
		last_status = "Batch ferdig. Kontroller dieselkvaliteten ved LAB / SALG."


func take_diesel_sample(unit_id: String) -> Dictionary:
	if not commissioning_contract_complete:
		return _result(false, "Prøvetaking låses opp etter godkjent oppstart av Område 02.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route: Dictionary = network.find_route_for_unit(unit_id)
	if route.is_empty():
		return _result(false, "Ta prøven fra dieseltanken i en komplett prosesslinje.")
	if _route_pump_running(route):
		return _result(false, "Stopp pumpen før dieselprøven tas.")
	if route["products"]["diesel"] != unit_id:
		return _result(false, "Ta prøven fra dieseltanken i denne prosesslinjen.")
	var contract_id := _contract_id_for_route(route)
	if not CrudeCatalog.is_valid(contract_id):
		return _result(false, "Ingen aktiv råoljekontrakt er knyttet til produktet.")
	var tank: Dictionary = equipment[unit_id]
	if tank["contents"] != "diesel" or tank["volume_l"] <= 0.001:
		return _result(false, "Ingen diesel tilgjengelig for prøvetaking.")
	_sample_sequence += 1
	var average_temperature := 0.0
	var average_flow := 0.0
	var source: Dictionary = equipment[route["source"]]
	if float(source["report_crude_processed_l"]) > 0.001:
		average_temperature = float(source["report_temperature_total"]) / float(source["report_crude_processed_l"])
		average_flow = float(source["report_flow_total"]) / float(source["report_crude_processed_l"])
	_diesel_sample = {
		"sample_id": "P-%03d" % _sample_sequence,
		"revision": product_inventory_revision,
		"tank_id": unit_id,
		"contract_id": contract_id,
		"volume_l": float(tank["volume_l"]),
		"quality_percent": float(tank["quality_percent"]),
		"sulfur_ppm": float(tank.get("sulfur_ppm", 0.0)),
		"average_temperature_c": average_temperature,
		"average_flow_lps": average_flow,
		"analyzed": false,
	}
	last_status = "Prøve %s tatt. Lever den til LAB / SALG." % _diesel_sample["sample_id"]
	return {
		"ok": true,
		"message": last_status,
		"sample_id": _diesel_sample["sample_id"],
		"charge": 0,
		"revenue": 0,
	}


func analyze_diesel_sample() -> Dictionary:
	var current: Dictionary = _current_sample_result()
	if not current["ok"]:
		return current
	var route: Dictionary = network.find_route_for_unit(String(_diesel_sample.get("tank_id", "")))
	if _route_pump_running(route):
		return _result(false, "Stopp pumpen før dieselprøven analyseres.")
	_diesel_sample["analyzed"] = true
	var analysis := _build_sample_analysis()
	last_status = analysis["message"]
	return analysis


func lab_dispatch_status() -> Dictionary:
	var current: Dictionary = _current_sample_result()
	if not current["ok"]:
		return current
	if not bool(_diesel_sample.get("analyzed", false)):
		return {
			"ok": false,
			"sample_current": true,
			"analyzed": false,
			"sample_id": _diesel_sample["sample_id"],
			"dispatch_ready": false,
			"message": (
				"Stopp pumpen før prøve %s analyseres." % _diesel_sample["sample_id"]
				if _route_pump_running(network.find_route_for_unit(String(_diesel_sample.get("tank_id", ""))))
				else "Prøve %s er klar for analyse ved LAB / SALG." % _diesel_sample["sample_id"]
			),
		}
	return _build_sample_analysis()


func diesel_is_dispatch_ready() -> bool:
	if not commissioning_contract_complete:
		return diesel_is_approved()
	var status := lab_dispatch_status()
	return status.get("ok", false) and status.get("dispatch_ready", false)


func sell_diesel() -> Dictionary:
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route: Dictionary = network.find_route_for_unit(String(_diesel_sample.get("tank_id", "")))
	if route.is_empty():
		return _result(false, "Ta en ny dieselprøve ved dieseltanken.")
	if _route_pump_running(route):
		return _result(false, "Stopp pumpen før diesel kontrolleres og selges.")
	var contract_id := _contract_id_for_route(route)
	if not CrudeCatalog.is_valid(contract_id):
		return _result(false, "Ingen aktiv råoljekontrakt er knyttet til produktene.")
	if commissioning_contract_complete:
		var lab_status := lab_dispatch_status()
		if not lab_status.get("sample_current", false):
			return _result(false, lab_status["message"])
		if not lab_status.get("analyzed", false):
			return _result(false, "Analyser dieselprøven ved LAB / SALG før utsending.")
		if not lab_status.get("approved", false):
			return _result(false, lab_status["message"])
	var off_route_message := _off_route_product_message(route)
	if not off_route_message.is_empty():
		return _result(false, off_route_message)
	var profile := contract_definition(contract_id)
	var products := _active_product_totals(route)
	var delivery := _delivery_terms(route, contract_id)
	var diesel_tank: Dictionary = equipment[route["products"]["diesel"]]
	var total_volume: float = diesel_tank["volume_l"] if diesel_tank["contents"] == "diesel" else 0.0
	var weighted_quality: float = total_volume * diesel_tank["quality_percent"]
	var target_l := float(profile["diesel_target_l"])
	var minimum_quality := float(profile["minimum_quality_percent"])
	var average_temperature := 0.0
	var average_flow := 0.0
	var source: Dictionary = equipment[route["source"]]
	if float(source["report_crude_processed_l"]) > 0.001:
		average_temperature = float(source["report_temperature_total"]) / float(source["report_crude_processed_l"])
		average_flow = float(source["report_flow_total"]) / float(source["report_crude_processed_l"])
	if float(source["report_crude_processed_l"]) <= 0.001 and total_volume <= 0.001:
		return _result(false, "Ingen diesel produsert. Varm anlegget og start prosessen.")
	if total_volume < target_l:
		return _result(
			false,
			"For lite %s-diesel: %.0f / %.0f L. Snitt %.0f °C, mål ca. %.0f °C. R x2 tømmer produktene." % [
				profile["short_name"], total_volume, target_l,
				average_temperature, profile["ideal_temperature_c"],
			]
		)
	var quality: float = weighted_quality / total_volume
	if quality < minimum_quality:
		return _result(
			false,
			"OFF-SPEC %s: %.1f %% ved %.0f °C. Minst %.0f %% kreves; mål ca. %.0f °C. R x2 tømmer." % [
				profile["short_name"], quality, average_temperature,
				minimum_quality, profile["ideal_temperature_c"],
			]
		)
	if float(delivery["volume_l"]) + 0.01 < float(delivery["target_l"]):
		return _result(false, "Ordren mangler %.0f L %s. Fortsett produksjonen og ta en ny dieselprøve." % [
			float(delivery["target_l"]) - float(delivery["volume_l"]),
			String(delivery["product_name"]).to_lower(),
		])
	var product_revenue := int(round(total_volume * float(profile["diesel_price_per_l"])))
	var delivery_bonus := (
		int(profile["delivery_bonus"])
		if bool(source["contract_bonus_available"])
		else 0
	)
	var revenue := product_revenue + delivery_bonus
	var processed_l: float = products["light"] + products["diesel"] + products["heavy"]
	var crude_cost := int(round(float(source["report_crude_cost"])))
	var report := {
		"contract_id": contract_id,
		"contract_name": profile["display_name"],
		"order_name": profile["order_name"],
		"delivery_product": delivery["product"],
		"delivery_product_name": delivery["product_name"],
		"delivery_target_l": delivery["target_l"],
		"delivery_volume_l": delivery["volume_l"],
		"ideal_temperature_c": profile["ideal_temperature_c"],
		"diesel_target_l": target_l,
		"required_quality_percent": minimum_quality,
		"crude_processed_l": processed_l,
		"light_l": products["light"],
		"diesel_l": products["diesel"],
		"heavy_l": products["heavy"],
		"diesel_quality_percent": quality,
		"spec_status": "GODKJENT",
		"average_temperature_c": average_temperature,
		"average_flow_lps": average_flow,
		"product_revenue": product_revenue,
		"delivery_bonus": delivery_bonus,
		"revenue": revenue,
		"crude_cost": crude_cost,
		"net_profit": revenue - crude_cost,
	}
	var contract_completed_now := not commissioning_contract_complete
	commissioning_contract_complete = true
	successful_sales += 1
	active_contract_bonus_available = false
	source["contract_bonus_available"] = false
	last_batch_report = report.duplicate(true)
	# The primary contract pays for diesel quality and, for Heavy, its ordered
	# residue. Other fractions remain in storage for their own delivery orders.
	var consumed_products := {"diesel": true}
	if delivery["product"] != "diesel":
		consumed_products[delivery["product"]] = true
	for product_name in consumed_products:
		var state: Dictionary = equipment[route["products"][product_name]]
		state["volume_l"] = 0.0
		state["contents"] = "empty"
		state["quality_percent"] = 0.0
		state["sulfur_ppm"] = 0.0
	product_inventory_revision += 1
	_diesel_sample = {}
	_reset_route_report(source)
	_reset_report_tracking()
	_clear_contract_if_empty()
	last_status = "%s godkjent; produktbatch sendt for %d kr." % [profile["order_name"], revenue]
	return {
		"ok": true,
		"message": last_status,
		"revenue": revenue,
		"sold_volume_l": total_volume,
		"report": report,
		"contract_completed_now": contract_completed_now,
	}


func available_product_orders() -> Array[Dictionary]:
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"] or _any_pump_running():
		return []
	var route: Dictionary = active_route()
	if route.is_empty():
		return []
	var orders: Array[Dictionary] = []
	for product_id in CrudeCatalog.PRODUCT_ORDER:
		var order := CrudeCatalog.product_order_definition(product_id)
		var tank: Dictionary = equipment[route["products"][product_id]]
		var volume_l := float(tank["volume_l"]) if tank["contents"] == product_id else 0.0
		order["volume_l"] = volume_l
		order["ready"] = volume_l + 0.01 >= float(order["target_l"])
		order["revenue_preview"] = int(round(volume_l * float(order["price_per_l"])))
		orders.append(order)
	return orders


func dispatch_product(product_id: String) -> Dictionary:
	return _dispatch_route_product(active_route(), product_id)


func dispatch_product_from_tank(unit_id: String) -> Dictionary:
	var route: Dictionary = network.find_route_for_unit(unit_id)
	if route.is_empty():
		return _result(false, "Produktet må stå i en komplett prosesslinje før utsending.")
	var product_id := _product_role_for_tank(unit_id)
	if product_id.is_empty() or product_id == "diesel":
		return _result(false, "Dette produktet sendes via riktig leveringspunkt.")
	return _dispatch_route_product(route, product_id)


func _dispatch_route_product(route: Dictionary, product_id: String) -> Dictionary:
	if route.is_empty():
		return _result(false, "Ingen komplett prosesslinje er klar for produktleveranse.")
	if _route_pump_running(route):
		return _result(false, "Stopp pumpen før produktleveransen sendes.")
	var order := CrudeCatalog.product_order_definition(product_id)
	if order.is_empty():
		return _result(false, "Denne produktleveransen finnes ikke.")
	var off_route_message := _off_route_product_message(route)
	if not off_route_message.is_empty():
		return _result(false, off_route_message)
	var tank: Dictionary = equipment[route["products"][product_id]]
	var volume_l := float(tank["volume_l"]) if tank["contents"] == product_id else 0.0
	if volume_l + 0.01 < float(order["target_l"]):
		return _result(false, "%s krever %.0f L; tanken har %.0f L." % [
			order["order_name"], order["target_l"], volume_l,
		])
	var revenue := int(round(volume_l * float(order["price_per_l"])))
	tank["volume_l"] = 0.0
	tank["contents"] = "empty"
	tank["quality_percent"] = 0.0
	tank["sulfur_ppm"] = 0.0
	product_inventory_revision += 1
	_diesel_sample = {}
	successful_sales += 1
	_clear_contract_if_empty()
	last_status = "%s sendt: %.0f L for %d kr." % [order["product_name"], volume_l, revenue]
	return {
		"ok": true,
		"message": last_status,
		"revenue": revenue,
		"product_id": product_id,
		"product_name": order["product_name"],
		"sold_volume_l": volume_l,
	}


func diesel_is_approved() -> bool:
	var route: Dictionary = active_route()
	if route.is_empty():
		return false
	var tank: Dictionary = equipment[route["products"]["diesel"]]
	var total_volume: float = tank["volume_l"] if tank["contents"] == "diesel" else 0.0
	var profile := contract_definition()
	var delivery := _delivery_terms(route, active_contract_id)
	return (
		total_volume >= float(profile["diesel_target_l"])
		and tank["quality_percent"] >= float(profile["minimum_quality_percent"])
		and float(tank.get("sulfur_ppm", 0.0)) <= float(profile.get("maximum_sulfur_ppm", INF))
		and float(delivery["volume_l"]) + 0.01 >= float(delivery["target_l"])
		and _off_route_product_message(route).is_empty()
	)


func product_volume_l() -> float:
	var total := 0.0
	for state in equipment.values():
		if state["type"] == "tank" and state["contents"] in ["light", "diesel", "heavy"]:
			total += state["volume_l"]
	return total


func _route_product_volume_l(route: Dictionary) -> float:
	var total := 0.0
	if route.is_empty():
		return total
	for product_id in route["products"]:
		var tank: Dictionary = equipment[route["products"][product_id]]
		if tank["contents"] == product_id:
			total += float(tank["volume_l"])
	return total


func _route_pump_running(route: Dictionary) -> bool:
	return not route.is_empty() and equipment.has(route.get("pump", "")) and bool(equipment[route["pump"]]["running"])


func _unassigned_material_message() -> String:
	var assigned_tanks := {}
	for route in network.find_complete_routes():
		assigned_tanks[route["source"]] = true
		for product_tank_id in route["products"].values():
			assigned_tanks[product_tank_id] = true
	var names: Array[String] = []
	for unit_id in equipment:
		var state: Dictionary = equipment[unit_id]
		if (
			state["type"] == "tank"
			and state["contents"] in ["crude", "light", "diesel", "heavy"]
			and state["volume_l"] > 0.001
			and not assigned_tanks.has(unit_id)
		):
			names.append(state["name"])
	return "Koble til eller tøm frakoblet materiale før ny leveranse: %s." % ", ".join(names) if not names.is_empty() else ""


func objective_text() -> String:
	var prefix := "MÅL 02: "
	if commissioning_contract_complete:
		prefix = "OMRÅDE 02 FULLFØRT — Frivillig: "
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		if network.find_complete_routes().size() > 1:
			return prefix + "gå til byggemodus og koble fra én prosesslinje"
		return prefix + "bygg og koble en komplett linje"
	var route: Dictionary = active_route()
	if route.is_empty():
		return prefix + "velg fôringsrute på Crude Feed Header"
	var source: Dictionary = equipment[route["source"]]
	var heater: Dictionary = equipment[route["heater"]]
	var pump: Dictionary = equipment[route["pump"]]
	var valve: Dictionary = equipment[route["valve"]]
	var profile := contract_definition()
	if source["volume_l"] <= 0.001 and product_volume_l() <= 0.001:
		return (
			prefix + "velg Standard eller Tung råolje ved kildetanken"
			if commissioning_contract_complete
			else prefix + "avslutt bygging og last gratis oppstartsbatch"
		)
	if pump["running"] and not valve["open"]:
		return prefix + "finn årsaken til LOW FLOW"
	var approved_range := CrudeCatalog.approved_temperature_range(
		active_contract_id, pump["flow_setpoint_lps"], PUMP_CAPACITY_LPS
	)
	if heater["temperature_c"] < approved_range.x and source["volume_l"] > 0.001:
		return prefix + "varm %s til ca. %.0f °C" % [
			profile["short_name"], profile["ideal_temperature_c"],
		]
	if heater["temperature_c"] > approved_range.y and source["volume_l"] > 0.001:
		return prefix + "%ssenk %s mot ca. %.0f °C" % [
			"stopp pumpen og " if pump["running"] else "",
			profile["short_name"], profile["ideal_temperature_c"],
		]
	var delivery := _delivery_terms(route, active_contract_id)
	if commissioning_contract_complete:
		var lab_status := lab_dispatch_status()
		if lab_status.get("sample_current", false):
			if not lab_status.get("analyzed", false):
				return (
					prefix + "stopp pumpen og lever dieselprøven til LAB / SALG"
					if pump["running"]
					else prefix + "lever dieselprøven til LAB / SALG"
				)
			if lab_status.get("approved", false):
				return (
					prefix + "stopp pumpen før godkjent batch sendes"
					if not lab_status.get("dispatch_ready", false)
					else prefix + "send godkjent batch ved LAB / SALG"
				)
			if lab_status.get("status", "OFF-SPEC") == "IKKE KLAR":
				return prefix + "ordren er ikke klar — fortsett produksjonen og ta en ny prøve"
			return prefix + "prøven er OFF-SPEC — korriger eller tøm med R x2"
		var diesel_tank: Dictionary = equipment[route["products"]["diesel"]]
		var sample_due: bool = (
			diesel_tank["contents"] == "diesel"
			and (
				(
					diesel_tank["volume_l"] >= float(profile["diesel_target_l"])
					and float(delivery["volume_l"]) + 0.01 >= float(delivery["target_l"])
				)
				or source["volume_l"] <= 0.001
			)
		)
		if sample_due:
			return (
				prefix + "stopp pumpen og ta dieselprøve ved dieseltanken"
				if pump["running"]
				else prefix + "ta dieselprøve ved dieseltanken"
			)
	if diesel_is_approved():
		return (
			prefix + "stopp pumpen og lever godkjent diesel ved LAB / SALG"
			if pump["running"]
			else prefix + "lever godkjent diesel ved LAB / SALG"
		)
	if source["volume_l"] <= 0.001 and product_volume_l() > 0.001:
		return prefix + "kontroller kvaliteten — tøm OFF-SPEC produkt med R ved behov"
	return prefix + "ORDRE %s: %s %.0f / %.0f L | diesel %.0f / %.0f L" % [
		profile["order_name"],
		delivery["product_name"], delivery["volume_l"], delivery["target_l"],
		float(equipment[route["products"]["diesel"]]["volume_l"]), profile["diesel_target_l"],
	]


func inspect_unit(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return "Ukjent bygd utstyr."
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"tank":
			var contents_name := _contents_name(state["contents"])
			if state["contents"] == "crude" and CrudeCatalog.is_valid(active_contract_id):
				contents_name = contract_definition()["short_name"] + " RÅOLJE"
			var details := "%s: %.0f / %.0f L, %.0f °C" % [
				contents_name,
				state["volume_l"],
				state["capacity_l"],
				state["temperature_c"],
			]
			if state["contents"] == "diesel":
				if commissioning_contract_complete and not _sample_reveals_tank(unit_id):
					details += ", kvalitet IKKE ANALYSERT"
				else:
					details += ", kvalitet %.1f %%" % state["quality_percent"]
			return details + "."
		"pump":
			var fault_text := " Driftsavvik registrert." if not String(state["fault_id"]).is_empty() else ""
			return "Pumpe %s, faktisk flow %.1f L/s, flowmål %.0f L/s.%s" % [
				"PÅ" if state["running"] else "AV",
				state["actual_flow_lps"],
				state["flow_setpoint_lps"],
				fault_text,
			]
		"valve":
			return "Manuell ventil %s." % ("ÅPEN" if state["open"] else "STENGT")
		"heater":
			return "Varme %.0f °C, mål %.0f °C." % [state["temperature_c"], state["setpoint_c"]]
		"column":
			return "Destillasjon: %.0f L totalt prosessert." % state["processed_total_l"]
		"treatment":
			return "Dieselbehandler %s, %.0f L behandlet." % ["PÅ" if state["running"] else "AV", state["processed_total_l"]]
		"header":
			return _feed_header_inspection(unit_id)
	return "Bygd prosessutstyr."


func unit_status(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return "IKKE REGISTRERT"
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"tank":
			var contents_label := _contents_name(state["contents"])
			if state["contents"] == "crude" and CrudeCatalog.is_valid(active_contract_id):
				contents_label = contract_definition()["short_name"]
			var status := "%.0f / %.0f L  |  %s" % [
				state["volume_l"],
				state["capacity_l"],
				contents_label,
			]
			if state["contents"] == "diesel":
				if commissioning_contract_complete and not _sample_reveals_tank(unit_id):
					status += "  |  PRØVE KREVES"
				else:
					status += "  |  %.1f %%" % state["quality_percent"]
			return status
		"pump":
			return "%s  |  faktisk %.1f L/s  |  mål %.0f%s" % [
				"PÅ" if state["running"] else "AV",
				state["actual_flow_lps"],
				state["flow_setpoint_lps"],
				"  |  AVVIK" if not String(state["fault_id"]).is_empty() else "",
			]
		"valve":
			return "ÅPEN" if state["open"] else "STENGT"
		"heater":
			return "%.0f °C  |  mål %.0f °C" % [state["temperature_c"], state["setpoint_c"]]
		"column":
			return "%.0f L prosessert" % state["processed_total_l"]
		"treatment":
			return "%s  |  %.0f L behandlet" % ["PÅ" if state["running"] else "AV", state["processed_total_l"]]
		"header":
			return _feed_header_status(unit_id)
	return "KLAR"


func _feed_header_status(header_id: String) -> String:
	var source_id: String = network.source_for_header(header_id)
	var routes: Array[Dictionary] = network.routes_for_header(header_id)
	if source_id.is_empty():
		return "KOBLE INN KILDETANK"
	if routes.is_empty():
		return "KOBLE OUT A/B TIL PUMPE"
	var selected_train := ""
	if feed_allocations.has(source_id):
		selected_train = feed_allocations[source_id].selected_train_id
	if selected_train.is_empty():
		return "INGEN RUTE VALGT"
	for route in routes:
		if route["pump"] == selected_train:
			return "RUTE %s → %s" % [
				"A" if route["header_outlet"] == "out_a" else "B",
				equipment[selected_train]["name"],
			]
	return "VALGT RUTE ER UGYLDIG"


func _feed_header_inspection(header_id: String) -> String:
	var source_id: String = network.source_for_header(header_id)
	if source_id.is_empty():
		return "CRUDE FEED HEADER: koble IN til en råoljetank."
	var lines := ["CRUDE FEED HEADER", "Kilde: %s" % equipment[source_id]["name"]]
	for route in network.routes_for_header(header_id):
		var branch := "A" if route["header_outlet"] == "out_a" else "B"
		var selected: bool = (
			feed_allocations.has(source_id)
			and feed_allocations[source_id].selected_train_id == route["pump"]
		)
		lines.append("Rute %s: %s%s" % [branch, equipment[route["pump"]]["name"], " — VALGT" if selected else ""])
	if not feed_allocations.has(source_id) or feed_allocations[source_id].selected_train_id.is_empty():
		lines.append("Valgt rute: INGEN")
	return "\n".join(lines)


func summary_text() -> String:
	var validation: Dictionary = network.validate_configuration()
	var diesel_volume := 0.0
	var diesel_quality := 0.0
	var displayed_route := active_route()
	if validation["valid"] and not displayed_route.is_empty():
		var tank: Dictionary = equipment[displayed_route["products"]["diesel"]]
		if tank["contents"] == "diesel":
			diesel_volume = tank["volume_l"]
			diesel_quality = tank["quality_percent"]
	var quality_text := "VENTER"
	if diesel_volume > 0.001:
		var lab_status := lab_dispatch_status()
		if commissioning_contract_complete and not lab_status.get("analyzed", false):
			quality_text = "IKKE ANALYSERT — PRØVE KREVES"
		else:
			quality_text = "%.1f %% — %s" % [
				diesel_quality,
				(
					"GODKJENT"
					if lab_status.get("quality_ready", false)
					else "OFF-SPEC"
				) if commissioning_contract_complete else ("GODKJENT" if diesel_is_approved() else "OFF-SPEC"),
			]
	var crude_text := "INGEN"
	var target_text := "—"
	var pump_target_text := "—"
	if CrudeCatalog.is_valid(active_contract_id):
		var profile := contract_definition()
		crude_text = profile["short_name"]
		target_text = "%.0f °C" % profile["ideal_temperature_c"]
	if validation["valid"] and not displayed_route.is_empty():
		pump_target_text = "%.0f L/s" % equipment[displayed_route["pump"]]["flow_setpoint_lps"]
	return (
		"CRUDEWORKS — BYGGEOMRÅDE 02\n\n"
		+ "Nettverk      %s\n" % (
			"GYLDIG"
			if validation["valid"]
			else ("FLERE LINJER" if network.find_complete_routes().size() > 1 else "UFULLSTENDIG")
		)
		+ "Råolje        %s  |  mål %s\n" % [crude_text, target_text]
		+ "Flow          %6.1f L/s  |  pumpemål %s\n" % [actual_flow_lps, pump_target_text]
		+ "Diesel        %6.0f L\n" % diesel_volume
		+ "Kvalitet      %s\n\n" % quality_text
		+ last_status
	)


func alarm_text() -> String:
	return _process_alarm_text()


func control_snapshot() -> Dictionary:
	if not commissioning_contract_complete:
		return {
			"unlocked": false,
			"valid": false,
			"message": "Fullfør oppstarten av Område 02 for å låse opp LS-201.",
		}
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return {
			"unlocked": true,
			"valid": false,
			"ambiguous_routes": network.find_complete_routes().size() > 1,
			"message": validation["message"],
		}
	var route: Dictionary = active_route()
	if route.is_empty():
		return {
			"unlocked": true,
			"valid": false,
			"message": "Velg fôringsrute på Crude Feed Header.",
		}
	var source: Dictionary = equipment[route["source"]]
	var pump: Dictionary = equipment[route["pump"]]
	var valve: Dictionary = equipment[route["valve"]]
	var heater: Dictionary = equipment[route["heater"]]
	var products: Dictionary = route["products"]
	var light_tank: Dictionary = equipment[products["light"]]
	var diesel_tank: Dictionary = equipment[products["diesel"]]
	var heavy_tank: Dictionary = equipment[products["heavy"]]
	var profile := contract_definition()
	var safe_range := (
		CrudeCatalog.approved_temperature_range(
			active_contract_id, pump["flow_setpoint_lps"], PUMP_CAPACITY_LPS
		)
		if CrudeCatalog.is_valid(active_contract_id)
		else Vector2.ZERO
	)
	return {
		"unlocked": true,
		"valid": true,
		"crude_name": profile["short_name"] if CrudeCatalog.is_valid(active_contract_id) else "INGEN",
		"ideal_temperature_c": float(profile["ideal_temperature_c"]) if CrudeCatalog.is_valid(active_contract_id) else 0.0,
		"source_volume_l": float(source["volume_l"]),
		"source_capacity_l": float(source["capacity_l"]),
		"source_level_percent": 100.0 * float(source["volume_l"]) / float(source["capacity_l"]),
		"heater_temperature_c": float(heater["temperature_c"]),
		"heater_setpoint_c": float(heater["setpoint_c"]),
		"pump_running": bool(pump["running"]),
		"pump_flow_setpoint_lps": float(pump["flow_setpoint_lps"]),
		"actual_flow_lps": float(pump["actual_flow_lps"]),
		"approved_temperature_min_c": safe_range.x,
		"approved_temperature_max_c": safe_range.y,
		"valve_open": bool(valve["open"]),
		"light_volume_l": float(light_tank["volume_l"]),
		"diesel_volume_l": float(diesel_tank["volume_l"]),
		"diesel_quality_percent": float(diesel_tank["quality_percent"]),
		"heavy_volume_l": float(heavy_tank["volume_l"]),
		"temperature_guard_active": _remote_guard_pump_id == route["pump"],
		"temperature_trip_message": _remote_guard_trip_message,
		"alarm": alarm_text(),
		"status": last_status,
	}


func remote_toggle_route_pump() -> Dictionary:
	if not commissioning_contract_complete:
		return _result(false, "LS-201 låses opp etter første godkjente Område 02-batch.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route: Dictionary = active_route()
	if route.is_empty():
		return _result(false, "Velg fôringsrute på Crude Feed Header før fjernstart brukes.")
	var pump: Dictionary = equipment[route["pump"]]
	if pump["running"]:
		var stop_result := _toggle_pump(route["pump"])
		_remote_guard_pump_id = ""
		return stop_result
	if not CrudeCatalog.is_valid(active_contract_id):
		return _result(false, "START SPERRET — last råolje før fjernstart brukes.")
	var source: Dictionary = equipment[route["source"]]
	if source["contents"] != "crude" or source["volume_l"] <= 0.001:
		return _result(false, "START SPERRET — LT-201 viser tom kildetank.")
	var heater: Dictionary = equipment[route["heater"]]
	var profile := contract_definition()
	var safe_range := CrudeCatalog.approved_temperature_range(
		active_contract_id, pump["flow_setpoint_lps"], PUMP_CAPACITY_LPS
	)
	if heater["temperature_c"] < safe_range.x or heater["temperature_c"] > safe_range.y:
		last_status = "START SPERRET — TT-201 %.0f °C; %s krever %.0f–%.0f °C." % [
			heater["temperature_c"], profile["short_name"], safe_range.x, safe_range.y,
		]
		return _result(false, last_status)
	var start_result := _toggle_pump(route["pump"])
	if start_result["ok"]:
		_remote_guard_pump_id = route["pump"]
		_remote_guard_trip_message = ""
	return start_result


func remote_cycle_route_heater() -> Dictionary:
	if not commissioning_contract_complete:
		return _result(false, "LS-201 låses opp etter første godkjente Område 02-batch.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route := active_route()
	if route.is_empty():
		return _result(false, "Velg fôringsrute på Crude Feed Header før temperaturen fjernstyres.")
	var result := _cycle_heater(route["heater"])
	if result["ok"]:
		_remote_guard_trip_message = ""
	return result


func remote_cycle_route_pump_flow() -> Dictionary:
	if not commissioning_contract_complete:
		return _result(false, "Flowstyring låses opp etter første godkjente Område 02-batch.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route := active_route()
	if route.is_empty():
		return _result(false, "Velg fôringsrute på Crude Feed Header før flowmålet endres.")
	return cycle_pump_flow(route["pump"])


func cycle_pump_flow(unit_id: String) -> Dictionary:
	if not commissioning_contract_complete:
		return _result(false, "Flowstyring låses opp etter første godkjente Område 02-batch.")
	if not equipment.has(unit_id) or equipment[unit_id]["type"] != "pump":
		return _result(false, "Flowmålet kan bare endres på en pumpe.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route := active_route()
	if route.is_empty() or route["pump"] != unit_id:
		return _result(false, "%s er ikke del av den komplette prosesslinjen." % equipment[unit_id]["name"])
	var pump: Dictionary = equipment[unit_id]
	var current_index := PUMP_FLOW_STEPS.find(float(pump["flow_setpoint_lps"]))
	if current_index < 0:
		current_index = 1
	pump["flow_setpoint_lps"] = PUMP_FLOW_STEPS[(current_index + 1) % PUMP_FLOW_STEPS.size()]
	var mode_text := flow_mode_text(pump["flow_setpoint_lps"]).to_lower()
	last_status = "Flowmål %.0f L/s — %s." % [pump["flow_setpoint_lps"], mode_text]
	return _result(true, last_status)


func inspect_or_service_pump(unit_id: String) -> Dictionary:
	if not equipment.has(unit_id) or equipment[unit_id]["type"] != "pump":
		return _result(false, "Driftsavvik kan bare undersøkes på en pumpe.")
	var pump: Dictionary = equipment[unit_id]
	if String(pump["fault_id"]).is_empty():
		return _result(false, "%s har ingen registrert servicefeil." % pump["name"])
	if not pump["fault_inspected"]:
		pump["fault_inspected"] = true
		last_status = "%s har lav kapasitet. Mulig filterrestriksjon — stopp pumpen før service." % pump["name"]
		return _result(true, last_status)
	if pump["running"]:
		return _result(false, "Stopp %s før filteret renses." % pump["name"])
	pump["fault_id"] = ""
	pump["fault_inspected"] = false
	pump["processed_since_service_l"] = 0.0
	last_status = "Filter renset på %s. Normal kapasitet er gjenopprettet." % pump["name"]
	return _result(true, last_status)


func flow_mode_text(flow_lps: float) -> String:
	if flow_lps <= 5.1:
		return "LAV — STØRRE TEMPERATURMARGIN"
	if flow_lps >= 14.9:
		return "HØY — MINDRE TEMPERATURMARGIN"
	return "NORMAL"


func _effective_pump_flow_lps(pump: Dictionary) -> float:
	var target_flow := float(pump["flow_setpoint_lps"])
	if String(pump.get("fault_id", "")) == "blocked_filter":
		return target_flow * FILTER_RESTRICTION_FACTOR
	return target_flow


func _update_pump_fault_progress(pump: Dictionary, processed_l: float) -> bool:
	if (
		not commissioning_contract_complete
		or pump["fault_triggered"]
		or float(pump["flow_setpoint_lps"]) < PUMP_MAX_FLOW_LPS - 0.1
		or processed_l <= 0.001
	):
		return false
	pump["processed_since_service_l"] += processed_l
	if pump["processed_since_service_l"] < FIRST_FILTER_FAULT_AFTER_L:
		return false
	pump["fault_id"] = "blocked_filter"
	pump["fault_inspected"] = false
	pump["fault_triggered"] = true
	return true


func active_connection_keys() -> Dictionary:
	var keys := {}
	for route in network.find_complete_routes():
		if not _route_has_feed_access(route):
			continue
		if not String(route.get("header", "")).is_empty():
			_add_connection_key(keys, route["source"], "output", route["header"], "input")
			_add_connection_key(keys, route["header"], route["header_outlet"], route["pump"], "input")
		else:
			_add_connection_key(keys, route["source"], "output", route["pump"], "input")
		_add_connection_key(keys, route["pump"], "output", route["valve"], "input")
		_add_connection_key(keys, route["valve"], "output", route["heater"], "input")
		_add_connection_key(keys, route["heater"], "output", route["column"], "input")
		for product_name in ["light", "diesel", "heavy"]:
			var diesel_destination: String = route["products"][product_name]
			if product_name == "diesel" and not String(route.get("treatment", "")).is_empty():
				_add_connection_key(keys, route["column"], "diesel", route["treatment"], "input")
				_add_connection_key(keys, route["treatment"], "output", diesel_destination, "input")
				continue
			_add_connection_key(keys, route["column"], product_name, diesel_destination, "input")
	return keys


func _route_has_feed_access(route: Dictionary) -> bool:
	if not feed_allocations.has(route.get("source", "")):
		return true
	return feed_allocations[route["source"]].is_selected(route["pump"])


func active_route() -> Dictionary:
	var first_unallocated_route: Dictionary = {}
	for route in network.find_complete_routes():
		if feed_allocations.has(route["source"]):
			if feed_allocations[route["source"]].is_selected(route["pump"]):
				return route
			continue
		if first_unallocated_route.is_empty():
			first_unallocated_route = route
	return first_unallocated_route


func fractions_for_temperature(
	temperature_c: float,
	contract_id := CrudeCatalog.DEFAULT_ID
) -> Vector3:
	return CrudeCatalog.fractions_for_temperature(contract_id, temperature_c)


func _toggle_pump(unit_id: String) -> Dictionary:
	var pump: Dictionary = equipment[unit_id]
	if pump["running"]:
		pump["running"] = false
		pump["actual_flow_lps"] = 0.0
		actual_flow_lps = 0.0
	else:
		var route: Dictionary = network.find_route_for_unit(unit_id)
		if route.is_empty() or route["pump"] != unit_id:
			return _result(false, "%s er ikke del av den komplette prosesslinjen." % pump["name"])
		if not _route_has_feed_access(route):
			return _result(false, "Velg denne ruten på Crude Feed Header før %s startes." % pump["name"])
		pump["running"] = true
	last_status = "%s er %s." % [pump["name"], "startet" if pump["running"] else "stoppet"]
	return _result(true, last_status)


func _toggle_valve(unit_id: String) -> Dictionary:
	var valve: Dictionary = equipment[unit_id]
	valve["open"] = not valve["open"]
	last_status = "%s er %s." % [valve["name"], "åpen" if valve["open"] else "stengt"]
	return _result(true, last_status)


func _toggle_treatment(unit_id: String) -> Dictionary:
	var treatment: Dictionary = equipment[unit_id]
	treatment["running"] = not treatment["running"]
	last_status = "%s er %s." % [treatment["name"], "startet" if treatment["running"] else "stoppet"]
	return _result(true, last_status)


func _cycle_heater(unit_id: String) -> Dictionary:
	var heater: Dictionary = equipment[unit_id]
	if heater["setpoint_c"] < 1.0:
		heater["setpoint_c"] = 170.0
	elif heater["setpoint_c"] < 180.0:
		heater["setpoint_c"] = 200.0
	elif heater["setpoint_c"] < 210.0:
		heater["setpoint_c"] = 230.0
	else:
		heater["setpoint_c"] = 0.0
	last_status = "Temperaturmål satt til %.0f °C." % heater["setpoint_c"] if heater["setpoint_c"] > 0.0 else "Varmeenheten er slått av."
	return _result(true, last_status)


func _update_heaters(delta: float, routes: Array[Dictionary]) -> void:
	var pump_for_heater := {}
	for route in routes:
		pump_for_heater[route["heater"]] = route["pump"]
	for unit_id in equipment:
		var state: Dictionary = equipment[unit_id]
		if state["type"] != "heater":
			continue
		var target: float = state["setpoint_c"] if state["setpoint_c"] > 0.0 else AMBIENT_TEMPERATURE_C
		var pump_id: String = String(pump_for_heater.get(unit_id, ""))
		var rate := 18.0
		if not pump_id.is_empty() and equipment.has(pump_id) and equipment[pump_id]["actual_flow_lps"] > 0.01:
			rate = 7.0
		state["temperature_c"] = move_toward(state["temperature_c"], target, rate * delta)


func _stop_all_pumps() -> void:
	for state in equipment.values():
		if state["type"] == "pump":
			state["running"] = false
			state["actual_flow_lps"] = 0.0
	actual_flow_lps = 0.0
	_remote_guard_pump_id = ""


func _process_alarm_text() -> String:
	# The HUD/alarm channel follows the train the player has explicitly selected
	# on a shared feed header. It must never report a sibling branch by accident.
	var route: Dictionary = active_route()
	if route.is_empty():
		return ""
	var pump: Dictionary = equipment[route["pump"]]
	var valve: Dictionary = equipment[route["valve"]]
	var source: Dictionary = equipment[route["source"]]
	var state: Dictionary = equipment[route["heater"]]
	if not CrudeCatalog.is_valid(active_contract_id):
		return ""
	var approved_range := CrudeCatalog.approved_temperature_range(
		active_contract_id, pump["flow_setpoint_lps"], PUMP_CAPACITY_LPS
	)
	var alarms: Array[String] = []
	if state["temperature_c"] > approved_range.y:
		alarms.append("HIGH TEMPERATURE — dieselkvalitet i fare")
	if pump["running"] and not valve["open"]:
		alarms.append("LOW FLOW — pumpen går, men flow er 0.0 L/s")
	if (
		pump["running"]
		and valve["open"]
		and source["contents"] == "crude"
		and source["volume_l"] > 0.001
		and not String(pump.get("fault_id", "")).is_empty()
	):
		alarms.append("LOW FLOW — %s leverer under flowmålet" % pump["name"])
	if actual_flow_lps > 0.01 and state["temperature_c"] < approved_range.x:
		alarms.append("LOW TEMPERATURE — dårlig separasjon og kvalitet")
	return "\n".join(alarms)


func _process_input(
	route: Dictionary,
	input_l: float,
	fractions: Vector3,
	temperature_c: float,
	flow_lps: float,
	contract_id: String
) -> void:
	var source: Dictionary = equipment[route["source"]]
	source["report_crude_processed_l"] += input_l
	source["report_temperature_total"] += input_l * temperature_c
	source["report_flow_total"] += input_l * flow_lps
	source["report_crude_cost"] += input_l * float(source.get("crude_cost_per_l", 0.0))
	# Keep the legacy aggregate for the single-line HUD/report path while each
	# source also owns an isolated copy for multi-train processing.
	_report_crude_processed_l += input_l
	_report_temperature_total += input_l * temperature_c
	_report_flow_total += input_l * flow_lps
	_report_crude_cost += input_l * float(source.get("crude_cost_per_l", 0.0))
	source["volume_l"] -= input_l
	var diesel_quality := _diesel_quality(temperature_c, flow_lps, contract_id)
	var diesel_sulfur: float = float(CrudeCatalog.definition(contract_id).get("diesel_sulfur_ppm", 0.0))
	if not String(route.get("treatment", "")).is_empty():
		diesel_sulfur = TREATED_DIESEL_SULFUR_PPM
		equipment[route["treatment"]]["processed_total_l"] += input_l * fractions.y
	for product_name in ["light", "diesel", "heavy"]:
		var product_l := input_l * _fraction_value(fractions, product_name)
		var tank: Dictionary = equipment[route["products"][product_name]]
		if product_name == "diesel":
			var quality_total: float = tank["quality_percent"] * tank["volume_l"]
			quality_total += diesel_quality * product_l
			tank["quality_percent"] = quality_total / (tank["volume_l"] + product_l)
			var sulfur_total: float = tank.get("sulfur_ppm", 0.0) * tank["volume_l"]
			sulfur_total += diesel_sulfur * product_l
			tank["sulfur_ppm"] = sulfur_total / (tank["volume_l"] + product_l)
		tank["volume_l"] += product_l
		tank["contents"] = product_name
		tank["temperature_c"] = temperature_c
	equipment[route["column"]]["processed_total_l"] += input_l
	product_inventory_revision += 1


func _diesel_quality(temperature_c: float, current_flow_lps: float, contract_id := "") -> float:
	return CrudeCatalog.diesel_quality(
		contract_id if CrudeCatalog.is_valid(contract_id) else CrudeCatalog.DEFAULT_ID,
		temperature_c,
		current_flow_lps,
		PUMP_CAPACITY_LPS
	)


func _fraction_value(fractions: Vector3, product_name: String) -> float:
	match product_name:
		"light":
			return fractions.x
		"diesel":
			return fractions.y
		_:
			return fractions.z


func _full_product_message(route: Dictionary) -> String:
	for product_name in ["light", "diesel", "heavy"]:
		var tank: Dictionary = equipment[route["products"][product_name]]
		if tank["volume_l"] >= tank["capacity_l"] - 0.001:
			return "%s er full. Produksjonen er stoppet." % tank["name"]
	return "Ingen ledig produktkapasitet."


func _is_route_source(unit_id: String) -> bool:
	var route: Dictionary = network.find_route_for_unit(unit_id)
	return not route.is_empty() and route["source"] == unit_id


func _product_role_for_tank(unit_id: String) -> String:
	var route: Dictionary = network.find_route_for_unit(unit_id)
	if route.is_empty():
		return ""
	for product_name in route["products"]:
		if route["products"][product_name] == unit_id:
			return product_name
	return ""


func _active_product_totals(route: Dictionary) -> Dictionary:
	var totals := {"light": 0.0, "diesel": 0.0, "heavy": 0.0}
	for product_name in totals:
		var tank: Dictionary = equipment[route["products"][product_name]]
		if tank["contents"] == product_name:
			totals[product_name] = tank["volume_l"]
	return totals


func _delivery_terms(route: Dictionary, contract_id := "") -> Dictionary:
	var profile := contract_definition(contract_id)
	var product: String = profile.get("delivery_product", "diesel")
	var tank_id: String = route.get("products", {}).get(product, "")
	var volume_l := 0.0
	if equipment.has(tank_id):
		var tank: Dictionary = equipment[tank_id]
		if tank["contents"] == product:
			volume_l = float(tank["volume_l"])
	return {
		"product": product,
		"product_name": profile.get("delivery_product_name", _contents_name(product)),
		"tank_id": tank_id,
		"volume_l": volume_l,
		"target_l": float(profile.get("delivery_target_l", profile["diesel_target_l"])),
	}


func _off_route_product_message(route: Dictionary) -> String:
	var active_tanks := {}
	# Product stored in another complete train is legitimate inventory, not
	# off-route material. Only truly disconnected tanks block dispatch.
	for complete_route in network.find_complete_routes():
		for product_name in ["light", "diesel", "heavy"]:
			active_tanks[complete_route["products"][product_name]] = true
	var disconnected_names: Array[String] = []
	for unit_id in equipment:
		var state: Dictionary = equipment[unit_id]
		if (
			state["type"] == "tank"
			and state["contents"] in ["light", "diesel", "heavy"]
			and state["volume_l"] > 0.001
			and not active_tanks.has(unit_id)
		):
			disconnected_names.append(state["name"])
	if disconnected_names.is_empty():
		return ""
	return "Koble til eller tøm frakoblet produkt før ordren sendes: %s." % ", ".join(disconnected_names)


func _any_pump_running() -> bool:
	for state in equipment.values():
		if state["type"] == "pump" and state["running"]:
			return true
	return false


func _reset_report_tracking() -> void:
	_report_crude_processed_l = 0.0
	_report_temperature_total = 0.0
	_report_flow_total = 0.0
	_report_crude_cost = 0.0


func _clear_contract_if_empty() -> void:
	var any_active_contract := false
	for route in network.find_complete_routes():
		var source: Dictionary = equipment[route["source"]]
		if source["contents"] == "empty" and _route_product_volume_l(route) <= 0.001:
			source["contract_id"] = ""
			source["contract_bonus_available"] = false
			_reset_route_report(source)
		elif not String(source["contract_id"]).is_empty():
			any_active_contract = true
	if not any_active_contract:
		active_contract_id = ""
		active_contract_bonus_available = false
		_remote_guard_trip_message = ""


func _material_volume_l() -> float:
	var total := 0.0
	for state in equipment.values():
		if state["type"] == "tank" and state["contents"] in ["crude", "light", "diesel", "heavy"]:
			total += state["volume_l"]
	return total


func _active_contract_short_name() -> String:
	if not CrudeCatalog.is_valid(active_contract_id):
		return ""
	return CrudeCatalog.definition(active_contract_id)["short_name"]


func _sample_is_current() -> bool:
	return _current_sample_result()["ok"]


func _sample_reveals_tank(unit_id: String) -> bool:
	return (
		_sample_is_current()
		and bool(_diesel_sample.get("analyzed", false))
		and String(_diesel_sample.get("tank_id", "")) == unit_id
	)


func _current_sample_result() -> Dictionary:
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return {
			"ok": false,
			"sample_current": false,
			"analyzed": false,
			"message": validation["message"],
		}
	if _diesel_sample.is_empty():
		var empty_route: Dictionary = validation["route"]
		if not empty_route.is_empty():
			var diesel_tank: Dictionary = equipment[empty_route["products"]["diesel"]]
			if diesel_tank["contents"] != "diesel" or diesel_tank["volume_l"] <= 0.001:
				return {
					"ok": false,
					"sample_current": false,
					"analyzed": false,
					"message": "Ingen diesel tilgjengelig for prøvetaking.",
				}
		return {
			"ok": false,
			"sample_current": false,
			"analyzed": false,
			"message": "Ta en dieselprøve ved dieseltanken før LAB / SALG brukes.",
		}
	var route: Dictionary = network.find_route_for_unit(String(_diesel_sample.get("tank_id", "")))
	var current := (
		not route.is_empty()
		and int(_diesel_sample.get("revision", -1)) == product_inventory_revision
		and String(_diesel_sample.get("tank_id", "")) == String(route.get("products", {}).get("diesel", ""))
		and String(_diesel_sample.get("contract_id", "")) == _contract_id_for_route(route)
	)
	if not current:
		return {
			"ok": false,
			"sample_current": false,
			"analyzed": false,
			"message": "Prøven er utdatert. Ta en ny prøve ved dieseltanken.",
		}
	return {
		"ok": true,
		"sample_current": true,
		"analyzed": bool(_diesel_sample.get("analyzed", false)),
		"message": "Prøven er gyldig.",
	}


func _build_sample_analysis() -> Dictionary:
	var profile := contract_definition(String(_diesel_sample["contract_id"]))
	var volume_l := float(_diesel_sample["volume_l"])
	var quality := float(_diesel_sample["quality_percent"])
	var sulfur_ppm := float(_diesel_sample.get("sulfur_ppm", 0.0))
	var required_volume := float(profile["diesel_target_l"])
	var required_quality := float(profile["minimum_quality_percent"])
	var maximum_sulfur := float(profile.get("maximum_sulfur_ppm", INF))
	var average_temperature := float(_diesel_sample["average_temperature_c"])
	var average_flow := float(_diesel_sample.get("average_flow_lps", PUMP_CAPACITY_LPS))
	var route: Dictionary = network.find_route_for_unit(String(_diesel_sample.get("tank_id", "")))
	if route.is_empty():
		return _result(false, "Prøven er utdatert. Ta en ny prøve ved dieseltanken.")
	var delivery := _delivery_terms(route, String(_diesel_sample["contract_id"]))
	var delivery_ready := float(delivery["volume_l"]) + 0.01 >= float(delivery["target_l"])
	var sample_volume_ready := volume_l + 0.01 >= required_volume
	var quality_ready := quality >= required_quality
	var sulfur_ready := sulfur_ppm <= maximum_sulfur
	var off_route_message := _off_route_product_message(route)
	var approved := sample_volume_ready and delivery_ready and quality_ready and sulfur_ready and off_route_message.is_empty()
	var status := "GODKJENT" if approved else "OFF-SPEC"
	var deviation := "Dieselprøven og leveringsmålet oppfyller kontrakten."
	var source: Dictionary = equipment[route["source"]]
	var source_has_crude: bool = source["contents"] == "crude" and source["volume_l"] > 0.001
	var missing: Array[String] = []
	if not sample_volume_ready:
		missing.append("Mangler %.0f L diesel" % (required_volume - volume_l))
	if not delivery_ready and delivery["product"] != "diesel":
		missing.append("Mangler %.0f L %s" % [
			float(delivery["target_l"]) - float(delivery["volume_l"]),
			String(delivery["product_name"]).to_lower(),
		])
	if not off_route_message.is_empty():
		status = "IKKE KLAR"
		deviation = off_route_message
	elif not missing.is_empty():
		status = "IKKE KLAR" if source_has_crude else "OFF-SPEC"
		deviation = ". ".join(missing) + "."
		if source_has_crude:
			deviation += " Fortsett produksjonen og ta en ny prøve."
		else:
			deviation += " Råoljetanken er tom; behold for inspeksjon eller tøm med R x2."
	if not quality_ready:
		var temperature_difference: float = average_temperature - float(profile["ideal_temperature_c"])
		var quality_deviation := "Dieselkvaliteten er under kontraktskravet."
		if absf(temperature_difference) >= 0.5:
			quality_deviation = "%.0f °C %s prosessmålet" % [
				absf(temperature_difference),
				"over" if temperature_difference > 0.0 else "under",
			]
			if average_flow > PUMP_CAPACITY_LPS + 0.1:
				quality_deviation += " ved høy flow; høy flow reduserte temperaturmarginen"
		status = "OFF-SPEC"
		deviation = quality_deviation + "." if missing.is_empty() and off_route_message.is_empty() else deviation + " " + quality_deviation + "."
	if not sulfur_ready:
		status = "OFF-SPEC"
		var sulfur_deviation := "Svovel %.0f ppm er over kravet på %.0f ppm. Dieselbehandling kreves" % [sulfur_ppm, maximum_sulfur]
		deviation = sulfur_deviation + "." if deviation == "Dieselprøven og leveringsmålet oppfyller kontrakten." else deviation + " " + sulfur_deviation + "."
	var product_revenue := int(round(volume_l * float(profile["diesel_price_per_l"])))
	var delivery_bonus := int(profile["delivery_bonus"]) if bool(source["contract_bonus_available"]) else 0
	return {
		"ok": true,
		"sample_current": true,
		"analyzed": true,
		"approved": approved,
		"dispatch_ready": approved and not _route_pump_running(route),
		"sample_id": _diesel_sample["sample_id"],
		"contract_id": _diesel_sample["contract_id"],
		"contract_name": profile["short_name"],
		"order_name": profile["order_name"],
		"volume_l": volume_l,
		"required_volume_l": required_volume,
		"delivery_product": delivery["product"],
		"delivery_product_name": delivery["product_name"],
		"delivery_volume_l": delivery["volume_l"],
		"required_delivery_volume_l": delivery["target_l"],
		"delivery_ready": delivery_ready,
		"sample_volume_ready": sample_volume_ready,
		"quality_ready": quality_ready,
		"quality_percent": quality,
		"required_quality_percent": required_quality,
		"sulfur_ppm": sulfur_ppm,
		"maximum_sulfur_ppm": maximum_sulfur,
		"sulfur_ready": sulfur_ready,
		"average_temperature_c": average_temperature,
		"average_flow_lps": average_flow,
		"ideal_temperature_c": float(profile["ideal_temperature_c"]),
		"status": status,
		"deviation": deviation,
		"revenue_preview": product_revenue + delivery_bonus,
		"message": (
			"Prøve %s er godkjent for utsending." % _diesel_sample["sample_id"]
			if approved
			else "%s — %s" % [status, deviation]
		),
	}


func _contents_name(contents: String) -> String:
	return {
		"empty": "TOM",
		"crude": "RÅOLJE",
		"light": "NAPHTHA",
		"diesel": "DIESEL",
		"heavy": "TUNG REST",
	}.get(contents, contents.to_upper())


func _add_connection_key(
	keys: Dictionary,
	from_unit_id: String,
	from_port_id: String,
	to_unit_id: String,
	to_port_id: String
) -> void:
	keys["%s:%s>%s:%s" % [from_unit_id, from_port_id, to_unit_id, to_port_id]] = true


func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message, "charge": 0, "revenue": 0}
