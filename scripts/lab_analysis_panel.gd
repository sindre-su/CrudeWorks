class_name LabAnalysisPanel
extends PanelContainer

var analysis: Dictionary = {}
var result_label: Label


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -390.0
	offset_right = 390.0
	offset_top = -270.0
	offset_bottom = 270.0
	visible = false
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.add_theme_font_size_override("font_size", 22)
	result_label.add_theme_color_override("font_color", Color("d9f4ff"))
	result_label.add_theme_constant_override("line_spacing", 4)
	add_child(result_label)


func show_analysis(result: Dictionary) -> void:
	analysis = result.duplicate(true)
	visible = true
	var approved: bool = bool(analysis.get("approved", false))
	var footer := (
		"Enter — send batch (%s kr)\nEsc — behold produktet" % _money_text(int(analysis["revenue_preview"]))
		if approved
		else "Esc — behold produktet\nR x2 etter lukking — sikker tømming"
	)
	result_label.text = (
		"LAB-101 — DIESELPRØVE\n\n"
		+ "Prøve        %s — %s\n" % [analysis["sample_id"], String(analysis["contract_name"]).to_upper()]
		+ "Diesel       %6.0f L / krav %.0f L\n" % [analysis["volume_l"], analysis["required_volume_l"]]
		+ "Kvalitet     %6.1f %% / krav ≥ %.1f %%\n" % [analysis["quality_percent"], analysis["required_quality_percent"]]
		+ "Prosess      %6.0f °C snitt / %.0f °C mål\n\n" % [analysis["average_temperature_c"], analysis["ideal_temperature_c"]]
		+ "STATUS       %s\n" % analysis["status"]
		+ ("AVVIK        %s\n" % analysis["deviation"] if not approved else "")
		+ "\n" + footer
	)


func close_panel() -> void:
	visible = false
	analysis = {}


func can_dispatch() -> bool:
	return visible and bool(analysis.get("approved", false))


func _money_text(amount: int) -> String:
	var digits := str(absi(amount))
	var formatted := ""
	while digits.length() > 3:
		formatted = " " + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	formatted = digits + formatted
	return ("-" if amount < 0 else "") + formatted
