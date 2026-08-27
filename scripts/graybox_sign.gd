class_name GrayboxSign
extends Node3D

## Reusable two-line physical sign for graybox navigation.
## Text remains mounted to its board; it never billboards independently.

const MAX_TEXT_LENGTH := 24
const MAX_LINES := 2
const DEFAULT_BOARD_SIZE := Vector2(3.2, 0.8)
const BOARD_THICKNESS := 0.12
const POST_THICKNESS := 0.14
const TEXT_OFFSET := 0.007

var primary_text := ""
var secondary_text := ""
var direction := ""
var board_size := DEFAULT_BOARD_SIZE
var label: Label3D


func configure(
	primary: String,
	secondary: String = "",
	arrow: String = "",
	size: Vector2 = DEFAULT_BOARD_SIZE,
	include_posts: bool = true
) -> void:
	primary_text = primary.replace("\n", " ").strip_edges().left(MAX_TEXT_LENGTH)
	secondary_text = secondary.replace("\n", " ").strip_edges().left(MAX_TEXT_LENGTH)
	direction = arrow.strip_edges().left(2)
	board_size = Vector2(maxf(size.x, 2.0), maxf(size.y, 0.7))
	set_meta("graybox_sign", true)
	set_meta("board_size", board_size)
	set_meta("line_count", mini(MAX_LINES, 1 + int(not secondary_text.is_empty())))

	var board_center_y := 1.55 if include_posts else 0.0
	if include_posts:
		_create_static_box(
			"Post",
			Vector3(
				0.0,
				board_center_y * 0.5,
				BOARD_THICKNESS * 0.5 + POST_THICKNESS * 0.5
			),
			Vector3(POST_THICKNESS, board_center_y, POST_THICKNESS),
			Color("#3f4749")
		)
	_create_static_box(
		"Board",
		Vector3(0.0, board_center_y, 0.0),
		Vector3(board_size.x, board_size.y, BOARD_THICKNESS),
		Color("#30434a")
	)

	label = Label3D.new()
	label.name = "SignLabel"
	label.text = _display_text()
	# Mount and face the label toward local -Z so board and text retain one
	# physical orientation instead of drifting independently toward the camera.
	label.position = Vector3(0.0, board_center_y, -BOARD_THICKNESS * 0.5 - TEXT_OFFSET)
	label.rotation_degrees.y = 180.0
	label.font_size = 30
	label.pixel_size = 0.007
	label.modulate = Color("#f1e4bc")
	label.outline_modulate = Color("#172126")
	label.outline_size = 5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	add_child(label)


func _display_text() -> String:
	var first_line := primary_text
	var second_line := secondary_text
	if not direction.is_empty():
		if second_line.is_empty():
			first_line += "  " + direction
		else:
			second_line += "  " + direction
	return first_line if second_line.is_empty() else first_line + "\n" + second_line


func _create_static_box(node_name: String, box_position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	# Graybox navigation helpers should not introduce large or unstable moving
	# shadow regions in the playable world.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
