extends CharacterBody3D

# --- Movement Constants ---
const WALK_SPEED = 4.5
const SPRINT_SPEED = 7.0
const CROUCH_SPEED = 2.25
const JUMP_VELOCITY = 4.5
const GRAVITY = 9.8

# --- Camera & Mouse Constants ---
const SENS_RATIO = 0.001
const SENSITIVITY = SENS_RATIO * 3

# --- Head Bobbing Constants ---
const BOB_FREQUENCY = 1.0
const BOB_AMPLITUDE = 0.04

# --- Crouch/Stand Heights ---
const CROUCH_HEIGHT = 1.0
const STAND_HEIGHT = 1.8

# --- Camera FOV Constants ---
const BASE_FOV = 75.0
const SPRINT_FOV = 90.0
const CROUCH_FOV = 60.0

# --- State Variables ---
var speed = WALK_SPEED
var t_bob = 0.0
var footstep_timer = 0.0
var current_footstep_interval = 0.5

# --- Node References ---
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var footstep_player = $Footsteps
@onready var knife = $Head/Camera3D/Knife

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Rotate the head and camera based on mouse movement.
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -80, 80)

	# Handle input for exiting the game.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _physics_process(delta: float) -> void:
	# Add gravity.
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle sprinting.
	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	elif Input.is_action_just_released("sprint"):
		# Reset speed to walking speed if sprint is released.
		speed = WALK_SPEED

	# Handle crouch toggle
	if Input.is_action_just_pressed("crouch"):
		if speed == WALK_SPEED or speed == SPRINT_SPEED:
			speed = CROUCH_SPEED
		else:
			speed = WALK_SPEED

	# Handle head position when crouching, smoothly interpolate.
	var target_height = CROUCH_HEIGHT if speed == CROUCH_SPEED else STAND_HEIGHT
	head.position.y = lerp(head.position.y, target_height, delta * 6.0)
	camera.position.y = lerp(camera.position.y, target_height, delta * 6.0)
		
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
	else:
		# Apply deceleration when not on the floor.
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 5.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 5.0)

	# Apply head bobbing effect.
	t_bob += velocity.length() * delta * float(is_on_floor())
	camera.transform.origin = _headbob(t_bob)

	camera.fov = lerpf(camera.fov, (SPRINT_FOV if Input.is_action_pressed("sprint") else BASE_FOV), delta * 10.0)
	camera.fov = lerpf(camera.fov, (CROUCH_FOV if speed == CROUCH_SPEED else BASE_FOV), delta * 8.0)

	move_and_slide()

func _headbob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQUENCY) * BOB_AMPLITUDE
	pos.x = cos(time * BOB_FREQUENCY / 2) * BOB_AMPLITUDE
	return pos
