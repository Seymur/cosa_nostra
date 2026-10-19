extends Label

## Shows the player's short messages for a moment.

const DURATION := 2.0

var _tween: Tween

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.notified.connect(_show_message)

func _show_message(message: String) -> void:
	text = message
	modulate.a = 1.0
	visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(DURATION)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(hide)
