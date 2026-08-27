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
	_test_terrace_configuration()
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
		is_equal_approx(world_bounds.size.x, 214.0) and is_equal_approx(world_bounds.size.y, 268.0)
		and WorldLayoutScript.LAND_BOUNDS.size == Vector2(214.0, 264.0),
		"compact bounds support the 214 m x 264 m intimate refinery land footprint"
	)
	_expect(
		BuildControllerScript.build_bounds() == WorldLayoutScript.build_bounds()
		and SaveSystemScript.build_bounds() == WorldLayoutScript.build_bounds(),
		"placement and save validation consume the same canonical build bounds"
	)
	_expect(
		WorldLayoutScript.world_contains_rect(WorldLayoutScript.build_bounds()),
		"canonical Area 02 compatibility build bounds remain inside the rescaled world"
	)


func _test_terrace_configuration() -> void:
	var expected_elevations := {
		"harbor": 0.0,
		"lower_plant": 3.5,
		"main_plant": 7.0,
		"upper_plant": 10.5,
	}
	var ids := {}
	for terrace: Dictionary in WorldLayoutScript.TERRACE_SPECS:
		var terrace_id := String(terrace["id"])
		_expect(not ids.has(terrace_id), "terrace ID %s is unique" % terrace_id)
		ids[terrace_id] = true
		_expect(
			expected_elevations.has(terrace_id)
			and is_equal_approx(float(terrace["elevation"]), float(expected_elevations[terrace_id])),
			"%s uses its canonical progression elevation" % terrace_id
		)
		_expect(
			WorldLayoutScript.world_contains_rect(WorldLayoutScript.terrace_rect(terrace)),
			"%s lies fully inside world bounds" % terrace_id
		)
		_expect(not String(terrace.get("purpose", "")).is_empty(), "%s has an explicit functional purpose" % terrace_id)
	_expect(ids.size() == 4, "Harbor, Lower, Main and Upper are the only canonical elevation bands")
	var grade_samples := [
		WorldLayoutScript.natural_grade_elevation_at_z(0.0),
		WorldLayoutScript.natural_grade_elevation_at_z(-75.0),
		WorldLayoutScript.natural_grade_elevation_at_z(-127.0),
		WorldLayoutScript.natural_grade_elevation_at_z(-178.0),
	]
	_expect(
		grade_samples[0] < grade_samples[1]
		and grade_samples[1] < grade_samples[2]
		and grade_samples[2] < grade_samples[3],
		"macro terrain rises continuously from Harbor through the three inland districts"
	)
	_expect(
		is_equal_approx(
			WorldLayoutScript.natural_grade_elevation_at_z(WorldLayoutScript.NATURAL_GRADE_END_Z),
			10.5
		),
		"broad natural grade reaches the approved +10.5 m upper elevation"
	)


func _test_area_configuration() -> void:
	var ids := {}
	var expected_dimensions := {
		"crude_intake": Vector2(26.0, 18.0),
		"pilot_plant": Vector2(55.0, 42.0),
		"operations_hub": Vector2(80.0, 60.0),
		"crude_storage": Vector2(38.0, 26.0),
		"cdu": Vector2(28.0, 26.0),
		"vdu": Vector2(48.0, 28.0),
		"ht": Vector2(28.0, 26.0),
		"fcc": Vector2(22.0, 28.0),
		"utilities": Vector2(34.0, 26.0),
		"control_room": Vector2(20.0, 14.0),
		"lab": Vector2(20.0, 14.0),
		"product_storage": Vector2(50.0, 36.0),
		"maintenance": Vector2(46.0, 34.0),
		"product_dispatch": Vector2(34.0, 18.0),
		"future_expansion": Vector2(46.0, 28.0),
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
		var terrace := WorldLayoutScript.terrace_by_id(String(area.get("terrace", "")))
		_expect(
			not terrace.is_empty()
			and WorldLayoutScript.terrace_rect(terrace).encloses(WorldLayoutScript.area_rect(area)),
			"%s belongs to and fits its canonical terrace" % area_id
		)
		_expect(not String(area.get("purpose", "")).is_empty(), "%s has an explicit spatial purpose" % area_id)
		_expect(not String(area.get("road_access", "")).is_empty(), "%s records its road/access relationship" % area_id)
		if expected_dimensions.has(area_id):
			_expect(dimensions == expected_dimensions[area_id], "%s preserves its target footprint" % area_id)
		if bool(area.get("terrain_pad", false)):
			_expect(
				is_equal_approx(
					WorldLayoutScript.terrain_elevation_at(area["center"]),
					float(area["elevation"])
				),
				"%s remains locally level within the natural macro grade" % area_id
			)
	for required_id: String in expected_dimensions:
		_expect(ids.has(required_id), "required area %s exists" % required_id)
	_expect(
		String(WorldLayoutScript.area_by_id("future_expansion").get("kind", "")) == "reserved",
		"future expansion is explicit and reserved"
	)
	for first_index in WorldLayoutScript.AREA_SPECS.size():
		var first: Dictionary = WorldLayoutScript.AREA_SPECS[first_index]
		for second_index in range(first_index + 1, WorldLayoutScript.AREA_SPECS.size()):
			var second: Dictionary = WorldLayoutScript.AREA_SPECS[second_index]
			if String(first["terrace"]) != String(second["terrace"]):
				continue
			var overlap := WorldLayoutScript.area_rect(first).intersection(WorldLayoutScript.area_rect(second))
			_expect(
				overlap.size.x <= 0.001 or overlap.size.y <= 0.001,
				"same-terrace areas %s and %s do not unintentionally overlap" % [first["id"], second["id"]]
			)
	_expect(
		WorldLayoutScript.harbor_logistics_anchor("crude_intake") == Vector2(31.0, 49.0)
		and WorldLayoutScript.harbor_logistics_anchor("product_dispatch") == Vector2(138.0, 49.0),
		"final CI/PD Harbor anchors are exact canonical reservations"
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
	var main_sequence := []
	for road: Dictionary in WorldLayoutScript.ROAD_SPECS:
		var road_id := String(road["id"])
		var dimensions: Vector2 = road["dimensions"]
		var road_width := minf(dimensions.x, dimensions.y)
		_expect(not ids.has(road_id), "road ID %s is unique" % road_id)
		ids[road_id] = true
		if String(road["class"]) == "main":
			_expect(road_width >= 7.0 and road_width <= 8.0, "%s uses the 7-8 m main-road target" % road_id)
			main_sequence.append(road)
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
	main_sequence.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["sequence"]) < int(right["sequence"]))
	_expect(main_sequence.size() == 2, "one primary road spine contains one Harbor flat and one continuous inland grade")
	var inland_grade: Dictionary = main_sequence[1]
	var grade := (
		(float(inland_grade["to_elevation"]) - float(inland_grade["from_elevation"]))
		/ float(Vector2(inland_grade["dimensions"]).y)
	)
	_expect(
		String(inland_grade.get("kind", "")) == "grade" and grade > 0.0 and grade <= 0.07,
		"continuous inland road remains a gentle future-vehicle grade"
	)
	for sequence_index in range(main_sequence.size() - 1):
		var current_rect := WorldLayoutScript.road_rect(main_sequence[sequence_index])
		var next_rect := WorldLayoutScript.road_rect(main_sequence[sequence_index + 1])
		_expect(
			is_equal_approx(current_rect.position.x, next_rect.position.x)
			and is_equal_approx(current_rect.position.y, next_rect.end.y),
			"main-road sequence %d meets the next segment edge-to-edge" % sequence_index
		)
	for first_index in WorldLayoutScript.ROAD_SPECS.size():
		var first: Dictionary = WorldLayoutScript.ROAD_SPECS[first_index]
		for second_index in range(first_index + 1, WorldLayoutScript.ROAD_SPECS.size()):
			var second: Dictionary = WorldLayoutScript.ROAD_SPECS[second_index]
			var overlap := WorldLayoutScript.road_rect(first).intersection(WorldLayoutScript.road_rect(second))
			_expect(
				overlap.size.x <= 0.001 or overlap.size.y <= 0.001,
				"road overlays %s and %s meet without coplanar overlap" % [first["id"], second["id"]]
			)
	var path_ids := {}
	for path_spec: Dictionary in WorldLayoutScript.PATH_SPECS:
		var path_id := String(path_spec["id"])
		var dimensions: Vector2 = path_spec["dimensions"]
		_expect(not path_ids.has(path_id), "pedestrian path ID %s is unique" % path_id)
		path_ids[path_id] = true
		_expect(minf(dimensions.x, dimensions.y) == 5.0, "%s keeps one consistent pedestrian width" % path_id)
	for first_index in WorldLayoutScript.PATH_SPECS.size():
		var first: Dictionary = WorldLayoutScript.PATH_SPECS[first_index]
		var first_rect := Rect2(Vector2(first["center"]) - Vector2(first["dimensions"]) * 0.5, first["dimensions"])
		for second_index in range(first_index + 1, WorldLayoutScript.PATH_SPECS.size()):
			var second: Dictionary = WorldLayoutScript.PATH_SPECS[second_index]
			var second_rect := Rect2(Vector2(second["center"]) - Vector2(second["dimensions"]) * 0.5, second["dimensions"])
			var overlap := first_rect.intersection(second_rect)
			_expect(
				overlap.size.x <= 0.001 or overlap.size.y <= 0.001,
				"pedestrian paths %s and %s meet without coplanar overlap" % [first["id"], second["id"]]
			)


func _test_surface_standard() -> void:
	_expect(
		is_zero_approx(WorldLayoutScript.BASE_GRADE_ELEVATION),
		"Harbor remains the canonical zero-elevation reference"
	)
	var semantic_colors := {
		WorldBuilderScript.COLOR_GROUND.to_html(): true,
		WorldBuilderScript.COLOR_MAIN_ROAD.to_html(): true,
		WorldBuilderScript.COLOR_SERVICE_ROAD.to_html(): true,
		WorldBuilderScript.COLOR_PATH.to_html(): true,
		WorldBuilderScript.COLOR_PLATFORM.to_html(): true,
		WorldBuilderScript.COLOR_PROTOTYPE_PAD.to_html(): true,
		WorldBuilderScript.COLOR_RESERVED.to_html(): true,
	}
	_expect(semantic_colors.size() == 7, "graybox surface roles use distinct flat development colors")


func _test_wayfinding_configuration() -> void:
	var expected_arrows := {
		"starter_site": "←",
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
		WorldLayoutScript.wayfinding_spec_by_id("crude_intake").is_empty(),
		"obsolete Crude Intake sign has no remaining Pilot wayfinding authority"
	)
	_expect(
		WorldLayoutScript.wayfinding_arrow(
			WorldLayoutScript.wayfinding_spec_by_id("pilot_process_chain")
		).is_empty(),
		"non-directional Pilot process marker does not invent a route arrow"
	)
	var gate_spec := WorldLayoutScript.wayfinding_spec_by_id("main_refinery_gate")
	_expect(
		is_equal_approx(float(gate_spec["yaw_degrees"]), 180.0),
		"Main Refinery gate board faces the player approaching north from Harbor"
	)


func _test_spawn_and_legacy_coordinates() -> void:
	var spawn := WorldLayoutScript.NEW_GAME_SPAWN
	_expect(WorldLayoutScript.player_position_is_valid(spawn), "new-game spawn is inside canonical player bounds")
	_expect(
		WorldLayoutScript.area_id_at(Vector2(spawn.x, spawn.z)) == "pilot_plant",
		"new-game spawn is in the contained Harbor Pilot region"
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
	_expect(
		WorldLayoutScript.player_requires_recovery(Vector3(0.0, 0.1, WorldLayoutScript.DEEP_WATER_RECOVERY_Z))
		and not WorldLayoutScript.player_position_is_valid(
			Vector3(0.0, 0.1, WorldLayoutScript.DEEP_WATER_RECOVERY_Z)
		),
		"deep Harbor water triggers safe recovery without swimming"
	)
	_expect(
		is_equal_approx(WorldLayoutScript.LAND_BOUNDS.end.y, WorldLayoutScript.SHORELINE_Z)
		and WorldLayoutScript.player_position_is_valid(Vector3(0.0, 0.1, WorldLayoutScript.SHORELINE_Z - 1.0)),
		"visible Harbor land ends at the canonical shoreline before deep-water recovery"
	)
	_expect(
		WorldLayoutScript.legacy_v0304_player_position(Vector3(400.0, 0.1, 0.0))
		and not WorldLayoutScript.player_position_is_valid(Vector3(400.0, 0.1, 0.0)),
		"old broad-world positions are recognized for deterministic Harbor recovery"
	)
	_expect(
		WorldLayoutScript.legacy_v0310_player_position(Vector3(52.0, 16.0, -285.0))
		and not WorldLayoutScript.player_position_is_valid(Vector3(52.0, 16.0, -285.0)),
		"old v0.31.0 Upper Plant positions are recognized for intimacy-pass recovery"
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
	_expect(builder.terrace_nodes.size() == WorldLayoutScript.TERRACE_SPECS.size(), "world builder emits every canonical terrace")
	_expect(builder.road_nodes.size() == WorldLayoutScript.ROAD_SPECS.size(), "world builder emits every configured road")
	_expect(builder.path_nodes.size() == WorldLayoutScript.PATH_SPECS.size(), "world builder emits every configured pedestrian path")
	_expect(builder.landmark_nodes.size() == 10, "world builder emits restrained process and central-core landmarks")
	_expect(
		builder.harbor_nodes.has("quay_edge")
		and builder.harbor_nodes.has("crude_intake")
		and builder.harbor_nodes.has("product_dispatch")
		and builder.harbor_nodes.has("warehouse"),
		"Harbor has a quay, two non-functional logistics reservations and one orienting warehouse mass"
	)
	_expect(
		builder.harbor_nodes["quay_edge"].get_meta("canonical_spec") == WorldLayoutScript.HARBOR_QUAY_SPEC
		and builder.harbor_nodes["warehouse"].get_meta("canonical_spec") == WorldLayoutScript.HARBOR_WAREHOUSE_SPEC,
		"Harbor quay and warehouse geometry consume canonical layout specifications"
	)
	_expect(
		builder.find_children("*", "StaticBody3D", true, false).filter(
			func(node) -> bool: return String(node.get_meta("harbor_feature", "")).contains("quay")
		).size() == 1
		and builder.find_children("QuayBarrier", "StaticBody3D", true, false).is_empty(),
		"Harbor emits one shoreline safety edge and no duplicate parallel barrier layer"
	)
	_expect(builder.has_node("TerrainBuffer"), "world builder creates traversable macro terrain")
	var terrain_buffer: StaticBody3D = builder.get_node("TerrainBuffer")
	_expect(
		terrain_buffer.find_children("*", "MeshInstance3D", true, false).is_empty()
		and terrain_buffer.find_children("*", "CollisionShape3D", true, false).size() == 1,
		"macro terrain collision has no duplicate rendered surface at base grade"
	)
	var industrial_ground: MeshInstance3D = builder.get_node("IndustrialGround")
	_expect(
		industrial_ground is MeshInstance3D and industrial_ground.mesh.get_surface_count() == 7,
		"one authoritative terrain mesh renders ground, roads, paths and local pads without overlays"
	)
	_expect(builder.has_node("SouthernSea"), "world builder creates the southern sea edge")
	for boundary_name: String in ["NorthBoundary", "WestBoundary", "EastBoundary"]:
		_expect(builder.has_node(boundary_name), "%s collision boundary exists" % boundary_name)
	_expect(not builder.has_node("SouthShoreBoundary"), "shoreline safety edge replaces the duplicate south perimeter fence")
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
		else:
			_expect(
				not area_node.has_node("AreaFootprint")
				and bool(area_node.get_meta("terrain_pad", false)) == bool(area.get("terrain_pad", false)),
				"%s uses the single rendered terrain surface instead of a coplanar area overlay" % area_id
			)
	for terrace: Dictionary in WorldLayoutScript.TERRACE_SPECS:
		var terrace_id := String(terrace["id"])
		var terrace_node: Node3D = builder.terrace_nodes[terrace_id]
		_expect(
			terrace_node.get_meta("canonical_rect") == WorldLayoutScript.terrace_rect(terrace)
			and is_equal_approx(float(terrace_node.get_meta("surface_elevation")), float(terrace["elevation"])),
			"%s geometry consumes canonical footprint and elevation" % terrace_id
		)
	for road: Dictionary in WorldLayoutScript.ROAD_SPECS:
		var road_node: Node3D = builder.road_nodes[String(road["id"])]
		_expect(
			road_node.get_meta("canonical_rect") == WorldLayoutScript.road_rect(road)
			and String(road_node.get_meta("render_owner")) == "IndustrialGround"
			and not road_node is MeshInstance3D,
			"%s is canonically painted into the single terrain mesh" % road["id"]
		)
		if String(road.get("kind", "flat")) == "grade":
			_expect(
				float(road_node.get_meta("grade_percent")) <= 7.0,
				"%s rendered grade remains at most seven percent" % road["id"]
			)
	_expect(
		builder.get_node("PrototypeProcessPad") is Node3D
		and builder.get_node("Area02BuildOverlay") is Node3D
		and not builder.has_node("PrototypeBuildPad"),
		"Pilot pad is painted into terrain and no legacy build-pad node survives"
	)
	var build_overlay: Node3D = builder.get_node("Area02BuildOverlay")
	var canonical_build_bounds := WorldLayoutScript.build_bounds()
	_expect(
		build_overlay.get_meta("canonical_bounds") == canonical_build_bounds
		and not build_overlay is MeshInstance3D,
		"Build Mode uses canonical boundary lines without a duplicate full-pad floor surface"
	)
	var signs: Array = [
		builder.orientation_nodes["starter_site"],
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
	for sign_id: String in ["starter_site"]:
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
	for area_id: String in [
		"cdu", "vdu", "fcc", "ht", "utilities", "crude_storage", "product_storage",
		"control_room", "lab", "maintenance",
	]:
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

	for road: Dictionary in WorldLayoutScript.ROAD_SPECS:
		if String(road.get("kind", "flat")) != "ramp":
			continue
		var route := _road_ramp_route(road)
		var from_terrace := WorldLayoutScript.terrace_by_id(String(road["from_terrace"]))
		var to_terrace := WorldLayoutScript.terrace_by_id(String(road["to_terrace"]))
		walker.global_position = Vector3(route[0].x, float(from_terrace["elevation"]) + 0.1, route[0].y)
		walker.velocity = Vector3.ZERO
		await physics_frame
		await _walk_existing_body(walker, route[1], 8.0)
		_expect(
			walker.global_position.y >= float(to_terrace["elevation"]) - 0.15,
			"%s connects %s to %s for a player-sized body" % [
				road["id"], road["from_terrace"], road["to_terrace"]
			]
		)

	var boundary_checks := [
		{"start": Vector3(WorldLayoutScript.WORLD_BOUNDS.position.x + 2.0, 0.1, 0.0), "direction": Vector3.LEFT},
		{"start": Vector3(WorldLayoutScript.WORLD_BOUNDS.end.x - 2.0, 0.1, 0.0), "direction": Vector3.RIGHT},
		{"start": Vector3(52.0, 10.4, WorldLayoutScript.WORLD_BOUNDS.position.y + 2.0), "direction": Vector3.FORWARD},
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

	walker.global_position = Vector3(52.0, 0.1, -22.0)
	walker.velocity = Vector3.ZERO
	await physics_frame
	for frame_index in 100:
		walker.velocity = Vector3(0.0, -0.5, -6.0)
		walker.move_and_slide()
		await physics_frame
	_expect(
		walker.global_position.z < -32.0,
		"open starter transition gate preserves player-sized access toward the Main Refinery"
	)

	walker.global_position = Vector3(0.0, 0.1, WorldLayoutScript.SHORELINE_Z - 4.0)
	walker.velocity = Vector3.ZERO
	await physics_frame
	for frame_index in 60:
		walker.velocity = Vector3(0.0, -0.5, 6.0)
		walker.move_and_slide()
		await physics_frame
	_expect(
		walker.global_position.z < WorldLayoutScript.DEEP_WATER_RECOVERY_Z,
		"single Harbor safety edge physically blocks the visible shoreline before recovery water"
	)

	await _walk_route(
		walker,
		[
			Vector2(-10.0, 8.0),
			Vector2(-10.0, 28.0),
			Vector2(52.0, 28.0),
			Vector2(52.0, -28.0),
			Vector2(52.0, -75.0),
			Vector2(52.0, -127.0),
			Vector2(52.0, -178.0),
		],
		6.0
	)
	_expect(
		WorldLayoutScript.terrace_id_at(Vector2(walker.global_position.x, walker.global_position.z)) == "upper_plant"
		and walker.global_position.y >= 8.8,
		"Harbor → Lower → Main → Upper main-road route is continuous without jumping"
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


func _walk_existing_body(walker: CharacterBody3D, target: Vector2, speed: float) -> void:
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


func _road_ramp_route(road: Dictionary) -> Array[Vector2]:
	var center: Vector2 = road["center"]
	var dimensions: Vector2 = road["dimensions"]
	return [
		Vector2(center.x, center.y + dimensions.y * 0.5 - 3.0),
		Vector2(center.x, center.y - dimensions.y * 0.5 + 1.0),
	]


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
