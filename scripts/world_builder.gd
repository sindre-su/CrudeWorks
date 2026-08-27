class_name GrayboxWorldBuilder
extends Node3D

const WorldLayoutScript := preload("res://scripts/world_layout.gd")
const GrayboxSignScript := preload("res://scripts/graybox_sign.gd")

const COLOR_GROUND := Color("#405347")
const COLOR_BUFFER := Color("#26352f")
const COLOR_SEA := Color("#214d61")
const COLOR_FOREST := Color("#1e3228")
const COLOR_SERVICE_ROAD := Color("#414a50")
const COLOR_MAIN_ROAD := Color("#252c31")
const COLOR_PATH := Color("#897955")
const COLOR_PLATFORM := Color("#899197")
const COLOR_RESERVED := Color("#50545b")
const COLOR_LOGISTICS := Color("#717c78")
const COLOR_BOUNDARY := Color("#9c906b")
const COLOR_PROTOTYPE_PAD := Color("#65736d")
const COLOR_BUILD_PAD := Color("#526775")
const COLOR_FIXED_STRUCTURE := Color("#444c51")
const SURFACE_VISUAL_THICKNESS := 0.02

var prototype_build_area_label: Label3D
var area_nodes: Dictionary = {}
var road_nodes: Dictionary = {}
var path_nodes: Dictionary = {}
var orientation_nodes: Dictionary = {}
var landmark_nodes: Dictionary = {}
var area_labels: Array[Label3D] = []
var area_labels_visible := false


func build_world() -> void:
	_build_environment()
	_build_macro_terrain()
	_build_site_boundaries()
	_build_area_platforms()
	_build_roads()
	_build_paths()
	_build_prototype_pads()
	_build_starter_orientation()
	_build_landmark_placeholders()
	set_area_labels_visible(area_labels_visible)


func _build_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#76909a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d4e0df")
	env.ambient_light_energy = 0.68
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "NordicSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#fff0d0")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)


func _build_macro_terrain() -> void:
	var terrain_center := WorldLayoutScript.TERRAIN_BOUNDS.get_center()
	var terrain_size := WorldLayoutScript.TERRAIN_BOUNDS.size
	_create_static_box(
		"TerrainBuffer",
		Vector3(
			terrain_center.x,
			WorldLayoutScript.BASE_GRADE_ELEVATION - 0.25,
			terrain_center.y
		),
		Vector3(terrain_size.x, 0.5, terrain_size.y),
		COLOR_BUFFER
	)

	var world_center := WorldLayoutScript.WORLD_BOUNDS.get_center()
	var world_size := WorldLayoutScript.WORLD_BOUNDS.size
	_create_visual_box(
		"IndustrialGround",
		Vector3(world_center.x, WorldLayoutScript.BASE_GRADE_ELEVATION - 0.004, world_center.y),
		Vector3(world_size.x, 0.008, world_size.y),
		COLOR_GROUND
	)

	_create_visual_box(
		"SouthernSea",
		Vector3(world_center.x, -0.08, WorldLayoutScript.TERRAIN_BOUNDS.end.y + 45.0),
		Vector3(terrain_size.x + 120.0, 0.08, 90.0),
		COLOR_SEA
	)

	_create_visual_box(
		"NorthForestBorder",
		Vector3(world_center.x, 1.5, WorldLayoutScript.WORLD_BOUNDS.position.y - 15.0),
		Vector3(world_size.x + 60.0, 3.0, 28.0),
		COLOR_FOREST
	)
	_create_visual_box(
		"WestForestBorder",
		Vector3(WorldLayoutScript.WORLD_BOUNDS.position.x - 15.0, 1.5, world_center.y),
		Vector3(28.0, 3.0, world_size.y + 30.0),
		COLOR_FOREST
	)
	_create_visual_box(
		"EastForestBorder",
		Vector3(WorldLayoutScript.WORLD_BOUNDS.end.x + 15.0, 1.5, world_center.y),
		Vector3(28.0, 3.0, world_size.y + 30.0),
		COLOR_FOREST
	)


func _build_site_boundaries() -> void:
	var bounds := WorldLayoutScript.WORLD_BOUNDS
	var center := bounds.get_center()
	var wall_height := 2.2
	var wall_thickness := 0.5
	_create_static_box(
		"NorthBoundary",
		Vector3(center.x, wall_height * 0.5, bounds.position.y),
		Vector3(bounds.size.x, wall_height, wall_thickness),
		Color("#41564e")
	)
	_create_static_box(
		"WestBoundary",
		Vector3(bounds.position.x, wall_height * 0.5, center.y),
		Vector3(wall_thickness, wall_height, bounds.size.y),
		Color("#41564e")
	)
	_create_static_box(
		"EastBoundary",
		Vector3(bounds.end.x, wall_height * 0.5, center.y),
		Vector3(wall_thickness, wall_height, bounds.size.y),
		Color("#41564e")
	)
	_create_static_box(
		"SouthShoreBoundary",
		Vector3(center.x, 0.55, bounds.end.y),
		Vector3(bounds.size.x, 1.1, wall_thickness),
		Color("#50605c")
	)


func _build_area_platforms() -> void:
	for area: Dictionary in WorldLayoutScript.AREA_SPECS:
		var area_id := String(area["id"])
		var center: Vector2 = area["center"]
		var dimensions: Vector2 = area["dimensions"]
		var elevation := float(area["elevation"])
		var platform_color := _platform_color(String(area["kind"]))
		var area_root := Node3D.new()
		area_root.name = "Area_%s" % area_id
		area_root.set_meta("area_id", area_id)
		add_child(area_root)
		area_nodes[area_id] = area_root
		area_root.set_meta(
			"surface_role",
			"future_locked" if String(area["kind"]) == "reserved" else "process_platform"
		)

		if bool(area["render_platform"]):
			if elevation > 0.05:
				_create_static_box(
					"Platform",
					Vector3(center.x, elevation * 0.5, center.y),
					Vector3(dimensions.x, elevation, dimensions.y),
					platform_color,
					area_root
				)
				var access_sides: Array = area.get("access_sides", [area.get("access_side", "south")])
				for access_side in access_sides:
					_create_access_ramp(area, String(access_side), area_root)
			else:
				_create_visual_box(
					"GroundLevelFootprint",
					Vector3(center.x, WorldLayoutScript.BASE_GRADE_ELEVATION + 0.006, center.y),
					Vector3(dimensions.x, 0.012, dimensions.y),
					platform_color,
					area_root
				)

		_create_area_outline(area, area_root)
		_create_area_label(area, area_root)


func _build_roads() -> void:
	for road: Dictionary in WorldLayoutScript.ROAD_SPECS:
		var road_id := String(road["id"])
		var center: Vector2 = road["center"]
		var dimensions: Vector2 = road["dimensions"]
		var road_class := String(road["class"])
		var color := COLOR_MAIN_ROAD if road_class == "main" else COLOR_SERVICE_ROAD
		var road_node := _create_visual_box(
			road_id,
			Vector3(center.x, WorldLayoutScript.ROAD_ELEVATION, center.y),
			Vector3(dimensions.x, SURFACE_VISUAL_THICKNESS, dimensions.y),
			color
		)
		road_node.set_meta("road_id", road_id)
		road_node.set_meta("surface_role", "main_road" if road_class == "main" else "service_road")
		road_nodes[road_id] = road_node


func _build_paths() -> void:
	for path_spec: Dictionary in WorldLayoutScript.PATH_SPECS:
		var path_id := String(path_spec["id"])
		var center: Vector2 = path_spec["center"]
		var dimensions: Vector2 = path_spec["dimensions"]
		var path_node := _create_visual_box(
			path_id,
			Vector3(center.x, WorldLayoutScript.PEDESTRIAN_PATH_ELEVATION, center.y),
			Vector3(dimensions.x, SURFACE_VISUAL_THICKNESS, dimensions.y),
			COLOR_PATH
		)
		path_node.set_meta("path_id", path_id)
		path_node.set_meta("surface_role", "pedestrian_route")
		path_nodes[path_id] = path_node


func _build_prototype_pads() -> void:
	var process_pad := _create_visual_box(
		"PrototypeProcessPad",
		Vector3(0.0, WorldLayoutScript.BASE_GRADE_ELEVATION + 0.009, 0.0),
		Vector3(31.0, 0.018, 13.0),
		COLOR_PROTOTYPE_PAD
	)
	process_pad.set_meta("surface_role", "pilot_process")
	var build_pad := _create_visual_box(
		"PrototypeBuildPad",
		Vector3(0.0, WorldLayoutScript.BASE_GRADE_ELEVATION + 0.009, 24.5),
		Vector3(44.0, 0.018, 30.0),
		COLOR_BUILD_PAD
	)
	build_pad.set_meta("surface_role", "buildable_area")

	for x_position: float in [-21.5, 21.5]:
		_create_visual_box(
			"BuildBoundaryX",
			Vector3(x_position, 0.022, 24.5),
			Vector3(0.18, 0.03, 29.0),
			Color("#7896a3")
		)
	for z_position: float in [10.2, 38.8]:
		_create_visual_box(
			"BuildBoundaryZ",
			Vector3(0.0, 0.022, z_position),
			Vector3(43.0, 0.03, 0.18),
			Color("#7896a3")
		)

	var build_sign = GrayboxSignScript.new()
	build_sign.name = "Orientation_build_area"
	build_sign.position = Vector3(0.0, 0.0, 39.5)
	add_child(build_sign)
	build_sign.configure("BUILD AREA 02", "LOCKED — COMPLETE PILOT", "", Vector2(5.2, 1.2))
	orientation_nodes["build_area"] = build_sign
	prototype_build_area_label = build_sign.label


func _build_starter_orientation() -> void:
	_create_graybox_sign(
		"starter_site",
		Vector3(-3.0, 0.0, 8.2),
		90.0,
		"STARTER SITE",
		"PILOT AREA",
		"←"
	)
	_create_graybox_sign(
		"crude_intake",
		Vector3(-17.0, 0.0, 9.0),
		-90.0,
		"CRUDE INTAKE",
		"SOUTH ROUTE",
		"↓"
	)
	_create_graybox_sign(
		"pilot_process_chain",
		Vector3(14.5, 0.0, 6.8),
		180.0,
		"PILOT AREA",
		"PROCESS LINE",
		"→"
	)
	_create_starter_access_gate()


func _create_starter_access_gate() -> void:
	var gate_root := Node3D.new()
	gate_root.name = "StarterMainRefineryGate"
	gate_root.position = Vector3(34.0, 0.0, -10.0)
	add_child(gate_root)
	orientation_nodes["main_refinery_gate"] = gate_root
	_create_fence_section("NorthFence", -9.5, gate_root)
	_create_fence_section("SouthFence", 9.5, gate_root)
	for z_position: float in [-3.0, 3.0]:
		_create_static_box(
			"GatePost",
			Vector3(0.0, 1.2, z_position),
			Vector3(0.45, 2.4, 0.45),
			Color("#b58a36"),
			gate_root
		)
	var gate_sign = GrayboxSignScript.new()
	gate_sign.name = "GateSign"
	gate_sign.position = Vector3(0.0, 2.85, 0.0)
	gate_sign.rotation_degrees.y = 90.0
	gate_root.add_child(gate_sign)
	gate_sign.configure("MAIN REFINERY", "", "→", Vector2(4.4, 0.8), false)


func _create_fence_section(node_name: String, local_z: float, parent: Node3D) -> void:
	var section := Node3D.new()
	section.name = node_name
	section.position.z = local_z
	parent.add_child(section)
	for z_offset: float in [-4.5, 0.0, 4.5]:
		_create_static_box(
			"FencePost",
			Vector3(0.0, 0.8, z_offset),
			Vector3(0.18, 1.6, 0.18),
			COLOR_FIXED_STRUCTURE,
			section
		)
	for rail_y: float in [0.45, 1.15]:
		_create_static_box(
			"FenceRail",
			Vector3(0.0, rail_y, 0.0),
			Vector3(0.14, 0.12, 9.0),
			COLOR_FIXED_STRUCTURE,
			section
		)


func _create_graybox_sign(
	sign_id: String,
	position_3d: Vector3,
	yaw_degrees: float,
	primary_text: String,
	secondary_text: String = "",
	direction: String = ""
) -> void:
	var sign_root = GrayboxSignScript.new()
	sign_root.name = "Orientation_%s" % sign_id
	sign_root.position = position_3d
	sign_root.rotation_degrees.y = yaw_degrees
	add_child(sign_root)
	orientation_nodes[sign_id] = sign_root
	sign_root.configure(primary_text, secondary_text, direction)


func _build_landmark_placeholders() -> void:
	_create_landmark_root("cdu", "tall_column")
	_create_landmark_root("vdu", "broad_column")
	_create_landmark_root("fcc", "twin_columns")
	_create_landmark_root("ht", "reactor_blocks")
	_create_landmark_root("utilities", "mechanical_block")
	_create_landmark_root("storage", "tank_group")


func _create_landmark_root(area_id: String, silhouette: String) -> void:
	var area := WorldLayoutScript.area_by_id(area_id)
	if area.is_empty():
		return
	var center: Vector2 = area["center"]
	var elevation := float(area["elevation"])
	var root_node := Node3D.new()
	root_node.name = "Landmark_%s" % area_id
	root_node.position = Vector3(center.x, elevation, center.y)
	root_node.set_meta("graybox_landmark", true)
	root_node.set_meta("navigation_placeholder", true)
	root_node.set_meta("gameplay_equipment", false)
	root_node.set_meta("area_id", area_id)
	add_child(root_node)
	landmark_nodes[area_id] = root_node

	match silhouette:
		"tall_column":
			_create_static_cylinder(
				"CDUColumn", Vector3(8.0, 16.0, 0.0), 4.0, 32.0, Color("#5c6970"), root_node
			)
		"broad_column":
			_create_static_cylinder(
				"VDUColumn", Vector3(6.0, 12.5, 0.0), 5.5, 25.0, Color("#697178"), root_node
			)
		"twin_columns":
			_create_static_cylinder(
				"FCCReactor", Vector3(-7.0, 13.0, 0.0), 4.0, 26.0, Color("#665f59"), root_node
			)
			_create_static_cylinder(
				"FCCRegenerator", Vector3(7.0, 15.0, 0.0), 4.8, 30.0, Color("#75665c"), root_node
			)
		"reactor_blocks":
			_create_static_cylinder(
				"HTReactor", Vector3(-6.0, 7.0, 0.0), 3.8, 14.0, Color("#626d70"), root_node
			)
			_create_static_box(
				"HTStructure",
				Vector3(5.0, 4.0, 0.0),
				Vector3(8.0, 8.0, 9.0),
				COLOR_FIXED_STRUCTURE,
				root_node
			)
		"mechanical_block":
			_create_static_box(
				"UtilitiesMass",
				Vector3(0.0, 5.5, 0.0),
				Vector3(18.0, 11.0, 13.0),
				Color("#59676c"),
				root_node
			)
			for x_offset: float in [-6.0, -2.0, 2.0, 6.0]:
				_create_visual_box(
					"CoolingBay",
					Vector3(x_offset, 7.0, 6.58),
					Vector3(2.2, 6.0, 0.18),
					Color("#78858a"),
					root_node
				)
		"tank_group":
			for tank_position: Vector3 in [Vector3(-12.0, 5.0, 0.0), Vector3(0.0, 5.0, 0.0), Vector3(12.0, 5.0, 0.0)]:
				_create_static_cylinder(
					"StorageTank", tank_position, 4.5, 10.0, Color("#68767a"), root_node
				)


func set_area_labels_visible(value: bool) -> void:
	area_labels_visible = value
	for label: Label3D in area_labels:
		if is_instance_valid(label):
			label.visible = value


func _create_access_ramp(area: Dictionary, side: String, parent: Node3D) -> void:
	var center: Vector2 = area["center"]
	var dimensions: Vector2 = area["dimensions"]
	var elevation := float(area["elevation"])
	var ramp_length := 5.0
	var ramp_width := 5.0
	var ramp_thickness := 0.16
	var angle := atan(elevation / ramp_length)
	var slope_length := sqrt(ramp_length * ramp_length + elevation * elevation)
	# Place the top face exactly between base grade and platform grade. The old
	# centered slab ended about 8 cm above both surfaces and created a collision lip.
	var ramp_center_y := (
		(WorldLayoutScript.BASE_GRADE_ELEVATION + elevation) * 0.5
		- cos(angle) * ramp_thickness * 0.5
	)
	var ramp_position := Vector3(center.x, ramp_center_y, center.y)
	var ramp_size := Vector3(ramp_width, ramp_thickness, slope_length)
	var ramp_rotation := Vector3.ZERO

	match side:
		"north":
			ramp_position.z -= dimensions.y * 0.5 + ramp_length * 0.5
			ramp_rotation.x = -angle
		"south":
			ramp_position.z += dimensions.y * 0.5 + ramp_length * 0.5
			ramp_rotation.x = angle
		"west":
			ramp_position.x -= dimensions.x * 0.5 + ramp_length * 0.5
			ramp_size = Vector3(slope_length, ramp_thickness, ramp_width)
			ramp_rotation.z = angle
		"east":
			ramp_position.x += dimensions.x * 0.5 + ramp_length * 0.5
			ramp_size = Vector3(slope_length, ramp_thickness, ramp_width)
			ramp_rotation.z = -angle

	var ramp := _create_static_box(
		"AccessRamp_%s" % side.capitalize(),
		ramp_position,
		ramp_size,
		Color("#737b83"),
		parent
	)
	ramp.rotation = ramp_rotation


func _create_area_outline(area: Dictionary, parent: Node3D) -> void:
	var center: Vector2 = area["center"]
	var dimensions: Vector2 = area["dimensions"]
	var elevation := maxf(float(area["elevation"]), 0.04) + 0.025
	var thickness := 0.22
	for z_offset: float in [-dimensions.y * 0.5, dimensions.y * 0.5]:
		_create_visual_box(
			"Boundary",
			Vector3(center.x, elevation, center.y + z_offset),
			Vector3(dimensions.x, 0.04, thickness),
			COLOR_BOUNDARY,
			parent
		)
	for x_offset: float in [-dimensions.x * 0.5, dimensions.x * 0.5]:
		_create_visual_box(
			"Boundary",
			Vector3(center.x + x_offset, elevation, center.y),
			Vector3(thickness, 0.04, dimensions.y),
			COLOR_BOUNDARY,
			parent
		)


func _create_area_label(area: Dictionary, parent: Node3D) -> void:
	var center: Vector2 = area["center"]
	var dimensions: Vector2 = area["dimensions"]
	var elevation := float(area["elevation"])
	var text := "%s  [%s]\n%.0f x %.0f m  |  +%.2f m" % [
		String(area["display_name"]),
		String(area["id"]),
		dimensions.x,
		dimensions.y,
		elevation,
	]
	var label := _create_world_label(
		text,
		Vector3(
			center.x - dimensions.x * 0.5 + 4.0,
			elevation + 1.4,
			center.y - dimensions.y * 0.5 + 4.0
		),
		Color("#f3e4b8"),
		0.55,
		parent
	)
	label.name = "AreaLabel"
	area_labels.append(label)


func _platform_color(kind: String) -> Color:
	match kind:
		"reserved":
			return COLOR_RESERVED
		"logistics":
			return COLOR_LOGISTICS
		_:
			return COLOR_PLATFORM


func _create_static_box(
	node_name: String,
	position: Vector3,
	size: Vector3,
	color: Color,
	parent: Node = self
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _create_visual_box(
	node_name: String,
	position: Vector3,
	size: Vector3,
	color: Color,
	parent: Node = self
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	parent.add_child(mesh_instance)
	return mesh_instance


func _create_static_cylinder(
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	color: Color,
	parent: Node = self
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	return body


func _create_world_label(
	text: String,
	position: Vector3,
	color: Color,
	pixel_size: float,
	parent: Node = self
) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.modulate = color
	label.font_size = 42
	label.pixel_size = pixel_size / 42.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	return label


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
