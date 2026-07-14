class_name ItemTooltip
extends Control

# The reference artwork is 789 px wide. Keeping that design-space width lets us
# reuse its crisp top, side, art-window, and footer sections without distortion.
const DESIGN_WIDTH := 789.0
const DEFAULT_DISPLAY_SCALE := 0.5
const MIN_DISPLAY_SCALE := 0.38
const MOUSE_OFFSET := Vector2(20, 20)

const FRAME_SOURCE_SIZE := Vector2(789, 1420)
const TOP_CAP_HEIGHT := 252.0
const BOTTOM_CAP_HEIGHT := 250.0
const SIDE_RAIL_WIDTH := 82.0
const STATS_Y := 770.0
const ROW_HEIGHT := 52.0
const FOOTER_SPACE := 176.0

const FRAME_MAGENTA := Color(1.0, 0.08, 0.64)
const FRAME_CYAN := Color(0.05, 0.92, 1.0)
const TEXT_PRIMARY := Color(0.84, 0.88, 0.96)
const TEXT_MUTED := Color(0.46, 0.53, 0.64)
const RARITY_DISPLAY_COLORS := [
	Color(0.76, 0.8, 0.84),
	Color(0.28, 1.0, 0.62),
	Color(0.12, 0.9, 1.0),
	Color(0.72, 0.28, 1.0),
	Color(1.0, 0.16, 0.64),
]

const TITLE_GRADIENT_SHADER := preload("res://scenes/ui/inventory/item_tooltip_title_gradient.gdshader")

const FRAME_TEXTURE := preload("res://assets/ui/item_tooltip/tooltip_frame_background.png")
# Keep the title in the same crisp pixel family as the stat rows. Jacquard24
# looked ornate in isolation but became muddy and overly medieval at tooltip scale.
const TITLE_FONT := preload("res://assets/ui/item_tooltip/fonts/Oxanium-VariableFont_wght.ttf")
const BODY_FONT := preload("res://assets/ui/item_tooltip/fonts/PixeloidMono.ttf")
const FLAVOR_FONT := preload("res://assets/ui/item_tooltip/fonts/Oxanium-VariableFont_wght.ttf")

const TYPE_NAMES := ["WEAPON", "ARMOR", "BOOTS", "IMPLANT", "CORE", "GEM", "HELM", "GLOVES", "BELT", "AMULET", "RING"]
const STAT_ICONS := {
	&"damage": preload("res://assets/ui/item_tooltip/icons/stat_physical_damage.png"),
	&"critical_chance": preload("res://assets/ui/item_tooltip/icons/stat_critical_strike_chance.png"),
	&"critical_multiplier": preload("res://assets/ui/item_tooltip/icons/stat_critical_strike_multiplier.png"),
	&"attack_speed": preload("res://assets/ui/item_tooltip/icons/stat_attack_speed.png"),
	&"armor_penetration": preload("res://assets/ui/item_tooltip/icons/stat_armor_penetration.png"),
	&"life_on_kill": preload("res://assets/ui/item_tooltip/icons/stat_life_on_kill.png"),
}
const STAT_ICON_ALIASES := {
	&"damage_min": &"damage",
	&"damage_max": &"damage",
	&"damage_multiplier": &"damage",
	&"burn_damage_per_second": &"damage",
	&"cooldown": &"attack_speed",
	&"move_speed": &"attack_speed",
	&"projectile_speed_multiplier": &"attack_speed",
	&"duration_multiplier": &"critical_multiplier",
	&"affliction_duration": &"critical_multiplier",
	&"max_health": &"armor_penetration",
	&"explosion_radius": &"armor_penetration",
	&"projectile_count": &"armor_penetration",
	&"projectile_scale": &"armor_penetration",
	&"pierce": &"armor_penetration",
	&"spread_degrees": &"critical_chance",
}

var item: Resource
var design_size := Vector2(DESIGN_WIDTH, 970.0)
var card_size := design_size * DEFAULT_DISPLAY_SCALE
var display_scale := DEFAULT_DISPLAY_SCALE
var rows: Array[Dictionary] = []
var flavor_height := 0.0


func setup(source_item: Resource) -> void:
	item = source_item
	_calculate_layout()
	if is_node_ready():
		_rebuild()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calculate_layout()
	_apply_display_size()
	_build()
	pivot_offset = card_size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.97, 0.97)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var desired := get_viewport().get_mouse_position() + MOUSE_OFFSET
	desired.x = clampf(desired.x, 0.0, maxf(0.0, viewport_size.x - card_size.x))
	desired.y = clampf(desired.y, 0.0, maxf(0.0, viewport_size.y - card_size.y))
	global_position = desired


func _rebuild() -> void:
	for child in get_children():
		child.free()
	_apply_display_size()
	_build()
	pivot_offset = card_size * 0.5


func _calculate_layout() -> void:
	rows = _collect_rows()
	var definition: ItemDefinition = item.definition if item and item.definition else null
	flavor_height = _measure_flavor_height(definition.flavor_text) if definition else 0.0
	var socket_height := 38.0 if item and not item.sockets.is_empty() else 0.0
	var content_bottom := STATS_Y + rows.size() * ROW_HEIGHT + socket_height + flavor_height
	design_size = Vector2(DESIGN_WIDTH, maxf(970.0, content_bottom + FOOTER_SPACE))
	card_size = design_size * DEFAULT_DISPLAY_SCALE


func _apply_display_size() -> void:
	display_scale = DEFAULT_DISPLAY_SCALE
	var viewport_height := get_viewport_rect().size.y
	if viewport_height > 0.0 and design_size.y * display_scale > viewport_height - 24.0:
		display_scale = maxf(MIN_DISPLAY_SCALE, (viewport_height - 24.0) / design_size.y)
	card_size = design_size * display_scale
	custom_minimum_size = card_size
	size = card_size


func _build() -> void:
	if not item or not item.definition:
		return
	var definition: ItemDefinition = item.definition
	var rarity_color: Color = item.get_rarity_color()
	_add_modular_frame()
	_add_header(definition, rarity_color)
	_add_item_art(definition)
	_add_ornate_divider(744.0)

	var row_y := STATS_Y
	for row in rows:
		_add_stat_row(row, row_y, rarity_color)
		row_y += ROW_HEIGHT

	if not item.sockets.is_empty():
		_add_socket_summary(row_y + 4.0, rarity_color)
		row_y += 38.0

	if not definition.flavor_text.is_empty():
		_add_ornate_divider(row_y + 7.0)
		var flavor := _add_label(
			definition.flavor_text,
			Rect2(102, row_y + 24.0, DESIGN_WIDTH - 204.0, flavor_height - 30.0),
			FLAVOR_FONT,
			25,
			Color(1.0, 0.22, 0.59)
		)
		flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_footer(definition, rarity_color)


func _add_modular_frame() -> void:
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = card_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.006, 0.013, 0.985)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.1, 0.02, 0.12, 0.94)
	style.shadow_color = Color(0, 0, 0, 0.9)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var middle_height := design_size.y - TOP_CAP_HEIGHT - BOTTOM_CAP_HEIGHT
	_add_atlas_texture(
		Rect2(0, TOP_CAP_HEIGHT, SIDE_RAIL_WIDTH, FRAME_SOURCE_SIZE.y - TOP_CAP_HEIGHT - BOTTOM_CAP_HEIGHT),
		Rect2(0, TOP_CAP_HEIGHT, SIDE_RAIL_WIDTH, middle_height)
	)
	_add_atlas_texture(
		Rect2(FRAME_SOURCE_SIZE.x - SIDE_RAIL_WIDTH, TOP_CAP_HEIGHT, SIDE_RAIL_WIDTH, FRAME_SOURCE_SIZE.y - TOP_CAP_HEIGHT - BOTTOM_CAP_HEIGHT),
		Rect2(DESIGN_WIDTH - SIDE_RAIL_WIDTH, TOP_CAP_HEIGHT, SIDE_RAIL_WIDTH, middle_height)
	)
	_add_atlas_texture(Rect2(0, 0, FRAME_SOURCE_SIZE.x, TOP_CAP_HEIGHT), Rect2(0, 0, DESIGN_WIDTH, TOP_CAP_HEIGHT))
	_add_atlas_texture(
		Rect2(0, FRAME_SOURCE_SIZE.y - BOTTOM_CAP_HEIGHT, FRAME_SOURCE_SIZE.x, BOTTOM_CAP_HEIGHT),
		Rect2(0, design_size.y - BOTTOM_CAP_HEIGHT, DESIGN_WIDTH, BOTTOM_CAP_HEIGHT)
	)


func _add_header(definition: ItemDefinition, _rarity_color: Color) -> void:
	var title_size := _title_font_size(definition.display_name)
	var title_shadow := _add_label(
		definition.display_name.to_upper(),
		Rect2(86, 106, DESIGN_WIDTH - 164.0, 101),
		TITLE_FONT,
		title_size,
		Color(0.10, 0.0, 0.07, 0.82)
	)
	title_shadow.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_shadow.add_theme_color_override("font_outline_color", Color(0.22, 0.0, 0.14, 0.52))
	title_shadow.add_theme_constant_override("outline_size", 3)
	title_shadow.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.68))
	title_shadow.add_theme_constant_override("shadow_outline_size", 3)
	title_shadow.add_theme_constant_override("shadow_offset_x", 1)
	title_shadow.add_theme_constant_override("shadow_offset_y", 1)

	var title := _add_label(
		definition.display_name.to_upper(),
		Rect2(82, 101, DESIGN_WIDTH - 164.0, 101),
		TITLE_FONT,
		title_size,
		Color(1.0, 0.26, 0.74)
	)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A tight magenta outline adds weight to PixeloidMono without the muddy
	# medieval distortion the previous display font produced.
	title.add_theme_color_override("font_outline_color", Color(0.62, 0.015, 0.30, 0.98))
	title.add_theme_constant_override("outline_size", 2)
	var title_material := ShaderMaterial.new()
	title_material.shader = TITLE_GRADIENT_SHADER
	var title_gradient := Gradient.new()
	title_gradient.colors = PackedColorArray([
		Color(1.0, 0.76, 0.93, 1.0),
		Color(1.0, 0.22, 0.68, 1.0),
		Color(0.56, 0.0, 0.28, 1.0),
	])
	var title_gradient_texture := GradientTexture1D.new()
	title_gradient_texture.gradient = title_gradient
	title_gradient_texture.width = 256
	title_material.set_shader_parameter("gradient_texture", title_gradient_texture)
	title_material.set_shader_parameter("label_height", title.size.y)
	title.material = title_material

	var descriptor := _item_descriptor(definition)
	var descriptor_label := _add_label(descriptor, Rect2(90, 234, DESIGN_WIDTH - 180.0, 38), BODY_FONT, 25, FRAME_MAGENTA.lightened(0.16))
	descriptor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	var rarity_index := clampi(item.rarity, 0, item.RARITY_NAMES.size() - 1)
	var rarity_name: String = item.RARITY_NAMES[rarity_index]
	var display_rarity: Color = RARITY_DISPLAY_COLORS[rarity_index]
	_add_label(rarity_name, Rect2(90, 274, DESIGN_WIDTH - 180.0, 34), BODY_FONT, 23, display_rarity)


func _add_item_art(definition: ItemDefinition) -> void:
	# This source region contains the occult circle and its square neon border.
	_add_atlas_texture(Rect2(201, 330, 387, 390), Rect2(201, 329, 387, 390))
	var art_texture: Texture2D = definition.tooltip_art if definition.tooltip_art else definition.inventory_icon
	if art_texture:
		var art := _add_texture(art_texture, Rect2(229, 355, 331, 339))
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		_add_label("NO ITEM ART", Rect2(229, 355, 331, 339), BODY_FONT, 20, TEXT_MUTED)


func _add_stat_row(row: Dictionary, y: float, rarity_color: Color) -> void:
	var stat := StringName(row.get("stat", &"armor_penetration"))
	var icon_key: StringName = STAT_ICON_ALIASES.get(stat, stat)
	var icon_texture: Texture2D = STAT_ICONS.get(icon_key, STAT_ICONS[&"armor_penetration"])
	var icon := _add_texture(icon_texture, Rect2(78, y + 4.0, 38, 38))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var label_text := String(row.get("label", _stat_label(stat)))
	var label := _add_label(label_text, Rect2(132, y, 430, 43), BODY_FONT, _row_font_size(label_text), TEXT_PRIMARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var value := _add_label(String(row.get("value", "--")), Rect2(558, y, 151, 43), BODY_FONT, 27, _stat_value_color(stat, rarity_color))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_divider(78, y + 48.0, DESIGN_WIDTH - 156.0, Color(0.26, 0.32, 0.42, 0.62))


func _add_socket_summary(y: float, _rarity_color: Color) -> void:
	var filled := 0
	for socket in item.sockets:
		if socket:
			filled += 1
	var socket_text := "SOCKETS  %d / %d" % [filled, item.sockets.size()]
	_add_label(socket_text, Rect2(200, y, DESIGN_WIDTH - 400.0, 30), BODY_FONT, 19, FRAME_CYAN)


func _add_footer(definition: ItemDefinition, _rarity_color: Color) -> void:
	var footer_y := design_size.y - 119.0
	var level_text := "REQUIRES LEVEL %d" % definition.required_level if definition.required_level > 0 else "NO LEVEL REQUIREMENT"
	var level := _add_label(level_text, Rect2(72, footer_y, 255, 36), BODY_FONT, 18, FRAME_CYAN)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var bound_text := "ACCOUNT BOUND" if definition.account_bound else "INVENTORY ITEM"
	var bound := _add_label(bound_text, Rect2(DESIGN_WIDTH - 327.0, footer_y, 255, 36), BODY_FONT, 18, FRAME_CYAN)
	bound.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _collect_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not item or not item.definition:
		return result
	if item.definition is GemDefinition:
		var gem := item.definition as GemDefinition
		var effects: Dictionary = gem.effects
		if effects.has(&"damage_min") and effects.has(&"damage_max"):
			result.append({
				"stat": &"damage",
				"label": "DAMAGE",
				"value": "%s-%s" % [_plain_number(float(effects[&"damage_min"])), _plain_number(float(effects[&"damage_max"]))],
			})
		for raw_stat in effects:
			var stat := StringName(raw_stat)
			if stat in [&"damage_min", &"damage_max"]:
				continue
			result.append(_make_row(stat, float(effects[raw_stat])))
	else:
		var modifiers: Dictionary = item.get_modifiers()
		for raw_stat in modifiers:
			var stat := StringName(raw_stat)
			result.append(_make_row(stat, float(modifiers[raw_stat])))
	if result.is_empty():
		result.append({"stat": &"armor_penetration", "label": "NO MODIFIERS", "value": "--"})
	return result


func _make_row(stat: StringName, value: float) -> Dictionary:
	var label_text := _stat_label(stat)
	if stat == &"damage":
		label_text = "PHYSICAL DAMAGE"
	return {"stat": stat, "label": label_text, "value": _format_value(stat, value)}


func _measure_flavor_height(flavor_text: String) -> float:
	if flavor_text.is_empty():
		return 0.0
	var estimated_lines := maxi(2, ceili(float(flavor_text.length()) / 47.0))
	return 48.0 + estimated_lines * 28.0


func _item_descriptor(definition: ItemDefinition) -> String:
	if not definition.tier_label.is_empty():
		return definition.tier_label.to_upper()
	if not definition.allowed_slots.is_empty():
		return String(definition.allowed_slots[0]).replace("_", " ").to_upper()
	var type_index := clampi(int(definition.item_type), 0, TYPE_NAMES.size() - 1)
	return TYPE_NAMES[type_index]


func _stat_label(stat: StringName) -> String:
	var labels := {
		&"burn_damage_per_second": "BURN DAMAGE / SECOND",
		&"critical_chance": "CRITICAL STRIKE CHANCE",
		&"critical_multiplier": "CRITICAL STRIKE MULTIPLIER",
		&"move_speed": "MOVEMENT SPEED",
	}
	return labels.get(stat, String(stat).replace("_", " ").to_upper())


func _format_value(stat: StringName, value: float) -> String:
	if (String(stat).ends_with("_multiplier") and stat != &"critical_multiplier") or stat == &"projectile_scale":
		return "x%.2f" % value
	if String(stat).ends_with("_duration"):
		return "%.1fs" % value
	if String(stat).ends_with("_degrees"):
		return "%.0f DEG" % value
	if stat in [&"projectile_count", &"pierce", &"explosion_radius"]:
		return _plain_number(value)
	if stat in [&"critical_chance", &"critical_multiplier", &"attack_speed", &"armor_penetration", &"cooldown"]:
		return "%+.1f%%" % (value * 100.0)
	if stat == &"move_speed":
		return "%+.1f%%" % value
	if absf(value) < 1.0:
		return "%+.1f%%" % (value * 100.0)
	return "+%s" % _plain_number(value) if value >= 0.0 else _plain_number(value)


func _plain_number(value: float) -> String:
	return "%.0f" % value if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _title_font_size(item_name: String) -> int:
	if item_name.length() >= 23:
		return 42
	if item_name.length() >= 17:
		return 50
	return 58


func _row_font_size(label_text: String) -> int:
	if label_text.length() >= 29:
		return 20
	if label_text.length() >= 23:
		return 22
	return 25


func _stat_value_color(stat: StringName, _rarity_color: Color) -> Color:
	if stat in [&"damage", &"damage_multiplier", &"life_on_kill", &"burn_damage_per_second"]:
		return Color(1.0, 0.22, 0.56)
	if stat in [&"critical_chance", &"critical_multiplier", &"attack_speed", &"move_speed", &"projectile_speed_multiplier"]:
		return FRAME_CYAN
	return FRAME_CYAN


func _add_ornate_divider(y: float) -> void:
	var center := DESIGN_WIDTH * 0.5
	_add_divider(78, y, center - 101.0, Color(0.25, 0.31, 0.42, 0.72))
	_add_divider(center + 23.0, y, center - 101.0, Color(0.25, 0.31, 0.42, 0.72))
	_add_label("*", Rect2(center - 22.0, y - 19.0, 44, 38), BODY_FONT, 27, FRAME_MAGENTA)


func _add_divider(x: float, y: float, width: float, color: Color) -> void:
	var divider := ColorRect.new()
	divider.position = Vector2(x, y) * display_scale
	divider.size = Vector2(width, 1.4) * display_scale
	divider.color = color
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)


func _add_label(label_text: String, rect: Rect2, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position * display_scale
	label.size = rect.size * display_scale
	label.text = label_text
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", maxi(1, roundi(font_size * display_scale)))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.002, 0.004, 0.009, 0.98))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label


func _add_texture(texture: Texture2D, rect: Rect2) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.position = rect.position * display_scale
	texture_rect.size = rect.size * display_scale
	texture_rect.texture = texture
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)
	return texture_rect


func _add_atlas_texture(source_rect: Rect2, destination_rect: Rect2) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = FRAME_TEXTURE
	atlas.region = source_rect
	return _add_texture(atlas, destination_rect)
