class_name InventorySlot
extends Button

const ITEM_TOOLTIP_SCENE := preload("res://scenes/ui/inventory/item_tooltip.tscn")

signal drop_requested(data: Dictionary, target_kind: StringName, target_key: Variant)
signal socket_clicked(item: Resource, socket_index: int)
signal delete_requested(source_kind: StringName, source_key: Variant)

var container_kind := &"inventory"
var slot_key: Variant = -1
var item: Resource
var placeholder := ""

@onready var item_art: TextureRect = $ItemArt
@onready var socket_row: GemSocketStrip = $SocketRow

func _ready() -> void:
	pressed.connect(_on_pressed)
	socket_row.drop_requested.connect(_on_socket_drop_requested)
	socket_row.socket_clicked.connect(_on_socket_target_clicked)
	_show_item()

func configure(index: int, type: StringName, display_name: String = "") -> void:
	container_kind = &"inventory" if type == &"inventory" else &"equipment"
	slot_key = index if container_kind == &"inventory" else type
	placeholder = display_name
	_show_item()

func set_item(new_item: Resource) -> void:
	item = new_item
	_show_item()

func _gui_input(event: InputEvent) -> void:
	if not item or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if mouse_event.ctrl_pressed and mouse_event.shift_pressed and mouse_event.alt_pressed:
		delete_requested.emit(container_kind, slot_key)
		accept_event()

func _get_drag_data(position: Vector2) -> Variant:
	if not item:
		return null
	var socket_index := _socket_index_at(position)
	if socket_index >= 0 and item.sockets[socket_index]:
		var socketed_gem: Resource = item.sockets[socket_index]
		_set_icon_drag_preview(_get_inventory_texture(socketed_gem))
		return {
			"source_kind": &"socket",
			"source_key": {"item": item, "index": socket_index},
		}
	_set_icon_drag_preview(_get_inventory_texture(item))
	return {
		"source_kind": container_kind,
		"source_key": slot_key,
	}

func _set_icon_drag_preview(texture: Texture2D) -> void:
	var preview := Control.new()
	var preview_art := TextureRect.new()
	preview.add_child(preview_art)
	preview_art.size = Vector2(76, 76)
	preview_art.position = Vector2(-38, -38)
	preview_art.texture = texture
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	set_drag_preview(preview)

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("source_kind") and data.has("source_key")

func _drop_data(position: Vector2, data: Variant) -> void:
	var socket_index := _socket_index_at(position)
	if socket_index >= 0:
		drop_requested.emit(data, &"socket", {"item": item, "index": socket_index})
	else:
		drop_requested.emit(data, container_kind, slot_key)

func _make_custom_tooltip(_for_text: String) -> Object:
	if not item:
		return null
	var socket_index := _socket_index_at(get_local_mouse_position())
	if socket_index >= 0 and item.sockets[socket_index]:
		var gem_tooltip := ITEM_TOOLTIP_SCENE.instantiate()
		gem_tooltip.call("setup", item.sockets[socket_index])
		return gem_tooltip
	var custom_tooltip := ITEM_TOOLTIP_SCENE.instantiate()
	custom_tooltip.call("setup", item)
	return custom_tooltip

func _show_item() -> void:
	if not is_node_ready():
		return
	if not item:
		text = placeholder
		item_art.hide()
		socket_row.hide()
		socket_row.set_socket_data([], null)
		tooltip_text = placeholder if not placeholder.is_empty() else "Empty inventory slot"
		add_theme_color_override("font_color", Color(0.42, 0.62, 0.66))
		return
	text = ""
	item_art.texture = _get_inventory_texture()
	item_art.visible = item_art.texture != null
	socket_row.set_socket_data(item.sockets, item)
	socket_row.visible = not item.sockets.is_empty()
	tooltip_text = item.get_tooltip()
	add_theme_color_override("font_color", item.get_rarity_color())

func _socket_index_at(position: Vector2) -> int:
	if not item or item.sockets.is_empty() or position.y < size.y - 24.0:
		return -1
	return clampi(floori(position.x / maxf(size.x, 1.0) * item.sockets.size()), 0, item.sockets.size() - 1)

func _on_pressed() -> void:
	var socket_index := _socket_index_at(get_local_mouse_position())
	if socket_index >= 0 and item.sockets[socket_index]:
		socket_clicked.emit(item, socket_index)

func _on_socket_drop_requested(data: Dictionary, socket_index: int) -> void:
	drop_requested.emit(data, &"socket", {"item": item, "index": socket_index})

func _on_socket_target_clicked(socket_index: int) -> void:
	if item and socket_index >= 0 and socket_index < item.sockets.size() and item.sockets[socket_index]:
		socket_clicked.emit(item, socket_index)

func _get_inventory_texture(source_item: Resource = null) -> Texture2D:
	if not source_item:
		source_item = item
	# Always render from the original full-resolution art. Godot handles the
	# downscale with mipmapped filtering and preserves its aspect ratio.
	if source_item.definition.tooltip_art:
		return source_item.definition.tooltip_art
	return source_item.definition.inventory_icon
