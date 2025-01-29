extends StaticBody2D

@onready var blood: GPUParticles2D = $Blood
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	add_to_group("hole")
	blood.emitting = true
	await get_tree().create_timer(0.1).timeout
	blood.emitting = false
	animation_player.play("text")
	
func trigger_fall_effect():
	AudioManager.eating.play()
	AudioManager.pig_die.play()
	blood.emitting = true
