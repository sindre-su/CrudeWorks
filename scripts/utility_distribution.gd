class_name UtilityDistribution
extends RefCounted

const TRIP_NONE := ""
const TRIP_OVERLOAD := "overload"
const TRIP_SUPPLY_LOSS := "supply_loss"
const VALID_TRIP_IDS := [TRIP_NONE, TRIP_OVERLOAD, TRIP_SUPPLY_LOSS]

var utility_id := ""
var tripped := false
var trip_id := TRIP_NONE
var last_trip_demand := 0.0
var last_trip_capacity := 0.0


func _init(p_utility_id := "utility") -> void:
	utility_id = p_utility_id


func trip(p_trip_id: String, demand: float, capacity: float) -> void:
	tripped = true
	trip_id = p_trip_id if p_trip_id in VALID_TRIP_IDS else TRIP_OVERLOAD
	last_trip_demand = maxf(0.0, demand)
	last_trip_capacity = maxf(0.0, capacity)


func can_reset(capacity: float, requested_demand: float) -> bool:
	return capacity > 0.001 and requested_demand <= capacity + 0.001


func reset(capacity: float, requested_demand: float) -> bool:
	if not can_reset(capacity, requested_demand):
		return false
	tripped = false
	trip_id = TRIP_NONE
	return true


func clear() -> void:
	tripped = false
	trip_id = TRIP_NONE
	last_trip_demand = 0.0
	last_trip_capacity = 0.0


func save_state() -> Dictionary:
	return {
		"tripped": tripped,
		"trip_id": trip_id,
		"last_trip_demand": last_trip_demand,
		"last_trip_capacity": last_trip_capacity,
	}


func apply_saved_state(state: Dictionary) -> void:
	tripped = bool(state.get("tripped", false))
	trip_id = String(state.get("trip_id", TRIP_NONE)) if tripped else TRIP_NONE
	last_trip_demand = maxf(0.0, float(state.get("last_trip_demand", 0.0)))
	last_trip_capacity = maxf(0.0, float(state.get("last_trip_capacity", 0.0)))
