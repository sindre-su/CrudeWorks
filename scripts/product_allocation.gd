class_name ProductAllocation
extends RefCounted

# Owns the deliberate storage choice for one physical product header. Topology
# supplies compatible destination tanks; the refinery model decides when it is
# safe to change the selected destination.
var header_id := ""
var product_id := ""
var eligible_tank_ids: Array[String] = []
var selected_tank_id := ""


func configure(p_header_id: String, p_product_id: String, candidates: Array[String]) -> void:
	header_id = p_header_id
	product_id = p_product_id
	eligible_tank_ids = candidates.duplicate()
	if not selected_tank_id in eligible_tank_ids:
		selected_tank_id = ""


func select(tank_id: String, producer_running: bool) -> Dictionary:
	if producer_running:
		return {"ok": false, "message": "Stopp prosessen før produktruten endres."}
	if not tank_id.is_empty() and not tank_id in eligible_tank_ids:
		return {"ok": false, "message": "Den valgte tanken er ikke tilgjengelig for dette produktet."}
	selected_tank_id = tank_id
	return {
		"ok": true,
		"message": "Produkttank valgt." if not tank_id.is_empty() else "Ingen produkttank er valgt.",
	}


func is_selected(tank_id: String) -> bool:
	return selected_tank_id == tank_id


func save_state() -> Dictionary:
	return {
		"header_id": header_id,
		"product_id": product_id,
		"eligible_tank_ids": eligible_tank_ids,
		"selected_tank_id": selected_tank_id,
	}
