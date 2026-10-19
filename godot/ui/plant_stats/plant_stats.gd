extends Label

## Shown beside the crosshair with the focused interactable's HUD text, if it has any.

var _player: Node

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	var target: Interactable = null
	if _player != null and is_instance_valid(_player.focused_interactable):
		target = _player.focused_interactable
	var hud_text := target.get_hud_text() if target else ""
	visible = not hud_text.is_empty()
	text = hud_text
