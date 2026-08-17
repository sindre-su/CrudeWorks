class_name ProcessPort
extends Node3D

var port_kind := "input"
var marker_material: StandardMaterial3D
var base_color := Color.WHITE


func configure(kind: String) -> void:
	port_kind = kind
	base_color = Color("4da6ff") if kind == "input" else Color("ff9b42")

	var marker := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mesh.radial_segments = 16
	mesh.rings = 8
	marker.mesh = mesh
	marker_material = StandardMaterial3D.new()
	marker_material.albedo_color = base_color
	marker_material.emission_enabled = true
	marker_material.emission = base_color
	marker_material.emission_energy_multiplier = 0.75
	marker.material_override = marker_material
	add_child(marker)

	var port_label := Label3D.new()
	port_label.text = "IN" if kind == "input" else "OUT"
	port_label.position = Vector3(0.0, 0.34, 0.0)
	port_label.font_size = 28
	port_label.outline_size = 8
	port_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	port_label.no_depth_test = true
	add_child(port_label)


func set_highlight(enabled: bool) -> void:
	if not is_instance_valid(marker_material):
		return
	marker_material.emission_energy_multiplier = 2.4 if enabled else 0.75
	marker_material.albedo_color = Color.WHITE if enabled else base_color

