extends CanvasLayer
@onready var animated_h: AnimatedSprite2D = $AnimatedSprite2DH
@onready var animated_j: AnimatedSprite2D = $AnimatedSprite2DJ
@onready var animated_k: AnimatedSprite2D = $AnimatedSprite2DK
@onready var animated_l: AnimatedSprite2D = $AnimatedSprite2DL


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_anything_pressed():
		start_game()
		
	
func start_game() -> void:
	AudioManager.background_music.play()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	
	
	
