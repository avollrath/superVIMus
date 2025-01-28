extends Node

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return grid_pos * Vector2(Constants.GRID_SIZE, Constants.GRID_SIZE)

func world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(floor(world_pos.x / Constants.GRID_SIZE), floor(world_pos.y / Constants.GRID_SIZE))
