class_name GemSocketStrip
extends Control

const SOCKET_TARGET_SCRIPT := preload("res://scenes/ui/inventory/gem_socket_target.gd")

signal drop_requested(data: Dictionary, socket_index: int)
signal socket_clicked(socket_index: int)

var sockets: Array = []
var gear_item: Resource

func set_socket_data(new_sockets: Array, source_item: Resource = null) -> void:
	sockets = new_sockets
	gear_item = source_item
	_rebuild_targets()
	queue_redraw()

func _rebuild_targets() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if sockets.is_empty():
		return
	var rects := _socket_rects()
	for index in sockets.size():
		var target := Control.new()
		target.set_script(SOCKET_TARGET_SCRIPT)
		add_child(target)
		# Fill the entire strip with contiguous targets. The visible gems stay
		# compact, but there are no tiny dead gaps while moving the mouse.
		var target_width := size.x / float(sockets.size())
		target.position = Vector2(target_width * index, 0.0)
		target.size = Vector2(target_width, size.y)
		target.mouse_filter = Control.MOUSE_FILTER_STOP
		target.call("setup", gear_item, index, sockets[index])
		target.connect("drop_requested", _on_target_drop_requested)
		target.connect("socket_clicked", _on_target_socket_clicked)

func _socket_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if sockets.is_empty():
		return rects
	var gap := 2.0
	var slot_width := (size.x - gap * float(sockets.size() - 1)) / float(sockets.size())
	var icon_size := minf(slot_width, size.y)
	var start_x := (size.x - (icon_size * sockets.size() + gap * (sockets.size() - 1))) * 0.5
	for index in sockets.size():
		rects.append(Rect2(start_x + index * (icon_size + gap), (size.y - icon_size) * 0.5, icon_size, icon_size))
	return rects

func _draw() -> void:
	if sockets.is_empty():
		return
	var rects := _socket_rects()
	for index in sockets.size():
		var rect := rects[index]
		var icon_size := rect.size.x
		var gem: Resource = sockets[index]
		var border := Color(0.32, 0.46, 0.5, 0.95)
		if gem and gem.definition is GemDefinition:
			border = Color(1.0, 0.28, 0.12) if gem.definition.gem_kind == GemDefinition.GemKind.SKILL else Color(0.25, 1.0, 0.48)
		draw_rect(rect, Color(0.008, 0.016, 0.026, 0.98), true)
		draw_rect(rect, border, false, 1.5)
		if gem:
			var texture: Texture2D = gem.definition.tooltip_art if gem.definition.tooltip_art else gem.definition.inventory_icon
			if texture:
				draw_texture_rect(texture, rect.grow(-2.0), false)
		else:
			draw_circle(rect.get_center(), maxf(1.5, icon_size * 0.16), Color(0.22, 0.34, 0.38, 0.9), false, 1.2, true)

func _on_target_drop_requested(data: Dictionary, socket_index: int) -> void:
	drop_requested.emit(data, socket_index)

func _on_target_socket_clicked(socket_index: int) -> void:
	socket_clicked.emit(socket_index)
