extends SceneTree

const WorldLayoutScript = preload("res://scripts/world_layout.gd")
const WorldBuilderScript = preload("res://scripts/world_builder.gd")
const BuildControllerScript = preload("res://scripts/build_controller.gd")
const SaveSystemScript = preload("res://scripts/save_system.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	_test_canonical_bounds()
	_test_area_configuration()
	_test_area02_spatial_contract()
	_test_road_configuration()
	_test_wayfinding_configuration()
	_test_surface_standard()
	_test_spawn_and_legacy_coordinates()
	_test_world_builder()
	await _test_platform_walkability()
	_test_authoritative_source_is_not_duplicated()

	if failures == 0:
		print("PASS: all CrudeWorks world-layout tests passed")
		quit(0)
	else:
		printerr("FAIL: %d CrudeWorks world-layout check(s) failed" % failures)
		quit(1)


func _test_canonical_bounds() -> void:
	var world_bounds: Rect2 = WorldLayoutScript.WORLD_BOUNDS
	_expect(
		is_equal_approx(world_bounds.size.x, 600.0) and is_equal_approx(world_bounds.size.y, 400.0),
		"industrial site uses the canonical 600 m x 400 m footprint"
	)
	_expect(
		BuildControllerScript.build_bounds() == WorldLayoutScript.build_bounds()
		and SaveSystemScript.build_bounds() == WorldLayoutScript.build_bounds(),
		"placement and save validation consume the same canonical build bounds"
	)
	_expect(
		WorldLayoutScript.world_contains_rect(WorldLayoutScript.build_bounds()),
		"canonical Area 02 build bounds remain inside the enlarged world"
	)


func _test_area_configuration() -> void:
	var ids := {}
	var expected_dimensions := {
		"crude_intake": Vector2(80.0, 70.0),
		"pilot_plant": Vector2(75.0, 75.0),
		"cdu": Vector2(100.0, 90.0),
		"vdu": Vector2(100.0, 90.0),
		"ht": Vector2(90.0, 80.0),
		"fcc": Vector2(110.0, 95.0),
		"utilities": Vector2(110.0, 90.0),
		"control_room": Vector2(30.0, 22.0),
		"lab": Vector2(24.0, 20.0),
		"storage": Vector2(150.0, 120.0),
		"product_dispatch": Vector2(90.0, 70.0),
		"future_expansion": Vector2(160.0, 130.0),
	}
	for area: Dictionary in WorldLayoutScript.AREA_SPECS:
		var area_id := String(area["id"])
		var dimensions: Vector2 = area["dimensions"]
		_expect(not ids.has(area_id), "area ID %s is unique" % area_id)
		ids[area_id] = true
		_expect(dimensions.x > 0.0 and dimensions.y > 0.0, "%s has positive dimensions" % area_id)
		_expect(
			WorldLayoutScript.world_contains_rect(WorldLayoutScript.area_rect(area)),
			"%s lies fully inside world bounds" % area_id
		)
		if expected_dimensions.has(area_id):
			_expect(dimensions == expected_dimensions[area_id], "%s preserves its target footprint" % area_id)
	for required_id: String in expected_dimensions:
		_expect(ids.has(required_id), "required area %s exists" % required_id)
	_expect(
		String(WorldLayoutScript.area_by_id("future_expansion").get("kind", "")) == "reserved",
		"future expansion is explicit and reserved"
	)


func _test_area02_spatial_contract() -> void:
	var area := WorldLayoutScript.area02_spec()
	var platform_rect := WorldLayoutScript.area02_platform_rect()
	var build_bounds := WorldLayoutScript.build_bounds()
	_expect(
		String(area["id"]) == WorldLayoutScript.AREA_02_ID
		and platform_rect == WorldLayoutScript.area_rect(area),
		"Area 02 platform footprint derives from one canonical area specification"
	)
	_expect(
		platform_rect.encloses(build_bounds)
		and build_bounds.position == platform_rect.position + WorldLayoutScript.AREA_02_BUILD_MARGIN
		and build_bounds.end == platform_rect.end - WorldLayoutScript.AREA_02_BUILD_MARGIN,
		"Area 02 build bounds are the platform footprint with one canonical safety margin"
	)
	_expect(
		WorldLayoutScript.placement_inside_active_build_bounds(build_bounds.get_center(), Vector2(3.2, 3.2)),
		"canonical white-platform center is buildable"
	)
	_expect(
		not WorldLayoutScript.placement_inside_active_build_bounds(
			WorldLayoutScript.LEGACY_AREA_02_BUILD_BOUNDS.get_center(), Vector2(2.0, 2.0)
		),
		"legacy CI-to-PD blue zone has no active build authority"
	)
	for anchor_id: String in ["crude_intake", "product_dispatch"]:
		var anchor := WorldLayoutScript.area02_anchor(anchor_id)
		_expect(
			platform_rect.has_point(anchor)
			and not build_bounds.has_point(anchor)
			and WorldLayoutScript.area02_inward_direction(anchor_id).dot(
				(platform_rect.get_center() - anchor).normalized()
			) > 0.999,
			"%s uses a canonical platform-edge support anchor facing inward" % anchor_id
		)


func _test_road_configuration() -> void:
	var ids := {}
	for road: Dictionary in WorldLayoutScript.ROAD_SPECS:
		var road_id := String(road["id"])
		var dimensions: Vector2 = road["dimensions"]
		var road_width := minf(dimensions.x, dimensions.y)
		_expect(not ids.has(road_id), "road ID %s is unique" % road_id)
		ids[road_id] = true
		if String(road["class"]) == "main":
			_expect(road_width >= 7.0 and road_width <= 8.0, "%s uses the 7-8 m main-road target" % road_id)
		else:
			_expect(road_width >= 5.0 and road_width <= 6.0, "%s uses the 5-6 m service-road target" % road_id)
		var road_rect := Rect2(Vector2(road["center"]) - dimensions * 0.5, dimensions)
		var clear_of_platforms := true
		for area: Dictionary in WorldLayoutScript.AREA_SPECS:
			if not bool(area["render_platform"]):
				continue
			var overlap := road_rect.intersection(WorldLayoutScript.area_rect(area))
			if overlap.size.x > 0.001 and overlap.size.y > 0.001:
				clear_of_platforms = false
		_expect(clear_of_platforms, "%s does not disappear beneath an area platform" % road_id)
	var path_ids := {}
	for path_spec: Dictionary in WorldLayoutScript.PATH_SPECS:
		var path_id := String(path_spec["id"])
		var dimensions: Vector2 = path_spec["dimensions"]
		_expect(not path_ids.has(path_id), "pedestrian path ID %s is unique" % path_id)
		path_ids[path_id] = true
		_expect(minf(dimensions.x, dimensions.y) >= 2.0, "%s keeps human-scale walking clearance" % path_id)


func _test_surface_standard() -> void:
	_expect(
		is_zero_approx(WorldLayoutScript.BASE_GRADE_ELEVATION)
		and WorldLayoutScript.ROAD_ELEVATION <= 0.02
		and WorldLayoutScript.PEDESTRIAN_PATH_ELEVATION <= 0.03,
		"base, roads and pedestrian routes share a near-flush canonical grade"
	)
	_expect(
		absf(WorldLayoutScript.PEDESTRIAN_PATH_ELEVATION - WorldLayoutScript.ROAD_ELEVATION) <= 0.01,
		"road-to-path visual grade change cannot create a gameplay-sized seam"
	)
	var semantic_colors := {
		WorldBuilderScript.COLOR_GROUND.to_html(): true,
		WorldBuilderScript.COLOR_MAIN_ROAD.to_html(): true,
		WorldBuilderScript.COLOR_SERVICE_ROAD.to_html(): true,
		WorldBuilderScript.COLOR_PATH.to_html(): true,
		WorldBuilderScript.COLOR_PLATFORM.to_html(): true,
		WorldBuilderScript.COLOR_BUILD_PAD.to_html(): true,
		WorldBuilderScript.COLOR_RESERVED.to_html(): true,
	}
	_expect(semantic_colors.size() == 7, "graybox surface roles use distinct flat development colors")


func _test_wayfinding_configuration() -> void:
	var expected_arrows := {
		"starter_site": "←",
		"crude_intake": "←",
		"main_refinery_gate": "↑",
	}
	for sign_id: String in expected_arrows:
		var spec := WorldLayoutScript.wayfinding_spec_by_id(sign_id)
		_expect(not spec.is_empty(), "%s has canonical wayfinding metadata" % sign_id)
		_expect(
			WorldLayoutScript.wayfinding_arrow(spec) == expected_arrows[sign_id],
			"%s direction is derived from board approach and its canonical target center" % sign_id
		)
	_expect(
		WorldLayoutScript.wayfinding_arrow(
			WorldLayoutScript.wayfinding_spec_by_id("pilot_process_chain")
		).is_empty(),
		"non-directional Pilot process marker does not invent a route arrow"
	)


func _test_spawn_and_legacy_coordinates() -> void:
	var spawn := WorldLayoutScript.NEW_GAME_SPAWN
	_expect(WorldLayoutScript.player_position_is_valid(spawn), "new-game spawn is inside canonical player bounds")
	_expect(
		WorldLayoutScript.area_id_at(Vector2(spawn.x, spawn.z)) == "pilot_plant",
		"new-game spawn is in the southwest starter region"
	)
	for old_player_position: Vector3 in [
		Vector3(-10.0, 0.1, 8.0),
		Vector3(-4.0, 0.1, 17.0),
		Vector3(23.0, 1.4, 34.5),
	]:
		_expect(
			WorldLayoutScript.player_position_is_valid(old_player_position),
			"legacy absolute player coordinate %s remains naturally valid" % old_player_position
		)
	for old_placement: Vector2 in [Vector2(-11.0, 15.0), Vector2(0.0, 20.0), Vector2(17.0, 35.0)]:
		_expect(
			not WorldLayoutScript.placement_inside_active_build_bounds(old_placement, Vector2(2.0, 2.0))
			and WorldLayoutScript.placement_inside_legacy_build_bounds(old_placement, Vector2(2.0, 2.0)),
			"legacy prototype placement %s is migration-only, not actively buildable" % old_placement
		)


func _test_world_builder() -> void:
	var builder = WorldBuilderScript.new()
	root.add_child(builder)
	builder.build_world()
	_expect(builder.area_nodes.size() == WorldLayoutScript.AREA_SPECS.size(), "world builder emits every configured area marker")
	_expect(builder.road_nodes.size() == WorldLayoutScript.ROAD_SPECS.size(), "world builder emits every configured road")
	_expect(builder.path_nodes.size() == WorldLayoutScript.PATH_SPECS.size(), "world builder emits every configured pedestrian path")
	_expect(builder.landmark_nodes.size() == 6, "world builder emits the six restrained navigation landmark groups")
	_expect(builder.has_node("TerrainBuffer"), "world builder creates traversable macro terrain")
	var terrain_buffer: StaticBody3D = builder.get_node("TerrainBuffer")
	_expect(
		terrain_buffer.find_children("*", "MeshInstance3D", true, false).is_empty()
		and terrain_buffer.find_children("*", "CollisionShape3D", true, false).size() == 1,
		"macro terrain collision has no duplicate rendered surface at base grade"
	)
	_expect(builder.get_node("IndustrialGround") is MeshInstance3D, "one authoritative macro ground surface is rendered")
	_expect(builder.has_node("SouthernSea"), "world builder creates the southern sea edge")
	for boundary_name: String in ["NorthBoundary", "WestBoundary", "EastBoundary", "SouthShoreBoundary"]:
		_expect(builder.has_node(boundary_name), "%s collision boundary exists" % boundary_name)
	for area: Dictionary in WorldLayoutScript.AREA_SPECS:
		var area_id := String(area["id"])
		var area_node: Node = builder.area_nodes[area_id]
		_expect(area_node.has_node("AreaLabel"), "%s has a debug label" % area_id)
		if bool(area["render_platform"]) and float(area["elevation"]) > 0.05:
			_expect(area_node.has_node("Platform"), "%s has a raised graybox platform" % area_id)
			var access_sides: Array = area.get("access_sides", [area.get("access_side", "south")])
			for access_side in access_sides:
				_expect(
					area_node.has_node("AccessRamp_%s" % String(access_side).capitalize()),
					"%s raised platform has %s walk access" % [area_id, String(access_side)]
				)
	_expect(
		builder.get_node("PrototypeProcessPad") is MeshInstance3D
		and builder.get_node("Area02BuildOverlay") is MeshInstance3D
		and not builder.has_node("PrototypeBuildPad"),
		"Pilot pad remains visual-only and no legacy build-pad node survives"
	)
	var build_overlay: MeshInstance3D = builder.get_node("Area02BuildOverlay")
	var overlay_mesh: BoxMesh = build_overlay.mesh
	var canonical_build_bounds := WorldLayoutScript.build_bounds()
	_expect(
		Vector2(build_overlay.position.x, build_overlay.position.z) == canonical_build_bounds.get_center()
		and Vector2(overlay_mesh.size.x, overlay_mesh.size.z) == canonical_build_bounds.size
		and build_overlay.get_meta("canonical_bounds") == canonical_build_bounds,
		"Build Mode overlay footprint exactly matches canonical build validation"
	)
	var signs: Array = [
		builder.orientation_nodes["starter_site"],
		builder.orientation_nodes["crude_intake"],
		builder.orientation_nodes["pilot_process_chain"],
		builder.orientation_nodes["build_area"],
		builder.orientation_nodes["main_refinery_gate"].get_node("GateSign"),
	]
	for sign in signs:
		_expect(
			sign.has_meta("graybox_sign")
			and int(sign.get_meta("line_count")) <= 2
			and sign.primary_text.length() <= 24
			and sign.secondary_text.length() <= 24,
			"%s obeys reusable sign line and length limits" % sign.name
		)
		_expect(
			sign.label.billboard == BaseMaterial3D.BILLBOARD_DISABLED
			and not sign.label.no_depth_test
			and sign.label.position.z < -0.06,
			"%s keeps text mounted in front of its board without billboard drift" % sign.name
		)
		if sign.has_node("Post"):
			_expect(
				sign.label.position.z < sign.get_node("Board").position.z
				and sign.get_node("Post").position.z > sign.get_node("Board").position.z,
				"%s keeps viewer → text → board → post physical depth order" % sign.name
			)
	_expect(
		Vector2(builder.orientation_nodes["starter_site"].get_meta("board_size")).x <= 3.0,
		"starter sign remains human-scale rather than filling the approach view"
	)
	for sign_id: String in ["starter_site", "crude_intake"]:
		var sign = builder.orientation_nodes[sign_id]
		var spec := WorldLayoutScript.wayfinding_spec_by_id(sign_id)
		_expect(
			String(sign.get_meta("target_area_id")) == String(spec["target_area_id"])
			and String(sign.get_meta("wayfinding_arrow")) == WorldLayoutScript.wayfinding_arrow(spec),
			"%s rendered sign consumes canonical target metadata" % sign_id
		)
	_expect(
		builder.build_visual_nodes.all(func(node: Node3D) -> bool: return not node.visible),
		"construction pad, bounds and sign default hidden outside Build Mode"
	)
	builder.set_build_visualization_visible(true)
	_expect(
		builder.build_visual_nodes.all(func(node: Node3D) -> bool: return node.visible),
		"construction visualization can be enabled without changing build validation"
	)
	builder.set_build_visualization_visible(false)
	builder.set_build_visualization_visible(true)
	_expect(
		builder.build_visualization_visible
		and builder.build_visual_nodes.all(func(node: Node3D) -> bool: return node.visible)
		and WorldLayoutScript.build_bounds() == canonical_build_bounds,
		"repeated Build Mode toggles return every canonical Area 02 visual to one deterministic state"
	)
	_expect(
		builder.area_labels.all(func(label: Label3D) -> bool: return not label.visible),
		"distant area labels default OFF for uncluttered human navigation testing"
	)
	builder.set_area_labels_visible(true)
	_expect(
		builder.area_labels.all(func(label: Label3D) -> bool: return label.visible),
		"area labels can be enabled independently from core world debug"
	)
	for area_id: String in ["cdu", "vdu", "fcc", "ht", "utilities", "storage"]:
		var landmark: Node3D = builder.landmark_nodes[area_id]
		_expect(
			bool(landmark.get_meta("navigation_placeholder"))
			and not bool(landmark.get_meta("gameplay_equipment"))
			and not landmark.has_meta("unit_id")
			and not WorldLayoutScript.build_bounds().has_point(
				Vector2(landmark.global_position.x, landmark.global_position.z)
			),
			"%s landmark remains non-gameplay, non-persisted graybox geometry" % area_id
		)
	builder.queue_free()


func _test_platform_walkability() -> void:
	var builder = WorldBuilderScript.new()
	root.add_child(builder)
	builder.build_world()
	var walker := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	walker.add_child(collision)
	root.add_child(walker)
	await physics_frame

	for area: Dictionary in WorldLayoutScript.AREA_SPECS:
		if not bool(area["render_platform"]) or float(area["elevation"]) <= 0.05:
			continue
		var access_sides: Array = area.get("access_sides", [area.get("access_side", "south")])
		for access_side in access_sides:
			var route := _ramp_route(area, String(access_side))
			walker.global_position = Vector3(route[0].x, 0.1, route[0].y)
			walker.velocity = Vector3.ZERO
			await physics_frame
			for frame_index in 95:
				var target_3d := Vector3(route[1].x, walker.global_position.y, route[1].y)
				var direction := target_3d - walker.global_position
				direction.y = 0.0
				if direction.length() > 0.15:
					direction = direction.normalized()
					walker.velocity.x = direction.x * 6.0
					walker.velocity.z = direction.z * 6.0
				else:
					walker.velocity.x = 0.0
					walker.velocity.z = 0.0
				walker.velocity.y = -0.5 if walker.is_on_floor() else walker.velocity.y - 18.0 / 60.0
				walker.move_and_slide()
				await physics_frame
			var reached_area := WorldLayoutScript.area_rect(area).has_point(
				Vector2(walker.global_position.x, walker.global_position.z)
			)
			_expect(
				reached_area and walker.global_position.y >= 0.6,
				"%s %s ramp is traversable by a player-sized body" % [String(area["id"]), String(access_side)]
			)

	var boundary_checks := [
		{"start": Vector3(WorldLayoutScript.WORLD_BOUNDS.position.x + 2.0, 0.1, 0.0), "direction": Vector3.LEFT},
		{"start": Vector3(WorldLayoutScript.WORLD_BOUNDS.end.x - 2.0, 0.1, 0.0), "direction": Vector3.RIGHT},
		{"start": Vector3(400.0, 0.1, WorldLayoutScript.WORLD_BOUNDS.position.y + 2.0), "direction": Vector3.FORWARD},
		{"start": Vector3(400.0, 0.1, WorldLayoutScript.WORLD_BOUNDS.end.y - 2.0), "direction": Vector3.BACK},
	]
	for boundary_check: Dictionary in boundary_checks:
		walker.global_position = boundary_check["start"]
		walker.velocity = Vector3.ZERO
		await physics_frame
		for frame_index in 45:
			var direction: Vector3 = boundary_check["direction"]
			walker.velocity = Vector3(direction.x * 6.0, -0.5, direction.z * 6.0)
			walker.move_and_slide()
			await physics_frame
		_expect(
			WorldLayoutScript.world_contains_xz(Vector2(walker.global_position.x, walker.global_position.z)),
			"site boundary collision contains a player-sized body at %s" % boundary_check["start"]
		)

	walker.global_position = Vector3(29.0, 0.1, -10.0)
	walker.velocity = Vector3.ZERO
	await physics_frame
	for frame_index in 100:
		walker.velocity = Vector3(6.0, -0.5, 0.0)
		walker.move_and_slide()
		await physics_frame
	_expect(
		walker.global_position.x > 38.0,
		"open starter transition gate preserves player-sized access toward the Main Refinery"
	)

	await _walk_route(
		walker,
		[
			Vector2(-10.0, 8.0),
			Vector2(-10.0, 34.0),
			Vector2(-10.0, 46.0),
			Vector2(-10.0, 34.0),
			Vector2(-10.0, 20.0),
			Vector2(24.0, 20.0),
			Vector2(24.0, -10.0),
			Vector2(40.0, -10.0),
			Vector2(74.0, -10.0),
			Vector2(85.0, -10.0),
			Vector2(74.0, -10.0),
			Vector2(62.5, -10.0),
			Vector2(62.5, -105.0),
			Vector2(76.0, -105.0),
		],
		10.0
	)
	_expect(
		WorldLayoutScript.area_id_at(Vector2(walker.global_position.x, walker.global_position.z)) == "cdu"
		and walker.global_position.y >= 0.6,
		"spawn → Pilot → Crude Intake → gate → Operations → CDU route is continuous without jumping"
	)

	walker.queue_free()
	builder.queue_free()


func _walk_route(walker: CharacterBody3D, waypoints: Array[Vector2], speed: float) -> void:
	walker.global_position = Vector3(waypoints[0].x, 0.1, waypoints[0].y)
	walker.velocity = Vector3.ZERO
	await physics_frame
	for waypoint_index in range(1, waypoints.size()):
		var target := waypoints[waypoint_index]
		var starting_distance := Vector2(walker.global_position.x, walker.global_position.z).distance_to(target)
		var max_frames := int(ceil(starting_distance / speed * 90.0)) + 90
		for frame_index in max_frames:
			var current := Vector2(walker.global_position.x, walker.global_position.z)
			var direction := target - current
			if direction.length() <= 0.2:
				break
			direction = direction.normalized()
			walker.velocity.x = direction.x * speed
			walker.velocity.z = direction.y * speed
			walker.velocity.y = -0.5 if walker.is_on_floor() else walker.velocity.y - 18.0 / 60.0
			walker.move_and_slide()
			await physics_frame


func _ramp_route(area: Dictionary, side: String) -> Array[Vector2]:
	var center: Vector2 = area["center"]
	var dimensions: Vector2 = area["dimensions"]
	match side:
		"north":
			return [
				Vector2(center.x, center.y - dimensions.y * 0.5 - 6.0),
				Vector2(center.x, center.y - dimensions.y * 0.5 + 2.0),
			]
		"south":
			return [
				Vector2(center.x, center.y + dimensions.y * 0.5 + 6.0),
				Vector2(center.x, center.y + dimensions.y * 0.5 - 2.0),
			]
		"west":
			return [
				Vector2(center.x - dimensions.x * 0.5 - 6.0, center.y),
				Vector2(center.x - dimensions.x * 0.5 + 2.0, center.y),
			]
		_:
			return [
				Vector2(center.x + dimensions.x * 0.5 + 6.0, center.y),
				Vector2(center.x + dimensions.x * 0.5 - 2.0, center.y),
			]


func _test_authoritative_source_is_not_duplicated() -> void:
	var build_source := FileAccess.get_file_as_string("res://scripts/build_controller.gd")
	var save_source := FileAccess.get_file_as_string("res://scripts/save_system.gd")
	_expect("const BUILD_BOUNDS" not in build_source, "build controller does not define independent build bounds")
	_expect("const BUILD_BOUNDS" not in save_source, "save validation does not define independent build bounds")
	_expect(
		"placement_inside_active_build_bounds" in build_source
		and "placement_inside_active_build_bounds" in save_source,
		"placement and save code delegate footprint validation to WorldLayout"
	)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures += 1
		printerr("FAIL: %s" % description)
