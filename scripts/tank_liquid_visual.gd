class_name TankLiquidVisual
extends RefCounted

## Transparent tank shells must not render their triangulated top/bottom caps.
## The liquid cylinder owns the one intended horizontal surface inside a tank.


static func open_transparent_shell(mesh: CylinderMesh) -> void:
	mesh.cap_top = false
	mesh.cap_bottom = false


static func create(
	parent: Node,
	radius: float,
	max_height: float,
	color: Color,
	radial_segments := 28
) -> Dictionary:
	var liquid := MeshInstance3D.new()
	liquid.name = "LiquidLevel"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = radial_segments
	liquid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.05
	material.roughness = 0.18
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.2
	liquid.material_override = material
	liquid.visible = false
	liquid.set_meta("tank_liquid_render_path", "canonical_cylinder")
	parent.add_child(liquid)
	return {
		"node": liquid,
		"material": material,
		"max_height": max_height,
		"bottom_y": -max_height * 0.5,
	}


static func set_fill(data: Dictionary, fill_ratio: float, color: Color) -> void:
	var liquid: MeshInstance3D = data["node"]
	var material: StandardMaterial3D = data["material"]
	var max_height: float = data["max_height"]
	var ratio := clampf(fill_ratio, 0.0, 1.0)
	var display_height := maxf(max_height * ratio, 0.015)
	liquid.scale.y = display_height
	liquid.position.y = float(data["bottom_y"]) + display_height * 0.5
	liquid.visible = ratio > 0.001
	material.albedo_color = color
	material.emission = color
