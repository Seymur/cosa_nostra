class_name ItemSlot
extends PanelContainer
## One cell of the hotbar or the inventory. Shows what it is given and, when it
## holds an item, can be dragged onto any other slot to move or swap items.

const SLOT_SIZE := Vector2(64, 64)
const FIXED_SLOT_SHADER := preload("res://ui/hotbar/fixed_slot_stripes.gdshader")
const DRAG_DATA_KEY := "item_slot"
## Above every menu canvas layer, including the hotbar's.
const DRAG_PREVIEW_LAYER := 100

static var _normal_style := _make_style(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.25), 2)
static var _selected_style := _make_style(Color(0, 0, 0, 0.7), Color(1, 1, 1, 1), 3)

var player: Node
## Which of the player's containers this slot shows (the player's ItemStore enum).
var container: int
var index: int

var _slot_size := SLOT_SIZE
var _drag_preview: CanvasLayer
var _icon: TextureRect
var _name_label: Label

## Sets the slot up and builds its visuals. `fixed` marks the slot that never holds
## an item with diagonal stripes.
func setup(p_player: Node, p_container: int, p_index: int, fixed := false, slot_size := SLOT_SIZE) -> void:
	player = p_player
	container = p_container
	index = p_index
	_slot_size = slot_size
	custom_minimum_size = slot_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _normal_style)

	if fixed:
		var stripes := ColorRect.new()
		stripes.material = ShaderMaterial.new()
		stripes.material.shader = FIXED_SLOT_SHADER
		stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripes)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

## Shows `icon`, or `label` as text when there is no icon.
func show_content(icon: Texture2D, label: String) -> void:
	_icon.texture = icon
	_name_label.text = "" if icon else label

func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)

## Slots only take part in drag and drop while a screen that wants it is open.
func set_interactive(interactive: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_EXIT_TREE:
		_free_drag_preview()

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item: Equippable = player.get_item(container, index)
	if item == null:
		return null
	_free_drag_preview()
	_drag_preview = _make_drag_preview(item)
	get_tree().root.add_child(_drag_preview)
	_drag_preview.follow_cursor()
	return {DRAG_DATA_KEY: self}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has(DRAG_DATA_KEY)):
		return false
	# Checked before casting: the source slot is freed when its screen closes mid-drag,
	# and casting a freed object raises an error on every mouse move.
	var source: Variant = data[DRAG_DATA_KEY]
	if not is_instance_valid(source) or source == self:
		return false
	return not player.is_fixed_slot(container, index)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var source: Variant = data[DRAG_DATA_KEY]
	if not is_instance_valid(source):
		return
	player.move_item(source.container, source.index, container, index)

func _free_drag_preview() -> void:
	if is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null

## Not set_drag_preview: that one is drawn under higher canvas layers such as the
## hotbar's. This follows the cursor on a layer above them all.
func _make_drag_preview(item: Equippable) -> CanvasLayer:
	var root := DragPreview.new()
	root.layer = DRAG_PREVIEW_LAYER
	# The game may be paused while the inventory is open.
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var holder: Control
	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder = icon
	else:
		var label := Label.new()
		label.text = item.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		holder = label
	holder.custom_minimum_size = _slot_size
	holder.size = _slot_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# See-through so the slot under it stays readable.
	holder.modulate.a = 0.8
	root.holder = holder
	root.add_child(holder)
	return root

## Keeps `holder` centered on the cursor.
class DragPreview extends CanvasLayer:
	var holder: Control

	func _process(_delta: float) -> void:
		follow_cursor()

	func follow_cursor() -> void:
		holder.position = get_viewport().get_mouse_position() - holder.size * 0.5

static func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style
