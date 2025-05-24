extends CharacterBody3D
enum EnemyStates {
	PATROL,
	IDLE,
	INVESTIGATE,
	FIGHT
}

var current_state: EnemyStates

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_state = EnemyStates.PATROL
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	match current_state:
		EnemyStates.PATROL:
			pass
		EnemyStates.IDLE:
			pass
		EnemyStates.INVESTIGATE:
			pass
		EnemyStates.FIGHT:
			pass
		
	pass
