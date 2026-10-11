extends CharacterBody3D

## Emitted when an item enters or leaves a hotbar slot.
signal hotbar_changed
## Emitted when the selected hotbar slot changes.
signal selected_slot_changed(slot: int)

@export var default_mapping_context: GUIDEMappingContext;
@export var move_action: GUIDEAction;
@export var jump_action: GUIDEAction;
@export var look_action: GUIDEAction;
@export var speed_up_action: GUIDEAction;
@export var speed_down_action: GUIDEAction;
@export var crouch_action: GUIDEAction;
@export var drop_action: GUIDEAction;
## Fire to select the next / previous hotbar slot (mouse wheel).
@export var hotbar_next_action: GUIDEAction;
@export var hotbar_previous_action: GUIDEAction;
## The action that picks up a focused Equippable. Must also be in interaction_actions.
@export var interact_action: GUIDEAction;
## Actions forwarded to the focused interactable when they fire. The interactable
## decides what each one does.
@export var interaction_actions: Array[GUIDEAction];

@export_group("Mouse")
@export var horizontal_sensitivity = 0.1
@export var vertical_sensitivity = 0.1

@onready var head: Node3D = $Head
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $Head/Camera
@onready var shape_cast_3d: ShapeCast3D = $Head/Camera/ShapeCast3D

var focused_interactable: Interactable
## The item in the hand, which is always the one in the selected hotbar slot.
var held_item: Equippable
## Quick-slot contents, null for an empty slot.
var hotbar: Array[Equippable] = []
var selected_slot := 0

const HOTBAR_SIZE = 5

const SPEED = 5.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 4.5
const DROP_SPEED = 2.0

const STAND_HEIGHT = 1.8
const CROUCH_HEIGHT = 1.0
const STAND_EYE_HEIGHT = 1.65
const CROUCH_EYE_HEIGHT = 0.95
const CROUCH_TRANSITION_SPEED = 10.0

var is_crouching := false

func _ready() -> void:
	add_to_group("player")
	hotbar.resize(HOTBAR_SIZE)
	shape_cast_3d.add_exception(self)
	GUIDE.enable_mapping_context(default_mapping_context)
	look_action.triggered.connect(_on_look_triggered)
	speed_up_action.triggered.connect(_on_speed_up_triggered)
	speed_down_action.triggered.connect(_on_speed_down_triggered)
	for action in interaction_actions:
		action.just_triggered.connect(_on_interaction_action_triggered.bind(action))
	drop_action.just_triggered.connect(unequip)
	hotbar_next_action.just_triggered.connect(select_slot_relative.bind(1))
	hotbar_previous_action.just_triggered.connect(select_slot_relative.bind(-1))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## While an item is held, its actions go to the focused interactable first as an
## item-specific interaction. If that is unhandled they fall back to a plain interact
## (when the item allows it), and otherwise reach the item. Without a held item they
## go to whatever is focused.
func _on_interaction_action_triggered(action: GUIDEAction) -> void:
	if held_item:
		var target: Interactable = focused_interactable if is_instance_valid(focused_interactable) else null
		if target and target.on_item_action(held_item, action):
			return
		if target and held_item.allows_interact_fallthrough:
			target.on_action(interact_action)
		else:
			held_item.on_action(action)
	elif action == interact_action and focused_interactable is Equippable:
		pick_up(focused_interactable)
	elif is_instance_valid(focused_interactable):
		focused_interactable.on_action(action)

## Puts `item` into the selected hotbar slot (or the first free one, which then
## becomes selected) and holds it. Does nothing when the hotbar is full.
func pick_up(item: Equippable) -> void:
	if held_item:
		return
	var slot := selected_slot if hotbar[selected_slot] == null else hotbar.find(null)
	if slot == -1:
		return
	hotbar[slot] = item
	if slot != selected_slot:
		selected_slot = slot
		selected_slot_changed.emit(slot)
	_hold(hotbar[slot])
	hotbar_changed.emit()

## Selects `slot`, wrapping around the hotbar, and holds its item if it has one.
## Whatever was held goes back into its slot.
func select_slot(slot: int) -> void:
	slot = posmod(slot, HOTBAR_SIZE)
	if slot == selected_slot:
		return
	if held_item:
		var previous := _release_hand()
		previous.stow(head)
	selected_slot = slot
	if hotbar[slot]:
		_hold(hotbar[slot])
	selected_slot_changed.emit(slot)

func select_slot_relative(step: int) -> void:
	select_slot(selected_slot + step)

## Holds `item` and enables its mapping context above the default one, so the
## inputs it binds (e.g. left click) fire the item's actions instead.
func _hold(item: Equippable) -> void:
	set_focused_interactable(null)
	held_item = item
	item.equip(head)
	if item.mapping_context:
		GUIDE.enable_mapping_context(item.mapping_context, false, -1)

## Empties the hand and disables the item's mapping context. Returns the item.
func _release_hand() -> Equippable:
	var item := held_item
	held_item = null
	# Refocus next physics frame so the outline reappears if it was suppressed.
	set_focused_interactable(null)
	if item.mapping_context:
		GUIDE.disable_mapping_context(item.mapping_context)
	return item

## Drops the held item into the world and frees its hotbar slot.
func unequip() -> void:
	if not held_item:
		return
	var item := _release_hand()
	hotbar[selected_slot] = null
	item.drop(get_parent(), camera.global_transform, -camera.global_basis.z * DROP_SPEED + velocity)
	hotbar_changed.emit()

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
	if focused_interactable and _can_show_outline():
		focused_interactable.show_outline()

# An item whose click never interacts shouldn't make interactables look clickable.
func _can_show_outline() -> bool:
	return held_item == null or held_item.allows_interact_fallthrough

## Crouching is hold-to-crouch. Standing back up is blocked while something is
## directly overhead.
func _update_crouch(delta: float) -> void:
	var wants_crouch := crouch_action.is_triggered()
	if wants_crouch:
		is_crouching = true
	elif is_crouching and _can_stand_up():
		is_crouching = false

	var height := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule.height != height:
		capsule.height = height
		collision_shape.position.y = height * 0.5

	var eye_height := CROUCH_EYE_HEIGHT if is_crouching else STAND_EYE_HEIGHT
	head.position.y = move_toward(head.position.y, eye_height, CROUCH_TRANSITION_SPEED * delta)

func _can_stand_up() -> bool:
	return not test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT))

func _physics_process(delta: float) -> void:
	set_focused_interactable(find_closest_interactable())
	_update_crouch(delta)

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if jump_action.is_triggered() and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var input_dir := move_action.value_axis_2d
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := CROUCH_SPEED if is_crouching else SPEED
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
