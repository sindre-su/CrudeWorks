class_name FirstPersonPlayer
extends CharacterBody3D

signal interacted(unit_id: String)
signal reset_requested

const WALK_SPEED := 6.0
const RUN_SPEED := 9.0
const CROUCH_SPEED := 3.2
const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 18.0
const JUMP_VELOCITY := 6.2
const STANDING_HEIGHT := 1.75
const CROUCHING_HEIGHT := 1.05
const STANDING_CAMERA_HEIGHT := 1.65
const CROUCHING_CAMERA_HEIGHT := 0.88
const POSTURE_CHANGE_SPEED := 6.0

var camera: Camera3D
var raycast: RayCast3D
var collider: CollisionShape3D
var capsule: CapsuleShape3D
var is_crouching := false
var build_mode_active := false


func _ready() -> void:
	_register_input_actions()

	camera = Camera3D.new()
	camera.position = Vector3(0.0, STANDING_CAMERA_HEIGHT, 0.0)
	add_child(camera)

	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0.0, 0.0, -4.5)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	camera.add_child(raycast)

	collider = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = STANDING_HEIGHT
	collider.shape = capsule
	collider.position = Vector3(0.0, STANDING_HEIGHT * 0.5, 0.0)
	add_child(collider)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_update_posture(delta)

	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_W):
		movement.y += 1.0
	if Input.is_key_pressed(KEY_S):
		movement.y -= 1.0
	movement = movement.normalized()

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var direction := (right * movement.x + forward * movement.y).normalized()
	var speed := WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_key_pressed(KEY_SHIFT):
		speed = RUN_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _update_posture(delta: float) -> void:
	var wants_to_crouch := Input.is_action_pressed("crouch")
	if wants_to_crouch:
		is_crouching = true
	elif is_crouching and _can_stand_up():
		is_crouching = false

	var target_height := CROUCHING_HEIGHT if is_crouching else STANDING_HEIGHT
	var target_camera_height := (
		CROUCHING_CAMERA_HEIGHT if is_crouching else STANDING_CAMERA_HEIGHT
	)
	capsule.height = move_toward(
		capsule.height,
		target_height,
		POSTURE_CHANGE_SPEED * delta
	)
	collider.position.y = capsule.height * 0.5
	camera.position.y = move_toward(
		camera.position.y,
		target_camera_height,
		POSTURE_CHANGE_SPEED * delta
	)


func _can_stand_up() -> bool:
	var space_state := get_world_3d().direct_space_state
	var ray_offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(0.28, 0.0, 0.0),
		Vector3(-0.28, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.28),
		Vector3(0.0, 0.0, -0.28),
	]
	for offset in ray_offsets:
		var from: Vector3 = global_position + offset + Vector3.UP * (CROUCHING_HEIGHT - 0.12)
		var to: Vector3 = global_position + offset + Vector3.UP * (STANDING_HEIGHT + 0.08)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_rid()]
		if not space_state.intersect_ray(query).is_empty():
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(
			camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(-82.0),
			deg_to_rad(82.0)
		)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E and not build_mode_active:
			_try_interaction()
		elif event.keycode == KEY_R and not build_mode_active:
			reset_requested.emit()


func focused_unit():
	if not is_instance_valid(raycast):
		return null
	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return null
	var collider := raycast.get_collider()
	if collider is InteractiveUnit:
		return collider
	return null


func _try_interaction() -> void:
	var unit = focused_unit()
	if unit != null:
		interacted.emit(unit.unit_id)


func _register_input_actions() -> void:
	_register_key_action("interact", KEY_E)
	_register_key_action("jump", KEY_SPACE)
	_register_key_action("crouch", KEY_CTRL)
	_register_key_action("crouch", KEY_C)


func _register_key_action(action_name: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if (
			existing_event is InputEventKey
			and existing_event.physical_keycode == physical_keycode
		):
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, key_event)
