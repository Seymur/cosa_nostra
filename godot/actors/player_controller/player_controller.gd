extends CharacterBody3D

@export var default_mapping_context: GUIDEMappingContext;
@export var move_action: GUIDEAction;
@export var jump_action: GUIDEAction;
@export var look_action: GUIDEAction;
@export var speed_up_action: GUIDEAction;
@export var speed_down_action: GUIDEAction;
@export var pick_up_action: GUIDEAction;
@export var throw_action: GUIDEAction;

@export_group("Mouse")
@export var horizontal_sensitivity = 0.1
@export var vertical_sensitivity = 0.1
@onready var shape_cast_3d: ShapeCast3D = $Head/Camera/ShapeCast3D

var _focused_equippable: Equippable = null
var _held_equippable: Equippable = null

const HELD_POSITION := Vector3(0.3, -0.3, -0.5)
const THROW_SPEED = 10.0
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	GUIDE.enable_mapping_context(default_mapping_context)
	look_action.triggered.connect(_on_look_triggered)
	speed_up_action.triggered.connect(_on_speed_up_triggered)
	speed_down_action.triggered.connect(_on_speed_down_triggered)
	pick_up_action.triggered.connect(_on_pick_up_triggered)
	throw_action.triggered.connect(_on_throw_triggered)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_pick_up_triggered():
	if is_instance_valid(_held_equippable) or not is_instance_valid(_focused_equippable):
		return
	var item := _focused_equippable
	_focused_equippable = null
	item.set_outlined(false)
	item.reparent($Head, false)
	item.transform = Transform3D(Basis.IDENTITY, HELD_POSITION)
	# After reparenting, so the body's reset pose is applied in its final place in the tree.
	item.hold()
	_held_equippable = item

func _on_throw_triggered():
	if not is_instance_valid(_held_equippable):
		return
	var item := _held_equippable
	_held_equippable = null
	item.reparent(get_tree().current_scene, true)
	var forward: Vector3 = -$Head/Camera.global_basis.z
	item.release(forward * THROW_SPEED + velocity)

func _on_speed_up_triggered():
	GameControl.request_speed(GameClock.speed_multiplier * 2.0)

func _on_speed_down_triggered():
	GameControl.request_speed(GameClock.speed_multiplier / 2.0)

func _on_look_triggered():
	rotate_y(-deg_to_rad(look_action.value_axis_2d.x) * horizontal_sensitivity)
	$Head.rotate_x(-deg_to_rad(look_action.value_axis_2d.y) * vertical_sensitivity)
	$Head.rotation_degrees.x = clamp($Head.rotation_degrees.x, -89, 89)

func _physics_process(delta: float) -> void:
	shape_cast_3d.add_exception(self)
	var equippable: Equippable = null
	for i in shape_cast_3d.get_collision_count():
		var collider := shape_cast_3d.get_collider(i)
		if collider is Equippable:
			equippable = collider
		elif collider and collider.get_parent() is Equippable:
			equippable = collider.get_parent()
		if equippable:
			break

	if equippable != _focused_equippable:
		if is_instance_valid(_focused_equippable):
			_focused_equippable.set_outlined(false)
		if equippable:
			equippable.set_outlined(true)
		_focused_equippable = equippable

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if jump_action.is_triggered() and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := move_action.value_axis_2d
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
