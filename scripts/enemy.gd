extends CharacterBody3D

# region Consts and vars

enum EnemyState {PATROLLING, WAITING, INVESTIGATING, HUNTING}

const PATROL_SPEED = 0 # 3
const HUNT_SPEED = 0 # 5

@export var waypoints: Array[Marker3D]

var enemy_state = EnemyState.PATROLLING
var wp_index: int
var player

var player_in_earshot_far: bool
var player_in_earshot_mid: bool
var player_in_earshot_close: bool

var player_in_sight_far: bool
var player_in_sight_mid: bool
var player_in_sight_close: bool

var direct_line_to_player: bool

var awareness = 0.0
var awareness_timer_started: bool

# region Nodes

@onready var navigation_agent = $NavigationAgent3D
@onready var patrol_timer = $PatrolTimer
@onready var awareness_timer: Timer = $AwarenessTimer

# region Ready

func _ready() -> void:
	navigation_agent.set_target_position(waypoints[0].global_position)

	player = get_tree().get_nodes_in_group("Player")[0]

	awareness_timer.timeout.connect(_awareness_timer_tick)

# region Process

func _process(delta: float) -> void:
	if awareness >= 80.0:
		enemy_state = EnemyState.HUNTING
	elif awareness >= 50.0:
		enemy_state = EnemyState.INVESTIGATING
	
	if awareness > 100.0:
		awareness = 100.0
	elif awareness < 0.0:
		awareness = 0.0

	if not awareness_timer_started:
		awareness_timer.start()
		awareness_timer_started = true

	check_for_player()

	match enemy_state:
		EnemyState.PATROLLING:
			if navigation_agent.is_navigation_finished():
				patrol_timer.start()
				enemy_state = EnemyState.WAITING
				return
			move_towards_point(delta, PATROL_SPEED)
			pass
		EnemyState.WAITING:
			pass
		EnemyState.INVESTIGATING:
			if navigation_agent.is_navigation_finished():
				patrol_timer.start()
				enemy_state = EnemyState.WAITING
			navigation_agent.set_target_position(player.global_position) # TODO need to change to last seen position later
			move_towards_point(delta, PATROL_SPEED)
		EnemyState.HUNTING:
			if navigation_agent.is_navigation_finished():
				patrol_timer.start()
				enemy_state = EnemyState.WAITING
			navigation_agent.set_target_position(player.global_position)
			move_towards_point(delta, HUNT_SPEED)

# region Functions

func move_towards_point(delta, speed):
	var target_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(target_position)
	face_direction(delta, target_position)
	velocity = direction * speed
	move_and_slide()
		
func check_for_player():
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create($Head.global_position, player.get_node("Head/Camera3D").global_position, 1, [self]))
	if result.size() > 0:
		if result["collider"].is_in_group("Player"):
			direct_line_to_player = true
		else:
			direct_line_to_player = false
	else:
		direct_line_to_player = false

func face_direction(delta, direction: Vector3):
	look_at(Vector3(direction.x, global_position.y, direction.z), Vector3.UP)
	rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10)

func _on_patrol_timer_timeout() -> void:
	enemy_state = EnemyState.PATROLLING
	wp_index += 1
	if wp_index > waypoints.size() - 1:
		wp_index = 0
	navigation_agent.set_target_position(waypoints[wp_index].global_position)

func _awareness_timer_tick() -> void:
	if awareness >= 0:
		awareness -= 2

# region Hearing fuctions

func _on_hearing_far_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_far = true

func _on_hearing_far_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_far = false

func _on_hearing_mid_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_mid = true

func _on_hearing_mid_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_mid = false

func _on_hearing_close_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_close = true

func _on_hearing_close_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_close = false

# region Sight functions

func _on_sight_far_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_sight_far = true

func _on_sight_far_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_sight_far = false

func _on_sight_mid_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_sight_far = true

func _on_sight_mid_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_sight_far = false

func _on_sight_close_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_sight_far = true

func _on_sight_close_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_sight_far = false
