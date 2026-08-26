class_name MaterialBalance
extends RefCounted

# One shared test/diagnostic invariant for every material boundary:
# before + input - output - defined loss = after.
# Live simulation does not crash on rounding drift; callers decide how to report it.
const DEFAULT_TOLERANCE_L := 0.01


static func inventory_total_l(inventory: Dictionary) -> float:
	var total := 0.0
	for volume in inventory.values():
		if not _valid_volume(volume):
			return NAN
		total += float(volume)
	return total


static func evaluate(
	before_inventory: Dictionary,
	after_inventory: Dictionary,
	boundary_input_l := 0.0,
	boundary_output_l := 0.0,
	defined_loss_l := 0.0,
	tolerance_l := DEFAULT_TOLERANCE_L
) -> Dictionary:
	var before_l := inventory_total_l(before_inventory)
	var after_l := inventory_total_l(after_inventory)
	var boundary_values_valid := (
		_valid_volume(boundary_input_l)
		and _valid_volume(boundary_output_l)
		and _valid_volume(defined_loss_l)
		and _valid_volume(tolerance_l)
	)
	var inventories_valid := not is_nan(before_l) and not is_nan(after_l)
	var expected_after_l := (
		before_l + float(boundary_input_l) - float(boundary_output_l) - float(defined_loss_l)
		if inventories_valid and boundary_values_valid
		else NAN
	)
	var error_l := after_l - expected_after_l if not is_nan(expected_after_l) else NAN
	return {
		"conserved": (
			inventories_valid
			and boundary_values_valid
			and absf(error_l) <= float(tolerance_l)
		),
		"before_l": before_l,
		"input_l": float(boundary_input_l),
		"output_l": float(boundary_output_l),
		"defined_loss_l": float(defined_loss_l),
		"expected_after_l": expected_after_l,
		"after_l": after_l,
		"error_l": error_l,
		"tolerance_l": float(tolerance_l),
	}


static func _valid_volume(value) -> bool:
	return (
		typeof(value) in [TYPE_INT, TYPE_FLOAT]
		and not is_nan(float(value))
		and not is_inf(float(value))
		and float(value) >= 0.0
	)
