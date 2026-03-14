extends CharacterBody3D

enum EnemyState {PATROL, INVESTIGATE, COMBAT, WAIT}

const PATROL_SPEED = 3
const COMBAT_SPEED = 5

@export var waypoints: Array[Marker3D]

var enemy_state = EnemyState.PATROL
var wp_index: int

@onready var nav_agent = $NavigationAgent3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	nav_agent.set_target_position(waypoints[0].global_position)
	pass
 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	match enemy_state:
		EnemyState.PATROL:
			if nav_agent.is_navigation_finished():
				enemy_state = EnemyState.WAIT
				return
			var target_position = nav_agent.get_next_path_position()
			var direction = global_position.direction_to(target_position)
			velocity = direction * PATROL_SPEED
			move_and_slide()
			pass
		EnemyState.INVESTIGATE:
			pass
		EnemyState.COMBAT:
			pass
		EnemyState.WAIT:
			pass
	pass
