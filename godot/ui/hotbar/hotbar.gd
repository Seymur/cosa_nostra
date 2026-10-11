extends HBoxContainer

const SLOT_SIZE := Vector2(64, 64)

var _player: Node
var _slots: Array[PanelContainer] = []
var _name_labels: Array[Label] = []

var _normal_style := _make_style(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.25), 2)
var _selected_style := _make_style(Color(0, 0, 0, 0.7), Color(1, 1, 1, 1), 3)

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	for i in _player.HOTBAR_SIZE:
		_add_slot(i)
	_player.hotbar_changed.connect(_refresh)
	_player.selected_slot_changed.connect(_refresh.unbind(1))
	_refresh()

func _add_slot(index: int) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_label)

	var number_label := Label.new()
	number_label.text = str(index + 1)
	number_label.add_theme_font_size_override("font_size", 10)
	number_label.modulate = Color(1, 1, 1, 0.6)
	number_label.position = Vector2(5, 2)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(number_label)

	add_child(slot)
	_slots.append(slot)
	_name_labels.append(name_label)

func _refresh() -> void:
	for i in _slots.size():
		var item: Equippable = _player.hotbar[i]
		_name_labels[i].text = item.display_name if item else ""
		_slots[i].add_theme_stylebox_override("panel", _selected_style if i == _player.selected_slot else _normal_style)

func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style
