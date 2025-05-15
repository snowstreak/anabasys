extends CharacterBody3D

# --- Constants ---

# Movement
const WALK_SPEED = 3.0
const SPRINT_SPEED = 4.5
const CROUCH_SPEED = 1.5
const JUMP_VELOCITY = 8.5
const MAX_STEP_HEIGHT = 0.3
const BASE_TIME_WALKED = 0.0

# World
const GRAVITY = 24

# Camera and Mouse
const SENSITIVITY = 0.0028

# Head Bobbing
const BASE_BOB_FREQUENCY = 3.5
const BASE_BOB_AMPLITUDE = 0.025

# Weapon Sway
const SWAY_IDLE_FREQ = 0.75
const SWAY_IDLE_AMP = 0.02

# Heights
const STANDING_HEIGHT = 1.79
const CROUCH_HEIGHT = 0.99
const STANDING_EYE_HEIGHT = 1.7
const CROUCH_EYE_HEIGHT = 0.9

# FOV
const BASE_FOV = 75.0
const SPRINT_FOV = 80.0 * 1.5
const CROUCH_FOV = 70.0

# --- Variables ---

# Testing
var limbo_height = 1.7
var already_played = false

# Movement
var current_speed = WALK_SPEED
var prev_step_number = 0.0

# Physics
var time_walked = BASE_TIME_WALKED
var t_sway_time = 0.0
var knife_base_pos = Vector3.ZERO
var bob_frequency = BASE_BOB_FREQUENCY
var bob_amplitude = BASE_BOB_AMPLITUDE
var step_number = 0.0

# ! - for footsteps to correspond with steps, a step sound needs to play every time headbob pos.y sinewave is at its highest or lowest
# (*) Footsteps - handle later
# var footstep_timer = 0.0
# var current_footstep_interval = 0.5

# --- Node Declaration ---

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var knife = $Head/Camera3D/Knife
@onready var shadow = $Head/Shadow
@onready var player_collision = $PlayerCollision
@onready var limbo_bar = $"../LevelGeometry/limbo_bar"
@onready var player_shapecast = $PlayerShapeCast
@onready var footstep_sound = $FootstepSound
@onready var message_label = $"../UI/MessageLabel"

# --- Functions ---
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	knife_base_pos = knife.position

	limbo_bar.position.y = limbo_height + 0.1

	player_collision.shape.height = STANDING_HEIGHT

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Rotate the head and camera based on mouse movement.
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)

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
		time_walked = BASE_TIME_WALKED

	# Handle sprinting.
	# if the player is pressing the sprint button and not crouching and moving, set the speed to sprint speed
	if Input.is_action_pressed("sprint") and current_speed != CROUCH_SPEED and _player_is_moving():
		current_speed = SPRINT_SPEED
		bob_amplitude = BASE_BOB_AMPLITUDE * 2
	elif Input.is_action_just_released("sprint") and current_speed != CROUCH_SPEED:
		current_speed = WALK_SPEED
		bob_amplitude = BASE_BOB_AMPLITUDE

	# Handle crouch toggle
	if Input.is_action_just_pressed("crouch"):
		if current_speed != CROUCH_SPEED:
			current_speed = CROUCH_SPEED
		elif current_speed == CROUCH_SPEED and can_stand_up():
			current_speed = WALK_SPEED
		else:
			show_message("Can't stand up, not enough space")
				
	# Handle head position when crouching
	var target_eye_height = STANDING_EYE_HEIGHT
	if current_speed == CROUCH_SPEED:
		target_eye_height = CROUCH_EYE_HEIGHT
	else:
		target_eye_height = STANDING_EYE_HEIGHT

	head.position.y = lerp(head.position.y, target_eye_height, 0.25)
		
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		# Apply current_speed to movement when on the floor.
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			# Apply deceleration when no input is given.
			velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 10.0)
			velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 10.0)
	else:
		# Apply deceleration when not on the floor.
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 8.0)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 8.0)

	# Apply head bobbing effect.
	time_walked += velocity.length() * delta * float(is_on_floor())
	if time_walked > 10000:
		time_walked = 0.0
	camera.transform.origin = _headbob(time_walked)
	step_number = snapped((time_walked * 0.55) + 0.5, 0)
	show_test_message(str(step_number))
	# Every time step_number increases by 1, play footstep_sound
	if step_number != prev_step_number:
		footstep_sound.play()
		prev_step_number = step_number

	# Handle camera FOV changes.
	camera.fov = lerpf(camera.fov, (SPRINT_FOV if current_speed == SPRINT_SPEED else BASE_FOV), delta * 8.0)
	camera.fov = lerpf(camera.fov, (CROUCH_FOV if current_speed == CROUCH_SPEED else BASE_FOV), delta * 8.0)
	
	# Handle shadow transparency when crouching.
	if current_speed == CROUCH_SPEED:
		shadow.transparency = lerp(1.0, 0.1, 1)
	else:
		shadow.transparency = lerp(0.1, 1.0, 1)

	# --- Weapon Sway ---
	var sway_freq = SWAY_IDLE_FREQ
	var sway_amp = SWAY_IDLE_AMP

	t_sway_time += delta
	var sway_offset = Vector3(sin(t_sway_time * sway_freq) * sway_amp, 0, 0)
	knife.position = knife_base_pos + sway_offset

	if current_speed == CROUCH_SPEED:
		player_collision.shape.height = CROUCH_HEIGHT
	else:
		player_collision.shape.height = STANDING_HEIGHT

	# prevent player from standing when not enough space to fit their standing height


	move_and_slide()

func _headbob(time) -> Vector3:
	# Head bobbing effect based on time and current_speed.
	var pos = Vector3.ZERO
	pos.y = cos(time * bob_frequency) * bob_amplitude
	pos.x = sin(time * bob_frequency / 2) * (bob_amplitude / 2)
	return pos

#func _footstep(time) -> 

func can_stand_up() -> bool:
	var space_needed = STANDING_HEIGHT - CROUCH_HEIGHT - 0.01
	player_shapecast.target_position = Vector3.UP * space_needed
	player_shapecast.force_update_transform() # Ensure it's up to date
	player_shapecast.enabled = true
	player_shapecast.force_shapecast_update()
	return not player_shapecast.is_colliding()

func show_message(msg: String, duration := 2.0):
	message_label.text = msg
	message_label.show()
	await get_tree().create_timer(duration).timeout
	message_label.hide()

func show_test_message(msg: String):
	message_label.text = msg
	message_label.show()

func _player_is_moving() -> bool:
	# Check if the player is moving based on the current speed and input direction.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	return direction.length() > 0.1
