class_name LootDrop
extends Area2D

const ItemInstanceScript = preload("res://scripts/items/item_instance.gd")

var item: Resource
var collected := false
var age := 0.0

@onready var icon: Sprite2D = $Icon
@onready var quality_label: Label = $QualityLabel

func configure(definition: Resource, rarity: int) -> void:
	item = ItemInstanceScript.new()
	item.initialize(definition, rarity)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not item or not item.definition:
		queue_free()
		return
	icon.texture = item.definition.inventory_icon
	icon.modulate = item.get_rarity_color().lightened(0.12)
	quality_label.text = "%s %s" % [item.RARITY_NAMES[item.rarity], item.definition.display_name]
	quality_label.add_theme_color_override("font_color", item.get_rarity_color())
	queue_redraw()

func _process(delta: float) -> void:
	age += delta
	icon.position.y = -12.0 + sin(age * 3.2) * 3.0
	queue_redraw()

func _draw() -> void:
	if not item:
		return
	var color: Color = item.get_rarity_color()
	var pulse := 0.72 + sin(age * 4.0) * 0.12
	draw_circle(Vector2.ZERO, 19.0, Color(color, 0.12 * pulse))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(color, pulse), 2.5)
	draw_line(Vector2(0, -22), Vector2(0, -78), Color(color, 0.28 * pulse), 4.0)

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	var inventory := get_tree().get_first_node_in_group("item_inventory")
	if inventory and inventory.call("add_item", item):
		collected = true
		queue_free()
	else:
		quality_label.text = "INVENTORY FULL"
		quality_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.22))
