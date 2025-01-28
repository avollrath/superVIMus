extends CharacterBody2D

@onready var blood: GPUParticles2D = $Blood
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

signal entered_hole
signal exited_hole
signal box_pushed_into_hole

var is_in_hole = false
var destroy_timer: Timer

func _ready():
    add_to_group("boxes")
    print("Box ", name, " ready at position: ", position)
    
    # Create timer for delayed destruction
    destroy_timer = Timer.new()
    destroy_timer.one_shot = true
    destroy_timer.wait_time = 0.75  # Short delay for visual feedback
    destroy_timer.timeout.connect(_on_destroy_timer_timeout)
    add_child(destroy_timer)

func _physics_process(_delta):
    check_for_hole_overlap()

func check_for_hole_overlap():
    var holes = get_tree().get_nodes_in_group("hole")
    for hole in holes:
        var box_grid_pos = Utils.world_to_grid(position)
        var hole_grid_pos = Utils.world_to_grid(hole.position)
        
        if box_grid_pos == hole_grid_pos:
            if not is_in_hole:
                print("Box ", name, " is exactly over hole: ", hole.name, " at position: ", hole.position)
                is_in_hole = true
                entered_hole.emit()
                print("Emit blood")
                blood.emitting = true
                animated_sprite.visible = false
                destroy_timer.start()
            return
    
    # If we get here, we're not over any hole
    if is_in_hole:
        is_in_hole = false
        exited_hole.emit()
        destroy_timer.stop()  # Stop destruction if box moves away

func _on_destroy_timer_timeout():
    if is_in_hole:  # Double check we're still in hole
        print("Box ", name, " destroyed by hole")
        box_pushed_into_hole.emit()
        queue_free() 
