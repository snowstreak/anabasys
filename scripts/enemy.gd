extends CharacterBody3D

enum EnemyState {PATROLLING, WAITING, INVESTIGATING, HUNTING}

@export var waypoints: Array[Marker3D]
@export var patrol_speed = 3
@export var hunt_speed = 5

var enemy_state = EnemyState.PATROLLING
var wp_index: int
var player

var player_in_earshot_far: bool

var awareness = 0.0

@onready var navigation_agent = $NavigationAgent3D
@onready var patrol_timer = $PatrolTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	navigation_agent.set_target_position(waypoints[0].global_position)
	player = get_tree().get_nodes_in_group("Player")[0]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if awareness >= 10.0:
		enemy_state = EnemyState.INVESTIGATING
	elif awareness >= 30.0:
		enemy_state = EnemyState.HUNTING

	match enemy_state:
		EnemyState.PATROLLING:
			if navigation_agent.is_navigation_finished():
				enemy_state = EnemyState.WAITING
				patrol_timer.start()
				return
			move_towards_point(delta, patrol_speed)
			pass
		EnemyState.WAITING:
			pass
		EnemyState.INVESTIGATING:
			if navigation_agent.is_navigation_finished():
				patrol_timer.start()
				enemy_state = EnemyState.WAITING
			navigation_agent.set_target_position(player.global_position) # TODO need to change to last seen position later
			move_towards_point(delta, patrol_speed)
		EnemyState.HUNTING:
			if navigation_agent.is_navigation_finished():
				patrol_timer.start()
				enemy_state = EnemyState.WAITING
			navigation_agent.set_target_position(player.global_position)
			move_towards_point(delta, hunt_speed)

func move_towards_point(delta, speed):
	var target_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(target_position)
	face_direction(delta, target_position)
	velocity = direction * speed
	move_and_slide()
	if player_in_earshot_far:
		check_for_player()
		# awareness rises when player makes a step

func check_for_player():
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create($Head.global_position, player.get_node("Head/Camera3D").global_position, 1, [self]))
	if result.size() > 0:
		if result["collider"].is_in_group("Player"):
			if player_in_earshot_far:
				if !result["collider"].crouched:
					enemy_state = EnemyState.HUNTING
					#print("enemy on the prowl")

func face_direction(delta, direction: Vector3):
	look_at(Vector3(direction.x, global_position.y, direction.z), Vector3.UP)
	rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), delta * 10)

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
		#print("Far hearing entered")
	pass # Replace with function body.


func _on_hearing_far_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player_in_earshot_far = false
		#print("Far hearing exited")
	pass # Replace with function body.
