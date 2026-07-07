class_name GemSocketStrip
extends Control

var sockets: Array = []

func set_socket_data(new_sockets: Array) -> void:
	sockets = new_sockets
	queue_redraw()

func _draw() -> void:
	if sockets.is_empty():
		return
	var gap := 2.0
	var slot_width := (size.x - gap * float(sockets.size() - 1)) / float(sockets.size())
	var icon_size := minf(slot_width, size.y)
	var start_x := (size.x - (icon_size * sockets.size() + gap * (sockets.size() - 1))) * 0.5
	for index in sockets.size():
		var rect := Rect2(start_x + index * (icon_size + gap), (size.y - icon_size) * 0.5, icon_size, icon_size)
		var gem: Resource = sockets[index]
		var border := Color(0.32, 0.46, 0.5, 0.95)
		if gem and gem.definition is GemDefinition:
			border = Color(1.0, 0.28, 0.12) if gem.definition.gem_kind == GemDefinition.GemKind.SKILL else Color(0.25, 1.0, 0.48)
		draw_rect(rect, Color(0.008, 0.016, 0.026, 0.98), true)
		draw_rect(rect, border, false, 1.5)
		if gem:
			var texture: Texture2D = gem.definition.inventory_icon if gem.definition.inventory_icon else gem.definition.tooltip_art
			if texture:
				draw_texture_rect(texture, rect.grow(-2.0), false)
		else:
			draw_circle(rect.get_center(), maxf(1.5, icon_size * 0.16), Color(0.22, 0.34, 0.38, 0.9), false, 1.2, true)
