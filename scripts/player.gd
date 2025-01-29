extends CharacterBody2D

@export var move_delay: float = 0.01  # Delay between moves to prevent rapid movement
var can_move: bool = true
var rng = RandomNumberGenerator.new()
var is_animating: bool = false
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
signal shake_requested(intensity: float, duration: float)
func _ready():
	add_to_group("player")
	# Set initial animation and connect signal
	sprite.play("idle_front")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	if get_tree().paused:
		return

	if not can_move:
		return

	var direction = Vector2.ZERO

	if Input.is_action_just_pressed("move_left"):
		direction = Vector2.LEFT
		play_direction_animation("walking_side", true, true)  # Force animation
	elif Input.is_action_just_pressed("move_down"):
		direction = Vector2.DOWN
		play_direction_animation("walking_front", false, true)  # Force animation
		
	elif Input.is_action_just_pressed("move_up"):
		direction = Vector2.UP
		play_direction_animation("walking_back", false, true)  # Force animation
		
	elif Input.is_action_just_pressed("move_right"):
		direction = Vector2.RIGHT
		play_direction_animation("walking_side", false, true)  # Force animation

	if direction != Vector2.ZERO:
		can_move = false
		AudioManager.footstep.pitch_scale = rng.randf_range(0.7, 1.5)
		AudioManager.footstep.play()
		move_character(direction)
		await get_tree().create_timer(move_delay).timeout
		check_for_hole_overlap()
		can_move = true

func play_direction_animation(anim_name: String, flip_horizontal: bool = false, force: bool = false):
	if not is_animating or force:  # Allow animation override if forced
		is_animating = true
		sprite.play(anim_name)
		sprite.flip_h = flip_horizontal

func _on_animation_finished():
	# When any walking animation finishes, return to idle
	if sprite.animation.begins_with("walking_"):
		is_animating = false
		if not Input.is_action_pressed("move_left") and \
		   not Input.is_action_pressed("move_right") and \
		   not Input.is_action_pressed("move_up") and \
		   not Input.is_action_pressed("move_down"):
			sprite.play("idle_front")

func move_character(direction: Vector2):
	var move_velocity = direction * Constants.GRID_SIZE
	var target_position = position + move_velocity
	var tile_data = get_tree().get_root().get_node("Main").check_tile_at_position(target_position)
	
	if tile_data.is_wall:
		return
	
	if tile_data.is_water:
		can_move = false
		AudioManager.water.play()
		sprite.play("drown")
		position += move_velocity
		await get_tree().create_timer(0.4).timeout
		var main_scene = get_tree().get_root().get_node("Main")
		if main_scene.has_method("game_over"):
			main_scene.game_over()
		return
	
	
	var space_state = get_world_2d().direct_space_state
	var push_collision_mask = (1 << 1) | (1 << 2)

	var params = PhysicsPointQueryParameters2D.new()
	params.position = target_position
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = push_collision_mask
	params.exclude = [self]

	var collisions = space_state.intersect_point(params, 32)

	var initial_box = null
	for collision in collisions:
		var collider = collision.collider
		if collider.is_in_group("boxes"):
			initial_box = collider
			break

	if initial_box:
		var connected_boxes = find_pushable_boxes(initial_box, direction)
		if connected_boxes.size() > 0:
			var can_push = check_push_validity(connected_boxes, direction)
			if can_push:
				push_boxes(connected_boxes, direction)
				position += move_velocity
				position = Utils.grid_to_world(Utils.world_to_grid(position))
	else:
		position += move_velocity
		position = Utils.grid_to_world(Utils.world_to_grid(position))

func find_pushable_boxes(initial_box: Node2D, push_direction: Vector2) -> Array:
	var pushable = [initial_box]
	var player_grid_pos = Utils.world_to_grid(position)
	var initial_box_grid_pos = Utils.world_to_grid(initial_box.position)
	
	# For vertical pushes, only consider boxes in the same column
	if push_direction.y != 0:
		if player_grid_pos.x == initial_box_grid_pos.x:
			var connected = get_connected_boxes_in_line(initial_box, push_direction)
			pushable = connected
	# For horizontal pushes, consider boxes in the same row
	else:
		var connected = get_connected_boxes_in_line(initial_box, push_direction)
		pushable = connected

	# Sort boxes based on push direction
	pushable.sort_custom(func(a, b) -> bool:
		if push_direction == Vector2.LEFT:
			return a.position.x < b.position.x
		elif push_direction == Vector2.RIGHT:
			return a.position.x > b.position.x
		elif push_direction == Vector2.UP:
			return a.position.y < b.position.y
		else: # DOWN
			return a.position.y > b.position.y
	)

	return pushable

func get_connected_boxes_in_line(start_box: Node2D, direction: Vector2) -> Array:
	var connected = [start_box]
	var to_check = [start_box]
	var checked = []

	# Determine which coordinate to check based on push direction
	var check_axis = "x" if direction.y != 0 else "y"
	var start_pos = Utils.world_to_grid(start_box.position)

	while to_check.size() > 0:
		var current_box = to_check.pop_front()
		if checked.has(current_box):
			continue

		checked.append(current_box)
		var adjacent_boxes = get_adjacent_boxes(current_box)
		
		for adjacent_box in adjacent_boxes:
			var adjacent_grid_pos = Utils.world_to_grid(adjacent_box.position)
			var current_grid_pos = Utils.world_to_grid(current_box.position)
			
			# For vertical pushes, only connect boxes in the same column
			if direction.y != 0 and adjacent_grid_pos.x != start_pos.x:
				continue
			# For horizontal pushes, only connect boxes in the same row
			if direction.x != 0 and adjacent_grid_pos.y != start_pos.y:
				continue
				
			if not connected.has(adjacent_box):
				connected.append(adjacent_box)
				to_check.append(adjacent_box)

	return connected

func get_adjacent_boxes(box: Node2D) -> Array:
	var adjacent = []
	var space_state = get_world_2d().direct_space_state
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

	for dir in directions:
		var check_pos = box.position + dir * Constants.GRID_SIZE
		var params = PhysicsPointQueryParameters2D.new()
		params.position = check_pos
		params.collide_with_bodies = true
		params.collide_with_areas = false
		params.collision_mask = 1 << 1  # Layer 2 (boxes)
		
		var results = space_state.intersect_point(params, 1)
		if results.size() > 0 and results[0].collider.is_in_group("boxes"):
			adjacent.append(results[0].collider)

	return adjacent

func check_push_validity(boxes: Array, direction: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var occupied_positions = []

	# Get current box positions
	for box in boxes:
		occupied_positions.append(Utils.world_to_grid(box.position))

	# Check target positions
	for box in boxes:
		var target_pos = Utils.world_to_grid(box.position + direction * Constants.GRID_SIZE)
		
		# Skip if target position will be occupied by another moving box
		if occupied_positions.has(target_pos):
			continue

		var world_target = Utils.grid_to_world(target_pos)
		
		var tile_data = get_tree().get_root().get_node("Main").check_tile_at_position(world_target)
		if tile_data.is_wall:
			return false
		
		var params = PhysicsPointQueryParameters2D.new()
		params.position = world_target
		params.collide_with_bodies = true
		params.collide_with_areas = false
		params.collision_mask = (1 << 1) | (1 << 2)  # Layers 2 (boxes) and 3 (holes)
		params.exclude = boxes + [self]

		var results = space_state.intersect_point(params, 1)
		if results.size() > 0:
			var collider = results[0].collider
			if not collider.is_in_group("hole"):
				return false

	return true

func push_boxes(boxes: Array, direction: Vector2):
	[AudioManager.pig_1, AudioManager.pig_2][randi() % 2].play()
	for box in boxes:
		box.position += direction * Constants.GRID_SIZE
		box.position = Utils.grid_to_world(Utils.world_to_grid(box.position))

func check_for_hole_overlap():
	var holes = get_tree().get_nodes_in_group("hole")
	for hole in holes:
		var player_grid_pos = Utils.world_to_grid(position)
		var hole_grid_pos = Utils.world_to_grid(hole.position)

		if player_grid_pos == hole_grid_pos:
			can_move = false
			emit_signal("shake_requested", 20, 0.5)
			AudioManager.player_die.play()
			hole.trigger_fall_effect()
			# Make player invisible
			visible = false
			# Call game over
			var main_scene = get_tree().get_root().get_node("Main")
			if main_scene.has_method("game_over"):
				main_scene.game_over()
			return
