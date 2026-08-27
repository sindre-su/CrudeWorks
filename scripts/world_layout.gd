class_name WorldLayout
extends RefCounted

## Canonical x/z-space configuration for the CrudeWorks v1 graybox world.
## Rect2 values use x as east/west and y as north/south (world z).

const WORLD_BOUNDS := Rect2(-42.0, -200.0, 214.0, 268.0)
const LAND_BOUNDS := Rect2(-42.0, -200.0, 214.0, 264.0)
const TERRAIN_BOUNDS := Rect2(-58.0, -216.0, 246.0, 312.0)
const LEGACY_WORLD_BOUNDS_V0310 := Rect2(-60.0, -325.0, 240.0, 405.0)
const LEGACY_WORLD_BOUNDS_V0304 := Rect2(-60.0, -250.0, 600.0, 400.0)
const AREA_02_ID := "operations_hub"
const AREA_02_BUILD_MARGIN := Vector2(4.0, 4.0)
const AREA_02_FIXED_ANCHOR_INSET := 2.0
const BUILD_PLACEMENT_CLEARANCE := 0.02

## Migration-only v0.30.2 construction footprint. It must never drive current
## placement or visualization.
const LEGACY_AREA_02_BUILD_BOUNDS := Rect2(-20.0, 10.5, 40.0, 28.0)
const LEGACY_AREA_02_PLACEMENT_BASE_Y := 0.16
const PLAYER_Y_RANGE := Vector2(-5.0, 40.0)
const RECOVERY_MIN_Y := -20.0
const SHORELINE_Z := 64.0
const DEEP_WATER_RECOVERY_Z := 64.5
const NEW_GAME_SPAWN := Vector3(-10.0, 0.1, 8.0)
const NEW_GAME_YAW_DEGREES := -18.0
const PILOT_PROCESS_PAD_BOUNDS := Rect2(-15.5, -6.5, 31.0, 13.0)

const BASE_GRADE_ELEVATION := 0.0
const NATURAL_GRADE_START_Z := -42.0
const NATURAL_GRADE_END_Z := -200.0
const NATURAL_GRADE_MAX_ELEVATION := 10.5
const TERRAIN_GRID_STEP := 4.0
const PAD_TRANSITION_MARGIN := 6.0
const PROCESS_PLATFORM_ELEVATION := 0.75

const TERRACE_SPECS := [
	{
		"id": "harbor",
		"display_name": "Harbor",
		"center": Vector2(65.0, 11.0),
		"dimensions": Vector2(214.0, 106.0),
		"elevation": 0.0,
		"purpose": "Spawn, Pilot, logistics and active compatibility systems",
	},
	{
		"id": "lower_plant",
		"display_name": "Lower Plant",
		"center": Vector2(65.0, -75.0),
		"dimensions": Vector2(214.0, 38.0),
		"elevation": 3.5,
		"purpose": "Crude storage, first process block and early utilities",
	},
	{
		"id": "main_plant",
		"display_name": "Main Plant",
		"center": Vector2(65.0, -127.0),
		"dimensions": Vector2(214.0, 42.0),
		"elevation": 7.0,
		"purpose": "Product storage, Control/LAB core and maintenance",
	},
	{
		"id": "upper_plant",
		"display_name": "Upper Plant",
		"center": Vector2(65.0, -178.0),
		"dimensions": Vector2(214.0, 36.0),
		"elevation": 10.5,
		"purpose": "VDU, FCC and approved late expansion",
	},
]

const HARBOR_QUAY_SPEC := {
	"id": "quay_safety_edge",
	"center": Vector2(65.0, 63.7),
	"dimensions": Vector2(214.0, 0.4),
	"height": 1.1,
}
const HARBOR_WAREHOUSE_SPEC := {
	"id": "warehouse",
	"center": Vector2(82.0, 32.0),
	"dimensions": Vector2(16.0, 12.0),
	"height": 7.0,
}

const AREA_SPECS := [
	{
		"id": "control_room",
		"display_name": "Control Room",
		"center": Vector2(30.0, -116.0),
		"dimensions": Vector2(20.0, 14.0),
		"elevation": 7.0,
		"kind": "operations",
		"terrace": "main_plant",
		"purpose": "Future central supervision shell",
		"road_access": "main_corridor_west",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "lab",
		"display_name": "LAB",
		"center": Vector2(30.0, -138.0),
		"dimensions": Vector2(20.0, 14.0),
		"elevation": 7.0,
		"kind": "operations",
		"terrace": "main_plant",
		"purpose": "Future analytical facility near product operations",
		"road_access": "lab_access",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "crude_intake",
		"display_name": "Crude Intake",
		"center": Vector2(31.0, 49.0),
		"dimensions": Vector2(26.0, 18.0),
		"elevation": 0.0,
		"kind": "logistics",
		"terrace": "harbor",
		"purpose": "Reserved final CI-101 Harbor anchor",
		"road_access": "main_spine_harbor",
		"render_platform": false,
		"terrain_pad": false,
		"functional_state": "reserved_anchor",
	},
	{
		"id": "pilot_plant",
		"display_name": "Pilot Plant",
		"center": Vector2(-10.0, 5.0),
		"dimensions": Vector2(55.0, 42.0),
		"elevation": 0.0,
		"kind": "process",
		"terrace": "harbor",
		"purpose": "Contained functional tutorial process",
		"road_access": "pilot_access",
		"render_platform": false,
		"terrain_pad": false,
		"functional_state": "functional",
	},
	{
		"id": "operations_hub",
		"display_name": "Area 02 / Operations Hub",
		"center": Vector2(120.0, -10.0),
		"dimensions": Vector2(80.0, 60.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "operations",
		"terrace": "harbor",
		"purpose": "Temporary active Area 02 and functional CI/PD compatibility pocket",
		"road_access": "area02_access",
		"render_platform": true,
		"access_sides": ["west", "east"],
		"buildable": true,
		"build_margin": AREA_02_BUILD_MARGIN,
		"upstream_side": "west",
		"downstream_side": "east",
	},
	{
		"id": "crude_storage",
		"display_name": "Crude Storage",
		"center": Vector2(-15.0, -75.0),
		"dimensions": Vector2(38.0, 26.0),
		"elevation": 3.5,
		"kind": "storage",
		"terrace": "lower_plant",
		"purpose": "Future crude tank farm",
		"road_access": "lower_corridor_west",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "cdu",
		"display_name": "CDU",
		"center": Vector2(26.0, -75.0),
		"dimensions": Vector2(28.0, 26.0),
		"elevation": 3.5,
		"kind": "process",
		"terrace": "lower_plant",
		"purpose": "First atmospheric process block",
		"road_access": "lower_corridor_west",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "ht",
		"display_name": "HT",
		"center": Vector2(78.0, -75.0),
		"dimensions": Vector2(28.0, 26.0),
		"elevation": 3.5,
		"kind": "process",
		"terrace": "lower_plant",
		"purpose": "Treatment support within Lower Plant",
		"road_access": "lower_corridor_east",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "utilities",
		"display_name": "Utilities",
		"center": Vector2(113.0, -75.0),
		"dimensions": Vector2(34.0, 26.0),
		"elevation": 3.5,
		"kind": "utilities",
		"terrace": "lower_plant",
		"purpose": "Reserved early Utilities Yard",
		"road_access": "lower_corridor_east",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "vdu",
		"display_name": "VDU",
		"center": Vector2(-8.0, -178.0),
		"dimensions": Vector2(48.0, 28.0),
		"elevation": 10.5,
		"kind": "process",
		"terrace": "upper_plant",
		"purpose": "Future VDU process block",
		"road_access": "upper_corridor_west",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "fcc",
		"display_name": "FCC",
		"center": Vector2(31.0, -178.0),
		"dimensions": Vector2(22.0, 28.0),
		"elevation": 10.5,
		"kind": "process",
		"terrace": "upper_plant",
		"purpose": "Future FCC process block",
		"road_access": "upper_corridor_west",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "future_expansion",
		"display_name": "Future Expansion",
		"center": Vector2(87.0, -178.0),
		"dimensions": Vector2(46.0, 28.0),
		"elevation": 10.5,
		"kind": "reserved",
		"terrace": "upper_plant",
		"purpose": "Naphtha, larger utilities and approved late expansion",
		"road_access": "upper_corridor_east",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "product_dispatch",
		"display_name": "Product Dispatch",
		"center": Vector2(138.0, 49.0),
		"dimensions": Vector2(34.0, 18.0),
		"elevation": 0.0,
		"kind": "logistics",
		"terrace": "harbor",
		"purpose": "Reserved final PD-101 Harbor anchor",
		"road_access": "harbor_logistics_lane",
		"render_platform": false,
		"terrain_pad": false,
		"functional_state": "reserved_anchor",
	},
	{
		"id": "product_storage",
		"display_name": "Product Tank Farm",
		"center": Vector2(-9.0, -128.0),
		"dimensions": Vector2(50.0, 36.0),
		"elevation": 7.0,
		"kind": "storage",
		"terrace": "main_plant",
		"purpose": "Future product storage and routing",
		"road_access": "main_corridor_west",
		"render_platform": false,
		"terrain_pad": true,
	},
	{
		"id": "maintenance",
		"display_name": "Maintenance / Workshop",
		"center": Vector2(87.0, -128.0),
		"dimensions": Vector2(46.0, 34.0),
		"elevation": 7.0,
		"kind": "support",
		"terrace": "main_plant",
		"purpose": "Future central service and workshop gameplay",
		"road_access": "main_corridor_east",
		"render_platform": false,
		"terrain_pad": true,
	},
]

const ROAD_SPECS := [
	{
		"id": "main_spine_harbor",
		"center": Vector2(52.0, 11.0),
		"dimensions": Vector2(8.0, 106.0),
		"class": "main",
		"terrace": "harbor",
		"elevation": 0.0,
		"sequence": 0,
	},
	{
		"id": "main_spine_inland_grade",
		"center": Vector2(52.0, -121.0),
		"dimensions": Vector2(8.0, 158.0),
		"class": "main",
		"kind": "grade",
		"from_elevation": 0.0,
		"to_elevation": 10.5,
		"direction": "north",
		"sequence": 1,
	},
	{
		"id": "pilot_access",
		"center": Vector2(32.75, 5.0),
		"dimensions": Vector2(30.5, 5.0),
		"class": "service",
		"terrace": "harbor",
		"elevation": 0.0,
	},
	{
		"id": "area02_access",
		"center": Vector2(65.5, -10.0),
		"dimensions": Vector2(19.0, 5.0),
		"class": "service",
		"terrace": "harbor",
		"elevation": 0.0,
	},
	{
		"id": "harbor_logistics_lane",
		"center": Vector2(88.5, 49.0),
		"dimensions": Vector2(65.0, 5.0),
		"class": "service",
		"terrace": "harbor",
		"elevation": 0.0,
	},
	{
		"id": "lower_corridor_west",
		"center": Vector2(7.0, -57.0),
		"dimensions": Vector2(82.0, 5.0),
		"class": "service",
		"terrace": "lower_plant",
	},
	{
		"id": "lower_corridor_east",
		"center": Vector2(93.0, -57.0),
		"dimensions": Vector2(74.0, 5.0),
		"class": "service",
		"terrace": "lower_plant",
	},
	{
		"id": "main_corridor_west",
		"center": Vector2(7.0, -104.0),
		"dimensions": Vector2(82.0, 5.0),
		"class": "service",
		"terrace": "main_plant",
	},
	{
		"id": "main_corridor_east",
		"center": Vector2(83.0, -104.0),
		"dimensions": Vector2(54.0, 5.0),
		"class": "service",
		"terrace": "main_plant",
	},
	{
		"id": "lab_access",
		"center": Vector2(44.0, -138.0),
		"dimensions": Vector2(8.0, 5.0),
		"class": "service",
		"terrace": "main_plant",
	},
	{
		"id": "upper_corridor_west",
		"center": Vector2(8.0, -156.0),
		"dimensions": Vector2(80.0, 5.0),
		"class": "service",
		"terrace": "upper_plant",
	},
	{
		"id": "upper_corridor_east",
		"center": Vector2(83.0, -156.0),
		"dimensions": Vector2(54.0, 5.0),
		"class": "service",
		"terrace": "upper_plant",
	},
]

const PATH_SPECS := [
	{
		"id": "control_lab_path",
		"center": Vector2(30.0, -127.0),
		"dimensions": Vector2(5.0, 8.0),
		"terrace": "main_plant",
		"elevation": 7.0,
	},
	{
		"id": "pilot_quay_path",
		"center": Vector2(-10.0, 30.5),
		"dimensions": Vector2(5.0, 7.0),
		"terrace": "harbor",
		"elevation": 0.0,
	},
]

## Physical signs derive their displayed direction from this canonical placement
## and the target area's center. The arrow is relative to a player facing the
## readable side of the board, rather than a hardcoded compass instruction.
const WAYFINDING_SPECS := [
	{
		"id": "starter_site",
		"position": Vector3(-3.0, 0.0, 8.2),
		"yaw_degrees": 90.0,
		"primary": "PILOT AREA",
		"target_area_id": "pilot_plant",
		"board_size": Vector2(3.0, 0.8),
	},
	{
		"id": "pilot_process_chain",
		"position": Vector3(14.5, 0.0, 6.8),
		"yaw_degrees": 180.0,
		"primary": "PILOT PROCESS",
		"board_size": Vector2(3.2, 0.8),
	},
	{
		"id": "main_refinery_gate",
		"position": Vector3(52.0, 0.0, -28.0),
		"yaw_degrees": 180.0,
		"primary": "MAIN REFINERY",
		"target_area_id": "cdu",
		"target_position": Vector2(52.0, -75.0),
		"board_size": Vector2(3.8, 0.8),
	},
]


static func build_bounds() -> Rect2:
	var area := area02_spec()
	var platform_rect := area_rect(area)
	var margin: Vector2 = area["build_margin"]
	return Rect2(platform_rect.position + margin, platform_rect.size - margin * 2.0)


static func area02_spec() -> Dictionary:
	return area_by_id(AREA_02_ID)


static func area02_platform_rect() -> Rect2:
	return area_rect(area02_spec())


static func area02_surface_elevation() -> float:
	return float(area02_spec()["elevation"])


static func placement_center_y(equipment_height: float) -> float:
	return area02_surface_elevation() + BUILD_PLACEMENT_CLEARANCE + equipment_height * 0.5


static func area02_anchor(anchor_id: String) -> Vector2:
	var platform_rect := area02_platform_rect()
	var center := platform_rect.get_center()
	match anchor_id:
		"crude_intake":
			return Vector2(platform_rect.position.x + AREA_02_FIXED_ANCHOR_INSET, center.y)
		"product_dispatch":
			return Vector2(platform_rect.end.x - AREA_02_FIXED_ANCHOR_INSET, center.y)
	return center


static func area02_inward_direction(anchor_id: String) -> Vector2:
	return (area02_platform_rect().get_center() - area02_anchor(anchor_id)).normalized()


static func cardinal_rotation_quadrants(local_facing: Vector2, desired_world_facing: Vector2) -> int:
	var best_quadrant := 0
	var best_alignment := -INF
	var rotated := local_facing.normalized()
	var desired := desired_world_facing.normalized()
	for quadrant in 4:
		var alignment := rotated.dot(desired)
		if alignment > best_alignment:
			best_alignment = alignment
			best_quadrant = quadrant
		rotated = Vector2(rotated.y, -rotated.x)
	return best_quadrant


static func legacy_area02_translation() -> Vector3:
	var legacy_center := LEGACY_AREA_02_BUILD_BOUNDS.get_center()
	var current_center := build_bounds().get_center()
	return Vector3(
		current_center.x - legacy_center.x,
		area02_surface_elevation() + BUILD_PLACEMENT_CLEARANCE - LEGACY_AREA_02_PLACEMENT_BASE_Y,
		current_center.y - legacy_center.y + 0.5
	)


static func world_contains_xz(point: Vector2) -> bool:
	return WORLD_BOUNDS.has_point(point) or _point_on_rect_end(point, WORLD_BOUNDS)


static func world_contains_rect(rect: Rect2) -> bool:
	return (
		rect.position.x >= WORLD_BOUNDS.position.x
		and rect.position.y >= WORLD_BOUNDS.position.y
		and rect.end.x <= WORLD_BOUNDS.end.x
		and rect.end.y <= WORLD_BOUNDS.end.y
	)


static func terrace_rect(terrace: Dictionary) -> Rect2:
	var dimensions: Vector2 = terrace["dimensions"]
	var center: Vector2 = terrace["center"]
	return Rect2(center - dimensions * 0.5, dimensions)


static func terrace_by_id(terrace_id: String) -> Dictionary:
	for terrace: Dictionary in TERRACE_SPECS:
		if String(terrace["id"]) == terrace_id:
			return terrace
	return {}


static func terrace_id_at(point: Vector2) -> String:
	for terrace: Dictionary in TERRACE_SPECS:
		if terrace_rect(terrace).has_point(point):
			return String(terrace["id"])
	return "transit"


static func natural_grade_elevation_at_z(z_position: float) -> float:
	if z_position >= NATURAL_GRADE_START_Z:
		return BASE_GRADE_ELEVATION
	if z_position <= NATURAL_GRADE_END_Z:
		return NATURAL_GRADE_MAX_ELEVATION
	var progress := inverse_lerp(NATURAL_GRADE_START_Z, NATURAL_GRADE_END_Z, z_position)
	return lerpf(BASE_GRADE_ELEVATION, NATURAL_GRADE_MAX_ELEVATION, progress)


static func terrain_elevation_at(point: Vector2) -> float:
	var natural_elevation := natural_grade_elevation_at_z(point.y)
	var shaped_elevation := natural_elevation
	for area: Dictionary in AREA_SPECS:
		if not bool(area.get("terrain_pad", false)):
			continue
		var rect := area_rect(area)
		var target_elevation := float(area["elevation"])
		if rect.has_point(point) or _point_on_rect_end(point, rect):
			return target_elevation
		var margin := float(area.get("terrain_transition", PAD_TRANSITION_MARGIN))
		var expanded := rect.grow(margin)
		if not expanded.has_point(point):
			continue
		var delta_x := maxf(maxf(rect.position.x - point.x, point.x - rect.end.x), 0.0)
		var delta_z := maxf(maxf(rect.position.y - point.y, point.y - rect.end.y), 0.0)
		var distance := Vector2(delta_x, delta_z).length()
		var blend := 1.0 - smoothstep(0.0, margin, distance)
		shaped_elevation = maxf(
			shaped_elevation,
			lerpf(natural_elevation, target_elevation, blend)
		)
	return shaped_elevation


static func area_rect(area: Dictionary) -> Rect2:
	var dimensions: Vector2 = area["dimensions"]
	var center: Vector2 = area["center"]
	return Rect2(center - dimensions * 0.5, dimensions)


static func area_by_id(area_id: String) -> Dictionary:
	for area: Dictionary in AREA_SPECS:
		if String(area["id"]) == area_id:
			return area
	return {}


static func road_rect(road: Dictionary) -> Rect2:
	var dimensions: Vector2 = road["dimensions"]
	var center: Vector2 = road["center"]
	return Rect2(center - dimensions * 0.5, dimensions)


static func harbor_logistics_anchor(area_id: String) -> Vector2:
	var area := area_by_id(area_id)
	if String(area.get("terrace", "")) != "harbor":
		return Vector2.ZERO
	return area.get("center", Vector2.ZERO)


static func wayfinding_spec_by_id(sign_id: String) -> Dictionary:
	for spec: Dictionary in WAYFINDING_SPECS:
		if String(spec["id"]) == sign_id:
			return spec
	return {}


static func wayfinding_arrow(spec: Dictionary) -> String:
	var target_area_id := String(spec.get("target_area_id", ""))
	if target_area_id.is_empty() and not spec.has("target_position"):
		return ""
	var target_center: Vector2
	if spec.has("target_position"):
		target_center = spec["target_position"]
	else:
		var target_area := area_by_id(target_area_id)
		if target_area.is_empty():
			return ""
		target_center = target_area["center"]
	var sign_position: Vector3 = spec["position"]
	var target_direction := Vector3(
		target_center.x - sign_position.x,
		0.0,
		target_center.y - sign_position.z
	).normalized()
	var sign_basis := Basis(Vector3.UP, deg_to_rad(float(spec["yaw_degrees"])))
	var board_front := sign_basis * Vector3.FORWARD
	var viewer_forward := -board_front
	var viewer_right := viewer_forward.cross(Vector3.UP).normalized()
	var lateral := target_direction.dot(viewer_right)
	if absf(lateral) < 0.2:
		return "↑"
	return "→" if lateral > 0.0 else "←"


static func area_id_at(point: Vector2) -> String:
	for area: Dictionary in AREA_SPECS:
		if area_rect(area).has_point(point):
			return String(area["id"])
	return "transit"


static func placement_inside_active_build_bounds(center: Vector2, footprint: Vector2) -> bool:
	var active_bounds := build_bounds()
	var half := footprint * 0.5
	return (
		center.x - half.x >= active_bounds.position.x
		and center.x + half.x <= active_bounds.end.x
		and center.y - half.y >= active_bounds.position.y
		and center.y + half.y <= active_bounds.end.y
	)


static func placement_inside_legacy_build_bounds(center: Vector2, footprint: Vector2) -> bool:
	var half := footprint * 0.5
	return (
		center.x - half.x >= LEGACY_AREA_02_BUILD_BOUNDS.position.x
		and center.x + half.x <= LEGACY_AREA_02_BUILD_BOUNDS.end.x
		and center.y - half.y >= LEGACY_AREA_02_BUILD_BOUNDS.position.y
		and center.y + half.y <= LEGACY_AREA_02_BUILD_BOUNDS.end.y
	)


static func player_position_is_valid(position: Vector3) -> bool:
	return (
		world_contains_xz(Vector2(position.x, position.z))
		and position.z < DEEP_WATER_RECOVERY_Z
		and position.y >= PLAYER_Y_RANGE.x
		and position.y <= PLAYER_Y_RANGE.y
	)


static func player_requires_recovery(position: Vector3) -> bool:
	return (
		position.y < RECOVERY_MIN_Y
		or position.z >= DEEP_WATER_RECOVERY_Z
		or not world_contains_xz(Vector2(position.x, position.z))
	)


static func legacy_v0304_player_position(position: Vector3) -> bool:
	var point := Vector2(position.x, position.z)
	return (
		(LEGACY_WORLD_BOUNDS_V0304.has_point(point) or _point_on_rect_end(point, LEGACY_WORLD_BOUNDS_V0304))
		and position.y >= PLAYER_Y_RANGE.x
		and position.y <= PLAYER_Y_RANGE.y
	)


static func legacy_v0310_player_position(position: Vector3) -> bool:
	var point := Vector2(position.x, position.z)
	return (
		(LEGACY_WORLD_BOUNDS_V0310.has_point(point) or _point_on_rect_end(point, LEGACY_WORLD_BOUNDS_V0310))
		and position.y >= PLAYER_Y_RANGE.x
		and position.y <= PLAYER_Y_RANGE.y
	)


static func _point_on_rect_end(point: Vector2, rect: Rect2) -> bool:
	return (
		point.x >= rect.position.x
		and point.y >= rect.position.y
		and point.x <= rect.end.x
		and point.y <= rect.end.y
	)
