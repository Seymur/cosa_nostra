class_name InventoryScreen
extends Control
## Fullscreen inventory. The backdrop and grid fill the screen above the hotbar, which
## stays in its place at the bottom and takes drops through the shared drag and drop
## slots (see Hotbar).

const COLUMNS := 8
const SLOT_SIZE := Vector2(80, 80)

@onready var _grid: GridContainer = $Center/Panel/Margin/Grid

var _player: Node
var _slots: Array[ItemSlot] = []

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_grid.columns = COLUMNS
	for i in _player.INVENTORY_SIZE:
		var slot := ItemSlot.new()
		slot.setup(_player, _player.ItemStore.INVENTORY, i, false, SLOT_SIZE)
		slot.set_interactive(true)
		_grid.add_child(slot)
		_slots.append(slot)
	_player.inventory_changed.connect(_refresh)
	_refresh()

# _input rather than _unhandled_input so Tab can't be eaten by focus navigation.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("inventory") or UIManager.top() != self:
		return
	# Closing mid-drag would free the dragged slot.
	if get_viewport().gui_is_dragging():
		return
	UIManager.pop()
	get_viewport().set_input_as_handled()

# Esc closes the screen too, which frees the slots a drag may still point at.
func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport and viewport.gui_is_dragging():
		viewport.gui_cancel_drag()

func _refresh() -> void:
	for i in _slots.size():
		var item: Equippable = _player.inventory[i]
		if item:
			_slots[i].show_content(item.icon, item.display_name)
		else:
			_slots[i].show_content(null, "")
