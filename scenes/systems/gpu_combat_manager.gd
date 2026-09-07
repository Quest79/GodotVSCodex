class_name GPUCombatManager
extends Node

signal backend_ready(enabled: bool)

const GPU_SHADER_PATH := "res://scenes/systems/gpu_combat.glsl"
const PROJECTILE_SHADER: Shader = preload("res://scenes/combat/gpu_projectile.gdshader")
const ARC_SHADER: Shader = preload("res://scenes/combat/gpu_arc.gdshader")
const BURST_SHADER: Shader = preload("res://scenes/combat/gpu_burst.gdshader")

const MAX_ENEMIES := 1024
const MAX_PROJECTILES := 2048
const GRID_BUCKETS := 4096
const MAX_ARCS := 256
const MAX_BURSTS := 512
const WORKGROUP_SIZE := 64
const CELL_SIZE := 128.0

const ENEMY_STRIDE := 112
const PROJECTILE_STRIDE := 96
const PENDING_HIT_STRIDE := 48
const ARC_STRIDE := 32
const BURST_STRIDE := 32
const COUNTER_STRIDE := 16

const SNAPSHOT_INTERVAL_FRAMES := 4
const CONTACT_CHECK_INTERVAL := 0.1
const XP_CLUSTER_SIZE := 160.0

var rd: RenderingDevice
var gpu_shader_file: RDShaderFile
var shader_rid := RID()
var pipeline_rid := RID()
var uniform_set_rid := RID()

var enemy_buffer := RID()
var enemy_scratch_buffer := RID()
var projectile_buffer := RID()
var grid_heads_buffer := RID()
var grid_next_buffer := RID()
var pending_hits_buffer := RID()
var burn_explosion_buffer := RID()
var arc_buffer := RID()
var burst_buffer := RID()
var counters_buffer := RID()

var enemy_texture_rid := RID()
var projectile_texture_rid := RID()
var arc_texture_rid := RID()
var burst_texture_rid := RID()

var enemy_state_texture: Texture2DRD
var projectile_state_texture: Texture2DRD
var arc_state_texture: Texture2DRD
var burst_state_texture: Texture2DRD

var gpu_enabled := false
var backend_announced := false
var render_init_complete := false
var render_init_success := false
var render_init_error := ""

var state_mutex := Mutex.new()
var pending_uploads: Array[Dictionary] = []
var dispatch_queued := false
var snapshot_in_flight := false
var snapshot_available := false
var snapshot_bytes := PackedByteArray()
var requested_delta := 0.0
var requested_time := 0.0
var requested_player_position := Vector2.ZERO
var requested_player_velocity := Vector2.ZERO
var requested_player_radius := 16.0
var render_frame_index := 0

var enemy_free_slots: Array[int] = []
var slot_to_enemy: Array[Enemy] = []
var cpu_positions: Array[Vector2] = []
var cpu_active := PackedByteArray()
var active_enemy_count := 0

var projectile_cursor := 0
var contact_check_elapsed := 0.0
var player: Player

var xp_clusters: Dictionary = {}
var xp_flush_queued := false

var projectile_renderer: MultiMeshInstance2D
var arc_renderer: MultiMeshInstance2D
var burst_renderer: MultiMeshInstance2D


func _ready() -> void:
	add_to_group("gpu_combat")
	slot_to_enemy.resize(MAX_ENEMIES)
	cpu_positions.resize(MAX_ENEMIES)
	cpu_active.resize(MAX_ENEMIES)
	for index in range(MAX_ENEMIES - 1, -1, -1):
		enemy_free_slots.append(index)

	gpu_shader_file = load(GPU_SHADER_PATH) as RDShaderFile
	if gpu_shader_file == null:
		render_init_complete = true
		render_init_success = false
		render_init_error = "Compute shader resource could not be loaded."
		call_deferred("_finish_backend_initialization")
		return

	rd = RenderingServer.get_rendering_device()
	if rd == null:
		render_init_complete = true
		render_init_success = false
		render_init_error = "RenderingDevice unavailable; CPU fallback active."
		call_deferred("_finish_backend_initialization")
		return

	RenderingServer.call_on_render_thread(Callable(self, "_initialize_gpu_on_render_thread"))


func _process(_delta: float) -> void:
	if not backend_announced and render_init_complete:
		_finish_backend_initialization()

	if snapshot_available:
		var local_snapshot := PackedByteArray()
		state_mutex.lock()
		if snapshot_available:
			local_snapshot = snapshot_bytes
			snapshot_available = false
		state_mutex.unlock()
		if not local_snapshot.is_empty():
			_process_enemy_snapshot(local_snapshot)

	if gpu_enabled:
		contact_check_elapsed += _delta
		if contact_check_elapsed >= CONTACT_CHECK_INTERVAL:
			contact_check_elapsed = fmod(contact_check_elapsed, CONTACT_CHECK_INTERVAL)
			_process_contact_damage()


func _physics_process(delta: float) -> void:
	if not gpu_enabled:
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

	var should_queue := false
	state_mutex.lock()
	requested_delta = minf(delta, 1.0 / 20.0)
	requested_time += requested_delta
	if is_instance_valid(player):
		requested_player_position = player.global_position
		requested_player_velocity = player.velocity
		requested_player_radius = player.get_body_radius()
	if not dispatch_queued:
		dispatch_queued = true
		should_queue = true
	state_mutex.unlock()

	if should_queue:
		RenderingServer.call_on_render_thread(Callable(self, "_dispatch_gpu_on_render_thread"))


func is_gpu_enabled() -> bool:
	return gpu_enabled


func get_backend_text() -> String:
	if gpu_enabled:
		return "GPU COMPUTE"
	if render_init_complete:
		return "CPU FALLBACK"
	return "GPU STARTING"


func get_enemy_count() -> int:
	return active_enemy_count


func get_enemy_state_texture() -> Texture2D:
	return enemy_state_texture


func register_enemy(enemy: Enemy) -> int:
	if not gpu_enabled or not is_instance_valid(enemy) or enemy_free_slots.is_empty():
		return -1
	var slot: int = enemy_free_slots.pop_back()
	slot_to_enemy[slot] = enemy
	cpu_positions[slot] = enemy.global_position
	cpu_active[slot] = 1
	active_enemy_count += 1

	var data := PackedByteArray()
	data.resize(ENEMY_STRIDE)
	_encode_vec4(data, 0, Vector4(enemy.global_position.x, enemy.global_position.y, 0.0, 0.0))
	_encode_vec4(data, 16, Vector4(enemy.health.current, enemy.health.maximum, enemy.stats.move_speed, enemy.get_projectile_collision_radius()))
	_encode_vec4(data, 32, Vector4.ZERO)
	_encode_vec4(data, 48, Vector4.ZERO)
	_encode_vec4(data, 64, Vector4(0.0, 0.0, 0.0, 1.0))
	_encode_vec4(data, 80, Vector4(0.0, 0.0, 0.0, maxf(absf(enemy.global_scale.x), 1.0)))
	_encode_vec4(data, 96, Vector4(0.0, 0.0, fmod(float(enemy.get_instance_id()) * 0.000173, 1.0), 0.0))
	_enqueue_upload(&"enemy", slot, data)
	return slot


func unregister_enemy(enemy: Enemy) -> void:
	if not enemy:
		return
	var slot := enemy.gpu_slot
	if slot < 0 or slot >= MAX_ENEMIES:
		return
	if slot_to_enemy[slot] != enemy:
		return

	slot_to_enemy[slot] = null
	cpu_active[slot] = 0
	active_enemy_count = maxi(0, active_enemy_count - 1)
	enemy_free_slots.append(slot)

	var data := PackedByteArray()
	data.resize(ENEMY_STRIDE)
	_enqueue_upload(&"enemy", slot, data)


func fire_skill(
	origin: Vector2,
	skill_config: Dictionary,
	base_damage: float,
	base_projectile_speed: float,
	base_projectile_scale: float,
	attack_range: float
) -> bool:
	if not gpu_enabled or active_enemy_count <= 0:
		return false

	var projectile_count := maxi(1, roundi(float(skill_config.get(&"projectile_count", 1.0))))
	var spread := deg_to_rad(float(skill_config.get(&"spread_degrees", 0.0)))
	var skill_id := StringName(skill_config.get(&"skill_id", &"default_attack"))
	var skill_type := _skill_type_for_id(skill_id)
	var speed := base_projectile_speed * float(skill_config.get(&"projectile_speed_multiplier", 1.0))
	var scale_value := base_projectile_scale * float(skill_config.get(&"projectile_scale", 1.0))
	var lifetime := 2.0 * float(skill_config.get(&"duration_multiplier", 1.0))

	for index in range(projectile_count):
		var projectile_damage := base_damage * float(skill_config.get(&"damage_multiplier", 1.0))
		if skill_config.has(&"damage_min") and skill_config.has(&"damage_max"):
			projectile_damage = randf_range(
				float(skill_config.get(&"damage_min", base_damage)),
				float(skill_config.get(&"damage_max", base_damage))
			) * float(skill_config.get(&"damage_multiplier", 1.0))

		var angle_offset := 0.0
		if projectile_count > 1:
			angle_offset = lerpf(-spread * 0.5, spread * 0.5, float(index) / float(projectile_count - 1))

		var slot := projectile_cursor
		projectile_cursor = (projectile_cursor + 1) % MAX_PROJECTILES
		var data := PackedByteArray()
		data.resize(PROJECTILE_STRIDE)
		# Direction starts at zero. The compute shader acquires the initial target
		# from the GPU enemy buffer and applies this projectile's spread offset.
		_encode_vec4(data, 0, Vector4(origin.x, origin.y, 0.0, 0.0))
		_encode_vec4(data, 16, Vector4(speed, projectile_damage, lifetime, scale_value))
		_encode_vec4(data, 32, Vector4(
			1.0,
			float(roundi(float(skill_config.get(&"pierce", 0.0)))),
			float(skill_type),
			float(roundi(float(skill_config.get(&"chain_count", 0.0))))
		))
		_encode_vec4(data, 48, Vector4(
			float(skill_config.get(&"explosion_radius", 0.0)),
			float(skill_config.get(&"homing_strength", 0.0)),
			float(skill_config.get(&"chain_radius", 0.0)),
			float(skill_config.get(&"chain_damage_multiplier", 1.0))
		))
		var duration_multiplier := float(skill_config.get(&"duration_multiplier", 1.0))
		_encode_vec4(data, 64, Vector4(
			float(skill_config.get(&"affliction_duration", skill_config.get(&"burn_duration", 0.0))) * duration_multiplier,
			float(skill_config.get(&"burn_damage_per_second", 0.0)),
			float(skill_config.get(&"chill_duration", 0.0)) * duration_multiplier,
			float(skill_config.get(&"freeze_buildup_multiplier", 0.0))
		))
		_encode_vec4(data, 80, Vector4(lifetime, angle_offset, 0.0, 0.0))
		_enqueue_upload(&"projectile", slot, data)
	return true


func queue_xp_drop(position: Vector2, amount: int, gem_scene: PackedScene) -> void:
	if amount <= 0 or not gem_scene:
		return
	var cell := Vector2i(floori(position.x / XP_CLUSTER_SIZE), floori(position.y / XP_CLUSTER_SIZE))
	var entry: Dictionary = xp_clusters.get(cell, {
		"value": 0,
		"weighted_position": Vector2.ZERO,
		"scene": gem_scene,
	})
	var old_value := int(entry["value"])
	var new_value := old_value + amount
	entry["weighted_position"] = (Vector2(entry["weighted_position"]) * float(old_value) + position * float(amount)) / float(maxi(new_value, 1))
	entry["value"] = new_value
	entry["scene"] = gem_scene
	xp_clusters[cell] = entry
	if not xp_flush_queued:
		xp_flush_queued = true
		call_deferred("_flush_xp_clusters")


func _flush_xp_clusters() -> void:
	xp_flush_queued = false
	if xp_clusters.is_empty() or not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var clusters := xp_clusters.duplicate(true)
	xp_clusters.clear()
	for entry_value in clusters.values():
		var entry: Dictionary = entry_value
		var gem_scene := entry["scene"] as PackedScene
		if not gem_scene:
			continue
		var gem := gem_scene.instantiate() as XPGem
		var cluster_position: Vector2 = entry["weighted_position"]
		gem.global_position = cluster_position
		gem.set_xp_value(int(entry["value"]))
		scene.add_child(gem)


func _process_contact_damage() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) or not is_instance_valid(player.health):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var player_radius := player.get_body_radius()
	for slot in range(MAX_ENEMIES):
		if cpu_active[slot] == 0:
			continue
		var enemy := slot_to_enemy[slot]
		if is_instance_valid(enemy) and not enemy.dying:
			enemy.try_contact_damage(player.global_position, player_radius, player.health, now)


func _nearest_enemy_slots(origin: Vector2, limit: int, maximum_distance: float) -> Array[int]:
	var candidates: Array[Dictionary] = []
	var maximum_distance_squared := maximum_distance * maximum_distance
	for slot in range(MAX_ENEMIES):
		if cpu_active[slot] == 0:
			continue
		var distance_squared := origin.distance_squared_to(cpu_positions[slot])
		if distance_squared <= maximum_distance_squared:
			candidates.append({"slot": slot, "distance": distance_squared})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	var result: Array[int] = []
	for index in range(mini(limit, candidates.size())):
		result.append(int(candidates[index]["slot"]))
	return result


func _skill_type_for_id(skill_id: StringName) -> int:
	match skill_id:
		&"fireball", &"fire":
			return 1
		&"ice", &"frost", &"blizzard", &"ice_shard":
			return 2
		&"lightning", &"storm", &"shock", &"chain_lightning":
			return 3
	return 0


func _enqueue_upload(kind: StringName, slot: int, data: PackedByteArray) -> void:
	state_mutex.lock()
	pending_uploads.append({"kind": kind, "slot": slot, "data": data})
	state_mutex.unlock()


func _finish_backend_initialization() -> void:
	if backend_announced:
		return
	backend_announced = true
	if not render_init_success:
		gpu_enabled = false
		print("GPU COMBAT: CPU fallback (%s)" % render_init_error)
		backend_ready.emit(false)
		return

	enemy_state_texture = Texture2DRD.new()
	enemy_state_texture.texture_rd_rid = enemy_texture_rid
	projectile_state_texture = Texture2DRD.new()
	projectile_state_texture.texture_rd_rid = projectile_texture_rid
	arc_state_texture = Texture2DRD.new()
	arc_state_texture.texture_rd_rid = arc_texture_rid
	burst_state_texture = Texture2DRD.new()
	burst_state_texture.texture_rd_rid = burst_texture_rid

	gpu_enabled = true
	_create_gpu_renderers()
	var enemy_renderer := get_tree().get_first_node_in_group("enemy_render_manager") as EnemyRenderManager
	if is_instance_valid(enemy_renderer):
		enemy_renderer.bind_gpu_state(enemy_state_texture, MAX_ENEMIES)
	print("GPU COMBAT: ENABLED | enemies=%d projectiles=%d grid=%d" % [MAX_ENEMIES, MAX_PROJECTILES, GRID_BUCKETS])
	backend_ready.emit(true)


func _create_gpu_renderers() -> void:
	projectile_renderer = _make_state_renderer(
		"GPUProjectiles",
		Vector2(64.0, 64.0),
		MAX_PROJECTILES,
		PROJECTILE_SHADER,
		projectile_state_texture,
		MAX_PROJECTILES,
		2
	)
	projectile_renderer.z_index = 3
	add_child(projectile_renderer)

	arc_renderer = _make_state_renderer(
		"GPUArcs",
		Vector2(1.0, 1.0),
		MAX_ARCS,
		ARC_SHADER,
		arc_state_texture,
		MAX_ARCS,
		2
	)
	arc_renderer.z_index = 4
	add_child(arc_renderer)

	burst_renderer = _make_state_renderer(
		"GPUBursts",
		Vector2(96.0, 96.0),
		MAX_BURSTS,
		BURST_SHADER,
		burst_state_texture,
		MAX_BURSTS,
		2
	)
	burst_renderer.z_index = 5
	add_child(burst_renderer)


func _make_state_renderer(
	node_name: String,
	quad_size: Vector2,
	count: int,
	shader: Shader,
	state_texture: Texture2D,
	state_width: int,
	state_rows: int
) -> MultiMeshInstance2D:
	var renderer := MultiMeshInstance2D.new()
	renderer.name = node_name
	var quad := QuadMesh.new()
	quad.size = quad_size
	var mesh_data := MultiMesh.new()
	mesh_data.transform_format = MultiMesh.TRANSFORM_2D
	mesh_data.use_custom_data = true
	mesh_data.mesh = quad
	mesh_data.instance_count = count
	mesh_data.visible_instance_count = count
	for index in range(count):
		mesh_data.set_instance_custom_data(index, Color(float(index), 0.0, 0.0, 0.0))
	mesh_data.custom_aabb = AABB(Vector3(-100000.0, -100000.0, -1.0), Vector3(200000.0, 200000.0, 2.0))
	renderer.multimesh = mesh_data
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("state_tex", state_texture)
	material.set_shader_parameter("state_width", float(state_width))
	material.set_shader_parameter("state_rows", float(state_rows))
	renderer.material = material
	return renderer


func _initialize_gpu_on_render_thread() -> void:
	var local_rd := RenderingServer.get_rendering_device()
	if local_rd == null:
		_set_render_init_result(false, "RenderingDevice vanished during initialization.")
		return
	rd = local_rd

	var spirv: RDShaderSPIRV = gpu_shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(spirv)
	if not shader_rid.is_valid():
		_set_render_init_result(false, "Compute shader could not be created.")
		return
	pipeline_rid = rd.compute_pipeline_create(shader_rid)
	if not pipeline_rid.is_valid():
		_set_render_init_result(false, "Compute pipeline could not be created.")
		return

	enemy_buffer = rd.storage_buffer_create(MAX_ENEMIES * ENEMY_STRIDE, _zero_bytes(MAX_ENEMIES * ENEMY_STRIDE))
	enemy_scratch_buffer = rd.storage_buffer_create(MAX_ENEMIES * ENEMY_STRIDE, _zero_bytes(MAX_ENEMIES * ENEMY_STRIDE))
	projectile_buffer = rd.storage_buffer_create(MAX_PROJECTILES * PROJECTILE_STRIDE, _zero_bytes(MAX_PROJECTILES * PROJECTILE_STRIDE))
	grid_heads_buffer = rd.storage_buffer_create(GRID_BUCKETS * 4, _zero_bytes(GRID_BUCKETS * 4))
	grid_next_buffer = rd.storage_buffer_create(MAX_ENEMIES * 4, _zero_bytes(MAX_ENEMIES * 4))
	pending_hits_buffer = rd.storage_buffer_create(MAX_ENEMIES * PENDING_HIT_STRIDE, _zero_bytes(MAX_ENEMIES * PENDING_HIT_STRIDE))
	burn_explosion_buffer = rd.storage_buffer_create(MAX_ENEMIES * 4, _zero_bytes(MAX_ENEMIES * 4))
	arc_buffer = rd.storage_buffer_create(MAX_ARCS * ARC_STRIDE, _zero_bytes(MAX_ARCS * ARC_STRIDE))
	burst_buffer = rd.storage_buffer_create(MAX_BURSTS * BURST_STRIDE, _zero_bytes(MAX_BURSTS * BURST_STRIDE))
	counters_buffer = rd.storage_buffer_create(COUNTER_STRIDE, _zero_bytes(COUNTER_STRIDE))

	enemy_texture_rid = _create_state_texture(MAX_ENEMIES, 3)
	projectile_texture_rid = _create_state_texture(MAX_PROJECTILES, 2)
	arc_texture_rid = _create_state_texture(MAX_ARCS, 2)
	burst_texture_rid = _create_state_texture(MAX_BURSTS, 2)

	if not enemy_texture_rid.is_valid() or not projectile_texture_rid.is_valid() or not arc_texture_rid.is_valid() or not burst_texture_rid.is_valid():
		_set_render_init_result(false, "GPU state textures could not be created.")
		return

	var uniforms: Array[RDUniform] = []
	uniforms.append(_storage_uniform(0, enemy_buffer))
	uniforms.append(_storage_uniform(1, projectile_buffer))
	uniforms.append(_storage_uniform(2, grid_heads_buffer))
	uniforms.append(_storage_uniform(3, grid_next_buffer))
	uniforms.append(_storage_uniform(4, pending_hits_buffer))
	uniforms.append(_storage_uniform(5, burn_explosion_buffer))
	uniforms.append(_storage_uniform(6, arc_buffer))
	uniforms.append(_storage_uniform(7, burst_buffer))
	uniforms.append(_storage_uniform(8, counters_buffer))
	uniforms.append(_image_uniform(9, enemy_texture_rid))
	uniforms.append(_image_uniform(10, projectile_texture_rid))
	uniforms.append(_image_uniform(11, arc_texture_rid))
	uniforms.append(_image_uniform(12, burst_texture_rid))
	uniforms.append(_storage_uniform(13, enemy_scratch_buffer))

	uniform_set_rid = rd.uniform_set_create(uniforms, shader_rid, 0)
	if not uniform_set_rid.is_valid():
		_set_render_init_result(false, "Compute uniform set could not be created.")
		return

	_set_render_init_result(true, "")


func _dispatch_gpu_on_render_thread() -> void:
	if not render_init_success or rd == null:
		state_mutex.lock()
		dispatch_queued = false
		state_mutex.unlock()
		return

	var uploads: Array[Dictionary] = []
	var delta := 0.0
	var time_value := 0.0
	var player_position := Vector2.ZERO
	var player_velocity := Vector2.ZERO
	var player_radius := 16.0
	state_mutex.lock()
	uploads = pending_uploads.duplicate()
	pending_uploads.clear()
	delta = requested_delta
	time_value = requested_time
	player_position = requested_player_position
	player_velocity = requested_player_velocity
	player_radius = requested_player_radius
	state_mutex.unlock()

	for upload in uploads:
		var kind := StringName(upload["kind"])
		var slot := int(upload["slot"])
		var data: PackedByteArray = upload["data"]
		if kind == &"enemy":
			rd.buffer_update(enemy_buffer, slot * ENEMY_STRIDE, ENEMY_STRIDE, data)
		elif kind == &"projectile":
			rd.buffer_update(projectile_buffer, slot * PROJECTILE_STRIDE, PROJECTILE_STRIDE, data)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)

	# Build a grid from the stable input state, simulate enemies into scratch,
	# commit the result, then rebuild the grid for projectile collision.
	_dispatch_mode(compute_list, 1, GRID_BUCKETS, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 2, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 0, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 9, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)

	_dispatch_mode(compute_list, 1, GRID_BUCKETS, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 2, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)

	_dispatch_mode(compute_list, 3, MAX_PROJECTILES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 4, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 5, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	# Burning-stack explosions queue damage, so apply pending damage once more
	# before rendering to keep explosion damage in the same simulation tick.
	_dispatch_mode(compute_list, 4, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)

	_dispatch_mode(compute_list, 6, MAX_ENEMIES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 7, MAX_PROJECTILES, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_add_barrier(compute_list)
	_dispatch_mode(compute_list, 8, MAX_BURSTS, delta, time_value, player_position, player_velocity, player_radius)
	rd.compute_list_end()

	render_frame_index += 1
	if render_frame_index % SNAPSHOT_INTERVAL_FRAMES == 0 and not snapshot_in_flight:
		snapshot_in_flight = true
		rd.buffer_get_data_async(enemy_buffer, Callable(self, "_on_enemy_snapshot_from_gpu"))

	state_mutex.lock()
	dispatch_queued = false
	state_mutex.unlock()


func _dispatch_mode(
	compute_list: int,
	mode: int,
	item_count: int,
	delta: float,
	time_value: float,
	player_position: Vector2,
	player_velocity: Vector2,
	player_radius: float
) -> void:
	var push := PackedByteArray()
	push.resize(64)
	push.encode_u32(0, mode)
	push.encode_u32(4, render_frame_index)
	push.encode_u32(8, MAX_ENEMIES)
	push.encode_u32(12, MAX_PROJECTILES)
	push.encode_float(16, player_position.x)
	push.encode_float(20, player_position.y)
	push.encode_float(24, player_radius)
	push.encode_float(28, player_velocity.length())
	push.encode_float(32, delta)
	push.encode_float(36, time_value)
	push.encode_float(40, CELL_SIZE)
	push.encode_float(44, 0.0)
	push.encode_float(48, player_velocity.x)
	push.encode_float(52, player_velocity.y)
	push.encode_float(56, 0.0)
	push.encode_float(60, 0.0)
	rd.compute_list_set_push_constant(compute_list, push, push.size())
	var groups := ceili(float(item_count) / float(WORKGROUP_SIZE))
	rd.compute_list_dispatch(compute_list, groups, 1, 1)


func _on_enemy_snapshot_from_gpu(data: PackedByteArray) -> void:
	state_mutex.lock()
	snapshot_bytes = data
	snapshot_available = true
	snapshot_in_flight = false
	state_mutex.unlock()


func _process_enemy_snapshot(data: PackedByteArray) -> void:
	if data.size() < MAX_ENEMIES * ENEMY_STRIDE:
		return
	for slot in range(MAX_ENEMIES):
		var enemy := slot_to_enemy[slot]
		if not is_instance_valid(enemy):
			continue
		var base := slot * ENEMY_STRIDE
		var position := Vector2(data.decode_float(base), data.decode_float(base + 4))
		var velocity := Vector2(data.decode_float(base + 8), data.decode_float(base + 12))
		var health_value := data.decode_float(base + 16)
		var burn := data.decode_float(base + 32)
		var chill := data.decode_float(base + 36)
		var shock := data.decode_float(base + 40)
		var freeze_remaining := data.decode_float(base + 44)
		var hit_flash := data.decode_float(base + 72)
		var active := data.decode_float(base + 76) > 0.5

		cpu_positions[slot] = position
		if active:
			cpu_active[slot] = 1
			enemy.sync_gpu_snapshot(position, velocity, health_value, burn, chill, shock, freeze_remaining, hit_flash)
		else:
			cpu_active[slot] = 0
			enemy.sync_gpu_snapshot(position, Vector2.ZERO, 0.0, burn, chill, shock, freeze_remaining, hit_flash)


func _storage_uniform(binding: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(rid)
	return uniform


func _image_uniform(binding: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(rid)
	return uniform


func _create_state_texture(width: int, height: int) -> RID:
	var format := RDTextureFormat.new()
	format.width = width
	format.height = height
	format.depth = 1
	format.array_layers = 1
	format.mipmaps = 1
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	return rd.texture_create(format, RDTextureView.new(), [])


func _set_render_init_result(success: bool, error_message: String) -> void:
	state_mutex.lock()
	render_init_success = success
	render_init_error = error_message
	render_init_complete = true
	state_mutex.unlock()


func _zero_bytes(size: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(size)
	return bytes


func _encode_vec4(bytes: PackedByteArray, offset: int, value: Vector4) -> void:
	bytes.encode_float(offset, value.x)
	bytes.encode_float(offset + 4, value.y)
	bytes.encode_float(offset + 8, value.z)
	bytes.encode_float(offset + 12, value.w)


func _exit_tree() -> void:
	if rd != null and render_init_success:
		RenderingServer.call_on_render_thread(Callable(self, "_free_gpu_on_render_thread"))


func _free_gpu_on_render_thread() -> void:
	if rd == null:
		return
	for rid in [
		uniform_set_rid,
		pipeline_rid,
		shader_rid,
		enemy_buffer,
		enemy_scratch_buffer,
		projectile_buffer,
		grid_heads_buffer,
		grid_next_buffer,
		pending_hits_buffer,
		burn_explosion_buffer,
		arc_buffer,
		burst_buffer,
		counters_buffer,
		enemy_texture_rid,
		projectile_texture_rid,
		arc_texture_rid,
		burst_texture_rid,
	]:
		if rid.is_valid():
			rd.free_rid(rid)
