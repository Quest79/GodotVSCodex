class_name ItemTooltip
extends Control

const DESIGN_WIDTH := 640.0
const DISPLAY_SCALE := 0.5
const MOUSE_OFFSET := Vector2(20, 20)
const TITLE_FONT := preload("res://assets/ui/item_tooltip/fonts/Oxanium-VariableFont_wght.ttf")
const BODY_FONT := preload("res://assets/ui/item_tooltip/fonts/Oxanium-VariableFont_wght.ttf")

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
	&"cooldown": &"attack_speed",
	&"move_speed": &"attack_speed",
	&"max_health": &"armor_penetration",
}

var item: Resource
var design_size := Vector2(DESIGN_WIDTH, 760.0)
var card_size := design_size * DISPLAY_SCALE
var display_font: FontVariation

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_font = FontVariation.new()
	display_font.base_font = TITLE_FONT
	display_font.variation_opentype = {&"wght": 620.0}
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

func setup(source_item: Resource) -> void:
	item = source_item
	if item.definition is GemDefinition:
		design_size.y = 700.0 if item.definition.gem_kind == GemDefinition.GemKind.SUPPORT else 620.0
		card_size = design_size * DISPLAY_SCALE
		custom_minimum_size = card_size
		size = card_size
		return
	var stat_rows := clampi(item.get_modifiers().size(), 1, 5)
	var extra_height := 0.0
	if not item.definition.flavor_text.is_empty():
		extra_height += 48.0
	if item.definition.required_level > 0 or item.definition.account_bound:
		extra_height += 34.0
	design_size.y = 515.0 + stat_rows * 48.0 + extra_height
	card_size = design_size * DISPLAY_SCALE
	custom_minimum_size = card_size
	size = card_size

func _build() -> void:
	_add_background()
	if not item or not item.definition:
		return

	var definition: ItemDefinition = item.definition
	var rarity_color: Color = item.get_rarity_color()
	var title_size := _title_font_size(definition.display_name)
	var eyebrow := _add_label("EQUIPMENT", Rect2(48, 25, design_size.x - 96, 34), BODY_FONT, 24, Color(0.38, 1.0, 0.9))
	eyebrow.add_theme_constant_override("outline_size", 2)
	var title := _add_label(definition.display_name.to_upper(), Rect2(48, 63, design_size.x - 96, 58), TITLE_FONT, title_size, Color(0.94, 1.0, 0.98))
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.16, 0.17, 0.95))
	title.add_theme_constant_override("outline_size", 2)

	var type_index := clampi(int(definition.item_type), 0, TYPE_NAMES.size() - 1)
	var subtype: String = TYPE_NAMES[type_index]
	if definition is GemDefinition:
		subtype = "SKILL GEM" if definition.gem_kind == GemDefinition.GemKind.SKILL else "SUPPORT GEM"
	elif not definition.tier_label.is_empty():
		subtype = "%s %s" % [definition.tier_label.to_upper(), subtype]
	var rarity_name: String = item.RARITY_NAMES[clampi(item.rarity, 0, item.RARITY_NAMES.size() - 1)]
	var metadata := _add_label("%s   •   %s" % [subtype, rarity_name], Rect2(48, 121, design_size.x - 96, 38), BODY_FONT, 25, rarity_color.lightened(0.28))
	metadata.add_theme_constant_override("outline_size", 2)

	var art_rect := Rect2(205, 174, 230, 230)
	if definition.tooltip_art:
		var art := _add_texture(definition.tooltip_art, art_rect)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if definition is GemDefinition:
		_add_gem_details(definition)
		_add_optional_details(definition)
		return
	var socket_marks := ""
	for socket in item.sockets:
		socket_marks += "●" if socket else "○"
	var sockets := _add_label("SOCKETS   " + socket_marks, Rect2(165, 364, 310, 34), BODY_FONT, 18, rarity_color.lightened(0.16))
	sockets.add_theme_color_override("font_outline_color", Color(0.005, 0.01, 0.02, 1))
	sockets.add_theme_constant_override("outline_size", 3)

	var modifiers: Dictionary = item.get_modifiers()
	var row := 0
	for stat in modifiers:
		if row >= 5:
			break
		_add_stat_row(StringName(stat), float(modifiers[stat]), row, rarity_color)
		row += 1

	_add_optional_details(definition)

func _add_gem_details(gem: GemDefinition) -> void:
	var affinities := _add_label("AFFINITIES", Rect2(52, 416, design_size.x - 104, 34), BODY_FONT, 22, Color(0.38, 1.0, 0.9))
	affinities.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var affinity_values := _add_label(gem.affinity_text().to_upper(), Rect2(46, 452, design_size.x - 92, 42), BODY_FONT, 23, gem.accent_color.lightened(0.32))
	affinity_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if gem.gem_kind == GemDefinition.GemKind.SUPPORT:
		var requirements: PackedStringArray = []
		for affinity in gem.required_affinities:
			requirements.append(String(affinity).to_upper())
		var support_label := _add_label("SUPPORTS SKILLS WITH", Rect2(52, 501, design_size.x - 104, 32), BODY_FONT, 20, Color(0.38, 1.0, 0.9))
		support_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var support_values := _add_label(", ".join(requirements), Rect2(52, 533, design_size.x - 104, 36), BODY_FONT, 22, Color(0.76, 1.0, 0.82))
		support_values.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _add_background() -> void:
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = card_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.043, 0.985)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.11, 0.82, 0.78, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 14
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var accent := ColorRect.new()
	accent.position = Vector2(16, 77)
	accent.size = Vector2(card_size.x - 32, 1)
	accent.color = Color(0.18, 0.9, 0.82, 0.55)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

func _add_stat_row(stat: StringName, value: float, row: int, rarity_color: Color) -> void:
	var y := 424.0 + row * 48.0
	var icon_key: StringName = STAT_ICON_ALIASES.get(stat, stat)
	var icon_texture: Texture2D = STAT_ICONS.get(icon_key, STAT_ICONS[&"armor_penetration"])
	var icon := _add_texture(icon_texture, Rect2(58, y + 3, 32, 32))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var label_text := String(stat).replace("_", " ").to_upper()
	var stat_label := _add_label(label_text, Rect2(104, y, 340, 38), BODY_FONT, 20, Color(0.82, 0.9, 0.92))
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var value_label := _add_label(_format_value(stat, value), Rect2(454, y, 126, 38), BODY_FONT, 21, _stat_value_color(stat, rarity_color).lightened(0.12))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _add_optional_details(definition: ItemDefinition) -> void:
	var stat_rows := clampi(item.get_modifiers().size(), 1, 5)
	var flavor_y := 526.0 if definition is GemDefinition and definition.gem_kind == GemDefinition.GemKind.SKILL else 578.0 if definition is GemDefinition else 432.0 + stat_rows * 48.0
	if not definition.flavor_text.is_empty():
		_add_label(definition.flavor_text, Rect2(58, flavor_y, design_size.x - 116, 42), BODY_FONT, 22, Color(0.94, 0.72, 0.87))
	var footer_y := design_size.y - 54.0
	if definition.required_level > 0:
		var level := _add_label("REQUIRES LEVEL %d" % definition.required_level, Rect2(44, footer_y, 168, 24), BODY_FONT, 11, Color(0.12, 0.9, 0.96))
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if definition.account_bound:
		var bound := _add_label("ACCOUNT BOUND", Rect2(design_size.x - 204, footer_y, 160, 24), BODY_FONT, 11, Color(0.12, 0.9, 0.96))
		bound.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _title_font_size(item_name: String) -> int:
	var length := item_name.length()
	if length >= 18:
		return 38
	if length >= 14:
		return 42
	if length >= 10:
		return 46
	return 50

func _stat_value_color(stat: StringName, rarity_color: Color) -> Color:
	if stat == &"damage" or stat == &"life_on_kill":
		return Color(1.0, 0.24, 0.58)
	if rarity_color.get_luminance() < 0.35:
		return Color(0.12, 0.9, 0.96)
	return Color(0.18, 0.92, 0.96)

func _format_value(stat: StringName, value: float) -> String:
	if stat in [&"critical_chance", &"critical_multiplier", &"attack_speed", &"armor_penetration", &"cooldown"] or absf(value) < 1.0:
		return "%+.1f%%" % (value * 100.0 if absf(value) < 1.0 else value)
	return "%+.0f" % value

func _add_label(label_text: String, rect: Rect2, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position * DISPLAY_SCALE
	label.size = rect.size * DISPLAY_SCALE
	label.text = label_text
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", display_font if display_font else font)
	label.add_theme_font_size_override("font_size", maxi(1, roundi(font_size * DISPLAY_SCALE)))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.005, 0.012, 0.02, 0.95))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label

func _add_texture(texture: Texture2D, rect: Rect2, apply_display_scale := true) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.position = rect.position * DISPLAY_SCALE if apply_display_scale else rect.position
	texture_rect.size = rect.size * DISPLAY_SCALE if apply_display_scale else rect.size * DISPLAY_SCALE
	texture_rect.texture = texture
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)
	return texture_rect
