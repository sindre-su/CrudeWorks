class_name CrudeContractCatalog
extends RefCounted

const DEFAULT_ID := "standard"
const ORDER := ["standard", "heavy", "sour"]
static func definition(contract_id: String) -> Dictionary:
	match contract_id:
		"standard":
			return {
				"id": "standard",
				"display_name": "Standard råolje",
				"short_name": "STANDARD",
				"purchase_cost": 300,
				"ideal_temperature_c": 200.0,
				"minimum_quality_percent": 90.0,
				"maximum_sulfur_ppm": 50.0,
				"diesel_sulfur_ppm": 10.0,
				"quality_penalty_per_degree": 1.15,
				"description": "1 000 L feed • mål 200 °C",
			}
		"heavy":
			return {
				"id": "heavy",
				"display_name": "Tung råolje",
				"short_name": "TUNG",
				"purchase_cost": 180,
				"ideal_temperature_c": 230.0,
				"minimum_quality_percent": 90.0,
				"maximum_sulfur_ppm": 50.0,
				"diesel_sulfur_ppm": 10.0,
				"quality_penalty_per_degree": 1.2,
				"description": "1 000 L feed • mål 230 °C",
			}
		"sour":
			return {
				"id": "sour",
				"display_name": "Sour råolje",
				"short_name": "SOUR",
				"purchase_cost": 120,
				"ideal_temperature_c": 200.0,
				"minimum_quality_percent": 90.0,
				"maximum_sulfur_ppm": 50.0,
				"diesel_sulfur_ppm": 500.0,
				"quality_penalty_per_degree": 1.15,
				"description": "1 000 L feed • mål 200 °C • svovelrik diesel krever behandling",
			}
	return {}


static func is_valid(contract_id: String) -> bool:
	return not definition(contract_id).is_empty()


static func expected_yield_description(contract_id: String) -> String:
	var data := definition(contract_id)
	if data.is_empty():
		return ""
	var fractions := fractions_for_temperature(contract_id, float(data["ideal_temperature_c"]))
	return "Forventet CDU-utbytte: Naphtha %.0f %% / Diesel %.0f %% / Tung %.0f %%" % [
		fractions.x * 100.0, fractions.y * 100.0, fractions.z * 100.0,
	]


static func fractions_for_temperature(contract_id: String, temperature_c: float) -> Vector3:
	if not is_valid(contract_id):
		return Vector3.ZERO
	if contract_id == "heavy":
		if temperature_c < 200.0:
			return Vector3(0.05, 0.12, 0.83)
		if temperature_c < 220.0:
			return Vector3(0.10, 0.18, 0.72)
		if temperature_c <= 240.0:
			return Vector3(0.15, 0.22, 0.63)
		if temperature_c <= 250.0:
			return Vector3(0.28, 0.20, 0.52)
		return Vector3(0.40, 0.15, 0.45)
	# Standard and Sour use the proven v0.6 curve; Sour differs by specification.
	if temperature_c < 170.0:
		return Vector3(0.08, 0.12, 0.80)
	if temperature_c < 185.0:
		return Vector3(0.20, 0.25, 0.55)
	if temperature_c <= 215.0:
		return Vector3(0.30, 0.35, 0.35)
	if temperature_c <= 225.0:
		return Vector3(0.40, 0.30, 0.30)
	return Vector3(0.55, 0.20, 0.25)


static func approved_temperature_range(
	contract_id: String,
	flow_lps := 10.0,
	rated_flow_lps := 10.0
) -> Vector2:
	var data := definition(contract_id)
	if data.is_empty():
		return Vector2.ZERO
	var flow_factor := _quality_flow_factor(flow_lps, rated_flow_lps)
	var maximum_deviation := (
		(100.0 - float(data["minimum_quality_percent"]))
		/ (float(data["quality_penalty_per_degree"]) * flow_factor)
	)
	return Vector2(
		float(data["ideal_temperature_c"]) - maximum_deviation,
		float(data["ideal_temperature_c"]) + maximum_deviation
	)


static func diesel_quality(contract_id: String, temperature_c: float, flow_lps: float, rated_flow_lps: float) -> float:
	var data := definition(contract_id)
	if data.is_empty():
		return 0.0
	var temperature_penalty := (
		absf(temperature_c - float(data["ideal_temperature_c"]))
		* float(data["quality_penalty_per_degree"])
		* _quality_flow_factor(flow_lps, rated_flow_lps)
	)
	return clampf(100.0 - temperature_penalty, 0.0, 100.0)


static func _quality_flow_factor(flow_lps: float, rated_flow_lps: float) -> float:
	if rated_flow_lps <= 0.001:
		return 1.0
	return clampf(flow_lps / rated_flow_lps, 0.75, 1.5)
