extends CharacterBody3D

@export var default_mapping_context: GUIDEMappingContext;
@export var move_action: GUIDEAction;
@export var jump_action: GUIDEAction;
@export var look_action: GUIDEAction;
@export var speed_up_action: GUIDEAction;
@export var speed_down_action: GUIDEAction;
@export var interact_action: GUIDEAction;

## Temporary: keys 1..n equip these, 0 unequips. Replace with a real inventory.
@export var debug_items: Array[ItemData] = []

@export_group("Mouse")
@export var horizontal_sensitivity = 0.1
@export var vertical_sensitivity = 0.1

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const INTERACTION_MENU := preload("res://ui/interaction_menu/interaction_menu.tscn")

func _ready() -> void:
	GUIDE.enable_mapping_context(default_mapping_context)
	look_action.triggered.connect(_on_look_triggered)
	speed_up_action.triggered.connect(_on_speed_up_triggered)
	speed_down_action.triggered.connect(_on_speed_down_triggered)
	interact_action.triggered.connect(_on_interact_triggered)
	Equipment.equipped_changed.connect(_on_equipped_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_equipped_changed(item: ItemData) -> void:
	var hand: Node3D = $Head/Camera/HeldItem
	for child in hand.get_children():
		child.queue_free()
	if item and item.held_scene:
		hand.add_child(item.held_scene.instantiate())

func _on_speed_up_triggered():
	GameControl.request_speed(GameClock.speed_multiplier * 2.0)

func _on_speed_down_triggered():
	GameControl.request_speed(GameClock.speed_multiplier / 2.0)

func _on_interact_triggered() -> void:
	if UIManager.top() != null:
		return
	var interactable := get_target_interactable()
	if interactable == null:
		return
	# An equipped item that satisfies an option runs it.
	var direct := interactable.get_direct_option(Equipment.equipped)
	if direct:
		interactable.interact(direct, self)
		return
	var menu := UIManager.push(INTERACTION_MENU)
	menu.setup(interactable, self)
	# The menu is driven by scroll and E, so keep looking around.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_target_interactable() -> Interactable:
	var ray: RayCast3D = $Head/Camera/InteractRay
	ray.force_raycast_update()
	var collider := ray.get_collider() as Node
	if collider == null:
		return null
	for child in collider.get_children():
		if child is Interactable:
			return child
	return null

func _unhandled_input(event: InputEvent) -> void:
	if UIManager.top() != null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var interactable := get_target_interactable()
	if interactable == null:
		return
	# An option matching the equipped item wins, else the only available option.
	var direct := interactable.get_direct_option(Equipment.equipped)
	if direct:
		interactable.interact(direct, self)
		return
	var available: Array[InteractionOption] = []
	for option in interactable.options:
		if interactable.is_available(option, Equipment.equipped):
			available.append(option)
	if available.size() == 1:
		interactable.interact(available[0], self)

func _unhandled_key_input(event: InputEvent) -> void:
	if UIManager.top() != null or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_0:
		Equipment.unequip()
	elif key >= KEY_1 and key <= KEY_9 and key - KEY_1 < debug_items.size():
		Equipment.equip(debug_items[key - KEY_1])

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
