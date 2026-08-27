class_name WorldLayout
extends RefCounted

## Canonical x/z-space configuration for the CrudeWorks v1 graybox world.
## Rect2 values use x as east/west and y as north/south (world z).

const WORLD_BOUNDS := Rect2(-60.0, -250.0, 600.0, 400.0)
const TERRAIN_BOUNDS := Rect2(-90.0, -280.0, 660.0, 460.0)
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
const NEW_GAME_SPAWN := Vector3(-10.0, 0.1, 8.0)
const NEW_GAME_YAW_DEGREES := -18.0

const BASE_GRADE_ELEVATION := 0.0
const ROAD_ELEVATION := 0.012
const PEDESTRIAN_PATH_ELEVATION := 0.018
const PROCESS_PLATFORM_ELEVATION := 0.75

const AREA_SPECS := [
	{
		"id": "control_room",
		"display_name": "Control Room",
		"center": Vector2(105.0, -10.0),
		"dimensions": Vector2(30.0, 22.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "subarea",
		"render_platform": false,
	},
	{
		"id": "lab",
		"display_name": "LAB",
		"center": Vector2(145.0, -10.0),
		"dimensions": Vector2(24.0, 20.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "subarea",
		"render_platform": false,
	},
	{
		"id": "crude_intake",
		"display_name": "Crude Intake",
		"center": Vector2(-10.0, 75.0),
		"dimensions": Vector2(80.0, 70.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "logistics",
		"render_platform": true,
		"access_sides": ["north", "south"],
	},
	{
		"id": "pilot_plant",
		"display_name": "Pilot Plant",
		"center": Vector2(-10.0, -10.0),
		"dimensions": Vector2(75.0, 75.0),
		"elevation": 0.0,
		"kind": "process",
		"render_platform": true,
		"access_side": "east",
	},
	{
		"id": "operations_hub",
		"display_name": "Area 02 / Operations Hub",
		"center": Vector2(120.0, -10.0),
		"dimensions": Vector2(80.0, 60.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "operations",
		"render_platform": true,
		"access_sides": ["west", "east"],
		"buildable": true,
		"build_margin": AREA_02_BUILD_MARGIN,
		"upstream_side": "west",
		"downstream_side": "east",
	},
	{
		"id": "storage",
		"display_name": "Storage",
		"center": Vector2(260.0, 5.0),
		"dimensions": Vector2(150.0, 120.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "storage",
		"render_platform": true,
		"access_sides": ["west", "east"],
	},
	{
		"id": "cdu",
		"display_name": "CDU",
		"center": Vector2(120.0, -105.0),
		"dimensions": Vector2(100.0, 90.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "process",
		"render_platform": true,
		"access_side": "west",
	},
	{
		"id": "ht",
		"display_name": "HT",
		"center": Vector2(260.0, -105.0),
		"dimensions": Vector2(90.0, 80.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "process",
		"render_platform": true,
		"access_side": "east",
	},
	{
		"id": "utilities",
		"display_name": "Utilities",
		"center": Vector2(0.0, -195.0),
		"dimensions": Vector2(110.0, 90.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "utilities",
		"render_platform": true,
		"access_side": "east",
	},
	{
		"id": "vdu",
		"display_name": "VDU",
		"center": Vector2(120.0, -200.0),
		"dimensions": Vector2(100.0, 90.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "process",
		"render_platform": true,
		"access_side": "west",
	},
	{
		"id": "fcc",
		"display_name": "FCC",
		"center": Vector2(260.0, -197.5),
		"dimensions": Vector2(110.0, 95.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "process",
		"render_platform": true,
		"access_side": "east",
	},
	{
		"id": "future_expansion",
		"display_name": "Future Expansion",
		"center": Vector2(430.0, -180.0),
		"dimensions": Vector2(160.0, 130.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "reserved",
		"render_platform": true,
		"access_side": "west",
	},
	{
		"id": "product_dispatch",
		"display_name": "Product Dispatch",
		"center": Vector2(440.0, 75.0),
		"dimensions": Vector2(90.0, 70.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "logistics",
		"render_platform": true,
		"access_side": "west",
	},
]

const ROAD_SPECS := [
	{
		"id": "main_logistics_road",
		"center": Vector2(240.0, 120.0),
		"dimensions": Vector2(600.0, 8.0),
		"class": "main",
	},
	{
		"id": "west_service_road",
		"center": Vector2(62.5, -65.0),
		"dimensions": Vector2(5.0, 370.0),
		"class": "service",
	},
	{
		"id": "east_service_road",
		"center": Vector2(342.5, -65.0),
		"dimensions": Vector2(5.0, 370.0),
		"class": "service",
	},
	{
		"id": "middle_cross_road",
		"center": Vector2(200.0, -57.5),
		"dimensions": Vector2(280.0, 5.0),
		"class": "service",
	},
	{
		"id": "north_cross_west",
		"center": Vector2(130.0, -152.5),
		"dimensions": Vector2(140.0, 5.0),
		"class": "service",
	},
	{
		"id": "north_cross_east",
		"center": Vector2(270.0, -147.5),
		"dimensions": Vector2(140.0, 5.0),
		"class": "service",
	},
	{
		"id": "north_cross_jog",
		"center": Vector2(200.0, -150.0),
		"dimensions": Vector2(5.0, 5.0),
		"class": "service",
	},
	{
		"id": "crude_intake_access",
		"center": Vector2(-10.0, 115.0),
		"dimensions": Vector2(6.0, 10.0),
		"class": "service",
	},
	{
		"id": "pilot_access",
		"center": Vector2(43.75, -10.0),
		"dimensions": Vector2(32.5, 5.0),
		"class": "service",
	},
	{
		"id": "operations_access",
		"center": Vector2(70.0, -10.0),
		"dimensions": Vector2(10.0, 5.0),
		"class": "service",
	},
	{
		"id": "ht_access",
		"center": Vector2(325.0, -105.0),
		"dimensions": Vector2(30.0, 5.0),
		"class": "service",
	},
	{
		"id": "fcc_access",
		"center": Vector2(330.0, -197.5),
		"dimensions": Vector2(20.0, 5.0),
		"class": "service",
	},
	{
		"id": "product_dispatch_access",
		"center": Vector2(367.5, 75.0),
		"dimensions": Vector2(55.0, 6.0),
		"class": "service",
	},
]

const PATH_SPECS := [
	{
		"id": "operations_storage_path_x",
		"center": Vector2(172.5, -10.0),
		"dimensions": Vector2(15.0, 3.0),
	},
	{
		"id": "operations_storage_path_z",
		"center": Vector2(180.0, -2.5),
		"dimensions": Vector2(3.0, 15.0),
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
		"id": "crude_intake",
		"position": Vector3(-17.0, 0.0, 9.0),
		"yaw_degrees": -90.0,
		"primary": "CRUDE INTAKE",
		"target_area_id": "crude_intake",
		"board_size": Vector2(3.4, 0.8),
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
		"position": Vector3(34.0, 0.0, -10.0),
		"yaw_degrees": 90.0,
		"primary": "MAIN REFINERY",
		"target_area_id": "operations_hub",
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


static func area_rect(area: Dictionary) -> Rect2:
	var dimensions: Vector2 = area["dimensions"]
	var center: Vector2 = area["center"]
	return Rect2(center - dimensions * 0.5, dimensions)


static func area_by_id(area_id: String) -> Dictionary:
	for area: Dictionary in AREA_SPECS:
		if String(area["id"]) == area_id:
			return area
	return {}


static func wayfinding_spec_by_id(sign_id: String) -> Dictionary:
	for spec: Dictionary in WAYFINDING_SPECS:
		if String(spec["id"]) == sign_id:
			return spec
	return {}


static func wayfinding_arrow(spec: Dictionary) -> String:
	var target_area_id := String(spec.get("target_area_id", ""))
	if target_area_id.is_empty():
		return ""
	var target_area := area_by_id(target_area_id)
	if target_area.is_empty():
		return ""
	var sign_position: Vector3 = spec["position"]
	var target_center: Vector2 = target_area["center"]
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
		and position.y >= PLAYER_Y_RANGE.x
		and position.y <= PLAYER_Y_RANGE.y
	)


static func player_requires_recovery(position: Vector3) -> bool:
	return (
		position.y < RECOVERY_MIN_Y
		or not world_contains_xz(Vector2(position.x, position.z))
	)


static func _point_on_rect_end(point: Vector2, rect: Rect2) -> bool:
	return (
		point.x >= rect.position.x
		and point.y >= rect.position.y
		and point.x <= rect.end.x
		and point.y <= rect.end.y
	)
