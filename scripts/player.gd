extends CharacterBody2D

@export var move_delay: float = 0.1  # Delay between moves to prevent rapid movement
var can_move: bool = true

func _ready():
	add_to_group("player")
	print("Player ready at position:", position)
	log_all_boxes_and_holes()

func _physics_process(_delta):
	if get_tree().paused:
		return

	if not can_move:
		return

	var direction = Vector2.ZERO

	if Input.is_action_just_pressed("move_left"):
		direction = Vector2.LEFT
	elif Input.is_action_just_pressed("move_down"):
		direction = Vector2.DOWN
	elif Input.is_action_just_pressed("move_up"):
		direction = Vector2.UP
	elif Input.is_action_just_pressed("move_right"):
		direction = Vector2.RIGHT

	if direction != Vector2.ZERO:
		can_move = false
		print("\n--- Player Push Initiated ---")
		print("Player pushed: ", direction)
		move_character(direction)
		await get_tree().create_timer(move_delay).timeout
		check_for_hole_overlap()
		can_move = true
		print("--- Player Push Completed ---\n")

func move_character(direction: Vector2):
	var move_velocity = direction * Constants.GRID_SIZE
	var target_position = position + move_velocity
	print("Attempting to move player to: ", target_position)

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
		print("Initial box found: ", initial_box.name)
		var connected_boxes = find_pushable_boxes(initial_box, direction)
		if connected_boxes.size() > 0:
			print("Pushable boxes found: ", connected_boxes.size())
			var can_push = check_push_validity(connected_boxes, direction)
			if can_push:
				print("Push is valid. Moving boxes.")
				push_boxes(connected_boxes, direction)
				position += move_velocity
				position = Utils.grid_to_world(Utils.world_to_grid(position))
			else:
				print("Cannot push boxes due to blockage.")
		log_all_boxes_and_holes()
	else:
		position += move_velocity
		position = Utils.grid_to_world(Utils.world_to_grid(position))
		log_all_boxes_and_holes()

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
				print("Push blocked at position: ", world_target)
				return false

	return true

func push_boxes(boxes: Array, direction: Vector2):
	for box in boxes:
		print("Moving box: ", box.name, " from: ", box.position)
		box.position += direction * Constants.GRID_SIZE
		box.position = Utils.grid_to_world(Utils.world_to_grid(box.position))
		print("Moved box: ", box.name, " to: ", box.position)

func check_for_hole_overlap():
	var holes = get_tree().get_nodes_in_group("hole")
	for hole in holes:
		var player_grid_pos = Utils.world_to_grid(position)
		var hole_grid_pos = Utils.world_to_grid(hole.position)

		if player_grid_pos == hole_grid_pos:
			print("Player fell into hole at position: ", hole.position)
			# Directly call game_over on the main scene
			var main_scene = get_tree().get_root().get_node("Main")  # Adjust path if needed
			if main_scene.has_method("game_over"):
				main_scene.game_over()
			return

func log_all_boxes_and_holes():
	var boxes = get_tree().get_nodes_in_group("boxes")
	var holes = get_tree().get_nodes_in_group("hole")
	
	print("\n--- Current Positions ---")
	print("Player Position: ", position)
	
	for box in boxes:
		print("Box ", box.name, " Position: ", box.position)
	
	for hole in holes:
		print("Hole ", hole.name, " Position: ", hole.position)
	print("-------------------------\n")
