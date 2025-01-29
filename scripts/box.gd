extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
signal entered_hole
signal exited_hole
signal box_pushed_into_hole

var is_in_hole = false
var is_in_water = false 
var is_being_destroyed = false
var destroy_timer: Timer

func _ready():
	add_to_group("boxes")
	print("Box ", name, " ready at position: ", position)
	animated_sprite.frame = randi() % 4
	animated_sprite.flip_h = randf() < 0.5
	destroy_timer = Timer.new()
	destroy_timer.one_shot = true
	destroy_timer.wait_time = 0.75
	destroy_timer.timeout.connect(_on_destroy_timer_timeout)
	add_child(destroy_timer)

func _physics_process(_delta):
	check_for_hole_overlap()
	check_for_water_overlap()


func check_for_water_overlap():
	if is_being_destroyed:
		return
	
	var grid_pos = Utils.world_to_grid(position)
	var tile_data = get_tree().get_root().get_node("Main").check_tile_at_position(Utils.grid_to_world(grid_pos))

	
	if tile_data.is_water:
		if not is_in_water:
			is_in_water = true
			print("Box touched water")
			AudioManager.water.play()
			visible = false
			var main_scene = get_tree().get_root().get_node("Main")
			if main_scene.has_method("game_over"):
				main_scene.game_over()
			return
		
	else:
		if is_in_water:
			is_in_water = false
			# Optional: Handle box exiting water if needed


func check_for_hole_overlap():
	if is_being_destroyed:
		return
		
	var holes = get_tree().get_nodes_in_group("hole")
	for hole in holes:
		var box_grid_pos = Utils.world_to_grid(position)
		var hole_grid_pos = Utils.world_to_grid(hole.position)
		
		if box_grid_pos == hole_grid_pos:
			if not is_in_hole:
				print("Box ", name, " is exactly over hole: ", hole.name)
				is_in_hole = true
				is_being_destroyed = true
				entered_hole.emit()
				
				# Trigger hole effect instead of local particles
				hole.trigger_fall_effect()
				
				# Make box non-interactive immediately
				process_mode = Node.PROCESS_MODE_DISABLED
				animated_sprite.visible = false
				destroy_timer.start()
			return
	
	if is_in_hole:
		is_in_hole = false
		exited_hole.emit()
		destroy_timer.stop()

func _on_destroy_timer_timeout():
	if is_in_hole:
		print("Box ", name, " destroyed by hole")
		box_pushed_into_hole.emit()
		queue_free()
