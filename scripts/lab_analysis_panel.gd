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
	var footer := "Esc — behold produktet\nGodkjent produkt sendes fra PD-101"
	if not approved:
		footer = (
			"Esc — fortsett produksjonen; ny prøve kreves"
			if analysis.get("status", "OFF-SPEC") == "IKKE KLAR"
			else "Esc — behold produktet\nR x2 etter lukking — sikker tømming"
		)
	result_label.text = (
		"LAB-101 — DIESELPRØVE\n\n"
		+ "Prøve        %s — %s RÅOLJE\n" % [analysis["sample_id"], String(analysis["crude_name"]).to_upper()]
		+ "Diesel i tank %6.0f L\n" % analysis["volume_l"]
		+ "Kvalitet     %6.1f %% / krav ≥ %.1f %%\n" % [analysis["quality_percent"], analysis["required_quality_percent"]]
		+ "Svovel       %6.0f ppm / krav ≤ %.0f ppm\n" % [analysis.get("sulfur_ppm", 0.0), analysis.get("maximum_sulfur_ppm", 50.0)]
		+ "Prosess snitt %5.0f °C | flow %.1f L/s  (mål %.0f °C)\n\n" % [
			analysis["average_temperature_c"], analysis.get("average_flow_lps", 10.0),
			analysis["ideal_temperature_c"],
		]
		+ "LAB vurderer produktkvalitet; kontrakt og spotsalg håndteres ved PD-101.\n"
		+ "STATUS       %s\n" % analysis["status"]
		+ ("AVVIK        %s\n" % analysis["deviation"] if not approved else "")
		+ "\n" + footer
	)


func close_panel() -> void:
	visible = false
	analysis = {}
