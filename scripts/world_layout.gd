class_name WorldLayout
extends RefCounted

## Canonical x/z-space configuration for the CrudeWorks v1 graybox world.
## Rect2 values use x as east/west and y as north/south (world z).

const WORLD_BOUNDS := Rect2(-60.0, -250.0, 600.0, 400.0)
const TERRAIN_BOUNDS := Rect2(-90.0, -280.0, 660.0, 460.0)
const ACTIVE_BUILD_BOUNDS := Rect2(-20.0, 10.5, 40.0, 28.0)
const PLAYER_Y_RANGE := Vector2(-5.0, 40.0)
const RECOVERY_MIN_Y := -20.0
const NEW_GAME_SPAWN := Vector3(-10.0, 0.1, 8.0)
const NEW_GAME_YAW_DEGREES := -18.0

const ROAD_ELEVATION := 0.02
const PEDESTRIAN_PATH_ELEVATION := 0.12
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
		"access_side": "south",
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
		"display_name": "Operations Hub",
		"center": Vector2(120.0, -10.0),
		"dimensions": Vector2(80.0, 60.0),
		"elevation": PROCESS_PLATFORM_ELEVATION,
		"kind": "operations",
		"render_platform": true,
		"access_sides": ["west", "east"],
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
		"id": "starter_pilot_path",
		"center": Vector2(-10.0, 3.0),
		"dimensions": Vector2(2.0, 6.0),
	},
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


static func build_bounds() -> Rect2:
	return ACTIVE_BUILD_BOUNDS


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


static func area_id_at(point: Vector2) -> String:
	for area: Dictionary in AREA_SPECS:
		if area_rect(area).has_point(point):
			return String(area["id"])
	return "transit"


static func placement_inside_active_build_bounds(center: Vector2, footprint: Vector2) -> bool:
	var half := footprint * 0.5
	return (
		center.x - half.x >= ACTIVE_BUILD_BOUNDS.position.x
		and center.x + half.x <= ACTIVE_BUILD_BOUNDS.end.x
		and center.y - half.y >= ACTIVE_BUILD_BOUNDS.position.y
		and center.y + half.y <= ACTIVE_BUILD_BOUNDS.end.y
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
