extends CharacterBody2D

const GRID_SIZE = 32   # Match with your Constants.gd
@export var move_delay: float = 0.5  # Time between moves
@onready var blood: GPUParticles2D = $Blood

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
signal shake_requested(intensity: float, duration: float)
enum Direction { UP, RIGHT, DOWN, LEFT }
var current_direction = Direction.RIGHT
var can_move = true
var target_position: Vector2
var is_moving = false

func _ready():
	add_to_group("enemy")
	position = Utils.grid_to_world(Utils.world_to_grid(position))
	target_position = position
	blood.modulate.a = 0
	blood.emitting = true
	await get_tree().create_timer(0.1).timeout
	blood.emitting = false
	blood.modulate.a = 1
	start_movement_cycle()

func start_movement_cycle():
	while true:
		if can_move and not get_tree().paused:
			move_step()
		await get_tree().create_timer(move_delay).timeout

func move_step():
	choose_new_direction()
	check_player_collision()

func _physics_process(_delta):
	if get_tree().paused:
		return
	
	# Check collision every frame
	check_player_collision()

func choose_new_direction():
	var possible_directions = []
	var current_grid_pos = Utils.world_to_grid(position)
	
	var directions = [
		[Direction.UP, Vector2.UP],
		[Direction.RIGHT, Vector2.RIGHT],
		[Direction.DOWN, Vector2.DOWN],
		[Direction.LEFT, Vector2.LEFT]
	]
	
	for dir in directions:
		var check_pos = Utils.grid_to_world(current_grid_pos + dir[1])
		if is_valid_move(check_pos):
			possible_directions.append(dir[0])
	
	if possible_directions.is_empty():
		return
		
	# Prefer continuing in the same direction if possible
	if possible_directions.has(current_direction):
		if randf() < 0.7:  # 70% chance to continue in same direction
			set_direction(current_direction)
			return
	
	# Otherwise choose random direction
	var new_direction = possible_directions[randi() % possible_directions.size()]
	set_direction(new_direction)

func set_direction(direction: int):
	current_direction = direction
	var dir_vector = Vector2.ZERO
	
	match direction:
		Direction.UP: 
			dir_vector = Vector2.UP
			sprite.play("walking_back")
			sprite.flip_h = false
		Direction.RIGHT: 
			dir_vector = Vector2.RIGHT
			sprite.play("walking_side")
			sprite.flip_h = false
		Direction.DOWN: 
			dir_vector = Vector2.DOWN
			sprite.play("walking_front")
			sprite.flip_h = false
		Direction.LEFT: 
			dir_vector = Vector2.LEFT
			sprite.play("walking_side")
			sprite.flip_h = true
	
	var new_target = position + (dir_vector * GRID_SIZE)
	if is_valid_move(new_target):
		position = new_target  # Immediate movement to new position
		check_player_collision() 

func is_valid_move(check_pos: Vector2) -> bool:
	# Get tile data from main scene
	var main = get_tree().get_root().get_node("Main")
	var tile_data = main.check_tile_at_position(check_pos)
	
	if tile_data.is_wall or tile_data.is_water:
		return false
	
	# Check for boxes
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = check_pos
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = 1 << 1  # Layer 2 (boxes)
	
	var results = space_state.intersect_point(params, 1)
	if results.size() > 0:
		return false
	
	# Check for holes
	var holes = get_tree().get_nodes_in_group("hole")
	for hole in holes:
		if Utils.world_to_grid(hole.position) == Utils.world_to_grid(check_pos):
			return false
	
	return true

func check_player_collision():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var player_grid_pos = Utils.world_to_grid(player.position)
		var enemy_grid_pos = Utils.world_to_grid(position)
		
		if player_grid_pos == enemy_grid_pos:
			if can_move:
				can_move = false
				emit_signal("shake_requested", 25, 0.8)
				player.visible = false
				blood.emitting = true
				AudioManager.player_die.play()
				await get_tree().create_timer(0.4).timeout
				var main = get_tree().get_root().get_node("Main")
				if main.has_method("game_over"):
					main.game_over()
