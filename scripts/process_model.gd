class_name ProcessModel
extends RefCounted

const BATCH_VOLUME_L := 1000.0
const AMBIENT_TEMPERATURE_C := 20.0
const PUMP_CAPACITY_LPS := 10.0
const DIESEL_TARGET_L := 200.0
const APPROVED_QUALITY_PERCENT := 90.0
const PRODUCT_TANK_CAPACITY_L := 600.0
const PILOT_CONTRACT_MINIMUM_REVENUE := 2800

var crude_volume_l := BATCH_VOLUME_L
var light_product_l := 0.0
var diesel_volume_l := 0.0
var heavy_product_l := 0.0
var diesel_quality_percent := 0.0

var pump_running := false
var feed_valve_open := false
var heater_setpoint_c := 0.0
var heater_temperature_c := AMBIENT_TEMPERATURE_C
var flow_lps := 0.0
var money := 0
var batch_sold := false
var objective_complete := false


func reset_batch() -> void:
	crude_volume_l = BATCH_VOLUME_L
	light_product_l = 0.0
	diesel_volume_l = 0.0
	heavy_product_l = 0.0
	diesel_quality_percent = 0.0
	pump_running = false
	feed_valve_open = false
	heater_setpoint_c = 0.0
	heater_temperature_c = AMBIENT_TEMPERATURE_C
	flow_lps = 0.0
	batch_sold = false
	objective_complete = false


func toggle_pump() -> String:
	if crude_volume_l <= 0.0:
		return "Råoljetanken er tom."
	pump_running = not pump_running
	return "Pumpen er startet." if pump_running else "Pumpen er stoppet."


func toggle_feed_valve() -> String:
	feed_valve_open = not feed_valve_open
	return "Mateventilen er åpen." if feed_valve_open else "Mateventilen er stengt."


func cycle_heater() -> String:
	if heater_setpoint_c < 1.0:
		heater_setpoint_c = 170.0
	elif heater_setpoint_c < 180.0:
		heater_setpoint_c = 200.0
	elif heater_setpoint_c < 210.0:
		heater_setpoint_c = 230.0
	else:
		heater_setpoint_c = 0.0

	if heater_setpoint_c <= 0.0:
		return "Varmeenheten er slått av."
	return "Temperaturmål satt til %d °C." % int(heater_setpoint_c)


func tick(delta: float) -> void:
	_update_heater(delta)
	_update_flow()

	if flow_lps <= 0.0 or crude_volume_l <= 0.0:
		return

	var processed_l := minf(flow_lps * delta, crude_volume_l)
	var remaining_capacity := _smallest_remaining_product_capacity()
	processed_l = minf(processed_l, remaining_capacity)
	if processed_l <= 0.0:
		flow_lps = 0.0
		return

	crude_volume_l -= processed_l
	_separate(processed_l)

	if crude_volume_l <= 0.001:
		crude_volume_l = 0.0
		flow_lps = 0.0
		pump_running = false


func _update_heater(delta: float) -> void:
	var target_temperature := AMBIENT_TEMPERATURE_C
	if heater_setpoint_c > 0.0:
		target_temperature = heater_setpoint_c

	# The unit heats fastest before flow starts. This gives the player a useful
	# reason to warm up the process before opening the line.
	var degrees_per_second := 18.0 if flow_lps <= 0.01 else 7.0
	heater_temperature_c = move_toward(
		heater_temperature_c,
		target_temperature,
		degrees_per_second * delta
	)


func _update_flow() -> void:
	if pump_running and feed_valve_open and crude_volume_l > 0.0:
		flow_lps = PUMP_CAPACITY_LPS
	else:
		flow_lps = 0.0


func _separate(processed_l: float) -> void:
	var fractions := _fractions_for_temperature(heater_temperature_c)
	var new_light_l: float = processed_l * fractions.x
	var new_diesel_l: float = processed_l * fractions.y
	var new_heavy_l: float = processed_l * fractions.z
	var new_quality := _diesel_quality(heater_temperature_c, flow_lps)

	if new_diesel_l > 0.0:
		var quality_total := diesel_quality_percent * diesel_volume_l
		quality_total += new_quality * new_diesel_l
		diesel_quality_percent = quality_total / (diesel_volume_l + new_diesel_l)

	light_product_l += new_light_l
	diesel_volume_l += new_diesel_l
	heavy_product_l += new_heavy_l


func _fractions_for_temperature(temperature_c: float) -> Vector3:
	if temperature_c < 170.0:
		return Vector3(0.08, 0.12, 0.80)
	if temperature_c < 185.0:
		return Vector3(0.20, 0.25, 0.55)
	if temperature_c <= 215.0:
		return Vector3(0.30, 0.35, 0.35)
	if temperature_c <= 225.0:
		return Vector3(0.40, 0.30, 0.30)
	return Vector3(0.55, 0.20, 0.25)


func _diesel_quality(temperature_c: float, current_flow_lps: float) -> float:
	var temperature_penalty := absf(temperature_c - 200.0) * 1.15
	var flow_penalty := maxf(current_flow_lps - PUMP_CAPACITY_LPS, 0.0) * 2.0
	return clampf(100.0 - temperature_penalty - flow_penalty, 0.0, 100.0)


func _smallest_remaining_product_capacity() -> float:
	# The three fractions always sum to one, so this conservative value prevents
	# any product tank from overflowing in the prototype.
	return minf(
		PRODUCT_TANK_CAPACITY_L - light_product_l,
		minf(
			PRODUCT_TANK_CAPACITY_L - diesel_volume_l,
			PRODUCT_TANK_CAPACITY_L - heavy_product_l
		)
	)


func diesel_is_approved() -> bool:
	return (
		diesel_volume_l >= DIESEL_TARGET_L
		and diesel_quality_percent >= APPROVED_QUALITY_PERCENT
	)


func sell_diesel() -> String:
	if batch_sold:
		return "Denne batchen er allerede solgt."
	if diesel_volume_l < DIESEL_TARGET_L:
		return "For lite diesel: %.0f / %.0f liter." % [diesel_volume_l, DIESEL_TARGET_L]
	if diesel_quality_percent < APPROVED_QUALITY_PERCENT:
		return "OFF-SPEC: Kvaliteten må være minst %.0f %%" % APPROVED_QUALITY_PERCENT

	# The first Area 02 refinery costs 2 400 kr. The training contract guarantees
	# enough startup capital even when the player sells as soon as 200 L is ready.
	var revenue := maxi(
		int(round(diesel_volume_l * 8.0)),
		PILOT_CONTRACT_MINIMUM_REVENUE
	)
	money += revenue
	batch_sold = true
	objective_complete = true
	return "Batch godkjent og solgt for %d kr!" % revenue


func can_afford(cost: int) -> bool:
	return cost >= 0 and money >= cost


func purchase(cost: int) -> bool:
	if not can_afford(cost):
		return false
	money -= cost
	return true


func refund(amount: int) -> void:
	if amount > 0:
		money += amount


func credit(amount: int) -> void:
	if amount > 0:
		money += amount


func active_alarms() -> Array[String]:
	var alarms: Array[String] = []
	if pump_running and not feed_valve_open:
		alarms.append("LOW FLOW — kontroller ventilen")
	elif pump_running and crude_volume_l <= 0.0:
		alarms.append("LOW FLOW — råoljetanken er tom")
	if heater_temperature_c > 225.0:
		alarms.append("HIGH TEMPERATURE — produktkvalitet i fare")
	if _smallest_remaining_product_capacity() <= 0.01:
		alarms.append("PRODUCT TANK FULL — produksjonen er stoppet")
	return alarms
