class_name WorldMenu
extends Node3D
## Interaction menu drawn in 3D to the right of the crosshair. It follows the
## camera; scroll moves the selection and `choose()` picks it.

signal option_chosen(option: InteractionOption)
signal closed

const ROW_HEIGHT := 0.05
const WIDTH := 0.3
const PADDING := 0.02
## Distance in front of the camera, and offset to its right.
const DISTANCE := 0.8
const RIGHT_OFFSET := 0.25
## How far the panel is turned toward the crosshair, in degrees.
const TURN_LEFT_DEG := 20.0
const MAX_TARGET_DISTANCE := 5.0
const COLOR_NORMAL := Color.WHITE
const COLOR_SELECTED := Color(1.0, 0.85, 0.2)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5)

var _interactable: Interactable
var _camera: Camera3D
var _rows: Array[Label3D] = []
var _selected := -1

## Call before adding to the tree.
func setup(interactable: Interactable, camera: Camera3D) -> void:
	_interactable = interactable
	_camera = camera

func _ready() -> void:
	var count := _interactable.options.size()
	var height := count * ROW_HEIGHT

	var background := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH + PADDING * 2.0, height + PADDING * 2.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0, 0, 0, 0.7)
	material.no_depth_test = true
	quad.material = material
	background.mesh = quad
	add_child(background)

	for i in count:
		var label := Label3D.new()
		label.text = _interactable.options[i].label
		label.pixel_size = 0.0008
		label.font_size = 48
		label.no_depth_test = true
		label.render_priority = 1
		label.outline_render_priority = 0
		label.position = Vector3(0, height / 2.0 - (i + 0.5) * ROW_HEIGHT, 0.001)
		add_child(label)
		_rows.append(label)

	Equipment.equipped_changed.connect(_on_equipped_changed.unbind(1))
	_selected = _next_available(-1, 1)
	_follow_camera()
	_refresh_colors()

func _process(_delta: float) -> void:
	var target := _interactable.get_parent() as Node3D if is_instance_valid(_interactable) else null
	if target == null or _camera.global_position.distance_to(target.global_position) > MAX_TARGET_DISTANCE:
		close()
		return
	_follow_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-1)
		else:
			return
		get_viewport().set_input_as_handled()

## Chooses the selected option, if any.
func choose() -> void:
	if _selected < 0:
		return
	var option := _interactable.options[_selected]
	close()
	option_chosen.emit(option)

func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()

func _follow_camera() -> void:
	global_transform = Transform3D(
		_camera.global_basis * Basis(Vector3.UP, -deg_to_rad(TURN_LEFT_DEG)),
		_camera.global_position - _camera.global_basis.z * DISTANCE + _camera.global_basis.x * RIGHT_OFFSET)

func _scroll(step: int) -> void:
	var next := _next_available(_selected, step)
	if next >= 0:
		_selected = next
		_refresh_colors()

## Next available row after `from` in direction `step`, wrapping around.
## Returns -1 if none is available.
func _next_available(from: int, step: int) -> int:
	var count := _rows.size()
	for i in range(1, count + 1):
		var row := posmod(from + step * i, count)
		if _interactable.is_available(_interactable.options[row], Equipment.equipped):
			return row
	return -1

func _on_equipped_changed() -> void:
	if _selected < 0 or not _interactable.is_available(_interactable.options[_selected], Equipment.equipped):
		_selected = _next_available(-1, 1)
	_refresh_colors()

func _refresh_colors() -> void:
	for i in _rows.size():
		var available := _interactable.is_available(_interactable.options[i], Equipment.equipped)
		_rows[i].modulate = COLOR_SELECTED if i == _selected else (COLOR_NORMAL if available else COLOR_DISABLED)
