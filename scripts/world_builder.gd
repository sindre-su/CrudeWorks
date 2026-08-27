class_name GrayboxWorldBuilder
extends Node3D

const WorldLayoutScript := preload("res://scripts/world_layout.gd")

const COLOR_GROUND := Color("#38453b")
const COLOR_BUFFER := Color("#26352f")
const COLOR_SEA := Color("#214d61")
const COLOR_FOREST := Color("#1e3228")
const COLOR_ROAD := Color("#293038")
const COLOR_MAIN_ROAD := Color("#343d46")
const COLOR_PATH := Color("#4b5752")
const COLOR_PLATFORM := Color("#687079")
const COLOR_RESERVED := Color("#535968")
const COLOR_LOGISTICS := Color("#596b63")
const COLOR_BOUNDARY := Color("#d9b44a")
const COLOR_PROTOTYPE_PAD := Color("#354b46")
const COLOR_BUILD_PAD := Color("#273c4b")

var prototype_build_area_label: Label3D
var area_nodes: Dictionary = {}
var road_nodes: Dictionary = {}
var path_nodes: Dictionary = {}
var orientation_nodes: Dictionary = {}


func build_world() -> void:
	_build_environment()
	_build_macro_terrain()
	_build_site_boundaries()
	_build_area_platforms()
	_build_roads()
	_build_paths()
	_build_prototype_pads()
	_build_starter_orientation()


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
		Vector3(terrain_center.x, -0.28, terrain_center.y),
		Vector3(terrain_size.x, 0.5, terrain_size.y),
		COLOR_BUFFER
	)

	var world_center := WorldLayoutScript.WORLD_BOUNDS.get_center()
	var world_size := WorldLayoutScript.WORLD_BOUNDS.size
	_create_visual_box(
		"IndustrialGround",
		Vector3(world_center.x, -0.015, world_center.y),
		Vector3(world_size.x, 0.04, world_size.y),
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
					Vector3(center.x, 0.015, center.y),
					Vector3(dimensions.x, 0.03, dimensions.y),
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
		var color := COLOR_MAIN_ROAD if String(road["class"]) == "main" else COLOR_ROAD
		var road_node := _create_visual_box(
			road_id,
			Vector3(center.x, WorldLayoutScript.ROAD_ELEVATION, center.y),
			Vector3(dimensions.x, 0.035, dimensions.y),
			color
		)
		road_node.set_meta("road_id", road_id)
		road_nodes[road_id] = road_node


func _build_paths() -> void:
	for path_spec: Dictionary in WorldLayoutScript.PATH_SPECS:
		var path_id := String(path_spec["id"])
		var center: Vector2 = path_spec["center"]
		var dimensions: Vector2 = path_spec["dimensions"]
		var path_node := _create_visual_box(
			path_id,
			Vector3(center.x, WorldLayoutScript.PEDESTRIAN_PATH_ELEVATION, center.y),
			Vector3(dimensions.x, 0.025, dimensions.y),
			COLOR_PATH
		)
		path_node.set_meta("path_id", path_id)
		path_nodes[path_id] = path_node


func _build_prototype_pads() -> void:
	_create_static_box(
		"PrototypeProcessPad",
		Vector3(0.0, 0.03, 0.0),
		Vector3(31.0, 0.12, 13.0),
		COLOR_PROTOTYPE_PAD
	)
	_create_static_box(
		"PrototypeBuildPad",
		Vector3(0.0, 0.04, 24.5),
		Vector3(44.0, 0.14, 30.0),
		COLOR_BUILD_PAD
	)

	for x_position: float in [-21.5, 21.5]:
		_create_visual_box(
			"BuildBoundaryX",
			Vector3(x_position, 0.13, 24.5),
			Vector3(0.18, 0.03, 29.0),
			Color("#58c7e8")
		)
	for z_position: float in [10.2, 38.8]:
		_create_visual_box(
			"BuildBoundaryZ",
			Vector3(0.0, 0.13, z_position),
			Vector3(43.0, 0.03, 0.18),
			Color("#58c7e8")
		)

	prototype_build_area_label = _create_world_label(
		"Active Prototype Build Area",
		Vector3(0.0, 0.22, 39.5),
		Color("#75d9ef"),
		0.42
	)
	prototype_build_area_label.visible = true


func _build_starter_orientation() -> void:
	_create_physical_sign(
		"starter_site",
		Vector3(-3.0, 0.0, 8.2),
		90.0,
		"STARTER SITE\nPILOT PROCESS  ←\nCRUDE INTAKE  ↓ SOUTH"
	)
	_create_physical_sign(
		"pilot_process_chain",
		Vector3(14.5, 0.0, 6.8),
		0.0,
		"PILOT P-01\nTANK > PUMP > VALVE\n> HEATER > SEPARATION > TANKS"
	)
	_create_starter_access_gate()


func _create_starter_access_gate() -> void:
	var gate_root := Node3D.new()
	gate_root.name = "StarterMainRefineryGate"
	gate_root.position = Vector3(34.0, 0.0, -10.0)
	add_child(gate_root)
	orientation_nodes["main_refinery_gate"] = gate_root
	_create_static_box(
		"NorthBollard",
		Vector3(0.0, 0.65, -1.75),
		Vector3(0.45, 1.3, 1.35),
		Color("#b58a36"),
		gate_root
	)
	_create_static_box(
		"SouthBollard",
		Vector3(0.0, 0.65, 1.75),
		Vector3(0.45, 1.3, 1.35),
		Color("#b58a36"),
		gate_root
	)
	_create_static_box(
		"ClearanceBeam",
		Vector3(0.0, 2.35, 0.0),
		Vector3(0.35, 0.3, 4.8),
		Color("#535f61"),
		gate_root
	)
	var gate_label := Label3D.new()
	gate_label.name = "GateLabel"
	gate_label.text = "MAIN REFINERY  →\nAFTER PILOT SALE"
	gate_label.position = Vector3(0.0, 2.35, 0.0)
	gate_label.font_size = 42
	gate_label.pixel_size = 0.009
	gate_label.modulate = Color("#f3e4b8")
	gate_label.outline_size = 8
	gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate_label.no_depth_test = false
	gate_root.add_child(gate_label)


func _create_physical_sign(
	sign_id: String,
	position_3d: Vector3,
	yaw_degrees: float,
	text: String
) -> void:
	var sign_root := Node3D.new()
	sign_root.name = "Orientation_%s" % sign_id
	sign_root.position = position_3d
	sign_root.rotation_degrees.y = yaw_degrees
	add_child(sign_root)
	orientation_nodes[sign_id] = sign_root
	_create_static_box(
		"Post",
		Vector3(0.0, 0.72, 0.0),
		Vector3(0.16, 1.44, 0.16),
		Color("#3d4647"),
		sign_root
	)
	_create_static_box(
		"Board",
		Vector3(0.0, 1.65, 0.0),
		Vector3(4.6, 1.45, 0.14),
		Color("#34464b"),
		sign_root
	)
	var label := Label3D.new()
	label.name = "SignLabel"
	label.text = text
	label.position = Vector3(0.0, 1.65, -0.08)
	label.font_size = 40
	label.pixel_size = 0.008
	label.modulate = Color("#f2e3b5")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	sign_root.add_child(label)


func _create_access_ramp(area: Dictionary, side: String, parent: Node3D) -> void:
	var center: Vector2 = area["center"]
	var dimensions: Vector2 = area["dimensions"]
	var elevation := float(area["elevation"])
	var ramp_length := 5.0
	var ramp_width := 5.0
	var ramp_thickness := 0.16
	var angle := atan(elevation / ramp_length)
	var ramp_position := Vector3(center.x, elevation * 0.5, center.y)
	var ramp_size := Vector3(ramp_width, ramp_thickness, ramp_length)
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
			ramp_size = Vector3(ramp_length, ramp_thickness, ramp_width)
			ramp_rotation.z = angle
		"east":
			ramp_position.x += dimensions.x * 0.5 + ramp_length * 0.5
			ramp_size = Vector3(ramp_length, ramp_thickness, ramp_width)
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
		Vector3(center.x, elevation + 1.4, center.y),
		Color("#f3e4b8"),
		0.55,
		parent
	)
	label.name = "AreaLabel"


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
