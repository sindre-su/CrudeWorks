class_name SaveSystem
extends RefCounted

const EquipmentCatalogScript = preload("res://scripts/equipment_catalog.gd")
const ProcessNetworkScript = preload("res://scripts/process_network.gd")
const CrudeCatalogScript = preload("res://scripts/crude_contract_catalog.gd")
const BuiltRefineryModelScript = preload("res://scripts/built_refinery_model.gd")

const FORMAT_VERSION := 2
const DEFAULT_PATH := "user://crudeworks_save.json"
const BUILD_BOUNDS := Rect2(-20.0, 10.5, 40.0, 28.0)
const MAX_UNITS := 128
const MAX_CONNECTIONS := 256
const MAX_BUILD_SERIAL := 1000000
const SITE_UNIT_TYPES := {
	"built_crude_intake_0": "crude_intake",
	"built_product_dispatch_0": "product_dispatch",
}


static func write_snapshot(path: String, snapshot: Dictionary) -> Dictionary:
	var validation := validate_snapshot(snapshot)
	if not validation["ok"]:
		return validation
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _result(false, "Kunne ikke opprette midlertidig lagringsfil.")
	file.store_string(JSON.stringify(snapshot, "  "))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return _result(false, "Kunne ikke skrive den midlertidige lagringen.")
	var temporary_validation := _read_and_validate(temporary_path)
	if not temporary_validation["ok"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return _result(false, "Den midlertidige lagringen kunne ikke valideres.")

	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(path):
		if _read_and_validate(path)["ok"]:
			if FileAccess.file_exists(backup_path):
				DirAccess.remove_absolute(absolute_backup)
			var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
			if backup_error != OK:
				DirAccess.remove_absolute(absolute_temporary)
				return _result(false, "Kunne ikke sikre forrige lagring.")
		else:
			var corrupt_path := path + ".corrupt"
			var absolute_corrupt := ProjectSettings.globalize_path(corrupt_path)
			if FileAccess.file_exists(corrupt_path):
				DirAccess.remove_absolute(absolute_corrupt)
			if DirAccess.rename_absolute(absolute_path, absolute_corrupt) != OK:
				DirAccess.remove_absolute(absolute_temporary)
				return _result(false, "Kunne ikke bevare den skadde lagringsfilen.")
	var replace_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return _result(false, "Kunne ikke fullføre lagringen.")
	return _result(true, "Spillet er lagret.")


static func read_snapshot(path: String) -> Dictionary:
	var primary := _read_and_validate(path)
	if primary["ok"]:
		return primary
	var backup_path := path + ".bak"
	var backup := _read_and_validate(backup_path)
	if backup["ok"]:
		backup["recovered_from_backup"] = true
		backup["message"] = "Forrige sikre lagring ble gjenopprettet."
		return backup
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(backup_path):
		return {
			"ok": false,
			"missing": true,
			"message": "Ingen lagring funnet.",
		}
	return _result(false, "Lagringen er skadet eller fra en ukjent spillversjon.")


static func has_snapshot(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


static func archive_snapshot(path: String) -> Dictionary:
	var candidates := [path, path + ".bak", path + ".corrupt"]
	var found_file := false
	var moved_files: Array[Dictionary] = []
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		found_file = true
		var archive_path: String = String(candidate) + ".previous"
		var absolute_archive := ProjectSettings.globalize_path(archive_path)
		if FileAccess.file_exists(archive_path):
			DirAccess.remove_absolute(absolute_archive)
		var error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(candidate),
			absolute_archive
		)
		if error != OK:
			for index in range(moved_files.size() - 1, -1, -1):
				DirAccess.rename_absolute(
					moved_files[index]["archive"],
					moved_files[index]["original"]
				)
			return _result(false, "Kunne ikke arkivere forrige spill.")
		moved_files.append({
			"original": ProjectSettings.globalize_path(candidate),
			"archive": absolute_archive,
		})
	if not found_file:
		return _result(true, "Ingen lagring å arkivere.")
	return _result(true, "Forrige spill er arkivert.")


static func validate_snapshot(snapshot) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _result(false, "Lagringen mangler et gyldig rotobjekt.")
	if not _is_integer_number(snapshot.get("format_version")) or int(snapshot["format_version"]) != FORMAT_VERSION:
		return _result(false, "Lagringsversjonen støttes ikke.")
	for section in ["pilot", "construction", "built_refinery", "player"]:
		if typeof(snapshot.get(section)) != TYPE_DICTIONARY:
			return _result(false, "Lagringen mangler seksjonen %s." % section)

	var pilot_result := _validate_pilot(snapshot["pilot"])
	if not pilot_result["ok"]:
		return pilot_result
	var construction_result := _validate_construction(snapshot["construction"])
	if not construction_result["ok"]:
		return construction_result
	var built_result := _validate_built_refinery(
		snapshot["built_refinery"],
		construction_result["unit_types"],
		snapshot["construction"]["connections"]
	)
	if not built_result["ok"]:
		return built_result
	var player_result := _validate_player(snapshot["player"])
	if not player_result["ok"]:
		return player_result
	return {
		"ok": true,
		"message": "Lagringen er gyldig.",
	}


static func migrate_snapshot(snapshot) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY or not _is_integer_number(snapshot.get("format_version")):
		return _result(false, "Lagringen mangler versjonsnummer.")
	var version := int(snapshot["format_version"])
	if version == FORMAT_VERSION:
		return {"ok": true, "message": "Lagringen bruker gjeldende format.", "data": snapshot.duplicate(true)}
	if version != 1:
		return _result(false, "Lagringsversjonen støttes ikke.")
	if typeof(snapshot.get("built_refinery")) != TYPE_DICTIONARY:
		return _result(false, "Eldre lagring mangler prosesstilstand.")
	var migrated: Dictionary = snapshot.duplicate(true)
	var built: Dictionary = migrated["built_refinery"]
	var has_batch_state := (
		float(built.get("report_crude_processed_l", 0.0)) > 0.001
		or float(built.get("report_temperature_total", 0.0)) > 0.001
		or float(built.get("report_crude_cost", 0.0)) > 0.001
	)
	if typeof(built.get("equipment")) == TYPE_DICTIONARY:
		for state in built["equipment"].values():
			if (
				typeof(state) == TYPE_DICTIONARY
				and state.get("type") == "tank"
				and float(state.get("volume_l", 0.0)) > 0.001
				and state.get("contents", "empty") in ["crude", "light", "diesel", "heavy"]
			):
				has_batch_state = true
	built["active_contract_id"] = CrudeCatalogScript.DEFAULT_ID if has_batch_state else ""
	built["active_contract_bonus_available"] = false
	var report = built.get("last_batch_report", {})
	if typeof(report) == TYPE_DICTIONARY and not report.is_empty():
		var standard := CrudeCatalogScript.definition(CrudeCatalogScript.DEFAULT_ID)
		report["contract_id"] = CrudeCatalogScript.DEFAULT_ID
		report["contract_name"] = standard["display_name"]
		report["ideal_temperature_c"] = standard["ideal_temperature_c"]
		report["diesel_target_l"] = standard["diesel_target_l"]
		report["required_quality_percent"] = standard["minimum_quality_percent"]
		report["product_revenue"] = report.get("revenue", 0)
		report["delivery_bonus"] = 0
	migrated["format_version"] = FORMAT_VERSION
	return {"ok": true, "message": "Lagringen er oppgradert til format 2.", "data": migrated}


static func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(false, "Lagringsfilen finnes ikke.")
	var json_text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return _result(false, "Lagringsfilen inneholder ugyldig JSON.")
	var parsed = json.data
	var migration := migrate_snapshot(parsed)
	if not migration["ok"]:
		return migration
	var canonical = migration["data"]
	var validation := validate_snapshot(canonical)
	if not validation["ok"]:
		return validation
	return {
		"ok": true,
		"message": "Lagringen er lest.",
		"data": canonical,
		"recovered_from_backup": false,
	}


static func _validate_pilot(state: Dictionary) -> Dictionary:
	for field in [
		"crude_volume_l", "light_product_l", "diesel_volume_l", "heavy_product_l",
		"diesel_quality_percent", "heater_setpoint_c", "heater_temperature_c", "money",
	]:
		if not _finite_number(state.get(field)):
			return _result(false, "Ugyldig pilotverdi: %s." % field)
	for field in ["feed_valve_open", "batch_sold", "objective_complete"]:
		if typeof(state.get(field)) != TYPE_BOOL:
			return _result(false, "Ugyldig pilotstatus: %s." % field)
	if not _in_range(state["crude_volume_l"], 0.0, 1000.0):
		return _result(false, "Pilotens råoljevolum er ugyldig.")
	for field in ["light_product_l", "diesel_volume_l", "heavy_product_l"]:
		if not _in_range(state[field], 0.0, 600.0):
			return _result(false, "Pilotens produktvolum er ugyldig.")
	if not _in_range(state["diesel_quality_percent"], 0.0, 100.0):
		return _result(false, "Pilotens dieselkvalitet er ugyldig.")
	if not _in_range(state["heater_setpoint_c"], 0.0, 300.0):
		return _result(false, "Pilotens temperaturmål er ugyldig.")
	if not _in_range(state["heater_temperature_c"], -50.0, 500.0):
		return _result(false, "Pilotens temperatur er ugyldig.")
	if not _is_integer_number(state["money"]) or int(state["money"]) < 0 or int(state["money"]) > 1000000000:
		return _result(false, "Pengebeholdningen er ugyldig.")
	return _result(true, "Pilotdata er gyldige.")


static func _validate_construction(state: Dictionary) -> Dictionary:
	if (
		not _is_integer_number(state.get("build_serial_number"))
		or int(state["build_serial_number"]) < 0
		or int(state["build_serial_number"]) > MAX_BUILD_SERIAL
	):
		return _result(false, "Byggeserien mangler.")
	if typeof(state.get("units")) != TYPE_ARRAY or typeof(state.get("connections")) != TYPE_ARRAY:
		return _result(false, "Byggedata mangler enhets- eller koblingsliste.")
	var placements: Array = state["units"]
	var connections: Array = state["connections"]
	if placements.size() > MAX_UNITS or connections.size() > MAX_CONNECTIONS:
		return _result(false, "Lagringen inneholder for mange byggeenheter eller rør.")
	var unit_types := {}
	var maximum_serial := 0
	for placement in placements:
		if typeof(placement) != TYPE_DICTIONARY:
			return _result(false, "En bygd enhet har ugyldig format.")
		var equipment_type = placement.get("type")
		var serial = placement.get("serial")
		var rotation = placement.get("rotation_quadrants")
		var position = placement.get("position")
		if typeof(equipment_type) != TYPE_STRING or not EquipmentCatalogScript.is_valid(equipment_type):
			return _result(false, "Lagringen inneholder ukjent prosessutstyr.")
		if not _is_integer_number(serial) or int(serial) < 1 or int(serial) > MAX_BUILD_SERIAL:
			return _result(false, "En bygd enhet har ugyldig serienummer.")
		if not _is_integer_number(rotation) or int(rotation) < 0 or int(rotation) > 3:
			return _result(false, "En bygd enhet har ugyldig rotasjon.")
		if not _valid_vector(position, 3):
			return _result(false, "En bygd enhet har ugyldig posisjon.")
		var unit_id := "built_%s_%d" % [equipment_type, int(serial)]
		if unit_types.has(unit_id):
			return _result(false, "Lagringen inneholder dupliserte enhets-ID-er.")
		if not _placement_inside_build_area(equipment_type, int(rotation), position):
			return _result(false, "%s er plassert utenfor byggeområdet." % unit_id)
		unit_types[unit_id] = equipment_type
		maximum_serial = maxi(maximum_serial, int(serial))
	if int(state["build_serial_number"]) < maximum_serial:
		return _result(false, "Byggeserien kan gi dupliserte enhets-ID-er.")
	if not _placements_do_not_overlap(placements):
		return _result(false, "Lagrede byggeenheter overlapper.")

	var graph = ProcessNetworkScript.new()
	for unit_id in unit_types:
		var result: Dictionary = graph.register_unit(unit_id, unit_types[unit_id], unit_id)
		if not result["ok"]:
			return _result(false, result["message"])
	_register_site_units(graph)
	for edge in connections:
		if typeof(edge) != TYPE_DICTIONARY:
			return _result(false, "Et prosessrør har ugyldig format.")
		for field in ["from_unit", "from_port", "to_unit", "to_port"]:
			if typeof(edge.get(field)) != TYPE_STRING:
				return _result(false, "Et prosessrør mangler endepunkt.")
		var connect_result: Dictionary = graph.try_connect(
			edge["from_unit"], edge["from_port"], edge["to_unit"], edge["to_port"]
		)
		if not connect_result["ok"]:
			return _result(false, "Ugyldig lagret prosessrør: %s" % connect_result["message"])
	return {
		"ok": true,
		"message": "Byggedata er gyldige.",
		"unit_types": unit_types,
	}


static func _register_site_units(graph) -> void:
	for unit_id in SITE_UNIT_TYPES:
		graph.register_unit(unit_id, SITE_UNIT_TYPES[unit_id], unit_id)


static func _validate_built_refinery(state: Dictionary, unit_types: Dictionary, connections: Array) -> Dictionary:
	var logistics_result := _validate_site_logistics(state.get("site_logistics", {}))
	if not logistics_result["ok"]:
		return logistics_result
	for field in ["commissioning_batch_available", "commissioning_contract_complete"]:
		if typeof(state.get(field)) != TYPE_BOOL:
			return _result(false, "Ugyldig progresjonsstatus: %s." % field)
	if state["commissioning_contract_complete"] and state["commissioning_batch_available"]:
		return _result(false, "Oppstartsbatchen kan ikke være tilgjengelig etter fullført kontrakt.")
	for field in ["successful_sales", "product_inventory_revision"]:
		if not _is_integer_number(state.get(field)) or int(state[field]) < 0:
			return _result(false, "Ugyldig prosessverdi: %s." % field)
	if typeof(state.get("active_contract_id")) != TYPE_STRING:
		return _result(false, "Aktiv råoljekontrakt mangler.")
	var active_contract_id: String = state["active_contract_id"]
	if not active_contract_id.is_empty() and not CrudeCatalogScript.is_valid(active_contract_id):
		return _result(false, "Lagringen inneholder en ukjent råoljekontrakt.")
	if typeof(state.get("active_contract_bonus_available")) != TYPE_BOOL:
		return _result(false, "Kontraktbonusens status er ugyldig.")
	if state["active_contract_bonus_available"]:
		if active_contract_id.is_empty() or int(CrudeCatalogScript.definition(active_contract_id)["delivery_bonus"]) <= 0:
			return _result(false, "Lagringen inneholder en ugyldig kontraktbonus.")
	for field in ["report_crude_processed_l", "report_temperature_total", "report_crude_cost"]:
		if not _finite_number(state.get(field)) or float(state[field]) < 0.0:
			return _result(false, "Ugyldig prosessverdi: %s." % field)
	if state.has("report_flow_total"):
		var processed_l := float(state["report_crude_processed_l"])
		var minimum_flow_total := processed_l * float(BuiltRefineryModelScript.PUMP_FLOW_STEPS[0])
		var maximum_flow_total := processed_l * BuiltRefineryModelScript.PUMP_MAX_FLOW_LPS
		if (
			not _finite_number(state["report_flow_total"])
			or float(state["report_flow_total"]) < 0.0
			or float(state["report_flow_total"]) < minimum_flow_total - 0.1
			or float(state["report_flow_total"]) > maximum_flow_total + 0.1
		):
			return _result(false, "Ugyldig prosessverdi: report_flow_total.")
	if typeof(state.get("last_batch_report")) != TYPE_DICTIONARY:
		return _result(false, "Siste batchrapport har ugyldig format.")
	if not _validate_report(state["last_batch_report"]):
		return _result(false, "Siste batchrapport inneholder ugyldige verdier.")
	if typeof(state.get("equipment")) != TYPE_DICTIONARY:
		return _result(false, "Prosessutstyrets tilstand mangler.")
	var saved_equipment: Dictionary = state["equipment"]
	if saved_equipment.size() != unit_types.size():
		return _result(false, "Prosessutstyr og byggedata er ikke synkronisert.")
	for unit_id in unit_types:
		if typeof(saved_equipment.get(unit_id)) != TYPE_DICTIONARY:
			return _result(false, "%s mangler prosesstilstand." % unit_id)
		var unit_state: Dictionary = saved_equipment[unit_id]
		if unit_state.get("type") != unit_types[unit_id]:
			return _result(false, "%s har feil utstyrstype i prosesstilstanden." % unit_id)
		var equipment_result := _validate_equipment_state(unit_state)
		if not equipment_result["ok"]:
			return equipment_result
	for unit_id in saved_equipment:
		if not unit_types.has(unit_id):
			return _result(false, "Prosesstilstanden inneholder ukjent utstyr.")
	if state.has("product_allocations"):
		if typeof(state["product_allocations"]) != TYPE_DICTIONARY:
			return _result(false, "Lagrede produkttildelinger har ugyldig format.")
		for header_id in state["product_allocations"]:
			var allocation: Variant = state["product_allocations"][header_id]
			if (
				typeof(header_id) != TYPE_STRING
				or unit_types.get(header_id, "") != "product_header"
				or typeof(allocation) != TYPE_DICTIONARY
				or typeof(allocation.get("selected_tank_id", "")) != TYPE_STRING
			):
				return _result(false, "Lagret produkttildeling er ugyldig.")
			var selected_tank_id: String = allocation.get("selected_tank_id", "")
			if not selected_tank_id.is_empty() and unit_types.get(selected_tank_id, "") != "tank":
				return _result(false, "Lagret produkttildeling peker ikke på en tank.")
	var semantic_network := ProcessNetworkScript.new()
	for unit_id in unit_types:
		var unit_state: Dictionary = saved_equipment[unit_id]
		var intent := ""
		if unit_state["type"] == "tank":
			intent = String(unit_state.get("material_intent", ""))
			if intent.is_empty() and float(unit_state["volume_l"]) > 0.001:
				intent = String(unit_state["contents"])
		semantic_network.register_unit(unit_id, unit_types[unit_id], unit_id, intent)
	_register_site_units(semantic_network)
	for edge in connections:
		semantic_network.try_connect(edge["from_unit"], edge["from_port"], edge["to_unit"], edge["to_port"])
	var atmospheric_tanks := {}
	for route in semantic_network.atmospheric_routes():
		atmospheric_tanks[route["source"]] = true
		for product_tank in route["products"].values():
			atmospheric_tanks[product_tank] = true
	var has_atmospheric_batch_material := false
	for tank_id in atmospheric_tanks:
		var tank_state: Dictionary = saved_equipment[tank_id]
		if tank_state["type"] == "tank" and float(tank_state["volume_l"]) > 0.001:
			has_atmospheric_batch_material = true
			break
	var has_tracking := (
		float(state["report_crude_processed_l"]) > 0.001
		or float(state["report_temperature_total"]) > 0.001
		or float(state.get("report_flow_total", 0.0)) > 0.001
		or float(state["report_crude_cost"]) > 0.001
	)
	if (has_atmospheric_batch_material or has_tracking) and active_contract_id.is_empty():
		return _result(false, "Materiale mangler en aktiv råoljekontrakt.")
	if not has_atmospheric_batch_material and not has_tracking and not active_contract_id.is_empty():
		return _result(false, "En aktiv råoljekontrakt finnes uten batchmateriale.")
	return _result(true, "Bygd prosesstilstand er gyldig.")


static func _validate_site_logistics(state) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return _result(false, "Terminaltilstanden har ugyldig format.")
	if state.is_empty():
		return _result(true, "Eldre lagring uten terminaltilstand.")
	var pending = state.get("pending_intake_delivery", {})
	if typeof(pending) != TYPE_DICTIONARY:
		return _result(false, "CI-101-leveransen har ugyldig format.")
	var contract_id = pending.get("contract_id", "")
	var volume_l = pending.get("volume_l", 0.0)
	if typeof(contract_id) != TYPE_STRING or not _finite_number(volume_l) or not _in_range(volume_l, 0.0, BuiltRefineryModelScript.BATCH_VOLUME_L):
		return _result(false, "CI-101-leveransen inneholder ugyldige verdier.")
	if float(volume_l) > 0.001 and not CrudeCatalogScript.is_valid(contract_id):
		return _result(false, "CI-101-leveransen mangler gyldig råoljetype.")
	if float(volume_l) <= 0.001 and not contract_id.is_empty():
		return _result(false, "Tom CI-101-leveranse kan ikke ha råoljetype.")
	return _result(true, "CI-101-leveranse er gyldig.")


static func _validate_equipment_state(state: Dictionary) -> Dictionary:
	match state["type"]:
		"tank":
			for field in ["volume_l", "temperature_c", "quality_percent", "crude_cost_per_l"]:
				if not _finite_number(state.get(field)):
					return _result(false, "En lagret tank har ugyldig %s." % field)
			if not _in_range(state["volume_l"], 0.0, 1000.0):
				return _result(false, "En lagret tank overskrider kapasiteten.")
			if state.get("contents") not in ["empty", "crude", "light", "diesel", "heavy", "vacuum_gas_oil", "vacuum_residue", "gasoline_blendstock", "lpg", "light_cycle_oil"]:
				return _result(false, "En lagret tank har ukjent innhold.")
			if float(state["volume_l"]) > 0.001 and state["contents"] == "empty":
				return _result(false, "En lagret tank har volum uten innhold.")
			if state.has("material_intent"):
				if typeof(state["material_intent"]) != TYPE_STRING or state["material_intent"] not in ["", "crude", "light", "diesel", "heavy", "vacuum_gas_oil", "vacuum_residue", "gasoline_blendstock", "lpg", "light_cycle_oil"]:
					return _result(false, "En lagret tank har ukjent materialintensjon.")
				if float(state["volume_l"]) > 0.001 and state["material_intent"] != "" and state["material_intent"] != state["contents"]:
					return _result(false, "En lagret tank har innhold som ikke stemmer med materialintensjonen.")
			if not _in_range(state["temperature_c"], -50.0, 500.0) or not _in_range(state["quality_percent"], 0.0, 100.0):
				return _result(false, "En lagret tank har ugyldig temperatur eller kvalitet.")
			if not _in_range(state["crude_cost_per_l"], 0.0, 1000.0):
				return _result(false, "En lagret tank har ugyldig råoljekost.")
			if state.has("sulfur_ppm") and (not _finite_number(state["sulfur_ppm"]) or not _in_range(state["sulfur_ppm"], 0.0, 1000000.0)):
				return _result(false, "En lagret tank har ugyldig svovelinnhold.")
		"pump":
			if state.has("flow_setpoint_lps"):
				if not _finite_number(state["flow_setpoint_lps"]):
					return _result(false, "En lagret pumpe har ugyldig flowmål.")
				var flow_setpoint := float(state["flow_setpoint_lps"])
				if not BuiltRefineryModelScript.PUMP_FLOW_STEPS.has(flow_setpoint):
					return _result(false, "En lagret pumpe har ukjent flowmål.")
			if state.has("condition_percent"):
				if not _finite_number(state["condition_percent"]) or not _in_range(state["condition_percent"], 0.0, 100.0):
					return _result(false, "En lagret pumpe har ugyldig condition.")
			if state.has("fault_id") and state["fault_id"] not in ["", "blocked_filter"]:
				return _result(false, "En lagret pumpe har ukjent driftsavvik.")
			if state.has("fault_inspected") and typeof(state["fault_inspected"]) != TYPE_BOOL:
				return _result(false, "En lagret pumpe har ugyldig serviceinspeksjon.")
			if state.has("fault_triggered") and typeof(state["fault_triggered"]) != TYPE_BOOL:
				return _result(false, "En lagret pumpe har ugyldig servicehistorikk.")
			if state.has("processed_since_service_l"):
				if not _finite_number(state["processed_since_service_l"]) or not _in_range(state["processed_since_service_l"], 0.0, 1000000.0):
					return _result(false, "En lagret pumpe har ugyldig serviceteller.")
		"valve":
			if typeof(state.get("open")) != TYPE_BOOL:
				return _result(false, "En lagret ventil har ugyldig status.")
		"heater":
			if not _finite_number(state.get("setpoint_c")) or not _finite_number(state.get("temperature_c")):
				return _result(false, "En lagret varmeenhet har ugyldig temperatur.")
			if not _in_range(state["setpoint_c"], 0.0, 250.0) or not _in_range(state["temperature_c"], -50.0, 500.0):
				return _result(false, "En lagret varmeenhet er utenfor temperaturgrensene.")
			if state.has("control_mode") and state["control_mode"] not in ["manual", "auto"]:
				return _result(false, "En lagret varmeenhet har ukjent kontrollmodus.")
			if state.has("output_percent") and (
				not _finite_number(state["output_percent"])
				or not _in_range(state["output_percent"], 0.0, 100.0)
			):
				return _result(false, "En lagret varmeenhet har ugyldig varmeutgang.")
		"column":
			if not _finite_number(state.get("processed_total_l")) or float(state["processed_total_l"]) < 0.0:
				return _result(false, "En lagret kolonne har ugyldig prosessteller.")
		"treatment":
			if typeof(state.get("running")) != TYPE_BOOL or not _finite_number(state.get("processed_total_l")) or float(state["processed_total_l"]) < 0.0:
				return _result(false, "En lagret dieselbehandler har ugyldig tilstand.")
		"vacuum_distillation", "catalytic_cracking":
			if not _finite_number(state.get("processed_total_l")) or float(state["processed_total_l"]) < 0.0:
				return _result(false, "En lagret vakuumdestillasjon har ugyldig prosessteller.")
		"header", "product_header", "power_unit":
			pass
		_:
			return _result(false, "Ukjent lagret utstyrstype.")
	return _result(true, "Utstyrstilstanden er gyldig.")


static func _validate_report(report: Dictionary) -> bool:
	if report.is_empty():
		return true
	for field in [
		"crude_processed_l", "light_l", "diesel_l", "heavy_l", "diesel_quality_percent",
		"average_temperature_c", "ideal_temperature_c", "diesel_target_l",
		"required_quality_percent", "product_revenue", "delivery_bonus",
		"revenue", "crude_cost", "net_profit",
	]:
		if not _finite_number(report.get(field)):
			return false
	for field in ["crude_processed_l", "light_l", "diesel_l", "heavy_l", "product_revenue", "delivery_bonus", "revenue", "crude_cost"]:
		if float(report[field]) < 0.0:
			return false
	if not _in_range(report["diesel_quality_percent"], 0.0, 100.0):
		return false
	if report.has("average_flow_lps") and not _in_range(
		report["average_flow_lps"],
		float(BuiltRefineryModelScript.PUMP_FLOW_STEPS[0]),
		BuiltRefineryModelScript.PUMP_MAX_FLOW_LPS
	):
		return false
	if typeof(report.get("contract_id")) != TYPE_STRING or not CrudeCatalogScript.is_valid(report["contract_id"]):
		return false
	if typeof(report.get("contract_name")) != TYPE_STRING or String(report["contract_name"]).is_empty():
		return false
	var profile := CrudeCatalogScript.definition(report["contract_id"])
	if (
		not is_equal_approx(float(report["ideal_temperature_c"]), float(profile["ideal_temperature_c"]))
		or not is_equal_approx(float(report["diesel_target_l"]), float(profile["diesel_target_l"]))
		or not is_equal_approx(float(report["required_quality_percent"]), float(profile["minimum_quality_percent"]))
	):
		return false
	var product_total := float(report["light_l"]) + float(report["diesel_l"]) + float(report["heavy_l"])
	if absf(float(report["crude_processed_l"]) - product_total) > 0.1:
		return false
	if int(round(float(report["net_profit"]))) != int(round(float(report["revenue"]))) - int(round(float(report["crude_cost"]))):
		return false
	if int(round(float(report["revenue"]))) != int(round(float(report["product_revenue"]))) + int(round(float(report["delivery_bonus"]))):
		return false
	var delivery_fields := [
		"order_name", "delivery_product", "delivery_product_name",
		"delivery_target_l", "delivery_volume_l",
	]
	var has_delivery_fields := false
	for field in delivery_fields:
		if report.has(field):
			has_delivery_fields = true
			break
	if has_delivery_fields:
		for field in delivery_fields:
			if not report.has(field):
				return false
		if (
			typeof(report["order_name"]) != TYPE_STRING
			or typeof(report["delivery_product"]) != TYPE_STRING
			or typeof(report["delivery_product_name"]) != TYPE_STRING
			or not _finite_number(report["delivery_target_l"])
			or not _finite_number(report["delivery_volume_l"])
		):
			return false
		var delivery_product: String = report["delivery_product"]
		if (
			delivery_product != String(profile["delivery_product"])
			or String(report["order_name"]) != String(profile["order_name"])
			or String(report["delivery_product_name"]) != String(profile["delivery_product_name"])
			or not is_equal_approx(float(report["delivery_target_l"]), float(profile["delivery_target_l"]))
			or not is_equal_approx(float(report["delivery_volume_l"]), float(report[delivery_product + "_l"]))
			or float(report["delivery_volume_l"]) + 0.01 < float(report["delivery_target_l"])
		):
			return false
	return typeof(report.get("spec_status")) == TYPE_STRING


static func _validate_player(state: Dictionary) -> Dictionary:
	if not _valid_vector(state.get("position"), 3) or not _finite_number(state.get("rotation_y")):
		return _result(false, "Spillerposisjonen er ugyldig.")
	var position: Array = state["position"]
	if not _in_range(position[0], -28.0, 28.0) or not _in_range(position[1], -5.0, 20.0) or not _in_range(position[2], -20.0, 46.0):
		return _result(false, "Spillerposisjonen er utenfor spillområdet.")
	return _result(true, "Spillerposisjonen er gyldig.")


static func _placement_inside_build_area(equipment_type: String, rotation: int, position: Array) -> bool:
	var size: Vector3 = EquipmentCatalogScript.definition(equipment_type)["size"]
	var footprint := Vector2(size.x, size.z) if rotation % 2 == 0 else Vector2(size.z, size.x)
	var center := Vector2(float(position[0]), float(position[2]))
	var half := footprint * 0.5
	var expected_y := 0.16 + size.y * 0.5
	return (
		absf(float(position[1]) - expected_y) <= 0.1
		and center.x - half.x >= BUILD_BOUNDS.position.x
		and center.y - half.y >= BUILD_BOUNDS.position.y
		and center.x + half.x <= BUILD_BOUNDS.end.x
		and center.y + half.y <= BUILD_BOUNDS.end.y
	)


static func _placements_do_not_overlap(placements: Array) -> bool:
	for left_index in placements.size():
		var left: Dictionary = placements[left_index]
		var left_size: Vector3 = EquipmentCatalogScript.definition(left["type"])["size"]
		var left_footprint := Vector2(left_size.x, left_size.z)
		if int(left["rotation_quadrants"]) % 2 != 0:
			left_footprint = Vector2(left_size.z, left_size.x)
		var left_center := Vector2(float(left["position"][0]), float(left["position"][2]))
		for right_index in range(left_index + 1, placements.size()):
			var right: Dictionary = placements[right_index]
			var right_size: Vector3 = EquipmentCatalogScript.definition(right["type"])["size"]
			var right_footprint := Vector2(right_size.x, right_size.z)
			if int(right["rotation_quadrants"]) % 2 != 0:
				right_footprint = Vector2(right_size.z, right_size.x)
			var right_center := Vector2(float(right["position"][0]), float(right["position"][2]))
			if (
				absf(left_center.x - right_center.x) < (left_footprint.x + right_footprint.x) * 0.5 + 0.35
				and absf(left_center.y - right_center.y) < (left_footprint.y + right_footprint.y) * 0.5 + 0.35
			):
				return false
	return true


static func _valid_vector(value, expected_size: int) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != expected_size:
		return false
	for component in value:
		if not _finite_number(component):
			return false
	return true


static func _finite_number(value) -> bool:
	return _is_number(value) and not is_nan(float(value)) and not is_inf(float(value))


static func _is_number(value) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]


static func _is_integer_number(value) -> bool:
	return _finite_number(value) and float(value) == float(int(value))


static func _in_range(value, minimum: float, maximum: float) -> bool:
	return _finite_number(value) and float(value) >= minimum and float(value) <= maximum


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
