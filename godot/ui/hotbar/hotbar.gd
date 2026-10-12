extends HBoxContainer

## Icon for the bare-hands slot.
@export var bare_hands_icon: Texture2D

var _player: Node
var _slots: Array[ItemSlot] = []

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	for i in _player.HOTBAR_SIZE:
		var slot := ItemSlot.new()
		slot.setup(_player, _player.ItemStore.HOTBAR, i, i == _player.BARE_HANDS_SLOT)
		add_child(slot)
		_slots.append(slot)
	_player.hotbar_changed.connect(_refresh)
	_player.selected_slot_changed.connect(_refresh.unbind(1))
	UIManager.screen_changed.connect(_on_screen_changed)
	_refresh()

# The hotbar is drawn above the menu screens (same canvas layer, later in the tree) so
# it stays visible over the inventory. Other screens must cover it.
# While the inventory is open its slots are drag and drop targets too.
func _on_screen_changed(top: Control) -> void:
	visible = top == null or top is InventoryScreen
	for slot in _slots:
		slot.set_interactive(top is InventoryScreen)

func _refresh() -> void:
	for i in _slots.size():
		var item: Equippable = _player.hotbar[i]
		if i == _player.BARE_HANDS_SLOT:
			_slots[i].show_content(bare_hands_icon, "Hands")
		elif item:
			_slots[i].show_content(item.icon, item.display_name)
		else:
			_slots[i].show_content(null, "")
		_slots[i].set_selected(i == _player.selected_slot)
