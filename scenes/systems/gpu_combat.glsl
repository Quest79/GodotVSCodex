#[compute]
#version 450

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

const uint MAX_ENEMIES = 1024u;
const uint MAX_PROJECTILES = 2048u;
const uint GRID_BUCKETS = 4096u;
const uint MAX_ARCS = 256u;
const uint MAX_BURSTS = 512u;
const float BURN_STACK_THRESHOLD = 10.0;
const float SHOCK_MAX_STACKS = 5.0;
const float SHOCK_DAMAGE_PER_STACK = 0.08;
const float FREEZE_DECAY_PER_SECOND = 18.0;
const float CHILL_MAX_EFFECT = 0.30;
const float CROWD_SEPARATION_SPEED = 155.0;
const float CROWD_MAX_SEPARATION_SPEED = 190.0;
const float CROWD_FLOW_SPEED = 42.0;
const float CROWD_BODY_GAP = 5.0;
const float BURN_EXPLOSION_RADIUS = 180.0;

struct EnemyState {
	vec4 pos_vel;
	vec4 health_move;
	vec4 status;
	vec4 timers;
	vec4 impact;
	vec4 misc;
	vec4 extra;
};

struct ProjectileState {
	vec4 pos_dir;
	vec4 motion;
	vec4 flags;
	vec4 skill;
	vec4 status;
	vec4 extra;
};

struct PendingHit {
	ivec4 p0;
	ivec4 p1;
	ivec4 p2;
};

struct ArcState {
	vec4 ends;
	vec4 state;
};

struct BurstState {
	vec4 pos_type;
	vec4 state;
};

layout(set = 0, binding = 0, std430) restrict buffer EnemyBuffer {
	EnemyState items[];
} enemies;

layout(set = 0, binding = 1, std430) restrict buffer ProjectileBuffer {
	ProjectileState items[];
} projectiles;

layout(set = 0, binding = 2, std430) restrict buffer GridHeads {
	int items[];
} grid_heads;

layout(set = 0, binding = 3, std430) restrict buffer GridNext {
	int items[];
} grid_next;

layout(set = 0, binding = 4, std430) restrict buffer PendingHits {
	PendingHit items[];
} pending_hits;

layout(set = 0, binding = 5, std430) restrict buffer BurnExplosions {
	int damage_milli[];
} burn_explosions;

layout(set = 0, binding = 6, std430) restrict buffer ArcBuffer {
	ArcState items[];
} arcs;

layout(set = 0, binding = 7, std430) restrict buffer BurstBuffer {
	BurstState items[];
} bursts;

layout(set = 0, binding = 8, std430) restrict buffer Counters {
	uint arc_write;
	uint burst_write;
	uint pad0;
	uint pad1;
} counters;

layout(rgba32f, set = 0, binding = 9) uniform image2D enemy_render;
layout(rgba32f, set = 0, binding = 10) uniform image2D projectile_render;
layout(rgba32f, set = 0, binding = 11) uniform image2D arc_render;
layout(rgba32f, set = 0, binding = 12) uniform image2D burst_render;

layout(set = 0, binding = 13, std430) restrict buffer EnemyScratchBuffer {
	EnemyState items[];
} enemy_scratch;

layout(push_constant, std430) uniform Params {
	uvec4 control;
	vec4 player;
	vec4 sim;
	vec4 extra;
} pc;

float safe_length(vec2 value) {
	return sqrt(max(dot(value, value), 0.000001));
}

vec2 safe_normalize(vec2 value) {
	float length_value = safe_length(value);
	return value / length_value;
}

ivec2 cell_for_position(vec2 position) {
	return ivec2(floor(position / pc.sim.z));
}

uint hash_cell(ivec2 cell) {
	uint x = uint(cell.x);
	uint y = uint(cell.y);
	return (x * 73856093u ^ y * 19349663u) & (GRID_BUCKETS - 1u);
}

bool enemy_active(uint index) {
	return index < MAX_ENEMIES && enemies.items[index].impact.w > 0.5;
}

void spawn_arc(vec2 start_position, vec2 end_position, float width) {
	uint slot = atomicAdd(counters.arc_write, 1u) % MAX_ARCS;
	arcs.items[slot].ends = vec4(start_position, end_position);
	arcs.items[slot].state = vec4(0.18, 0.18, width, 1.0);
}

void spawn_burst(vec2 position, float type_id, float radius, float direction_angle) {
	uint slot = atomicAdd(counters.burst_write, 1u) % MAX_BURSTS;
	bursts.items[slot].pos_type = vec4(position, type_id, radius);
	bursts.items[slot].state = vec4(0.34, 0.34, direction_angle, 1.0);
}

void queue_hit(uint enemy_index, float damage, uint skill_type, ProjectileState projectile, vec2 hit_direction) {
	if (!enemy_active(enemy_index)) {
		return;
	}
	EnemyState target = enemies.items[enemy_index];
	int damage_milli = max(1, int(round(damage * 1000.0)));
	atomicAdd(pending_hits.items[enemy_index].p0.x, damage_milli);

	if (skill_type == 1u) {
		atomicAdd(pending_hits.items[enemy_index].p0.y, 1);
		atomicMax(pending_hits.items[enemy_index].p0.z, int(round(projectile.status.y * 1000.0)));
		atomicMax(pending_hits.items[enemy_index].p2.x, int(round(projectile.status.x * 1000.0)));
	} else if (skill_type == 2u) {
		float ratio = damage / max(target.health_move.y, 1.0);
		float chill = clamp(0.5 * pow(max(ratio, 0.0001), 0.4), 0.0, CHILL_MAX_EFFECT);
		if (chill >= 0.05) {
			atomicMax(pending_hits.items[enemy_index].p0.w, int(round(chill * 1000.0)));
			atomicMax(pending_hits.items[enemy_index].p2.y, int(round(projectile.status.z * 1000.0)));
		}
		float freeze_add = ratio * 100.0 * projectile.status.w;
		atomicAdd(pending_hits.items[enemy_index].p1.y, int(round(freeze_add * 1000.0)));
	} else if (skill_type == 3u) {
		atomicAdd(pending_hits.items[enemy_index].p1.x, 1);
		atomicMax(pending_hits.items[enemy_index].p2.z, int(round(projectile.status.x * 1000.0)));
	}

	float health_fraction = clamp(damage / max(target.health_move.y, 1.0), 0.0, 1.0);
	float shaped = pow(health_fraction, 0.82);
	float knock_speed = mix(35.0, 640.0, shaped);
	vec2 knock = safe_normalize(hit_direction) * knock_speed;
	atomicAdd(pending_hits.items[enemy_index].p1.z, int(round(knock.x * 1000.0)));
	atomicAdd(pending_hits.items[enemy_index].p1.w, int(round(knock.y * 1000.0)));
}

float segment_parameter(vec2 start_position, vec2 end_position, vec2 point) {
	vec2 segment = end_position - start_position;
	float length_squared = dot(segment, segment);
	if (length_squared <= 0.000001) {
		return 0.0;
	}
	return clamp(dot(point - start_position, segment) / length_squared, 0.0, 1.0);
}

int find_segment_hit(vec2 start_position, vec2 end_position, float projectile_radius, int excluded_slot) {
	vec2 segment = end_position - start_position;
	vec2 midpoint = (start_position + end_position) * 0.5;
	float query_radius = length(segment) * 0.5 + projectile_radius + 48.0;
	ivec2 center = cell_for_position(midpoint);
	int cell_radius = min(2, int(ceil(query_radius / pc.sim.z)));
	float best_t = 2.0;
	int best_slot = -1;

	for (int ox = -2; ox <= 2; ox++) {
		if (abs(ox) > cell_radius) {
			continue;
		}
		for (int oy = -2; oy <= 2; oy++) {
			if (abs(oy) > cell_radius) {
				continue;
			}
			int candidate = grid_heads.items[hash_cell(center + ivec2(ox, oy))];
			int visits = 0;
			while (candidate >= 0 && visits < 40) {
				uint slot = uint(candidate);
				if (slot < MAX_ENEMIES && candidate != excluded_slot && enemy_active(slot)) {
					vec2 target_position = enemies.items[slot].pos_vel.xy;
					float t = segment_parameter(start_position, end_position, target_position);
					vec2 closest = mix(start_position, end_position, t);
					float hit_radius = enemies.items[slot].health_move.w + projectile_radius;
					if (dot(closest - target_position, closest - target_position) <= hit_radius * hit_radius && t < best_t) {
						best_t = t;
						best_slot = candidate;
					}
				}
				candidate = candidate >= 0 && uint(candidate) < MAX_ENEMIES ? grid_next.items[candidate] : -1;
				visits++;
			}
		}
	}
	return best_slot;
}

int find_nearest_enemy(vec2 origin, float maximum_distance, int excluded_slot) {
	float best_distance_squared = maximum_distance * maximum_distance;
	int best_slot = -1;
	for (uint slot = 0u; slot < MAX_ENEMIES; slot++) {
		if (int(slot) == excluded_slot || !enemy_active(slot)) {
			continue;
		}
		vec2 delta = enemies.items[slot].pos_vel.xy - origin;
		float distance_squared = dot(delta, delta);
		if (distance_squared < best_distance_squared) {
			best_distance_squared = distance_squared;
			best_slot = int(slot);
		}
	}
	return best_slot;
}

bool was_visited(int slot, int visited[8], int count) {
	for (int i = 0; i < count; i++) {
		if (visited[i] == slot) {
			return true;
		}
	}
	return false;
}

int find_chain_target(vec2 origin, float radius, int visited[8], int visited_count) {
	ivec2 center = cell_for_position(origin);
	int cell_radius = min(4, int(ceil(radius / pc.sim.z)));
	float best_distance_squared = radius * radius;
	int best_slot = -1;
	for (int ox = -4; ox <= 4; ox++) {
		if (abs(ox) > cell_radius) {
			continue;
		}
		for (int oy = -4; oy <= 4; oy++) {
			if (abs(oy) > cell_radius) {
				continue;
			}
			int candidate = grid_heads.items[hash_cell(center + ivec2(ox, oy))];
			int visits = 0;
			while (candidate >= 0 && visits < 40) {
				uint slot = uint(candidate);
				if (slot < MAX_ENEMIES && enemy_active(slot) && !was_visited(candidate, visited, visited_count)) {
					vec2 delta = enemies.items[slot].pos_vel.xy - origin;
					float distance_squared = dot(delta, delta);
					if (distance_squared < best_distance_squared) {
						best_distance_squared = distance_squared;
						best_slot = candidate;
					}
				}
				candidate = candidate >= 0 && uint(candidate) < MAX_ENEMIES ? grid_next.items[candidate] : -1;
				visits++;
			}
		}
	}
	return best_slot;
}

void queue_explosion(vec2 origin, float radius, float damage, uint skill_type, ProjectileState projectile, int excluded_slot) {
	ivec2 center = cell_for_position(origin);
	int cell_radius = min(4, int(ceil(radius / pc.sim.z)));
	float radius_squared = radius * radius;
	for (int ox = -4; ox <= 4; ox++) {
		if (abs(ox) > cell_radius) {
			continue;
		}
		for (int oy = -4; oy <= 4; oy++) {
			if (abs(oy) > cell_radius) {
				continue;
			}
			int candidate = grid_heads.items[hash_cell(center + ivec2(ox, oy))];
			int visits = 0;
			while (candidate >= 0 && visits < 40) {
				uint slot = uint(candidate);
				if (slot < MAX_ENEMIES && candidate != excluded_slot && enemy_active(slot)) {
					vec2 target_position = enemies.items[slot].pos_vel.xy;
					vec2 delta = target_position - origin;
					if (dot(delta, delta) <= radius_squared) {
						queue_hit(slot, damage, 0u, projectile, delta);
					}
				}
				candidate = candidate >= 0 && uint(candidate) < MAX_ENEMIES ? grid_next.items[candidate] : -1;
				visits++;
			}
		}
	}
	spawn_burst(origin, 20.0 + float(skill_type), radius, 0.0);
}

void chain_lightning(int first_slot, ProjectileState projectile) {
	int chain_count = min(int(projectile.flags.w), 7);
	if (chain_count <= 0 || projectile.skill.z <= 0.0) {
		return;
	}
	int visited[8];
	for (int i = 0; i < 8; i++) {
		visited[i] = -1;
	}
	visited[0] = first_slot;
	int visited_count = 1;
	int current_slot = first_slot;
	float jump_damage = projectile.motion.y * projectile.skill.w;

	for (int jump = 0; jump < 7; jump++) {
		if (jump >= chain_count || current_slot < 0) {
			break;
		}
		vec2 current_position = enemies.items[uint(current_slot)].pos_vel.xy;
		int next_slot = find_chain_target(current_position, projectile.skill.z, visited, visited_count);
		if (next_slot < 0) {
			break;
		}
		vec2 next_position = enemies.items[uint(next_slot)].pos_vel.xy;
		queue_hit(uint(next_slot), jump_damage, 3u, projectile, next_position - current_position);
		spawn_arc(current_position, next_position, 5.0);
		spawn_burst(next_position, 13.0, 28.0, atan((next_position - current_position).y, (next_position - current_position).x));
		if (visited_count < 8) {
			visited[visited_count] = next_slot;
			visited_count++;
		}
		current_slot = next_slot;
		jump_damage *= projectile.skill.w;
	}
}

void simulate_enemy(uint index) {
	if (index >= MAX_ENEMIES) {
		return;
	}
	EnemyState enemy = enemies.items[index];
	if (enemy.impact.w <= 0.5) {
		enemy_scratch.items[index] = enemy;
		return;
	}

	float delta = pc.sim.x;
	enemy.impact.z = max(0.0, enemy.impact.z - delta / 0.12);
	enemy.misc.z = max(0.0, enemy.misc.z - delta);

	if (enemy.timers.x > 0.0 && enemy.status.x > 0.0) {
		enemy.health_move.x -= enemy.timers.y * enemy.status.x * delta;
		enemy.timers.x = max(0.0, enemy.timers.x - delta);
		if (enemy.timers.x <= 0.0) {
			enemy.status.x = 0.0;
			enemy.timers.y = 0.0;
			enemy.extra.x = 0.0;
		}
	}
	if (enemy.timers.z > 0.0) {
		enemy.timers.z = max(0.0, enemy.timers.z - delta);
		if (enemy.timers.z <= 0.0) {
			enemy.status.y = 0.0;
		}
	}
	if (enemy.timers.w > 0.0) {
		enemy.timers.w = max(0.0, enemy.timers.w - delta);
		if (enemy.timers.w <= 0.0) {
			enemy.status.z = 0.0;
		}
	}
	if (enemy.status.w > 0.0) {
		enemy.status.w = max(0.0, enemy.status.w - delta);
	}
	if (enemy.misc.y > 0.0) {
		enemy.misc.y = max(0.0, enemy.misc.y - delta);
	} else if (enemy.misc.x > 0.0 && enemy.status.w <= 0.0) {
		enemy.misc.x = max(0.0, enemy.misc.x - FREEZE_DECAY_PER_SECOND * delta);
	}

	if (enemy.health_move.x <= 0.0) {
		enemy.health_move.x = 0.0;
		enemy.impact.w = 0.0;
		enemy.pos_vel.zw = vec2(0.0);
		spawn_burst(enemy.pos_vel.xy, 30.0, 19.0 * enemy.misc.w, 0.0);
		enemy_scratch.items[index] = enemy;
		return;
	}

	// CPU-controlled special enemies (bosses/orbiters) remain in the GPU
	// collision/status buffer but keep their CPU-authored movement/AI.
	if (enemy.extra.y > 0.5) {
		enemy_scratch.items[index] = enemy;
		return;
	}

	vec2 position = enemy.pos_vel.xy;
	vec2 separation = vec2(0.0);
	int neighbor_count = 0;
	ivec2 center = cell_for_position(position);
	for (int ox = -1; ox <= 1; ox++) {
		for (int oy = -1; oy <= 1; oy++) {
			int candidate = grid_heads.items[hash_cell(center + ivec2(ox, oy))];
			int visits = 0;
			while (candidate >= 0 && visits < 24) {
				uint slot = uint(candidate);
				if (slot < MAX_ENEMIES && slot != index && enemy_active(slot)) {
					EnemyState other = enemies.items[slot];
					vec2 offset = position - other.pos_vel.xy;
					float desired = enemy.health_move.w + other.health_move.w + CROWD_BODY_GAP;
					float distance_squared = dot(offset, offset);
					if (distance_squared < desired * desired) {
						float distance_value = sqrt(max(distance_squared, 0.0001));
						vec2 direction = offset / distance_value;
						float overlap = 1.0 - distance_value / desired;
						separation += direction * overlap * CROWD_SEPARATION_SPEED * 0.5;
						neighbor_count++;
					}
				}
				candidate = candidate >= 0 && uint(candidate) < MAX_ENEMIES ? grid_next.items[candidate] : -1;
				visits++;
			}
		}
	}

	vec2 to_player = pc.player.xy - position;
	vec2 target_direction = safe_normalize(to_player);
	if (neighbor_count > 0) {
		float flow_sign = (index & 1u) == 0u ? -1.0 : 1.0;
		float density = clamp(float(neighbor_count) / 6.0, 0.0, 1.0);
		separation += vec2(-target_direction.y, target_direction.x) * flow_sign * CROWD_FLOW_SPEED * density;
		float separation_length = length(separation);
		if (separation_length > CROWD_MAX_SEPARATION_SPEED) {
			separation *= CROWD_MAX_SEPARATION_SPEED / separation_length;
		}
	}

	vec2 knockback = enemy.impact.xy;
	knockback *= exp(-7.0 * delta);
	if (length(knockback) < 6.0) {
		knockback = vec2(0.0);
	}
	enemy.impact.xy = knockback;

	float chilled_multiplier = 1.0 - clamp(enemy.status.y, 0.0, CHILL_MAX_EFFECT);
	vec2 chase_velocity = target_direction * enemy.health_move.z * chilled_multiplier;
	if (enemy.status.w > 0.0) {
		chase_velocity = vec2(0.0);
		knockback = vec2(0.0);
	}

	float player_distance = length(to_player);
	float contact_distance = enemy.health_move.w + pc.player.z;
	if (player_distance < contact_distance && pc.player.w > 1.0 && enemy.status.w <= 0.0) {
		vec2 push_direction = safe_normalize(position - pc.player.xy);
		knockback += push_direction * pc.player.w * 1.6;
	}

	vec2 velocity = chase_velocity + separation + knockback;
	position += velocity * delta;
	enemy.pos_vel = vec4(position, velocity);
	enemy_scratch.items[index] = enemy;
}

void commit_enemy(uint index) {
	if (index < MAX_ENEMIES) {
		enemies.items[index] = enemy_scratch.items[index];
	}
}

void clear_grid(uint index) {
	if (index < GRID_BUCKETS) {
		grid_heads.items[index] = -1;
	}
}

void build_grid(uint index) {
	if (index >= MAX_ENEMIES) {
		return;
	}
	if (!enemy_active(index)) {
		grid_next.items[index] = -1;
		return;
	}
	uint bucket = hash_cell(cell_for_position(enemies.items[index].pos_vel.xy));
	int previous = atomicExchange(grid_heads.items[bucket], int(index));
	grid_next.items[index] = previous;
}

void simulate_projectile(uint index) {
	if (index >= MAX_PROJECTILES) {
		return;
	}
	ProjectileState projectile = projectiles.items[index];
	if (projectile.flags.x <= 0.5) {
		return;
	}

	float delta = pc.sim.x;
	projectile.extra.w = max(0.0, projectile.extra.w - delta);
	projectile.motion.z -= delta;
	uint skill_type = uint(round(projectile.flags.z));

	if (dot(projectile.pos_dir.zw, projectile.pos_dir.zw) < 0.0001) {
		int initial_target = find_nearest_enemy(projectile.pos_dir.xy, 100000.0, -1);
		if (initial_target < 0) {
			projectiles.items[index] = projectile;
			return;
		}
		vec2 desired = safe_normalize(enemies.items[uint(initial_target)].pos_vel.xy - projectile.pos_dir.xy);
		float spread_angle = projectile.extra.y;
		float spread_cos = cos(spread_angle);
		float spread_sin = sin(spread_angle);
		projectile.pos_dir.zw = vec2(
			desired.x * spread_cos - desired.y * spread_sin,
			desired.x * spread_sin + desired.y * spread_cos
		);
	}

	if (projectile.motion.z <= 0.0) {
		if (projectile.skill.x > 0.0) {
			queue_explosion(projectile.pos_dir.xy, projectile.skill.x, projectile.motion.y, skill_type, projectile, -1);
		}
		projectile.flags.x = 0.0;
		projectiles.items[index] = projectile;
		return;
	}

	if (projectile.skill.y > 0.0) {
		int nearest = find_nearest_enemy(projectile.pos_dir.xy, 100000.0, -1);
		if (nearest >= 0) {
			vec2 desired = safe_normalize(enemies.items[uint(nearest)].pos_vel.xy - projectile.pos_dir.xy);
			float blend = clamp(projectile.skill.y * delta, 0.0, 1.0);
			projectile.pos_dir.zw = safe_normalize(mix(projectile.pos_dir.zw, desired, blend));
		}
	}

	vec2 start_position = projectile.pos_dir.xy;
	vec2 end_position = start_position + projectile.pos_dir.zw * projectile.motion.x * delta;
	int excluded_slot = projectile.extra.w > 0.0 ? int(round(projectile.extra.z)) - 1 : -1;
	int hit_slot = find_segment_hit(start_position, end_position, 7.0 * projectile.motion.w, excluded_slot);

	if (hit_slot >= 0) {
		uint slot = uint(hit_slot);
		vec2 hit_position = enemies.items[slot].pos_vel.xy;
		queue_hit(slot, projectile.motion.y, skill_type, projectile, hit_position - start_position);
		spawn_burst(hit_position, 10.0 + float(skill_type), 24.0 * projectile.motion.w, atan((hit_position - start_position).y, (hit_position - start_position).x));
		projectile.extra.z = float(hit_slot + 1);
		projectile.extra.w = 0.5;

		if (skill_type == 3u && projectile.flags.w > 0.0) {
			chain_lightning(hit_slot, projectile);
		}

		if (projectile.flags.y > 0.0) {
			projectile.flags.y -= 1.0;
			projectile.pos_dir.xy = end_position;
		} else {
			if (projectile.skill.x > 0.0) {
				queue_explosion(hit_position, projectile.skill.x, projectile.motion.y, skill_type, projectile, hit_slot);
			}
			projectile.flags.x = 0.0;
		}
	} else {
		projectile.pos_dir.xy = end_position;
	}

	projectiles.items[index] = projectile;
}

void apply_pending_hit(uint index) {
	if (index >= MAX_ENEMIES) {
		return;
	}
	PendingHit hit = pending_hits.items[index];
	pending_hits.items[index].p0 = ivec4(0);
	pending_hits.items[index].p1 = ivec4(0);
	pending_hits.items[index].p2 = ivec4(0);

	if (!enemy_active(index)) {
		return;
	}

	EnemyState enemy = enemies.items[index];
	float damage = float(hit.p0.x) / 1000.0;
	if (damage > 0.0) {
		float incoming_multiplier = 1.0 + clamp(enemy.status.z, 0.0, SHOCK_MAX_STACKS) * SHOCK_DAMAGE_PER_STACK;
		enemy.health_move.x -= damage * incoming_multiplier;
		enemy.impact.z = 1.0;
	}

	int new_burn_stacks = max(hit.p0.y, 0);
	if (new_burn_stacks > 0) {
		float burn_dps = float(max(hit.p0.z, 0)) / 1000.0;
		float burn_duration = float(max(hit.p2.x, 0)) / 1000.0;
		enemy.status.x += float(new_burn_stacks);
		enemy.timers.x = max(enemy.timers.x, burn_duration);
		enemy.timers.y = max(enemy.timers.y, burn_dps);
		enemy.extra.x += burn_dps * burn_duration * float(new_burn_stacks);
		if (enemy.status.x >= BURN_STACK_THRESHOLD) {
			burn_explosions.damage_milli[index] = int(round(enemy.extra.x * 3.0 * 1000.0));
			enemy.status.x = 0.0;
			enemy.timers.x = 0.0;
			enemy.timers.y = 0.0;
			enemy.extra.x = 0.0;
		}
	}

	float chill = float(max(hit.p0.w, 0)) / 1000.0;
	if (chill > 0.0) {
		enemy.status.y = max(enemy.status.y, chill);
		enemy.timers.z = max(enemy.timers.z, float(max(hit.p2.y, 0)) / 1000.0);
	}

	int shock_add = max(hit.p1.x, 0);
	if (shock_add > 0) {
		enemy.status.z = min(SHOCK_MAX_STACKS, enemy.status.z + float(shock_add));
		enemy.timers.w = max(enemy.timers.w, float(max(hit.p2.z, 0)) / 1000.0);
	}

	float freeze_add = float(max(hit.p1.y, 0)) / 1000.0;
	if (enemy.misc.z > 0.0) {
		freeze_add *= 0.35;
	}
	if (freeze_add > 0.0 && enemy.status.w <= 0.0) {
		enemy.misc.x = min(100.0, enemy.misc.x + freeze_add);
		enemy.misc.y = 1.0;
		if (enemy.misc.x >= 100.0) {
			enemy.misc.x = 0.0;
			enemy.misc.y = 0.0;
			enemy.status.w = 1.15;
			enemy.misc.z = 4.15;
		}
	}

	enemy.impact.x += float(hit.p1.z) / 1000.0;
	enemy.impact.y += float(hit.p1.w) / 1000.0;
	float knock_length = length(enemy.impact.xy);
	if (knock_length > 640.0) {
		enemy.impact.xy *= 640.0 / knock_length;
	}

	if (enemy.health_move.x <= 0.0) {
		enemy.health_move.x = 0.0;
		enemy.impact.w = 0.0;
		enemy.pos_vel.zw = vec2(0.0);
		spawn_burst(enemy.pos_vel.xy, 30.0, 19.0 * enemy.misc.w, 0.0);
	}

	enemies.items[index] = enemy;
}

void process_burn_explosion(uint index) {
	if (index >= MAX_ENEMIES) {
		return;
	}
	int damage_milli = burn_explosions.damage_milli[index];
	if (damage_milli <= 0) {
		return;
	}
	burn_explosions.damage_milli[index] = 0;
	vec2 origin = enemies.items[index].pos_vel.xy;
	float damage = float(damage_milli) / 1000.0;
	float radius_squared = BURN_EXPLOSION_RADIUS * BURN_EXPLOSION_RADIUS;
	ivec2 center = cell_for_position(origin);
	int cell_radius = min(3, int(ceil(BURN_EXPLOSION_RADIUS / pc.sim.z)));

	for (int ox = -3; ox <= 3; ox++) {
		if (abs(ox) > cell_radius) {
			continue;
		}
		for (int oy = -3; oy <= 3; oy++) {
			if (abs(oy) > cell_radius) {
				continue;
			}
			int candidate = grid_heads.items[hash_cell(center + ivec2(ox, oy))];
			int visits = 0;
			while (candidate >= 0 && visits < 40) {
				uint slot = uint(candidate);
				if (slot < MAX_ENEMIES && enemy_active(slot)) {
					vec2 delta = enemies.items[slot].pos_vel.xy - origin;
					if (dot(delta, delta) <= radius_squared) {
						atomicAdd(pending_hits.items[slot].p0.x, damage_milli);
					}
				}
				candidate = candidate >= 0 && uint(candidate) < MAX_ENEMIES ? grid_next.items[candidate] : -1;
				visits++;
			}
		}
	}
	spawn_burst(origin, 20.0, BURN_EXPLOSION_RADIUS, 0.0);
}

void write_enemy_render(uint index) {
	if (index >= MAX_ENEMIES) {
		return;
	}
	EnemyState enemy = enemies.items[index];
	float active_flag = enemy.impact.w > 0.5 ? 1.0 : 0.0;
	float health_fraction = enemy.health_move.y > 0.0 ? clamp(enemy.health_move.x / enemy.health_move.y, 0.0, 1.0) : 0.0;
	float burn = clamp(enemy.status.x / BURN_STACK_THRESHOLD, 0.0, 1.0);
	float chill = clamp(enemy.status.y / CHILL_MAX_EFFECT, 0.0, 1.0);
	float shock = clamp(enemy.status.z / SHOCK_MAX_STACKS, 0.0, 1.0);
	float frozen = enemy.status.w > 0.0 ? 1.0 : 0.0;
	imageStore(enemy_render, ivec2(int(index), 0), vec4(enemy.pos_vel.xy, enemy.pos_vel.zw));
	imageStore(enemy_render, ivec2(int(index), 1), vec4(active_flag, health_fraction, burn, chill));
	imageStore(enemy_render, ivec2(int(index), 2), vec4(shock, frozen, enemy.impact.z, max(enemy.misc.w, 1.0)));
}

void write_projectile_render(uint index) {
	if (index >= MAX_PROJECTILES) {
		return;
	}
	ProjectileState projectile = projectiles.items[index];
	float active_flag = projectile.flags.x > 0.5 ? 1.0 : 0.0;
	float life_fraction = projectile.extra.x > 0.0 ? clamp(projectile.motion.z / projectile.extra.x, 0.0, 1.0) : 0.0;
	imageStore(projectile_render, ivec2(int(index), 0), vec4(projectile.pos_dir.xy, projectile.pos_dir.zw));
	imageStore(projectile_render, ivec2(int(index), 1), vec4(active_flag, projectile.motion.w, projectile.flags.z, life_fraction));
}

void update_fx(uint index) {
	float delta = pc.sim.x;
	if (index < MAX_ARCS) {
		ArcState arc = arcs.items[index];
		if (arc.state.w > 0.5) {
			arc.state.x = max(0.0, arc.state.x - delta);
			if (arc.state.x <= 0.0) {
				arc.state.w = 0.0;
			}
			arcs.items[index] = arc;
		}
		imageStore(arc_render, ivec2(int(index), 0), arc.ends);
		imageStore(arc_render, ivec2(int(index), 1), arc.state);
	}
	if (index < MAX_BURSTS) {
		BurstState burst = bursts.items[index];
		if (burst.state.w > 0.5) {
			burst.state.x = max(0.0, burst.state.x - delta);
			if (burst.state.x <= 0.0) {
				burst.state.w = 0.0;
			}
			bursts.items[index] = burst;
		}
		imageStore(burst_render, ivec2(int(index), 0), burst.pos_type);
		imageStore(burst_render, ivec2(int(index), 1), burst.state);
	}
}

void main() {
	uint index = gl_GlobalInvocationID.x;
	uint mode = pc.control.x;
	if (mode == 0u) {
		simulate_enemy(index);
	} else if (mode == 1u) {
		clear_grid(index);
	} else if (mode == 2u) {
		build_grid(index);
	} else if (mode == 3u) {
		simulate_projectile(index);
	} else if (mode == 4u) {
		apply_pending_hit(index);
	} else if (mode == 5u) {
		process_burn_explosion(index);
	} else if (mode == 6u) {
		write_enemy_render(index);
	} else if (mode == 7u) {
		write_projectile_render(index);
	} else if (mode == 8u) {
		update_fx(index);
	} else if (mode == 9u) {
		commit_enemy(index);
	}
}
