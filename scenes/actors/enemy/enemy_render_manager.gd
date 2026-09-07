class_name EnemyRenderManager
extends MultiMeshInstance2D

const ENEMY_TEXTURE := preload("res://assets/enemies/enemy_body.svg")
const ENEMY_SHADER := preload("res://scenes/actors/enemy/enemy_multimesh.gdshader")
const SHADOW_SHADER := preload("res://scenes/actors/enemy/enemy_shadow_multimesh.gdshader")
const INITIAL_CAPACITY := 256
const QUAD_SIZE := Vector2(96.0, 96.0)
const SHADOW_SIZE := Vector2(58.0, 16.0)
const SHADOW_OFFSET := Vector2(0.0, 18.0)

var rendered_enemies: Array[Enemy] = []
var enemy_indices: Dictionary[int, int] = {}
var animation_phases: PackedFloat32Array = PackedFloat32Array()
var facing_angles: PackedFloat32Array = PackedFloat32Array()
var shadow_renderer: MultiMeshInstance2D
var gpu_state_bound := false


func _ready() -> void:
	add_to_group("enemy_render_manager")
	z_index = 1
	_create_shadow_renderer()
	texture = ENEMY_TEXTURE
	var quad := QuadMesh.new()
	quad.size = QUAD_SIZE
	var mesh_data := MultiMesh.new()
	mesh_data.transform_format = MultiMesh.TRANSFORM_2D
	mesh_data.use_colors = true
	mesh_data.use_custom_data = true
	mesh_data.mesh = quad
	mesh_data.instance_count = INITIAL_CAPACITY
	mesh_data.visible_instance_count = 0
	multimesh = mesh_data
	var shader_material := ShaderMaterial.new()
	shader_material.shader = ENEMY_SHADER
	material = shader_material


func _create_shadow_renderer() -> void:
	shadow_renderer = MultiMeshInstance2D.new()
	shadow_renderer.name = "EnemyShadows"
	shadow_renderer.z_index = -1
	var shadow_quad := QuadMesh.new()
	shadow_quad.size = SHADOW_SIZE
	var shadow_data := MultiMesh.new()
	shadow_data.transform_format = MultiMesh.TRANSFORM_2D
	shadow_data.use_custom_data = true
	shadow_data.mesh = shadow_quad
	shadow_data.instance_count = INITIAL_CAPACITY
	shadow_data.visible_instance_count = 0
	shadow_renderer.multimesh = shadow_data
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	shadow_renderer.material = shadow_material
	add_child(shadow_renderer)


func bind_gpu_state(state_texture: Texture2D, maximum_instances: int) -> void:
	if not state_texture or maximum_instances <= 0:
		return
	gpu_state_bound = true

	multimesh.instance_count = maximum_instances
	multimesh.visible_instance_count = maximum_instances
	multimesh.custom_aabb = AABB(Vector3(-100000.0, -100000.0, -1.0), Vector3(200000.0, 200000.0, 2.0))
	shadow_renderer.multimesh.instance_count = maximum_instances
	shadow_renderer.multimesh.visible_instance_count = maximum_instances
	shadow_renderer.multimesh.custom_aabb = AABB(Vector3(-100000.0, -100000.0, -1.0), Vector3(200000.0, 200000.0, 2.0))

	for index in range(maximum_instances):
		multimesh.set_instance_transform_2d(index, Transform2D.IDENTITY)
		multimesh.set_instance_custom_data(index, Color(float(index), 0.0, 0.0, 0.0))
		shadow_renderer.multimesh.set_instance_transform_2d(index, Transform2D.IDENTITY)
		shadow_renderer.multimesh.set_instance_custom_data(index, Color(float(index), 0.0, 0.0, 0.0))

	var enemy_material := material as ShaderMaterial
	enemy_material.set_shader_parameter("gpu_state_tex", state_texture)
	enemy_material.set_shader_parameter("gpu_state_enabled", true)
	enemy_material.set_shader_parameter("gpu_state_width", float(maximum_instances))
	enemy_material.set_shader_parameter("gpu_state_rows", 3.0)

	var shadow_material := shadow_renderer.material as ShaderMaterial
	shadow_material.set_shader_parameter("gpu_state_tex", state_texture)
	shadow_material.set_shader_parameter("gpu_state_enabled", true)
	shadow_material.set_shader_parameter("gpu_state_width", float(maximum_instances))
	shadow_material.set_shader_parameter("gpu_state_rows", 3.0)


func unbind_gpu_state() -> void:
	if not gpu_state_bound:
		return
	gpu_state_bound = false
	var enemy_material := material as ShaderMaterial
	if enemy_material:
		enemy_material.set_shader_parameter("gpu_state_enabled", false)
		enemy_material.set_shader_parameter("gpu_state_tex", null)
	var shadow_material := shadow_renderer.material as ShaderMaterial
	if shadow_material:
		shadow_material.set_shader_parameter("gpu_state_enabled", false)
		shadow_material.set_shader_parameter("gpu_state_tex", null)
	if multimesh:
		multimesh.visible_instance_count = rendered_enemies.size()
	if is_instance_valid(shadow_renderer) and shadow_renderer.multimesh:
		shadow_renderer.multimesh.visible_instance_count = rendered_enemies.size()


func register_enemy(enemy: Enemy) -> void:
	if gpu_state_bound:
		return
	if not is_instance_valid(enemy) or enemy_indices.has(enemy.get_instance_id()):
		return
	_ensure_capacity(rendered_enemies.size() + 1)
	var index := rendered_enemies.size()
	rendered_enemies.append(enemy)
	enemy_indices[enemy.get_instance_id()] = index
	animation_phases.append(fmod(float(enemy.get_instance_id()) * 0.000173, 1.0))
	facing_angles.append(0.0)
	multimesh.set_instance_color(index, Color(0.0, 0.0, 0.0, 1.0))
	multimesh.visible_instance_count = rendered_enemies.size()
	shadow_renderer.multimesh.visible_instance_count = rendered_enemies.size()


func unregister_enemy(enemy: Enemy) -> void:
	if gpu_state_bound:
		return
	if not enemy:
		return
	var enemy_id := enemy.get_instance_id()
	if not enemy_indices.has(enemy_id):
		return
	var removed_index: int = enemy_indices[enemy_id]
	var last_index := rendered_enemies.size() - 1
	if removed_index != last_index:
		var moved_enemy := rendered_enemies[last_index]
		rendered_enemies[removed_index] = moved_enemy
		animation_phases[removed_index] = animation_phases[last_index]
		facing_angles[removed_index] = facing_angles[last_index]
		enemy_indices[moved_enemy.get_instance_id()] = removed_index
	rendered_enemies.pop_back()
	animation_phases.resize(last_index)
	facing_angles.resize(last_index)
	enemy_indices.erase(enemy_id)
	if multimesh:
		multimesh.visible_instance_count = rendered_enemies.size()
	if is_instance_valid(shadow_renderer) and shadow_renderer.multimesh:
		shadow_renderer.multimesh.visible_instance_count = rendered_enemies.size()


func _physics_process(delta: float) -> void:
	if gpu_state_bound:
		return
	if not multimesh:
		return
	var index := 0
	while index < rendered_enemies.size():
		var enemy := rendered_enemies[index]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_boss:
			unregister_enemy(enemy)
			continue
		var direction := enemy.velocity.normalized()
		if direction == Vector2.ZERO and is_instance_valid(enemy.target):
			direction = enemy.global_position.direction_to(enemy.target.global_position)
		if direction != Vector2.ZERO:
			facing_angles[index] = lerp_angle(facing_angles[index], direction.angle(), 1.0 - exp(-9.0 * delta))
		var transform := Transform2D(facing_angles[index], enemy.global_position)
		multimesh.set_instance_transform_2d(index, transform)
		var shadow_transform := Transform2D(0.0, enemy.global_position + SHADOW_OFFSET)
		shadow_renderer.multimesh.set_instance_transform_2d(index, shadow_transform)
		var health_fraction := clampf(enemy.health.current / maxf(enemy.health.maximum, 1.0), 0.0, 1.0)
		multimesh.set_instance_custom_data(index, Color(
			animation_phases[index],
			enemy.gpu_burn_intensity,
			enemy.gpu_hit_flash,
			health_fraction
		))
		multimesh.set_instance_color(index, Color(
			enemy.gpu_chill_intensity,
			enemy.gpu_shock_intensity,
			enemy.gpu_frozen_amount,
			1.0
		))
		index += 1


func _ensure_capacity(required_count: int) -> void:
	if multimesh and required_count <= multimesh.instance_count:
		return
	var new_capacity := INITIAL_CAPACITY
	if multimesh:
		new_capacity = multimesh.instance_count
	while new_capacity < required_count:
		new_capacity *= 2
	if multimesh:
		multimesh.instance_count = new_capacity
	if is_instance_valid(shadow_renderer) and shadow_renderer.multimesh:
		shadow_renderer.multimesh.instance_count = new_capacity
