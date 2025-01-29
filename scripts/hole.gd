extends StaticBody2D

@onready var blood_particles: GPUParticles2D = $Blood
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	add_to_group("hole")
	# Ensure particles are not emitting by default
	blood_particles.emitting = false
	animation_player.play("text")
func trigger_fall_effect():
	AudioManager.eating.play()
	AudioManager.pig_die.play()
	blood_particles.restart()
	blood_particles.emitting = true
