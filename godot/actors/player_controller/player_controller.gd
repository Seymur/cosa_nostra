extends CharacterBody3D

@export var default_mapping_context: GUIDEMappingContext;
@export var move_action: GUIDEAction;
@export var jump_action: GUIDEAction;
@export var look_action: GUIDEAction;
@export var speed_up_action: GUIDEAction;
@export var speed_down_action: GUIDEAction;

@export_group("Mouse")
@export var horizontal_sensitivity = 0.1
@export var vertical_sensitivity = 0.1

@onready var camera: Camera3D = $Head/Camera
@onready var shape_cast_3d: ShapeCast3D = $Head/Camera/ShapeCast3D

var focused_interactable: Interactable

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	shape_cast_3d.add_exception(self)
	GUIDE.enable_mapping_context(default_mapping_context)
	look_action.triggered.connect(_on_look_triggered)
	speed_up_action.triggered.connect(_on_speed_up_triggered)
	speed_down_action.triggered.connect(_on_speed_down_triggered)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_speed_up_triggered():
	GameControl.request_speed(GameClock.speed_multiplier * 2.0)

func _on_speed_down_triggered():
	GameControl.request_speed(GameClock.speed_multiplier / 2.0)

func _on_look_triggered():
	rotate_y(-deg_to_rad(look_action.value_axis_2d.x) * horizontal_sensitivity)
	$Head.rotate_x(-deg_to_rad(look_action.value_axis_2d.y) * vertical_sensitivity)
	$Head.rotation_degrees.x = clamp($Head.rotation_degrees.x, -89, 89)

## Returns the Interactable whose hit point in the shape cast is closest to the camera,
## or null if the sweep hit no interactable. Call it from _physics_process, after the
## shape cast has updated.
func find_closest_interactable() -> Interactable:
	var closest: Interactable = null
	var closest_distance := INF
	for i in shape_cast_3d.get_collision_count():
		var interactable := _find_interactable(shape_cast_3d.get_collider(i))
		if interactable == null:
			continue
		var distance := camera.global_position.distance_squared_to(shape_cast_3d.get_collision_point(i))
		if distance < closest_distance:
			closest_distance = distance
			closest = interactable
	return closest

# Interactables are usually a parent of the physics body that got hit, so walk up the tree.
func _find_interactable(node: Node) -> Interactable:
	while node:
		if node is Interactable:
			return node
		node = node.get_parent()
	return null

## Moves focus to `interactable` (or clears it when null): hides the outline of the
## previously focused one and shows the outline of the new one.
func set_focused_interactable(interactable: Interactable) -> void:
	if interactable == focused_interactable:
		return
	# The previous one may have been freed (e.g. picked up) since the last frame.
	if is_instance_valid(focused_interactable):
		focused_interactable.hide_outline()
	focused_interactable = interactable
	if focused_interactable:
		focused_interactable.show_outline()

func _physics_process(delta: float) -> void:
	set_focused_interactable(find_closest_interactable())

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
