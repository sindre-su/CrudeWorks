class_name FlowVisual
extends Node3D

const MARKER_COUNT := 7

var start_position := Vector3.ZERO
var end_position := Vector3.ZERO
var progress := 0.0
var speed := 0.65
var markers: Array[MeshInstance3D] = []


func configure(from: Vector3, to: Vector3, flow_color: Color) -> void:
	start_position = from
	end_position = to

	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.095
	marker_mesh.height = 0.19
	marker_mesh.radial_segments = 12
	marker_mesh.rings = 6

	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = flow_color
	marker_material.emission_enabled = true
	marker_material.emission = flow_color
	marker_material.emission_energy_multiplier = 2.2
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for index in MARKER_COUNT:
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.material_override = marker_material
		add_child(marker)
		markers.append(marker)

	visible = false
	_update_marker_positions()


func set_flow(enabled: bool, normalized_rate := 1.0) -> void:
	visible = enabled
	speed = lerpf(0.35, 1.15, clampf(normalized_rate, 0.0, 1.0))


func _process(delta: float) -> void:
	if not visible:
		return
	progress = fmod(progress + delta * speed, 1.0)
	_update_marker_positions()


func _update_marker_positions() -> void:
	for index in markers.size():
		var offset := float(index) / float(MARKER_COUNT)
		var position_on_line := fmod(progress + offset, 1.0)
		markers[index].position = start_position.lerp(end_position, position_on_line)

