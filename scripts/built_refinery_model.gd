class_name BuiltRefineryModel
extends RefCounted

const ProcessNetworkScript = preload("res://scripts/process_network.gd")

const AMBIENT_TEMPERATURE_C := 20.0
const TANK_CAPACITY_L := 1000.0
const BATCH_VOLUME_L := 1000.0
const CRUDE_BATCH_COST := 300
const PUMP_CAPACITY_LPS := 10.0
const DIESEL_TARGET_L := 200.0
const APPROVED_QUALITY_PERCENT := 90.0
const DIESEL_PRICE_PER_L := 8.0

var network
var equipment: Dictionary = {}
var commissioning_batch_available := true
var commissioning_contract_complete := false
var successful_sales := 0
var last_batch_report: Dictionary = {}
var product_inventory_revision := 0
var actual_flow_lps := 0.0
var last_status := "Bygg og valider prosesslinjen."
var _report_crude_processed_l := 0.0
var _report_temperature_total := 0.0
var _report_crude_cost := 0.0


func _init(p_network = null) -> void:
	network = p_network if p_network != null else ProcessNetworkScript.new()
	network.topology_changed.connect(_on_topology_changed)


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
				"crude_cost_per_l": 0.0,
			})
		"pump":
			state.merge({
				"running": false,
				"max_flow_lps": PUMP_CAPACITY_LPS,
				"actual_flow_lps": 0.0,
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
	equipment[unit_id] = state
	return {"ok": true, "message": "%s er klar for tilkobling." % state["name"]}


func unregister_unit(unit_id: String) -> void:
	equipment.erase(unit_id)
	network.unregister_unit(unit_id)
	actual_flow_lps = 0.0
	last_status = network.validate_configuration()["message"]


func _on_topology_changed() -> void:
	_stop_all_pumps()
	last_status = network.validate_configuration()["message"]


func can_remove(unit_id: String) -> Dictionary:
	if not equipment.has(unit_id):
		return _result(false, "Utstyret er ikke registrert.")
	var state: Dictionary = equipment[unit_id]
	if state["type"] == "tank" and state["volume_l"] > 0.001:
		return _result(false, "Tøm %s før den fjernes." % state["name"])
	if state["type"] == "pump" and state["running"]:
		return _result(false, "Stopp %s før den fjernes." % state["name"])
	if _any_pump_running() or actual_flow_lps > 0.01:
		return _result(false, "Stopp prosessen før utstyr fjernes.")
	return _result(true, "%s kan fjernes." % state["name"])


func interact(unit_id: String, can_pay_for_crude := false) -> Dictionary:
	if not equipment.has(unit_id):
		return _result(false, "Ukjent bygd utstyr.")
	match equipment[unit_id]["type"]:
		"pump":
			return _toggle_pump(unit_id)
		"valve":
			return _toggle_valve(unit_id)
		"heater":
			return _cycle_heater(unit_id)
		"tank":
			if _is_route_source(unit_id) and equipment[unit_id]["volume_l"] <= 0.001:
				return load_crude_batch(unit_id, can_pay_for_crude)
	return _result(true, inspect_unit(unit_id))


func interaction_prompt(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return ""
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"pump":
			return "E — start/stopp bygd pumpe"
		"valve":
			return "E — %s %s" % [
				"steng" if state["open"] else "åpne",
				state["name"],
			]
		"heater":
			return "E — endre temperaturmål"
		"column":
			return "E — inspiser destillasjon"
		"tank":
			if _is_route_source(unit_id):
				if state["volume_l"] <= 0.001:
					return (
						"E — last gratis oppstartsbatch"
						if commissioning_batch_available
						else "E — kjøp 1 000 L råolje (%d kr)" % CRUDE_BATCH_COST
					)
				return "E — inspiser råoljetank"
			var product_role: String = _product_role_for_tank(unit_id)
			if not product_role.is_empty():
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
		if diesel_is_approved():
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
	_stop_all_pumps()
	product_inventory_revision += 1
	_reset_report_tracking()
	last_status = "%.0f L produkt sendt til sikker avfallshåndtering. Ingen betaling mottatt." % discarded_l
	return _result(true, last_status)


func load_crude_batch(unit_id: String, paid_batch := false) -> Dictionary:
	if not _is_route_source(unit_id):
		return _result(false, "Tanken må være koblet som råoljekilde i en komplett prosesslinje.")
	var tank: Dictionary = equipment[unit_id]
	if tank["volume_l"] > 0.001:
		return _result(false, "%s er ikke tom." % tank["name"])
	var charge := 0
	if commissioning_batch_available:
		commissioning_batch_available = false
	elif paid_batch:
		charge = CRUDE_BATCH_COST
	else:
		return _result(false, "Ny råoljebatch koster %d kr." % CRUDE_BATCH_COST)
	tank["volume_l"] = BATCH_VOLUME_L
	tank["contents"] = "crude"
	tank["temperature_c"] = AMBIENT_TEMPERATURE_C
	tank["quality_percent"] = 0.0
	tank["crude_cost_per_l"] = float(charge) / BATCH_VOLUME_L
	last_status = "1 000 L råolje er lastet. Varm opp anlegget før pumpen startes."
	var message := "Gratis oppstartsbatch lastet: 1 000 L råolje."
	if charge > 0:
		message = "Ny råoljebatch lastet for %d kr." % charge
	return {"ok": true, "message": message, "charge": charge}


func tick(delta: float) -> void:
	_update_heaters(delta)
	actual_flow_lps = 0.0
	for state in equipment.values():
		if state["type"] == "pump":
			state["actual_flow_lps"] = 0.0

	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		_stop_all_pumps()
		last_status = validation["message"]
		return
	var route: Dictionary = validation["route"]
	var pump: Dictionary = equipment[route["pump"]]
	var source: Dictionary = equipment[route["source"]]
	var valve: Dictionary = equipment[route["valve"]]
	var heater: Dictionary = equipment[route["heater"]]
	if not pump["running"]:
		if source["volume_l"] <= 0.001 or source["contents"] != "crude":
			last_status = "Linjen er klar. Trykk E på kildetanken for å laste råolje."
		elif heater["temperature_c"] < 190.0:
			last_status = "Råolje lastet. Varm anlegget til ca. 200 °C før pumpen startes."
		else:
			last_status = "Temperaturen er klar. Trykk E på pumpen for å starte flow."
		return
	if source["volume_l"] <= 0.001 or source["contents"] != "crude":
		pump["running"] = false
		last_status = "LOW FLOW — råoljetanken er tom."
		return
	if not valve["open"]:
		last_status = "Kontroller utstyret mellom pumpen og varmeenheten."
		return

	var fractions := fractions_for_temperature(heater["temperature_c"])
	var safe_input := minf(source["volume_l"], pump["max_flow_lps"] * delta)
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

	_process_input(route, safe_input, fractions, heater["temperature_c"])
	actual_flow_lps = safe_input / delta if delta > 0.0 else 0.0
	pump["actual_flow_lps"] = actual_flow_lps
	last_status = "Produksjon %.1f L/s ved %.0f °C." % [actual_flow_lps, heater["temperature_c"]]
	if source["volume_l"] <= 0.001:
		source["volume_l"] = 0.0
		source["contents"] = "empty"
		pump["running"] = false
		pump["actual_flow_lps"] = 0.0
		actual_flow_lps = 0.0
		last_status = "Batch ferdig. Kontroller dieselkvaliteten ved LAB / SALG."


func sell_diesel() -> Dictionary:
	if _any_pump_running():
		return _result(false, "Stopp pumpen før diesel kontrolleres og selges.")
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return _result(false, validation["message"])
	var route: Dictionary = validation["route"]
	var diesel_tank: Dictionary = equipment[route["products"]["diesel"]]
	var total_volume: float = diesel_tank["volume_l"] if diesel_tank["contents"] == "diesel" else 0.0
	var weighted_quality: float = total_volume * diesel_tank["quality_percent"]
	if total_volume < DIESEL_TARGET_L:
		return _result(
			false,
			"For lite bygd diesel: %.0f / %.0f liter. Trykk R for å tømme off-spec produkter." % [total_volume, DIESEL_TARGET_L]
		)
	var quality: float = weighted_quality / total_volume
	if quality < APPROVED_QUALITY_PERCENT:
		return _result(
			false,
			"OFF-SPEC: Bygd diesel er %.1f %%, minst %.0f %% kreves. Trykk R for sikker tømming." % [quality, APPROVED_QUALITY_PERCENT]
		)
	var products := _active_product_totals(route)
	var revenue := int(round(total_volume * DIESEL_PRICE_PER_L))
	var processed_l: float = products["light"] + products["diesel"] + products["heavy"]
	var average_temperature := 0.0
	if _report_crude_processed_l > 0.001:
		average_temperature = _report_temperature_total / _report_crude_processed_l
	var crude_cost := int(round(_report_crude_cost))
	var report := {
		"crude_processed_l": processed_l,
		"light_l": products["light"],
		"diesel_l": products["diesel"],
		"heavy_l": products["heavy"],
		"diesel_quality_percent": quality,
		"spec_status": "GODKJENT",
		"average_temperature_c": average_temperature,
		"revenue": revenue,
		"crude_cost": crude_cost,
		"net_profit": revenue - crude_cost,
	}
	var contract_completed_now := not commissioning_contract_complete
	commissioning_contract_complete = true
	successful_sales += 1
	last_batch_report = report.duplicate(true)
	for state in equipment.values():
		if state["type"] != "tank" or state["contents"] not in ["light", "diesel", "heavy"]:
			continue
		state["volume_l"] = 0.0
		state["contents"] = "empty"
		state["quality_percent"] = 0.0
	product_inventory_revision += 1
	_reset_report_tracking()
	last_status = "%.0f L bygd diesel godkjent; produktbatch sendt for %d kr." % [total_volume, revenue]
	return {
		"ok": true,
		"message": last_status,
		"revenue": revenue,
		"sold_volume_l": total_volume,
		"report": report,
		"contract_completed_now": contract_completed_now,
	}


func diesel_is_approved() -> bool:
	var route: Dictionary = network.find_complete_route()
	if route.is_empty():
		return false
	var tank: Dictionary = equipment[route["products"]["diesel"]]
	var total_volume: float = tank["volume_l"] if tank["contents"] == "diesel" else 0.0
	return (
		total_volume >= DIESEL_TARGET_L
		and tank["quality_percent"] >= APPROVED_QUALITY_PERCENT
	)


func product_volume_l() -> float:
	var total := 0.0
	for state in equipment.values():
		if state["type"] == "tank" and state["contents"] in ["light", "diesel", "heavy"]:
			total += state["volume_l"]
	return total


func objective_text() -> String:
	var prefix := "MÅL 02: "
	if commissioning_contract_complete:
		prefix = "OMRÅDE 02 FULLFØRT — Frivillig: "
	var validation: Dictionary = network.validate_configuration()
	if not validation["valid"]:
		return prefix + "bygg og koble en komplett linje"
	var route: Dictionary = validation["route"]
	var source: Dictionary = equipment[route["source"]]
	var heater: Dictionary = equipment[route["heater"]]
	var pump: Dictionary = equipment[route["pump"]]
	var valve: Dictionary = equipment[route["valve"]]
	if source["volume_l"] <= 0.001 and product_volume_l() <= 0.001:
		return (
			prefix + "last en betalt batch med mål om minst 95 % kvalitet"
			if commissioning_contract_complete
			else prefix + "avslutt bygging og last gratis oppstartsbatch"
		)
	if pump["running"] and not valve["open"]:
		return prefix + "finn årsaken til LOW FLOW"
	if heater["temperature_c"] < 190.0 and source["volume_l"] > 0.001:
		return prefix + "varm anlegget til ca. 200 °C"
	if diesel_is_approved():
		return (
			prefix + "stopp pumpen og lever godkjent diesel ved LAB / SALG"
			if pump["running"]
			else prefix + "lever godkjent diesel ved LAB / SALG"
		)
	if source["volume_l"] <= 0.001 and product_volume_l() > 0.001:
		return prefix + "kontroller kvaliteten — tøm OFF-SPEC produkt med R ved behov"
	if source["volume_l"] > 0.001 and not pump["running"]:
		return prefix + "start pumpen og produser minst 200 L diesel"
	return prefix + "produser minst 200 L diesel med minst 90 % kvalitet"


func inspect_unit(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return "Ukjent bygd utstyr."
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"tank":
			var contents_name := _contents_name(state["contents"])
			var details := "%s: %.0f / %.0f L, %.0f °C" % [
				contents_name,
				state["volume_l"],
				state["capacity_l"],
				state["temperature_c"],
			]
			if state["contents"] == "diesel":
				details += ", kvalitet %.1f %%" % state["quality_percent"]
			return details + "."
		"pump":
			return "Pumpe %s, faktisk flow %.1f L/s." % [
				"PÅ" if state["running"] else "AV",
				state["actual_flow_lps"],
			]
		"valve":
			return "Manuell ventil %s." % ("ÅPEN" if state["open"] else "STENGT")
		"heater":
			return "Varme %.0f °C, mål %.0f °C." % [state["temperature_c"], state["setpoint_c"]]
		"column":
			return "Destillasjon: %.0f L totalt prosessert." % state["processed_total_l"]
	return "Bygd prosessutstyr."


func unit_status(unit_id: String) -> String:
	if not equipment.has(unit_id):
		return "IKKE REGISTRERT"
	var state: Dictionary = equipment[unit_id]
	match state["type"]:
		"tank":
			var status := "%.0f / %.0f L  |  %s" % [
				state["volume_l"],
				state["capacity_l"],
				_contents_name(state["contents"]),
			]
			if state["contents"] == "diesel":
				status += "  |  %.1f %%" % state["quality_percent"]
			return status
		"pump":
			return "%s  |  %.1f L/s" % ["PÅ" if state["running"] else "AV", state["actual_flow_lps"]]
		"valve":
			return "ÅPEN" if state["open"] else "STENGT"
		"heater":
			return "%.0f °C  |  mål %.0f °C" % [state["temperature_c"], state["setpoint_c"]]
		"column":
			return "%.0f L prosessert" % state["processed_total_l"]
	return "KLAR"


func summary_text() -> String:
	var validation: Dictionary = network.validate_configuration()
	var diesel_volume := 0.0
	var diesel_quality := 0.0
	if validation["valid"]:
		var tank: Dictionary = equipment[validation["route"]["products"]["diesel"]]
		if tank["contents"] == "diesel":
			diesel_volume = tank["volume_l"]
			diesel_quality = tank["quality_percent"]
	var quality_text := "VENTER"
	if diesel_volume > 0.001:
		quality_text = "%.1f %% — %s" % [
			diesel_quality,
			"GODKJENT" if diesel_is_approved() else "OFF-SPEC",
		]
	return (
		"CRUDEWORKS — BYGGEOMRÅDE 02\n\n"
		+ "Nettverk      %s\n" % ("GYLDIG" if validation["valid"] else "UFULLSTENDIG")
		+ "Flow          %6.1f L/s\n" % actual_flow_lps
		+ "Diesel        %6.0f L\n" % diesel_volume
		+ "Kvalitet      %s\n\n" % quality_text
		+ last_status
	)


func alarm_text() -> String:
	return _process_alarm_text()


func active_connection_keys() -> Dictionary:
	var route: Dictionary = network.find_complete_route()
	if route.is_empty():
		return {}
	var keys := {}
	_add_connection_key(keys, route["source"], "output", route["pump"], "input")
	_add_connection_key(keys, route["pump"], "output", route["valve"], "input")
	_add_connection_key(keys, route["valve"], "output", route["heater"], "input")
	_add_connection_key(keys, route["heater"], "output", route["column"], "input")
	for product_name in ["light", "diesel", "heavy"]:
		_add_connection_key(
			keys,
			route["column"],
			product_name,
			route["products"][product_name],
			"input"
		)
	return keys


func fractions_for_temperature(temperature_c: float) -> Vector3:
	if temperature_c < 170.0:
		return Vector3(0.08, 0.12, 0.80)
	if temperature_c < 185.0:
		return Vector3(0.20, 0.25, 0.55)
	if temperature_c <= 215.0:
		return Vector3(0.30, 0.35, 0.35)
	if temperature_c <= 225.0:
		return Vector3(0.40, 0.30, 0.30)
	return Vector3(0.55, 0.20, 0.25)


func _toggle_pump(unit_id: String) -> Dictionary:
	var pump: Dictionary = equipment[unit_id]
	if pump["running"]:
		pump["running"] = false
		pump["actual_flow_lps"] = 0.0
		actual_flow_lps = 0.0
	else:
		var validation: Dictionary = network.validate_configuration()
		if not validation["valid"]:
			return _result(false, validation["message"])
		if validation["route"]["pump"] != unit_id:
			return _result(false, "%s er ikke del av den komplette prosesslinjen." % pump["name"])
		pump["running"] = true
	last_status = "%s er %s." % [pump["name"], "startet" if pump["running"] else "stoppet"]
	return _result(true, last_status)


func _toggle_valve(unit_id: String) -> Dictionary:
	var valve: Dictionary = equipment[unit_id]
	valve["open"] = not valve["open"]
	last_status = "%s er %s." % [valve["name"], "åpen" if valve["open"] else "stengt"]
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


func _update_heaters(delta: float) -> void:
	for state in equipment.values():
		if state["type"] != "heater":
			continue
		var target: float = state["setpoint_c"] if state["setpoint_c"] > 0.0 else AMBIENT_TEMPERATURE_C
		var rate := 7.0 if actual_flow_lps > 0.01 else 18.0
		state["temperature_c"] = move_toward(state["temperature_c"], target, rate * delta)


func _stop_all_pumps() -> void:
	for state in equipment.values():
		if state["type"] == "pump":
			state["running"] = false
			state["actual_flow_lps"] = 0.0
	actual_flow_lps = 0.0


func _process_alarm_text() -> String:
	var route: Dictionary = network.find_complete_route()
	if route.is_empty():
		return ""
	var pump: Dictionary = equipment[route["pump"]]
	var valve: Dictionary = equipment[route["valve"]]
	var state: Dictionary = equipment[route["heater"]]
	var alarms: Array[String] = []
	if state["temperature_c"] > 225.0:
		alarms.append("HIGH TEMPERATURE — dieselkvalitet i fare")
	if pump["running"] and not valve["open"]:
		alarms.append("LOW FLOW — pumpen går, men flow er 0.0 L/s")
	if actual_flow_lps > 0.01 and state["temperature_c"] < 170.0:
		alarms.append("LOW TEMPERATURE — dårlig separasjon og kvalitet")
	return "\n".join(alarms)


func _process_input(route: Dictionary, input_l: float, fractions: Vector3, temperature_c: float) -> void:
	var source: Dictionary = equipment[route["source"]]
	_report_crude_processed_l += input_l
	_report_temperature_total += input_l * temperature_c
	_report_crude_cost += input_l * float(source.get("crude_cost_per_l", 0.0))
	source["volume_l"] -= input_l
	var diesel_quality := _diesel_quality(temperature_c, PUMP_CAPACITY_LPS)
	for product_name in ["light", "diesel", "heavy"]:
		var product_l := input_l * _fraction_value(fractions, product_name)
		var tank: Dictionary = equipment[route["products"][product_name]]
		if product_name == "diesel":
			var quality_total: float = tank["quality_percent"] * tank["volume_l"]
			quality_total += diesel_quality * product_l
			tank["quality_percent"] = quality_total / (tank["volume_l"] + product_l)
		tank["volume_l"] += product_l
		tank["contents"] = product_name
		tank["temperature_c"] = temperature_c
	equipment[route["column"]]["processed_total_l"] += input_l
	product_inventory_revision += 1


func _diesel_quality(temperature_c: float, current_flow_lps: float) -> float:
	var temperature_penalty := absf(temperature_c - 200.0) * 1.15
	var flow_penalty := maxf(current_flow_lps - PUMP_CAPACITY_LPS, 0.0) * 2.0
	return clampf(100.0 - temperature_penalty - flow_penalty, 0.0, 100.0)


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
	var route: Dictionary = network.find_complete_route()
	return not route.is_empty() and route["source"] == unit_id


func _product_role_for_tank(unit_id: String) -> String:
	var route: Dictionary = network.find_complete_route()
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


func _any_pump_running() -> bool:
	for state in equipment.values():
		if state["type"] == "pump" and state["running"]:
			return true
	return false


func _reset_report_tracking() -> void:
	_report_crude_processed_l = 0.0
	_report_temperature_total = 0.0
	_report_crude_cost = 0.0


func _contents_name(contents: String) -> String:
	return {
		"empty": "TOM",
		"crude": "RÅOLJE",
		"light": "LETT",
		"diesel": "DIESEL",
		"heavy": "TUNG",
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
