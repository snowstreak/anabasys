extends CharacterBody3D

# region Constants

# Movement
const WALK_SPEED = 3.0
const SPRINT_SPEED = 4.5
const CROUCH_SPEED = 1.5
const JUMP_VELOCITY = 7.2 # can jump 1.2m, can't 1.3
const MAX_STEP_HEIGHT = 0.3
const BASE_TIME_WALKED = 0.0

# World
const BASE_GRAVITY = 24

# Camera and Mouse
const SENSITIVITY = 0.0028

# Head Bobbing
const BASE_BOB_FREQUENCY = 3.5
const BASE_BOB_AMPLITUDE = 0.025
const SPRINT_BOB_APLITUDE = BASE_BOB_AMPLITUDE * 2.0

# Weapon Sway
const SWAY_IDLE_FREQ = 0.75 / 4
const SWAY_IDLE_AMP = 0.02 * 1.2
const BASE_SWAY_TIME = 0.0

# Heights
const STANDING_HEIGHT = 1.8
const CROUCH_HEIGHT = 1
const STANDING_EYE_HEIGHT = 1.7
const CROUCH_EYE_HEIGHT = 0.9

# FOV
const BASE_FOV = 75.0
const SPRINT_FOV = 85.0
const CROUCH_FOV = 70.0

# endregion

const DEFAULT_PLAY_GUIDE_TEXT = "WASD to move
Space to jump
Ctrl to crouch
Shift to sprint
Esc to exit
N to noclip"

enum PlayerState {STANDING, CROUCHING, SPRINTING}
var player_state = PlayerState.STANDING

# region Variables

# Testing
var limbo_height = 6.5 + 0.05 + 1.1 - 0.5
var is_noclipping = false

# Movement
var current_speed = WALK_SPEED
var prev_footstep_phase = 0.0

# Physics
var time_walked = BASE_TIME_WALKED
var sway_time = BASE_SWAY_TIME
var knife_base_pos = Vector3.ZERO
var bob_frequency = BASE_BOB_FREQUENCY
var bob_amplitude = BASE_BOB_AMPLITUDE
var step_number = 0.0
var gravity = BASE_GRAVITY

# UI
var fade_duration = 0.2

# endregion

# region Nodes

# Player
@onready var player_collision = $PlayerCollision
@onready var player_shapecast = $PlayerShapeCast
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var knife = $Head/Camera3D/Knife
@onready var footstep_sound = $FootstepSound

# UI
@onready var movement_status_label = $"../UI/MovementStatus"
@onready var standing_message_label = $"../UI/StandingMessage"
@onready var vignette = $"../UI/Vignette"
@onready var play_guide = $"../UI/PlayGuide"

# Testing
@onready var limbo_bar = $"../LevelGeometry/LimboBar"

# Level
@onready var glow_box = $"../LevelGeometry/GlowBox"


# endregion

# region Ready

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	knife_base_pos = knife.position

	limbo_bar.position.y = limbo_height + 1

	player_collision.shape.height = STANDING_HEIGHT

	_show_game_title(2.0)

	vignette.modulate.a = 0

# endregion
# region Input

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Rotate the head and camera based on mouse movement.
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90, 90)

	# Handle input for exiting the game.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# endregion

# region Process

func _process(delta: float) -> void:
	# Noclip toggle
	if Input.is_action_just_pressed("noclip"):
		is_noclipping = not is_noclipping
		print(is_noclipping)
		player_collision.disabled = is_noclipping # Disable collision in noclip mode
		if is_noclipping:
			velocity = Vector3.ZERO # Reset velocity when entering noclip
			play_guide.text = "WASD to move
			Space to go up
			Ctrl to go down
			Shift to go faster
			Esc to exit
			N to stop noclipping"
		else:
			play_guide.text = DEFAULT_PLAY_GUIDE_TEXT

	if is_noclipping:
		# Noclip movement
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var base_noclip_speed = WALK_SPEED * 2
		var noclip_speed = base_noclip_speed
		if Input.is_action_pressed("sprint"):
			noclip_speed *= 2

		# Handle vertical movement with jump and crouch
		if Input.is_action_pressed("jump"):
			direction.y += 1.0
		if Input.is_action_pressed("crouch"):
			direction.y -= 1.0

		# Normalize direction if there's vertical movement to prevent faster diagonal movement
		if direction.length_squared() > 1.0:
			direction = direction.normalized()

		global_transform.origin += direction * noclip_speed * delta # Directly update position

	# Handle sprinting.
	# if the player is pressing the sprint button and not crouching and moving, set the state to sprinting
	if Input.is_action_pressed("sprint") and player_state != PlayerState.CROUCHING and _moving() and Input.is_action_pressed("move_forward") and is_on_floor():
		player_state = PlayerState.SPRINTING
	elif Input.is_action_just_released("sprint") and player_state == PlayerState.SPRINTING:
		player_state = PlayerState.STANDING

	# If player stops moving forward while sprinting, return to standing
	if (Input.is_action_just_released("move_forward") or Input.is_action_just_pressed("move_back")) and player_state == PlayerState.SPRINTING:
		player_state = PlayerState.STANDING

	# Handle crouch toggle
	if Input.is_action_just_pressed("crouch"):
		if player_state != PlayerState.CROUCHING:
			player_state = PlayerState.CROUCHING
			fade_in()
		elif player_state == PlayerState.CROUCHING:
			if _can_stand_up():
				player_state = PlayerState.STANDING
				fade_out()

	# Update player properties based on state (visual/audio parameters)
	match player_state:
		PlayerState.STANDING:
			bob_frequency = BASE_BOB_FREQUENCY
			bob_amplitude = BASE_BOB_AMPLITUDE
			head.transform.origin.y = lerpf(head.transform.origin.y, STANDING_EYE_HEIGHT, delta * 10)
		PlayerState.CROUCHING:
			bob_frequency = BASE_BOB_FREQUENCY * 0.7 # Adjust bobbing for crouch
			bob_amplitude = BASE_BOB_AMPLITUDE * 0.5 # Adjust bobbing for crouch
			head.transform.origin.y = lerpf(head.transform.origin.y, CROUCH_EYE_HEIGHT, delta * 10)
			if not _can_stand_up():
				_show_permanent_stand_error_message("No space above to stand up")
			else:
				standing_message_label.hide()
		PlayerState.SPRINTING:
			bob_frequency = BASE_BOB_FREQUENCY * 1.2 # Adjust bobbing for sprint
			bob_amplitude = SPRINT_BOB_APLITUDE
			head.transform.origin.y = lerpf(head.transform.origin.y, STANDING_EYE_HEIGHT, delta * 10)

	# Apply head bobbing effect (visual)
	camera.transform.origin = _headbob(time_walked)

	# Footstep sound triggering (audio)
	var current_footstep_phase = _footstep(time_walked)
	if prev_footstep_phase > 0.025 and current_footstep_phase <= 0.025:
		footstep_sound.play()
	prev_footstep_phase = current_footstep_phase

	# Handle camera FOV changes (visual)
	var target_fov = BASE_FOV
	match player_state:
		PlayerState.CROUCHING:
			target_fov = CROUCH_FOV
		PlayerState.SPRINTING:
			target_fov = SPRINT_FOV
	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)

	# Weapon sway effect (visual)
	var sway_freq = SWAY_IDLE_FREQ
	var sway_amp = SWAY_IDLE_AMP

	sway_time += delta
	var sway_offset = Vector3(sin(sway_time * sway_freq) * sway_amp, 0, 0)
	knife.position = knife_base_pos + sway_offset

	# Update movement status label (UI)
	match player_state:
		PlayerState.CROUCHING:
			movement_status_label.text = "Crouching"
		PlayerState.SPRINTING:
			movement_status_label.text = "Sprinting"
		PlayerState.STANDING:
			movement_status_label.text = "Walking"
		_: # Default case for any other state (shouldn't happen with enum)
			movement_status_label.text = "Error"

# endregion

# region Physics Process

func _physics_process(delta: float) -> void:
	if not is_noclipping:
		# Add gravity.
		if not is_on_floor():
			# falling
			velocity.y -= gravity * delta

		# Handle jump.
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			# waits two frames then resets bobbing and footsteps
			# the engine momentarily considers me on the ground for some reason
			await get_tree().process_frame
			await get_tree().process_frame
			time_walked = BASE_TIME_WALKED

		# Update player properties based on state (physics parameters)
		match player_state:
			PlayerState.STANDING:
				current_speed = WALK_SPEED
				player_collision.shape.height = STANDING_HEIGHT
				player_collision.transform.origin.y = 0.9
			PlayerState.CROUCHING:
				current_speed = CROUCH_SPEED
				player_collision.shape.height = CROUCH_HEIGHT
				player_collision.transform.origin.y = 0.5
			PlayerState.SPRINTING:
				current_speed = SPRINT_SPEED
				player_collision.shape.height = STANDING_HEIGHT # Sprinting is done standing
				player_collision.transform.origin.y = 0.9

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

		# Update time_walked based on velocity (physics-dependent)
		time_walked += velocity.length() * delta * float(is_on_floor())
		# Reset time_walked periodically to avoid float overflow, but keep bobbing/footsteps looping smoothly
		var bob_period = 2 * TAU / bob_frequency # bob_frequency is updated in _process, but used here. This dependency is acceptable.
		if time_walked > 1000.0:
			time_walked = fmod(time_walked, bob_period)

		move_and_slide()

# endregion

# region Functions

func _headbob(time) -> Vector3:
	# Calculates the head bobbing offset based on time, frequency, and amplitude.
	# Uses cosine for vertical movement and sine for horizontal movement (half frequency).
	var pos = Vector3.ZERO
	pos.y = cos(time * bob_frequency) * bob_amplitude
	pos.x = sin(time * bob_frequency / 2) * (bob_amplitude / 2)
	return pos

func _footstep(time) -> float:
	# Calculates a value related to the footstep phase based on head bobbing.
	# This value is used to trigger footstep sounds.
	var step = 0.0
	step = cos(time * bob_frequency) * bob_amplitude
	# Snapped value + offset for footstep trigger logic
	return snapped(100 * step, 0.01) + 2.5

func _can_stand_up() -> bool:
	var space_needed = STANDING_HEIGHT - CROUCH_HEIGHT - 0.01
	player_shapecast.target_position = Vector3.UP * space_needed
	player_shapecast.force_update_transform() # Ensure it's up to date
	player_shapecast.enabled = true
	player_shapecast.force_shapecast_update()
	return not player_shapecast.is_colliding()

func _show_stand_error_message(msg: String, duration: float):
	standing_message_label.text = msg
	standing_message_label.show()
	await get_tree().create_timer(duration).timeout
	standing_message_label.hide()

func _show_permanent_stand_error_message(msg: String):
	standing_message_label.text = msg
	standing_message_label.show()

func _show_game_title(duration: float):
	$"../UI/GameTitle".show()
	await get_tree().create_timer(duration).timeout
	$"../UI/GameTitle".hide()

func fade_in():
	var tween = get_tree().create_tween()
	tween.tween_property(vignette, "modulate:a", 1, fade_duration)
	tween.play()
	await tween.finished
	tween.kill()

func fade_out():
	var tween = get_tree().create_tween()
	tween.tween_property(vignette, "modulate:a", 0, fade_duration)
	tween.play()
	await tween.finished
	tween.kill()

# endregion

# region State Helpers

func _moving() -> bool:
	# Check if the player is moving based on the current speed and input direction.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	# return direction.length() > 0.1
	return direction.length() > 0.1

func _sprinting() -> bool:
	return player_state == PlayerState.SPRINTING

func _crouching() -> bool:
	return player_state == PlayerState.CROUCHING

# endregion
