class_name StepperSelect
extends HBoxContainer
## Left/right arrows cycling through a list of options. Wraps around at the ends.

signal selected(index: int)

var _items: PackedStringArray = []
var _index := 0

@onready var _left: Button = $Left
@onready var _label: Label = $Label
@onready var _right: Button = $Right

func _ready() -> void:
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left.pressed.connect(step.bind(-1))
	_right.pressed.connect(step.bind(1))
	_refresh()

func set_items(items: PackedStringArray, index := 0) -> void:
	_items = items
	_index = clampi(index, 0, maxi(items.size() - 1, 0))
	if is_node_ready():
		_refresh()

func get_selected_index() -> int:
	return _index

func select(index: int) -> void:
	if _items.is_empty():
		return
	_index = posmod(index, _items.size())
	_refresh()

func step(direction: int) -> void:
	if _items.is_empty():
		return
	select(_index + direction)
	selected.emit(_index)

func _refresh() -> void:
	# Keep the widget width stable by reserving room for the longest item.
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	var widest := 0.0
	for item in _items:
		widest = maxf(widest, font.get_string_size(item, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	_label.custom_minimum_size.x = widest
	_label.text = _items[_index] if not _items.is_empty() else ""
