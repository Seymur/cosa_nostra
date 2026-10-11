extends Interactable

@export var interact_action: GUIDEAction
@export var open_angle_degrees := 90.0
@export var open_duration := 0.4

# The door mesh is centered on the node, so it is swung around its left edge.
const HINGE := Vector3(-0.5, 0, 0)

@onready var body: StaticBody3D = $Door

var is_open := false
var _tween: Tween

func _ready() -> void:
	outline_mesh = $Door/Mesh/Outline

func on_action(action: GUIDEAction) -> void:
	if action == interact_action:
		toggle()

func toggle() -> void:
	is_open = not is_open
	var from := _current_angle()
	var to := deg_to_rad(open_angle_degrees) if is_open else 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_angle, from, to, open_duration)

func _current_angle() -> float:
	return body.rotation.y

func _set_angle(angle: float) -> void:
	var basis := Basis(Vector3.UP, angle)
	body.transform = Transform3D(basis, HINGE - basis * HINGE)
