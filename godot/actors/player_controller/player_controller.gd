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

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	GUIDE.enable_mapping_context(default_mapping_context)
	look_action.triggered.connect(_on_look_triggered)
	speed_up_action.triggered.connect(_on_speed_up_triggered)
	speed_down_action.triggered.connect(_on_speed_down_triggered)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_speed_up_triggered():
	GameClock.set_speed(GameClock.speed_multiplier * 2.0)

func _on_speed_down_triggered():
	GameClock.set_speed(GameClock.speed_multiplier / 2.0)

func _on_look_triggered():
	rotate_y(-deg_to_rad(look_action.value_axis_2d.x) * horizontal_sensitivity)
	$Head.rotate_x(-deg_to_rad(look_action.value_axis_2d.y) * vertical_sensitivity)
	$Head.rotation_degrees.x = clamp($Head.rotation_degrees.x, -89, 89)

func _physics_process(delta: float) -> void:
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
