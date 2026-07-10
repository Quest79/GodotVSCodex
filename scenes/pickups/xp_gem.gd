class_name XPGem
extends Area2D

const MAX_XP := 20
const SPATIAL_CELL_SIZE := 160.0
const INTERACTION_CHECK_INTERVAL := 0.2 # Five checks per second maximum.
const COLLECTION_RADIUS := 26.0 # Player body radius plus gem collision radius.

static var spatial_buckets: Dictionary = {}

@export var move_speed := 520.0
@export var crystal_attraction_radius := 135.0
@export var crystal_attraction_speed := 34.0
@export var crystal_merge_distance := 19.0

var xp_value := 1
var merged_xp := 0
var target: Node2D
var collected := false
var merging := false
var crystal_target: XPGem
var crystal_scan_elapsed := 0.0
var pickup_scan_elapsed := 0.0
var being_picked_up := false
var spatial_cell := Vector2i(2147483647, 2147483647)

@onready var value_label: Label = $ValueLabel
@onready var visual: Node2D = $Visual
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibilityNotifier

func _ready() -> void:
	add_to_group("xp_crystals")
	# Collection is handled by the throttled distance check below. Keeping Area2D
	# monitoring enabled would make every ground shard participate in physics scans.
	monitoring = false
	monitorable = false
	visibility_notifier.screen_entered.connect(_on_screen_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)
	visual.set_process(false)
	set_physics_process(false)
	target = get_tree().get_first_node_in_group("player") as Node2D
	_update_spatial_bucket()
	_update_appearance()

func _exit_tree() -> void:
	_remove_from_spatial_bucket()

func _on_screen_entered() -> void:
	visual.set_process(true)
	set_physics_process(true)

func _on_screen_exited() -> void:
	visual.set_process(false)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if collected or merging:
		return
	if not is_instance_valid(target):
		return

	# Detection and collection are intentionally limited to 5 Hz. Once detected,
	# movement remains per-frame so the pickup still travels smoothly.
	pickup_scan_elapsed += delta
	if pickup_scan_elapsed >= INTERACTION_CHECK_INTERVAL:
		pickup_scan_elapsed = fmod(pickup_scan_elapsed, INTERACTION_CHECK_INTERVAL)
		var pickup_range: float = target.get_pickup_range()
		var distance_squared := global_position.distance_squared_to(target.global_position)
		if distance_squared <= COLLECTION_RADIUS * COLLECTION_RADIUS:
			_collect(target)
			return
		if not being_picked_up:
			being_picked_up = distance_squared <= pickup_range * pickup_range

	if being_picked_up:
		global_position = global_position.move_toward(target.global_position, move_speed * delta)
		_update_spatial_bucket()
		return

	# Max-capacity shards do not participate in neighbor scans or attraction.
	if xp_value < MAX_XP:
		crystal_scan_elapsed += delta
		if crystal_scan_elapsed >= INTERACTION_CHECK_INTERVAL:
			crystal_scan_elapsed = fmod(crystal_scan_elapsed, INTERACTION_CHECK_INTERVAL)
			crystal_target = _find_crystal_target()
		_attract_to_crystal(delta)
	else:
		crystal_target = null
	_update_spatial_bucket()

func set_xp_value(value: int) -> void:
	xp_value = maxi(value, 1)
	if is_node_ready():
		_update_appearance()

func _update_appearance() -> void:
	value_label.text = str(xp_value)
	visual.call("set_crystal_state", merged_xp, xp_value)
	var growth := 1.0 + merged_xp * 0.02
	visual.scale = Vector2.ONE * growth
	value_label.add_theme_color_override("font_color", Color("#a9e8ff") if xp_value >= MAX_XP else Color("#c9a8ef").lerp(Color("#9168c7"), minf(merged_xp / 20.0, 1.0)))

func _find_crystal_target() -> XPGem:
	if xp_value >= MAX_XP:
		return null
	var nearest: XPGem
	var nearest_distance_squared := crystal_attraction_radius * crystal_attraction_radius
	var center_cell := _cell_for_position(global_position)
	for offset_x in range(-1, 2):
		for offset_y in range(-1, 2):
			var bucket_key := center_cell + Vector2i(offset_x, offset_y)
			var bucket: Array = spatial_buckets.get(bucket_key, [])
			for candidate_node in bucket:
				var candidate := candidate_node as XPGem
				if not is_instance_valid(candidate) or candidate == self or candidate.collected or candidate.merging or candidate.xp_value >= MAX_XP:
					continue
				var distance_squared := global_position.distance_squared_to(candidate.global_position)
				if distance_squared < nearest_distance_squared:
					nearest = candidate
					nearest_distance_squared = distance_squared
	return nearest

func _update_spatial_bucket() -> void:
	var new_cell := _cell_for_position(global_position)
	if new_cell == spatial_cell:
		return
	_remove_from_spatial_bucket()
	spatial_cell = new_cell
	if not spatial_buckets.has(spatial_cell):
		spatial_buckets[spatial_cell] = []
	var bucket: Array = spatial_buckets[spatial_cell]
	bucket.append(self)

func _remove_from_spatial_bucket() -> void:
	if not spatial_buckets.has(spatial_cell):
		return
	var bucket: Array = spatial_buckets[spatial_cell]
	bucket.erase(self)
	if bucket.is_empty():
		spatial_buckets.erase(spatial_cell)

func _cell_for_position(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / SPATIAL_CELL_SIZE),
		floori(world_position.y / SPATIAL_CELL_SIZE)
	)

func _attract_to_crystal(delta: float) -> void:
	if not is_instance_valid(crystal_target) or crystal_target.collected or crystal_target.merging or crystal_target.xp_value >= MAX_XP:
		crystal_target = null
		return
	var nearest_distance_squared := global_position.distance_squared_to(crystal_target.global_position)
	if nearest_distance_squared > crystal_attraction_radius * crystal_attraction_radius:
		crystal_target = null
		return
	if nearest_distance_squared <= crystal_merge_distance * crystal_merge_distance:
		# A stable instance-id tie breaker guarantees exactly one survivor.
		if get_instance_id() < crystal_target.get_instance_id():
			_absorb(crystal_target)
		crystal_target = null
		return
	var closeness := 1.0 - sqrt(nearest_distance_squared) / crystal_attraction_radius
	var speed := crystal_attraction_speed * lerpf(0.45, 1.7, closeness)
	global_position = global_position.move_toward(crystal_target.global_position, speed * delta)

func _absorb(other: XPGem) -> void:
	if not is_instance_valid(other) or other.collected or other.merging or xp_value >= MAX_XP:
		return
	other.merging = true
	var amount_added := mini(other.xp_value, MAX_XP - xp_value)
	xp_value += amount_added
	merged_xp += amount_added
	_spawn_merge_effect(other.global_position, amount_added)
	other.xp_value -= amount_added
	if other.xp_value <= 0:
		other.queue_free()
	else:
		other.merging = false
		other._update_appearance()
	_update_appearance()

func _spawn_merge_effect(from_position: Vector2, amount: int) -> void:
	var effect_script := preload("res://scenes/pickups/xp_merge_fx.gd")
	var effect := effect_script.new() as Node2D
	get_tree().current_scene.add_child(effect)
	effect.global_position = (global_position + from_position) * 0.5
	effect.call("configure", xp_value >= MAX_XP, amount)

func _collect(body: Node2D) -> void:
	if collected or not is_instance_valid(body) or not body.has_method("collect_xp"):
		return
	collected = true
	body.collect_xp(xp_value)
	queue_free()
