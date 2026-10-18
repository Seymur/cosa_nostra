extends Label

## Shown under the crosshair while a placeable item is held and snapping is on.

var _player: Node

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	text = "Snapping enabled"

func _process(_delta: float) -> void:
	visible = _player != null and _player.held_item is PlaceableItem and PlaceableItem.snapping
