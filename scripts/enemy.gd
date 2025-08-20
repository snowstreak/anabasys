extends CharacterBody3D

enum EnemyState {PATROLLING, WAITING, INVESTIGATING, HUNTING}

@export var waypoints: Array[Marker3D]
@export var speed = 3

var enemy_state = EnemyState.PATROLLING
var wp_index: int

var player_in_earshot_far: bool
var player_in_earshot_close: bool
var player_in_sight_far: bool
var player_in_sight_close: bool

var awareness = 0.0

@onready var navigation_agent = $NavigationAgent3D
@onready var patrol_timer = $PatrolTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	navigation_agent.set_target_position(waypoints[0].global_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match enemy_state:
		EnemyState.PATROLLING:
			if navigation_agent.is_navigation_finished():
				enemy_state = EnemyState.WAITING
				patrol_timer.start()
				return
			var target_position = navigation_agent.get_next_path_position()
			var direction = global_position.direction_to(target_position)
			face_direction(target_position)
			velocity = direction * speed
			move_and_slide()
			pass
		EnemyState.WAITING:
			pass
		EnemyState.INVESTIGATING:
			pass
		EnemyState.HUNTING:
			pass
	if awareness >= 10.0:
		enemy_state = EnemyState.INVESTIGATING

func check_for_player():
	pass

func face_direction(direction: Vector3):
	look_at(Vector3(direction.x, global_position.y, direction.z), Vector3.UP)

func _on_patrol_timer_timeout() -> void:
	enemy_state = EnemyState.PATROLLING
	wp_index += 1
	if wp_index > waypoints.size() - 1:
		wp_index = 0
	navigation_agent.set_target_position(waypoints[wp_index].global_position)
	pass # Replace with function body.


func _on_hearing_far_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_far = true
		print("Far hearing entered")
	pass # Replace with function body.


func _on_hearing_far_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_far = false
		print("Far hearing exited")
	pass # Replace with function body.