extends Node2D
@onready var enemies_container: Node2D = $Enemies
@onready var boxes_container = $Boxes
@onready var player = $Player
@onready var hole = $Hole
@onready var tile_map = $TileMapLayer
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var game_over_label = $CanvasLayer/GameOverLabel
@onready var time_progress_bar = $CanvasLayer/TimeProgressBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera: Camera2D = $Camera2D

@onready var animated_h: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2DH
@onready var animated_j: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2DJ
@onready var animated_k: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2DK
@onready var animated_l: AnimatedSprite2D = $CanvasLayer/AnimatedSprite2DL

var level_time = 15.0
var total_level_time: float
var time_remaining: float
var current_level = 1
var boxes_in_holes = 0
var total_boxes = 1 # Starting number of boxes
const MAX_BOXES = 30  # Maximum boxes in any level
const GRID_SIZE = 32  # Match with your Constants.gd
var recent_kills = 0
var kill_timer: float = 0
const KILL_TIMEOUT: float = 2.0
var pending_kill_check: bool = false
var sound_check_timer: float = 0.3
var is_game_over: bool


# Define visible game area bounds (in grid coordinates)
const VISIBLE_BOUNDS = {
	"min_x": 2,  # Leave 1 tile border
	"max_x": 17,  # (1200px / 32px) - 2 for border
	"min_y": 2,  # Leave 1 tile border
	"max_y": 8,  # (800px / 32px) - 2 for border
}

func _ready():
	get_tree().paused = false
	player.shake_requested.connect(shake_camera)
	animation_player.play("show_splash_screen")
	await get_tree().create_timer(2).timeout
	game_over_label.hide()
	setup_level()
	
func _process(delta):
	if time_remaining > 0:
		time_remaining -= delta
		time_progress_bar.value = time_remaining
		if time_remaining <= 0:
			game_over()
			
	if kill_timer > 0:
		kill_timer -= delta
		if kill_timer <= 0:
			recent_kills = 0  
			
	if pending_kill_check:
		sound_check_timer -= delta
		if sound_check_timer <= 0:
			pending_kill_check = false
			play_kill_sound()
			
func play_kill_sound() -> void:
	if recent_kills >= 5:
		AudioManager.monster_kill.play()
		shake_camera(7.0, 1)
	else:
		match recent_kills:
			2:
				AudioManager.double_kill.play()
				shake_camera(2.0, 0.3)
			3:
				AudioManager.multi_kill.play()
				shake_camera(3.0, 0.4)
			4:
				AudioManager.ultra_kill.play()
				shake_camera(5.0, 0.5)
				
func _physics_process(_delta):
	if get_tree().paused:
		return
		
	if Input.is_action_just_pressed("move_left"):
		animated_h.play()
		
	elif Input.is_action_just_pressed("move_down"):
		animated_j.play()
		
	elif Input.is_action_just_pressed("move_up"):
		animated_k.play()
		
	elif Input.is_action_just_pressed("move_right"):
		animated_l.play()

func setup_level():
	game_over_label.text = "Level: %d" % [current_level]
	game_over_label.show()
	total_level_time = level_time + (current_level * 3.0)
	time_remaining = total_level_time
	time_progress_bar.max_value = total_level_time
	time_progress_bar.value = time_remaining
	for box in boxes_container.get_children():
		box.free()
		
	for enemy in enemies_container.get_children():
		enemy.free()
	
	# Reset counters
	boxes_in_holes = 0
	update_score_label()
	
	# Calculate playable area based on TileMap and visible bounds
	var playable_cells = get_playable_cells()
	if playable_cells.is_empty():
		return
	
	# Place hole
	var hole_pos = get_random_empty_position(playable_cells)
	if hole_pos:
		hole.position = Utils.grid_to_world(hole_pos)
		playable_cells.erase(hole_pos)
	
	# Place player
	var player_pos = get_random_empty_position(playable_cells)
	if player_pos:
		player.position = Utils.grid_to_world(player_pos)
		playable_cells.erase(player_pos)
	
	# Calculate number of boxes for this level
	var num_boxes = min(total_boxes + (current_level - 1), MAX_BOXES)
	# Place boxes
	for i in range(num_boxes):
		var box_pos = get_random_empty_position(playable_cells)
		if box_pos:
			create_box(Utils.grid_to_world(box_pos))
			playable_cells.erase(box_pos)
	
	if current_level >= 6:
		var enemy_pos = get_position_away_from_player(playable_cells)
		if enemy_pos:
			var enemy_scene = preload("res://scenes/enemy.tscn")
			var enemy = enemy_scene.instantiate()
			enemy.position = Utils.grid_to_world(enemy_pos)
			enemies_container.add_child(enemy)
			playable_cells.erase(enemy_pos)
			enemy.shake_requested.connect(shake_camera)
		
	update_score_label()
	await get_tree().create_timer(1.0).timeout
	game_over_label.hide()

func get_playable_cells() -> Array:
	var playable_cells = []
	
	# Use visible bounds instead of map limits
	for y in range(VISIBLE_BOUNDS.min_y, VISIBLE_BOUNDS.max_y + 1):
		for x in range(VISIBLE_BOUNDS.min_x, VISIBLE_BOUNDS.max_x + 1):
			var cell_pos = Vector2i(x, y)
			var world_pos = Utils.grid_to_world(Vector2(x, y))
			var tile_data = check_tile_at_position(world_pos)
			
			# Only add cell if it's not water and not a wall
			if not tile_data.is_water and not tile_data.is_wall:
				playable_cells.append(Vector2(x, y))
	
	return playable_cells
	
func get_position_away_from_player(playable_cells: Array, min_distance: int = 5) -> Vector2:
	var valid_positions = []
	var player_grid_pos = Utils.world_to_grid(player.position)
	
	for cell in playable_cells:
		# Calculate grid distance (Manhattan distance)
		var distance = abs(cell.x - player_grid_pos.x) + abs(cell.y - player_grid_pos.y)
		if distance >= min_distance:
			valid_positions.append(cell)
	
	if valid_positions.is_empty():
		# Fallback to any available position if no position meets the minimum distance
		return get_random_empty_position(playable_cells)
	
	return valid_positions[randi() % valid_positions.size()]

func get_random_empty_position(playable_cells: Array) -> Vector2:
	if playable_cells.is_empty():
		# Return a safe default position within visible bounds if no playable cells
		return Vector2(VISIBLE_BOUNDS.min_x, VISIBLE_BOUNDS.min_y)
	
	var index = randi() % playable_cells.size()
	return playable_cells[index]

func create_box(pos: Vector2) -> void:
	var box_scene = preload("res://scenes/Box.tscn")
	var box = box_scene.instantiate()
	box.position = pos
	
	# Connect all signals
	box.entered_hole.connect(_on_box_entered_hole)
	box.exited_hole.connect(_on_box_exited_hole)
	box.box_pushed_into_hole.connect(_on_box_pushed_into_hole)
	
	boxes_container.add_child(box)

func update_score_label() -> void:
	score_label.text = "Level: %d      Pigs: %d/%d" % [
		current_level,
		boxes_in_holes,
		boxes_container.get_child_count()
	]

func shake_camera(intensity: float = 10.0, duration: float = 0.4) -> void:
	var original_position = camera.position
	var tween = create_tween()
	
	for i in range(int(duration / 0.05)):
		# Create random offset
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		
		# Tween to offset
		tween.tween_property(camera, "position", original_position + offset, 0.05)
	
	# Final tween back to original position
	tween.tween_property(camera, "position", original_position, 0.05)

func _on_box_entered_hole() -> void:
	boxes_in_holes += 1
	time_remaining += 3
	update_score_label()
	if kill_timer <= 0:
		# First kill in a new sequence
		recent_kills = 1
		kill_timer = KILL_TIMEOUT
	else:
		# Consecutive kill within time window
		recent_kills += 1
		kill_timer = KILL_TIMEOUT  # Reset timer for next potential kill
		
		# Reset the sound check timer and set pending flag
		if recent_kills >= 2:
			pending_kill_check = true
			sound_check_timer = 0.3 
	
	if boxes_in_holes == boxes_container.get_child_count():
		current_level += 1
		await get_tree().create_timer(1.0).timeout
		if is_game_over: return
		else:
			AudioManager.win.play()
			setup_level()

func _on_box_exited_hole() -> void:
	boxes_in_holes -= 1
	update_score_label()

func _on_box_pushed_into_hole() -> void:
	# Handle game over when player enters hole
	if player.position.distance_to(hole.position) < GRID_SIZE / 2:
		game_over()
		
func check_tile_at_position(pos: Vector2) -> Dictionary:
	var tile_data = tile_map.get_cell_tile_data(tile_map.local_to_map(pos))
	if tile_data:
		return {
			"is_water": tile_data.get_custom_data("is_water"),
			"is_wall": tile_data.get_custom_data("is_wall") 
		}
	return {"is_water": false, "is_wall": false}

func game_over() -> void:
	is_game_over = true
	AudioManager.game_over.play()
	game_over_label.text = "Game Over!"
	game_over_label.show()
	if is_instance_valid(player):
		player.process_mode = PROCESS_MODE_DISABLED
	
	await get_tree().create_timer(1).timeout
	
	# Check again if player is still valid before freeing
	if is_instance_valid(player):
		player.queue_free()
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
