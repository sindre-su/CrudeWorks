class_name SaveSystem
extends RefCounted

const EquipmentCatalogScript = preload("res://scripts/equipment_catalog.gd")
const ProcessNetworkScript = preload("res://scripts/process_network.gd")

const FORMAT_VERSION := 1
const DEFAULT_PATH := "user://crudeworks_save.json"
const BUILD_BOUNDS := Rect2(-14.0, 10.5, 28.0, 20.0)
const MAX_UNITS := 128
const MAX_CONNECTIONS := 256
const MAX_BUILD_SERIAL := 1000000


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
	file.close()

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
		construction_result["unit_types"]
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


static func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(false, "Lagringsfilen finnes ikke.")
	var json_text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return _result(false, "Lagringsfilen inneholder ugyldig JSON.")
	var parsed = json.data
	var validation := validate_snapshot(parsed)
	if not validation["ok"]:
		return validation
	return {
		"ok": true,
		"message": "Lagringen er lest.",
		"data": parsed,
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


static func _validate_built_refinery(state: Dictionary, unit_types: Dictionary) -> Dictionary:
	for field in ["commissioning_batch_available", "commissioning_contract_complete"]:
		if typeof(state.get(field)) != TYPE_BOOL:
			return _result(false, "Ugyldig progresjonsstatus: %s." % field)
	for field in ["successful_sales", "product_inventory_revision"]:
		if not _is_integer_number(state.get(field)) or int(state[field]) < 0:
			return _result(false, "Ugyldig prosessverdi: %s." % field)
	for field in ["report_crude_processed_l", "report_temperature_total", "report_crude_cost"]:
		if not _finite_number(state.get(field)) or float(state[field]) < 0.0:
			return _result(false, "Ugyldig prosessverdi: %s." % field)
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
	return _result(true, "Bygd prosesstilstand er gyldig.")


static func _validate_equipment_state(state: Dictionary) -> Dictionary:
	match state["type"]:
		"tank":
			for field in ["volume_l", "temperature_c", "quality_percent", "crude_cost_per_l"]:
				if not _finite_number(state.get(field)):
					return _result(false, "En lagret tank har ugyldig %s." % field)
			if not _in_range(state["volume_l"], 0.0, 1000.0):
				return _result(false, "En lagret tank overskrider kapasiteten.")
			if state.get("contents") not in ["empty", "crude", "light", "diesel", "heavy"]:
				return _result(false, "En lagret tank har ukjent innhold.")
			if float(state["volume_l"]) > 0.001 and state["contents"] == "empty":
				return _result(false, "En lagret tank har volum uten innhold.")
			if not _in_range(state["temperature_c"], -50.0, 500.0) or not _in_range(state["quality_percent"], 0.0, 100.0):
				return _result(false, "En lagret tank har ugyldig temperatur eller kvalitet.")
			if not _in_range(state["crude_cost_per_l"], 0.0, 1000.0):
				return _result(false, "En lagret tank har ugyldig råoljekost.")
		"pump":
			pass
		"valve":
			if typeof(state.get("open")) != TYPE_BOOL:
				return _result(false, "En lagret ventil har ugyldig status.")
		"heater":
			if not _finite_number(state.get("setpoint_c")) or not _finite_number(state.get("temperature_c")):
				return _result(false, "En lagret varmeenhet har ugyldig temperatur.")
			if not _in_range(state["setpoint_c"], 0.0, 300.0) or not _in_range(state["temperature_c"], -50.0, 500.0):
				return _result(false, "En lagret varmeenhet er utenfor temperaturgrensene.")
		"column":
			if not _finite_number(state.get("processed_total_l")) or float(state["processed_total_l"]) < 0.0:
				return _result(false, "En lagret kolonne har ugyldig prosessteller.")
		_:
			return _result(false, "Ukjent lagret utstyrstype.")
	return _result(true, "Utstyrstilstanden er gyldig.")


static func _validate_report(report: Dictionary) -> bool:
	if report.is_empty():
		return true
	for field in [
		"crude_processed_l", "light_l", "diesel_l", "heavy_l", "diesel_quality_percent",
		"average_temperature_c", "revenue", "crude_cost", "net_profit",
	]:
		if not _finite_number(report.get(field)):
			return false
	for field in ["crude_processed_l", "light_l", "diesel_l", "heavy_l", "revenue", "crude_cost"]:
		if float(report[field]) < 0.0:
			return false
	if not _in_range(report["diesel_quality_percent"], 0.0, 100.0):
		return false
	var product_total := float(report["light_l"]) + float(report["diesel_l"]) + float(report["heavy_l"])
	if absf(float(report["crude_processed_l"]) - product_total) > 0.1:
		return false
	if int(round(float(report["net_profit"]))) != int(round(float(report["revenue"]))) - int(round(float(report["crude_cost"]))):
		return false
	return typeof(report.get("spec_status")) == TYPE_STRING


static func _validate_player(state: Dictionary) -> Dictionary:
	if not _valid_vector(state.get("position"), 3) or not _finite_number(state.get("rotation_y")):
		return _result(false, "Spillerposisjonen er ugyldig.")
	var position: Array = state["position"]
	if not _in_range(position[0], -30.0, 30.0) or not _in_range(position[1], -5.0, 20.0) or not _in_range(position[2], -20.0, 45.0):
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
