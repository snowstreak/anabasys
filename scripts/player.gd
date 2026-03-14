extends CharacterBody3D
var _initial_head_local_origin: Vector3

# region Export
@export var enemy_node: Node3D

# region Constants

# Movement
const WALK_SPEED = 3.5
const SPRINT_SPEED = 5.5
const CROUCH_SPEED = 2.4
const JUMP_VELOCITY = 4.0 # can jump 1.2m, can't 1.3
const MAX_STEP_HEIGHT = 0.3 # irrelevant I think ?
const BASE_TIME_WALKED = 0.0 # declaration
const GROUND_DECEL_TIME = 10.0
const AIR_DECEL_TIME = 8.0

# World
const BASE_GRAVITY = 9.8

# Camera and Mouse
const SENSITIVITY = 0.001

# Head Bobbing
const BASE_BOB_FREQUENCY = 3.5
const BASE_BOB_AMPLITUDE = 0.025
const SPRINT_BOB_APLITUDE = BASE_BOB_AMPLITUDE * 2.0
const CROUCH_BOB_AMPLITUDE = BASE_BOB_AMPLITUDE * 0.8

# Weapon Sway
const SWAY_IDLE_FREQ = 0.75 / 4
const SWAY_IDLE_AMP = 0.02 * 1.2
const BASE_SWAY_TIME = 0.0

# Height
const STANDING_HEIGHT = 1.8
const CROUCH_HEIGHT = 1
const STANDING_EYE_HEIGHT = 1.7
const CROUCH_EYE_HEIGHT = 0.9

# FOV
const BASE_FOV = 75.0
const SPRINT_FOV = 85.0
const CROUCH_FOV = 70.0

# endregion

const DEFAULT_PLAY_GUIDE_TEXT = "WASD to WASD
Space to jump
Ctrl to crouch
Esc to exit
N to noclip"

enum PlayerState {STANDING, CROUCHING, SPRINTING}
enum Leaning {LEFT, RIGHT, NO}
var player_state = PlayerState.STANDING
var leaning
var lean = 0

var glowing: bool
var crouched: bool

# region Variables

var hearing_distance_mult: float
var light_level_mult: float
var player_state_mult = 1.0
var _seen_timer_started = false

# Testing
# var limbo_height = 
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
var is_jumping_from_floor = false # Flag to prevent time_walked update during jump

# Light
var light_value: float
var visibility
var light_level: int

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
@onready var light_detector = $Head/LightDetect
@onready var seen_timer: Timer = $SeenTimer
@onready var lean_ray = $LeanRay

# UI
@onready var movement_status_label = $"../UI/MovementStatus"
@onready var standing_message_label = $"../UI/StandingMessage"
@onready var vignette = $"../UI/Vignette"
@onready var play_guide = $"../UI/PlayGuide"

# Testing
#@onready var limbo_bar = $"../LevelGeometry/LimboBar"
#@onready var shade_box = $"../LevelGeometry/ShadeBox"
@onready var vis_label = $"../UI/VisibilityTesting"

# Level
#@onready var glow_box = $"../LevelGeometry/GlowBox"

# endregion

# region Ready

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	_initial_head_local_origin = head.transform.origin

	knife_base_pos = knife.position

	player_collision.shape.height = STANDING_HEIGHT

	vignette.modulate.a = 0

	seen_timer.timeout.connect(_seen_timer_tick)

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
			Esc to exit
			N to stop noclipping"
		else:
			play_guide.text = DEFAULT_PLAY_GUIDE_TEXT

	if is_noclipping:
		# Noclip movement
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var base_noclip_speed = WALK_SPEED * 4
		var noclip_speed = base_noclip_speed
		if Input.is_action_pressed("sprint"):
			noclip_speed *= 3

		# Handle vertical movement with jump and crouch
		if Input.is_action_pressed("jump"):
			direction.y += 1.0
		if Input.is_action_pressed("crouch"):
			direction.y -= 1.0

		# Normalize direction if there's vertical movement to prevent faster diagonal movement
		if direction.length_squared() > 1.0:
			direction = direction.normalized()

		global_transform.origin += direction * noclip_speed * delta # Directly update position

	if Input.is_action_pressed("lean_left"):
		#Vleaning = Leaning.LEFT
		lean = -1
	elif Input.is_action_pressed("lean_right"):
		#leaning = Leaning.RIGHT
		lean = 1
	else:
		#leaning = Leaning.NO
		lean = 0

	if Input.is_action_just_released("lean_left") or Input.is_action_just_released("lean_right"):
		#leaning = Leaning.NO
		lean = 0


	# Handle sprinting.
	# if the player is pressing the sprint button and not crouching and moving, set the state to sprinting
	if Input.is_action_pressed("sprint") and player_state != PlayerState.CROUCHING and _moving() and Input.is_action_pressed("move_forward") and is_on_floor():
		player_state = PlayerState.SPRINTING
		pass
	elif Input.is_action_just_released("sprint") and player_state == PlayerState.SPRINTING:
		player_state = PlayerState.STANDING
		pass

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

	# Handle light
	if Input.is_action_just_pressed("light"):
		if glowing:
			$AnimationPlayer.play("light_off")
		else:
			$AnimationPlayer.play("light_on")
		glowing = not glowing

	# Update player properties based on state (visual/audio parameters)
	match player_state:
		PlayerState.STANDING:
			# bob_frequency = BASE_BOB_FREQUENCY
			bob_amplitude = BASE_BOB_AMPLITUDE
			head.transform.origin.y = lerpf(head.transform.origin.y, STANDING_EYE_HEIGHT, delta * 10)
			player_state_mult = 1.0
		PlayerState.CROUCHING:
			# bob_frequency = BASE_BOB_FREQUENCY * 0.7 # Adjust bobbing for crouch
			bob_amplitude = CROUCH_BOB_AMPLITUDE # Adjust bobbing for crouch
			head.transform.origin.y = lerpf(head.transform.origin.y, CROUCH_EYE_HEIGHT, delta * 10)
			if not _can_stand_up():
				_show_permanent_stand_error_message("No space above to stand up")
			else:
				standing_message_label.hide()
			player_state_mult = 0.5
		PlayerState.SPRINTING:
			# bob_frequency = BASE_BOB_FREQUENCY * 1.2 # Adjust bobbing for sprint
			bob_amplitude = SPRINT_BOB_APLITUDE
			head.transform.origin.y = lerpf(head.transform.origin.y, STANDING_EYE_HEIGHT, delta * 10)
			player_state_mult = 1.2

	# Apply head bobbing effect (visual)
	camera.transform.origin = _headbob(time_walked)

	if enemy_node.player_in_earshot_close:
		hearing_distance_mult = 2.0
	elif enemy_node.player_in_earshot_mid:
		hearing_distance_mult = 1.0
	elif enemy_node.player_in_earshot_far:
		hearing_distance_mult = 0.5
	
	# Footstep sound triggering (audio)
	var current_footstep_phase = _footstep(time_walked)
	if prev_footstep_phase > 0.025 and current_footstep_phase <= 0.025:
		footstep_sound.play()
		if enemy_node.player_in_earshot_far:
			if player_state == PlayerState.CROUCHING:
				enemy_node.awareness += 2.0 * hearing_distance_mult
			elif player_state == PlayerState.STANDING:
				enemy_node.awareness += 10.0 * hearing_distance_mult
			elif player_state == PlayerState.SPRINTING:
				enemy_node.awareness += 20.0 * hearing_distance_mult
	prev_footstep_phase = current_footstep_phase

	light_value = snapped(light_detector.detector_light_value * 100, 1)

	# when in sight, awareness raises every X time by a value based on visibility and crouching state

	var player_visible = enemy_node.player_in_sight_far or enemy_node.player_in_sight_mid or enemy_node.player_in_sight_close
	if player_visible and not _seen_timer_started:
		seen_timer.start()
		_seen_timer_started = true
	elif not player_visible and _seen_timer_started:
		seen_timer.stop()
		_seen_timer_started = false
	# else:
	# 	print("player cant be seen")

	if light_value <= 12:
		visibility = "0/3" # 0
		light_level = 0
	elif light_value > 16 and light_value <= 20:
		visibility = "1/3" # 3
		light_level = 1
	elif light_value > 20 and light_value <= 24:
		visibility = "2/3" # 6
		light_level = 2
	elif light_value > 24:
		visibility = "3/3" # 10
		light_level = 3

	#vis_label.text = visibility
	vis_label.text = str(light_level)

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
			crouched = true
		PlayerState.SPRINTING:
			movement_status_label.text = "Sprinting"
			crouched = false
		PlayerState.STANDING:
			movement_status_label.text = "Walking"
			crouched = false

	# TODO health - tied to ui, losing health
	# TODO UI - health, vis, space above indicator, taking damage indicator, directional "seen" indicator, basic main manu
	# TODO basic throwing physics, fallen objects make (adjustable) noise

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
			is_jumping_from_floor = true # Set flag when jumping from floor

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
				velocity.x = lerp(velocity.x, direction.x * current_speed, delta * GROUND_DECEL_TIME)
				velocity.z = lerp(velocity.z, direction.z * current_speed, delta * GROUND_DECEL_TIME)
		else:
			# Apply deceleration when not on the floor.
			velocity.x = lerp(velocity.x, direction.x * current_speed, delta * AIR_DECEL_TIME)
			velocity.z = lerp(velocity.z, direction.z * current_speed, delta * AIR_DECEL_TIME)

		# Update time_walked based on velocity (physics-dependent), only if not jumping from floor
		if not is_jumping_from_floor:
			time_walked += velocity.length() * delta * float(is_on_floor())
		# Reset time_walked periodically to avoid float overflow, but keep bobbing/footsteps looping smoothly
		var bob_period = 2 * TAU / bob_frequency # bob_frequency is updated in _process, but used here. This dependency is acceptable.
		if time_walked > 1000.0:
			time_walked = fmod(time_walked, bob_period)

		# match leaning:
		# 	Leaning.LEFT:
		# 		var target_origin_left = _initial_head_local_origin + head.transform.basis.x * -0.5
		# 		head.transform.origin = head.transform.origin.lerp(target_origin_left, delta * 10)
		# 	Leaning.RIGHT:
		# 		var target_origin_right = _initial_head_local_origin + head.transform.basis.x * 0.5
		# 		head.transform.origin = head.transform.origin.lerp(target_origin_right, delta * 10)
		# 	Leaning.NO:
		# 		head.transform.origin = head.transform.origin.lerp(_initial_head_local_origin, delta * 10)

		var lean_offset_amount = 0.5
		var target_head_position = _initial_head_local_origin
		var target_lean_ray_position = Vector3.ZERO

		if lean == -1: # Lean left
			var lean_direction = - head.transform.basis.x # Left relative to head's orientation
			target_lean_ray_position = lean_direction * lean_offset_amount
			$LeanRay.target_position = target_lean_ray_position
			if $LeanRay.is_colliding():
				lean_offset_amount = $LeanRay.global_transform.origin.distance_to($LeanRay.get_collision_point()) - 0.3
				target_lean_ray_position = lean_direction * lean_offset_amount
			target_head_position = _initial_head_local_origin + lean_direction * lean_offset_amount
			camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(5), 5 * delta)
		elif lean == 1: # Lean right
			var lean_direction = head.transform.basis.x # Right relative to head's orientation
			target_lean_ray_position = lean_direction * lean_offset_amount
			$LeanRay.target_position = target_lean_ray_position
			if $LeanRay.is_colliding():
				lean_offset_amount = $LeanRay.global_transform.origin.distance_to($LeanRay.get_collision_point()) - 0.3
				target_lean_ray_position = lean_direction * lean_offset_amount
			target_head_position = _initial_head_local_origin + lean_direction * lean_offset_amount
			camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(-5), 5 * delta)
		else: # No lean
			camera.rotation.z = lerp(camera.rotation.z, deg_to_rad(0), 5 * delta)
			$LeanRay.target_position = Vector3.ZERO # Reset LeanRay position

		if lean != 0:
			current_speed -= 2
		head.position = lerp(head.position, target_head_position, 5 * delta)
		
		move_and_slide()

		# Reset jumping flag and time_walked when landing
		if is_on_floor() and is_jumping_from_floor:
			is_jumping_from_floor = false
			time_walked = BASE_TIME_WALKED

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
	return snapped(100 * step, 0.01)

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

func _seen_timer_tick() -> void:
	if enemy_node.direct_line_to_player:
		if light_level == 0:
			enemy_node.awareness += 10.0 * player_state_mult
		elif light_level == 1:
			enemy_node.awareness += 20.0 * player_state_mult
		elif light_level == 2:
			enemy_node.awareness += 30.0 * player_state_mult
		elif light_level == 3:
			enemy_node.awareness += 50.0 * player_state_mult

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
