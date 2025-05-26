extends CharacterBody3D

enum States {
	PATROL,
	IDLE,
	INVESTIGATE,
	FIGHT
}

var current_state: States
var waypoint_index: int

@onready var nav_agent := $EnemyNavAgent
@onready var patrol_timer := $PatrolTimer

@export var waypoints: Array[Marker3D]
@export var speed = 2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_state = States.PATROL
	nav_agent.set_target_position(waypoints[0].global_position)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match current_state:
		States.PATROL:
			if nav_agent.is_navigation_finished():
				current_state = States.IDLE
				patrol_timer.start()
				return
			var target_pos = nav_agent.get_next_path_position()
			var direction = global_position.direction_to(target_pos)
			face_direction(delta, direction)
			velocity = direction * speed
			move_and_slide()
			pass
		States.IDLE:
			pass
		States.INVESTIGATE:
			pass
		States.FIGHT:
			pass
	pass

func face_direction(delta, direction: Vector3):
	if direction.length_squared() > 0:
		var targetRotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, targetRotation, delta * 10)

func _on_patrol_timer_timeout() -> void:
	current_state = States.PATROL
	waypoint_index += 1
	if waypoint_index > waypoints.size() - 1:
		waypoint_index = 0
	nav_agent.set_target_position(waypoints[waypoint_index].global_position)
	pass # Replace with function body.
