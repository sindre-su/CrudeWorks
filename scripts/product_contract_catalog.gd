class_name ProductContractCatalog
extends RefCounted

## Product contracts and spot prices are commercial truth owned by PD-101.
## Crude supply definitions intentionally contain no downstream obligation.

const COMMISSIONING_ID := "area02_diesel_commissioning"
const LEGACY_DIESEL_ID := "legacy_diesel_delivery"
const LEGACY_HEAVY_ID := "legacy_heavy_delivery"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETE := "complete"
const STATUS_NONE := "none"
const VALID_STATUSES := [STATUS_ACTIVE, STATUS_COMPLETE, STATUS_NONE]


static func definition(contract_id: String) -> Dictionary:
	match contract_id:
		COMMISSIONING_ID:
			return {
				"id": COMMISSIONING_ID,
				"display_name": "Industridiesel",
				"requested_product": "diesel",
				"product_name": "Diesel",
				"required_quantity_l": 200.0,
				"required_quality_status": "on_spec",
				"unit_value": 8.0,
				"completion_bonus": 0,
				"progression_contract": true,
			}
		LEGACY_DIESEL_ID:
			return {
				"id": LEGACY_DIESEL_ID,
				"display_name": "Tidligere dieselleveranse",
				"requested_product": "diesel",
				"product_name": "Diesel",
				"required_quantity_l": 200.0,
				"required_quality_status": "on_spec",
				"unit_value": 8.0,
				"completion_bonus": 0,
				"progression_contract": false,
			}
		LEGACY_HEAVY_ID:
			return {
				"id": LEGACY_HEAVY_ID,
				"display_name": "Tidligere tungrestleveranse",
				"requested_product": "heavy",
				"product_name": "Tung rest",
				"required_quantity_l": 600.0,
				"required_quality_status": "not_applicable",
				"unit_value": 2.0,
				"completion_bonus": 1000,
				"progression_contract": false,
			}
	return {}


static func is_valid(contract_id: String) -> bool:
	return not definition(contract_id).is_empty()


static func initial_state() -> Dictionary:
	return {
		"contract_id": COMMISSIONING_ID,
		"delivered_l": 0.0,
		"status": STATUS_ACTIVE,
		"bonus_awarded": false,
	}


static func completed_commissioning_state() -> Dictionary:
	return {
		"contract_id": COMMISSIONING_ID,
		"delivered_l": float(definition(COMMISSIONING_ID)["required_quantity_l"]),
		"status": STATUS_COMPLETE,
		"bonus_awarded": true,
	}


static func legacy_state_for_crude(crude_id: String, commissioning_complete: bool) -> Dictionary:
	if not commissioning_complete:
		return initial_state()
	var contract_id := ""
	if crude_id in ["standard", "sour"]:
		contract_id = LEGACY_DIESEL_ID
	elif crude_id == "heavy":
		contract_id = LEGACY_HEAVY_ID
	if contract_id.is_empty():
		return completed_commissioning_state()
	return {
		"contract_id": contract_id,
		"delivered_l": 0.0,
		"status": STATUS_ACTIVE,
		"bonus_awarded": false,
	}


static func spot_sale_definition(product_id: String) -> Dictionary:
	match product_id:
		"light":
			return {"product": "light", "product_name": "Naphtha", "price_per_l": 5.0}
		"diesel":
			return {"product": "diesel", "product_name": "Diesel", "price_per_l": 8.0}
		"heavy":
			return {"product": "heavy", "product_name": "Tung rest", "price_per_l": 2.0}
		"vacuum_gas_oil":
			return {"product": "vacuum_gas_oil", "product_name": "Vacuum Gas Oil", "price_per_l": 4.0}
		"vacuum_residue":
			return {"product": "vacuum_residue", "product_name": "Vacuum Residue", "price_per_l": 1.0}
		"gasoline_blendstock":
			return {"product": "gasoline_blendstock", "product_name": "Gasoline Blendstock", "price_per_l": 7.0}
		"lpg":
			return {"product": "lpg", "product_name": "LPG", "price_per_l": 5.0}
		"light_cycle_oil":
			return {"product": "light_cycle_oil", "product_name": "Light Cycle Oil", "price_per_l": 3.0}
	return {}
