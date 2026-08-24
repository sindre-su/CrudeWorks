class_name FeedAllocation
extends RefCounted

# Owns the one deliberate feed choice for a source. It intentionally knows
# nothing about valves, pipes or fluid transfer; the refinery model supplies
# eligible train pump IDs and decides when the selected route may operate.
var source_id := ""
var eligible_train_ids: Array[String] = []
var selected_train_id := ""


func configure(p_source_id: String, candidates: Array[String]) -> void:
	var had_candidates := not eligible_train_ids.is_empty()
	source_id = p_source_id
	eligible_train_ids = candidates.duplicate()
	if not selected_train_id in eligible_train_ids:
		selected_train_id = ""
	# Existing one-route tanks remain frictionless. A removed selected route is
	# never silently rerouted to another candidate.
	if not had_candidates and eligible_train_ids.size() == 1:
		selected_train_id = eligible_train_ids[0]


func select(train_id: String, source_pump_running: bool) -> Dictionary:
	if source_pump_running:
		return {"ok": false, "message": "Stopp kildepumpen før fôringsruten endres."}
	if not train_id.is_empty() and not train_id in eligible_train_ids:
		return {"ok": false, "message": "Den valgte prosesslinjen kan ikke motta denne råoljekilden."}
	selected_train_id = train_id
	return {"ok": true, "message": "Fôringsrute valgt." if not train_id.is_empty() else "Ingen fôringsrute er valgt."}


func is_selected(train_id: String) -> bool:
	return selected_train_id == train_id


func save_state() -> Dictionary:
	return {"source_id": source_id, "eligible_train_ids": eligible_train_ids, "selected_train_id": selected_train_id}
