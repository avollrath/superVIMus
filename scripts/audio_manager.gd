extends Node

@onready var footstep: AudioStreamPlayer = $Footstep
@onready var eating: AudioStreamPlayer = $Eating
@onready var pig_1: AudioStreamPlayer = $Pig1
@onready var pig_2: AudioStreamPlayer = $Pig2
@onready var pig_die: AudioStreamPlayer = $PigDie
@onready var water: AudioStreamPlayer = $Water
@onready var game_over: AudioStreamPlayer = $GameOver
@onready var win: AudioStreamPlayer = $Win
@onready var player_die: AudioStreamPlayer = $PlayerDie
@onready var monster_kill: AudioStreamPlayer = $MonsterKill
@onready var first_blood: AudioStreamPlayer = $FirstBlood
@onready var double_kill: AudioStreamPlayer = $DoubleKill
@onready var mega_kill: AudioStreamPlayer = $MegaKill
@onready var multi_kill: AudioStreamPlayer = $MultiKill
@onready var triple_kill: AudioStreamPlayer = $TripleKill
@onready var ultra_kill: AudioStreamPlayer = $UltraKill
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
