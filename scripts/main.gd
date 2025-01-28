extends Node2D

@onready var boxes_container = $Boxes
@onready var player = $Player
@onready var hole = $Hole
@onready var tile_map = $TileMapLayer
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var game_over_label = $CanvasLayer/GameOverLabel

var current_level = 1
var boxes_in_holes = 0
var total_boxes = 3  # Starting number of boxes
const MAX_BOXES = 6  # Maximum boxes in any level
const GRID_SIZE = 32  # Match with your Constants.gd

# Define visible game area bounds (in grid coordinates)
const VISIBLE_BOUNDS = {
	"min_x": 2,  # Leave 1 tile border
	"max_x": 18,  # (1200px / 32px) - 2 for border
	"min_y": 2,  # Leave 1 tile border
	"max_y": 9,  # (800px / 32px) - 2 for border
}

func _ready():
	game_over_label.hide()
	setup_level()

func setup_level():
	# Clear existing boxes
	for box in boxes_container.get_children():
		box.queue_free()
	
	# Reset counters
	boxes_in_holes = 0
	
	# Calculate playable area based on TileMap and visible bounds
	var playable_cells = get_playable_cells()
	if playable_cells.is_empty():
		print("No playable cells found!")
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
	print(num_boxes)
	# Place boxes
	for i in range(num_boxes):
		var box_pos = get_random_empty_position(playable_cells)
		print(box_pos)
		if box_pos:
			create_box(Utils.grid_to_world(box_pos))
			playable_cells.erase(box_pos)
	
	update_score_label()

func get_playable_cells() -> Array:
	var playable_cells = []
	var used_cells = tile_map.get_used_cells()
	
	# Use visible bounds instead of map limits
	for y in range(VISIBLE_BOUNDS.min_y, VISIBLE_BOUNDS.max_y + 1):
		for x in range(VISIBLE_BOUNDS.min_x, VISIBLE_BOUNDS.max_x + 1):
			var cell_pos = Vector2i(x, y)
			# Check if cell is empty (no wall tile) and within bounds
			if used_cells.has(cell_pos):
				playable_cells.append(Vector2(x, y))
	
	return playable_cells

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
	score_label.text = "Level: %d\nBoxes in holes: %d/%d" % [
		current_level,
		boxes_in_holes,
		boxes_container.get_child_count()
	]

func _on_box_entered_hole() -> void:
	boxes_in_holes += 1
	update_score_label()
	
	if boxes_in_holes == boxes_container.get_child_count():
		current_level += 1
		await get_tree().create_timer(1.0).timeout
		setup_level()

func _on_box_exited_hole() -> void:
	boxes_in_holes -= 1
	update_score_label()

func _on_box_pushed_into_hole() -> void:
	# Handle game over when player enters hole
	if player.position.distance_to(hole.position) < GRID_SIZE / 2:
		game_over()

func game_over() -> void:
	game_over_label.show()
	get_tree().paused = true
