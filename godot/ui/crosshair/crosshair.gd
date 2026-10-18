extends ColorRect

## The hold-to-remove action; the ring fills as it is held on a removable prop.
@export var remove_action: GUIDEAction

var _player: Node

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	set_process(false)
	remove_action.started.connect(_on_hold_started)
	remove_action.completed.connect(_hide_progress)
	remove_action.cancelled.connect(_hide_progress)
	remove_action.triggered.connect(_hide_progress)

func _on_hold_started() -> void:
	if _can_remove():
		set_process(true)

func _process(_delta: float) -> void:
	# Looking away from the prop aborts the hold: the action would fire on nothing.
	if not _can_remove():
		_hide_progress()
		return
	(material as ShaderMaterial).set_shader_parameter("progress", remove_action.elapsed_ratio)

## Removing only works on a focused removable prop with empty hands.
func _can_remove() -> bool:
	return _player != null and _player.held_item == null and _player.focused_interactable is Removable

func _hide_progress() -> void:
	set_process(false)
	(material as ShaderMaterial).set_shader_parameter("progress", 0.0)
