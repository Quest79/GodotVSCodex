class_name XPGem
extends Area2D

const MAX_XP := 20

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

@onready var value_label: Label = $ValueLabel
@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("xp_crystals")
	body_entered.connect(_on_body_entered)
	target = get_tree().get_first_node_in_group("player") as Node2D
	_update_appearance()

func _physics_process(delta: float) -> void:
	if collected or merging:
		return
	if not is_instance_valid(target):
		return
	var pickup_range: float = target.get_pickup_range()
	if global_position.distance_squared_to(target.global_position) <= pickup_range * pickup_range:
		global_position = global_position.move_toward(target.global_position, move_speed * delta)
		return
	crystal_scan_elapsed += delta
	if crystal_scan_elapsed >= 0.12 or not is_instance_valid(crystal_target):
		crystal_scan_elapsed = 0.0
		crystal_target = _find_crystal_target()
	_attract_to_crystal(delta)

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
	for candidate_node in get_tree().get_nodes_in_group("xp_crystals"):
		var candidate := candidate_node as XPGem
		if candidate == self or candidate.collected or candidate.merging or candidate.xp_value >= MAX_XP:
			continue
		var distance_squared := global_position.distance_squared_to(candidate.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest

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

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.has_method("collect_xp"):
		return
	collected = true
	body.collect_xp(xp_value)
	queue_free()
