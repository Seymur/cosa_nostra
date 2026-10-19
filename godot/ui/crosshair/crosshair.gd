extends ColorRect

## Hold actions the ring fills for while they are held on something they work on:
## the hold-to-remove action and the held items' timed actions.
@export var hold_actions: Array[GUIDEAction]
## The hold-to-remove action, which only works with empty hands on a removable prop.
@export var remove_action: GUIDEAction

var _player: Node
var _active: GUIDEAction

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	set_process(false)
	for action in hold_actions:
		action.started.connect(_on_hold_started.bind(action))
		action.completed.connect(_hide_progress)
		action.cancelled.connect(_hide_progress)
		action.triggered.connect(_hide_progress)

func _on_hold_started(action: GUIDEAction) -> void:
	if _can_use(action):
		_active = action
		set_process(true)

func _process(_delta: float) -> void:
	# Looking away from the target aborts the hold: the action would fire on nothing.
	if not _can_use(_active):
		_hide_progress()
		return
	(material as ShaderMaterial).set_shader_parameter("progress", _active.elapsed_ratio)

## A hold only counts when the focused target would react to it.
func _can_use(action: GUIDEAction) -> bool:
	if _player == null or action == null:
		return false
	var target: Interactable = _player.focused_interactable if is_instance_valid(_player.focused_interactable) else null
	if target == null:
		return false
	var held: Equippable = _player.held_item
	if held == null:
		return action == remove_action and target is Removable
	return "primary_action" in held and held.primary_action == action and target.accepts_item(held)

func _hide_progress() -> void:
	_active = null
	set_process(false)
	(material as ShaderMaterial).set_shader_parameter("progress", 0.0)
