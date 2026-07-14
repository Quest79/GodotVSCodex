extends Node

# Spatial lookup service for combat. Enemies update their bucket after moving,
# avoiding repeated SceneTree group scans for every weapon and projectile.
const CELL_SIZE := 256.0

var enemies: Dictionary[int, Enemy] = {}
var enemy_cells: Dictionary[int, Vector2i] = {}
var spatial_buckets: Dictionary[Vector2i, Dictionary] = {}

func register(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var enemy_id := enemy.get_instance_id()
	enemies[enemy_id] = enemy
	_update_cell(enemy, enemy_id)

func update_enemy(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	var enemy_id := enemy.get_instance_id()
	if not enemies.has(enemy_id):
		register(enemy)
		return
	_update_cell(enemy, enemy_id)

func unregister(enemy: Enemy) -> void:
	if not enemy:
		return
	var enemy_id := enemy.get_instance_id()
	var old_cell: Vector2i = enemy_cells.get(enemy_id, Vector2i(2147483647, 2147483647))
	if spatial_buckets.has(old_cell):
		var bucket: Dictionary = spatial_buckets[old_cell]
		bucket.erase(enemy_id)
		if bucket.is_empty():
			spatial_buckets.erase(old_cell)
	enemy_cells.erase(enemy_id)
	enemies.erase(enemy_id)

func get_enemy_count() -> int:
	return enemies.size()

func get_nearest(origin: Vector2, maximum_distance: float = INF, excluded_enemy_id: int = -1) -> Enemy:
	var nearest: Enemy
	var nearest_distance_squared := maximum_distance * maximum_distance if is_finite(maximum_distance) else INF
	for enemy in _candidates_in_range(origin, maximum_distance):
		if not _is_targetable(enemy) or enemy.get_instance_id() == excluded_enemy_id:
			continue
		var distance_squared := origin.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = enemy
			nearest_distance_squared = distance_squared
	return nearest

func get_nearest_many(origin: Vector2, limit: int, maximum_distance: float) -> Array[Enemy]:
	var candidates: Array[Enemy] = []
	for enemy in _candidates_in_range(origin, maximum_distance):
		if _is_targetable(enemy):
			candidates.append(enemy)
	candidates.sort_custom(func(first: Enemy, second: Enemy) -> bool:
		return origin.distance_squared_to(first.global_position) < origin.distance_squared_to(second.global_position)
	)
	return candidates.slice(0, mini(limit, candidates.size()))

func get_in_radius(origin: Vector2, radius: float, excluded_enemy: Enemy = null) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var radius_squared := radius * radius
	for enemy in _candidates_in_range(origin, radius):
		if _is_targetable(enemy) and enemy != excluded_enemy and origin.distance_squared_to(enemy.global_position) <= radius_squared:
			result.append(enemy)
	return result

func _candidates_in_range(origin: Vector2, maximum_distance: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if is_finite(maximum_distance):
		var center_cell := _cell_for_position(origin)
		var cell_radius := ceili(maximum_distance / CELL_SIZE)
		for x_offset in range(-cell_radius, cell_radius + 1):
			for y_offset in range(-cell_radius, cell_radius + 1):
				_append_bucket(result, center_cell + Vector2i(x_offset, y_offset))
		return result
	for bucket in spatial_buckets.values():
		for enemy in bucket.values():
			result.append(enemy as Enemy)
	return result

func _append_bucket(result: Array[Enemy], cell: Vector2i) -> void:
	var bucket: Dictionary = spatial_buckets.get(cell, {})
	for enemy in bucket.values():
		result.append(enemy as Enemy)

func _update_cell(enemy: Enemy, enemy_id: int) -> void:
	var new_cell := _cell_for_position(enemy.global_position)
	var old_cell: Vector2i = enemy_cells.get(enemy_id, Vector2i(2147483647, 2147483647))
	if new_cell == old_cell:
		return
	if spatial_buckets.has(old_cell):
		var old_bucket: Dictionary = spatial_buckets[old_cell]
		old_bucket.erase(enemy_id)
		if old_bucket.is_empty():
			spatial_buckets.erase(old_cell)
	if not spatial_buckets.has(new_cell):
		spatial_buckets[new_cell] = {}
	spatial_buckets[new_cell][enemy_id] = enemy
	enemy_cells[enemy_id] = new_cell

func _cell_for_position(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / CELL_SIZE), floori(world_position.y / CELL_SIZE))

func _is_targetable(enemy: Enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.dying
