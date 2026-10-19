extends CharacterBody3D

## Emitted when an item enters or leaves a hotbar slot.
signal hotbar_changed
## Emitted when an item enters or leaves an inventory slot.
signal inventory_changed
## Emitted when the selected hotbar slot changes.
signal selected_slot_changed(slot: int)

@export var default_mapping_context: GUIDEMappingContext;
@export var move_action: GUIDEAction;
@export var jump_action: GUIDEAction;
@export var look_action: GUIDEAction;
@export var speed_up_action: GUIDEAction;
@export var speed_down_action: GUIDEAction;
@export var crouch_action: GUIDEAction;
## Hold to run faster. Has no effect while crouching.
@export var sprint_action: GUIDEAction;
@export var drop_action: GUIDEAction;
## Fire to select the next / previous hotbar slot (mouse wheel).
@export var hotbar_next_action: GUIDEAction;
@export var hotbar_previous_action: GUIDEAction;
## The action that picks up a focused Equippable. Must also be in interaction_actions.
@export var interact_action: GUIDEAction;
## Actions forwarded to the focused interactable when they fire. The interactable
## decides what each one does.
@export var interaction_actions: Array[GUIDEAction];
## Items stowed in the hotbar at start, filling the item slots in order (slot 0 is
## the bare hands).
@export var starting_hotbar_item_paths: Array[NodePath]

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
## Backpack contents, null for an empty slot. Items here are stowed, never held.
var inventory: Array[Equippable] = []
var selected_slot := 0

## The two places an item can be kept. The hotbar counts as extra inventory.
enum ItemStore { HOTBAR, INVENTORY }

const HOTBAR_SIZE = 8
## Slot 0 never holds an item; selecting it leaves the hands empty.
const BARE_HANDS_SLOT = 0
const INVENTORY_SIZE = 40

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 4.5
const AIR_SPEED = 2.5
const AIR_ACCEL = 20.0
const DROP_SPEED = 2.0

const STAND_HEIGHT = 1.8
const CROUCH_HEIGHT = 1.0
const STAND_EYE_HEIGHT = 1.65
const CROUCH_EYE_HEIGHT = 0.95
const CROUCH_TRANSITION_SPEED = 10.0

var is_crouching := false
## True while a menu is open and the gameplay mapping contexts are disabled.
var _input_blocked := false

func _ready() -> void:
	add_to_group("player")
	hotbar.resize(HOTBAR_SIZE)
	inventory.resize(INVENTORY_SIZE)
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
	UIManager.screen_changed.connect(_on_screen_changed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_stow_starting_items.call_deferred()

# Deferred so the items have finished their own _ready (they set up `body` there).
func _stow_starting_items() -> void:
	for i in starting_hotbar_item_paths.size():
		var slot := BARE_HANDS_SLOT + 1 + i
		var item := get_node_or_null(starting_hotbar_item_paths[i]) as Equippable
		if slot >= HOTBAR_SIZE or item == null:
			continue
		hotbar[slot] = item
		item.stow(head)
	hotbar_changed.emit()

## Menus must not leak input into the game (scrolling, looking, clicking), so the
## gameplay mapping contexts are off while any screen is open.
func _on_screen_changed(top: Control) -> void:
	var blocked := top != null
	if blocked == _input_blocked:
		return
	_input_blocked = blocked
	if blocked:
		GUIDE.disable_mapping_context(default_mapping_context)
		if held_item and held_item.mapping_context:
			GUIDE.disable_mapping_context(held_item.mapping_context)
	else:
		GUIDE.enable_mapping_context(default_mapping_context)
		if held_item and held_item.mapping_context:
			GUIDE.enable_mapping_context(held_item.mapping_context, false, -1)

## While an item is held, its actions go to the focused interactable first as an
## item-specific interaction. If that is unhandled they fall back to a plain interact
## (when the item allows it), and otherwise reach the item. Without a held item they
## go to whatever is focused.
func _on_interaction_action_triggered(action: GUIDEAction) -> void:
	# More of the stack in hand can be picked up even while holding it.
	if held_item and action == interact_action and focused_interactable is Equippable and held_item.can_stack_with(focused_interactable):
		pick_up(focused_interactable)
		return
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

## First empty item slot, skipping the bare-hands slot. -1 when all are taken.
func _find_free_slot() -> int:
	for i in range(1, HOTBAR_SIZE):
		if hotbar[i] == null:
			return i
	return -1

## First empty inventory slot. -1 when all are taken.
func _find_free_inventory_slot() -> int:
	return inventory.find(null)

## The item kept at `index` of `container`, or null.
func get_item(container: ItemStore, index: int) -> Equippable:
	return _items_of(container)[index]

func _items_of(container: ItemStore) -> Array[Equippable]:
	return hotbar if container == ItemStore.HOTBAR else inventory

## Moves the item at the source slot to the target slot, swapping with whatever is
## there. The bare-hands slot can neither give nor receive items.
func move_item(from_container: ItemStore, from_index: int, to_container: ItemStore, to_index: int) -> void:
	if from_container == to_container and from_index == to_index:
		return
	if is_fixed_slot(from_container, from_index) or is_fixed_slot(to_container, to_index):
		return
	var from_items := _items_of(from_container)
	var to_items := _items_of(to_container)
	if from_items[from_index] == null:
		return
	var moved := from_items[from_index]
	var target := to_items[to_index]
	if target != null and target.can_stack_with(moved):
		var amount := mini(target.max_stack - target.stack_count, moved.stack_count)
		target.stack_count += amount
		moved.stack_count -= amount
		if moved.stack_count == 0:
			from_items[from_index] = null
			# Stows it if it was in the hand, before it goes away.
			_sync_hand()
			moved.queue_free()
		_emit_changed(from_container)
		_emit_changed(to_container)
		return
	from_items[from_index] = to_items[to_index]
	to_items[to_index] = moved
	_sync_hand()
	if from_container == ItemStore.HOTBAR or to_container == ItemStore.HOTBAR:
		hotbar_changed.emit()
	if from_container == ItemStore.INVENTORY or to_container == ItemStore.INVENTORY:
		inventory_changed.emit()

## True for the slot that never holds an item (the bare hands).
func is_fixed_slot(container: ItemStore, index: int) -> bool:
	return container == ItemStore.HOTBAR and index == BARE_HANDS_SLOT

## Makes the hand match the selected slot after items were rearranged: whatever was
## held is stowed and the slot's item, if any, is taken into the hand.
func _sync_hand() -> void:
	var wanted := hotbar[selected_slot]
	if wanted == held_item:
		return
	if held_item:
		_release_hand().stow(head)
	if wanted:
		_hold(wanted)

## Puts `item` into the selected hotbar slot (or the first free item slot, which then
## becomes selected) and holds it. When the hotbar is full it is stowed in the
## inventory instead, and does nothing when that is full too.
func pick_up(item: Equippable) -> void:
	if _merge_into_stack(item):
		return
	if held_item:
		return
	var slot := selected_slot
	if slot == BARE_HANDS_SLOT or hotbar[slot] != null:
		slot = _find_free_slot()
	if slot == -1:
		_stow_in_inventory(item)
		return
	hotbar[slot] = item
	if slot != selected_slot:
		selected_slot = slot
		selected_slot_changed.emit(slot)
	_hold(hotbar[slot])
	hotbar_changed.emit()

## Folds a picked-up `item` into a stack of the same kind that has room. Returns
## whether it did; the item node is then freed.
func _merge_into_stack(item: Equippable) -> bool:
	for container in [ItemStore.HOTBAR, ItemStore.INVENTORY]:
		var items := _items_of(container)
		for i in items.size():
			if is_fixed_slot(container, i) or items[i] == null or not items[i].can_stack_with(item):
				continue
			items[i].stack_count += 1
			set_focused_interactable(null)
			item.queue_free()
			_emit_changed(container)
			return true
	return false

func _emit_changed(container: ItemStore) -> void:
	if container == ItemStore.HOTBAR:
		hotbar_changed.emit()
	else:
		inventory_changed.emit()

func _stow_in_inventory(item: Equippable) -> void:
	var slot := _find_free_inventory_slot()
	if slot == -1:
		return
	inventory[slot] = item
	item.stow(head)
	set_focused_interactable(null)
	inventory_changed.emit()

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
	# While a menu is open the context is enabled once the menu closes instead.
	if item.mapping_context and not _input_blocked:
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
	if held_item.stack_count > 1:
		held_item.drop_one(get_parent(), camera.global_transform, -camera.global_basis.z * DROP_SPEED + velocity)
		hotbar_changed.emit()
		return
	var item := _release_hand()
	hotbar[selected_slot] = null
	item.drop(get_parent(), camera.global_transform, -camera.global_basis.z * DROP_SPEED + velocity)
	hotbar_changed.emit()

## Removes the held item from the game, e.g. once it was used up by being placed.
func consume_held() -> void:
	if not held_item:
		return
	if held_item.stack_count > 1:
		held_item.stack_count -= 1
		hotbar_changed.emit()
		return
	var item := _release_hand()
	hotbar[selected_slot] = null
	item.queue_free()
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
	if focused_interactable and _can_show_outline(focused_interactable):
		focused_interactable.show_outline()

# An item whose click never interacts shouldn't make interactables look clickable,
# except more of the stack in hand, which can still be picked up.
func _can_show_outline(interactable: Interactable) -> bool:
	return held_item == null or held_item.allows_interact_fallthrough or (interactable is Equippable and held_item.can_stack_with(interactable))

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
	var speed := SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif sprint_action.is_triggered() and is_on_floor():
		speed = SPRINT_SPEED
	if not is_on_floor():
		# Lower top speed in the air: steer toward it and cap horizontal speed.
		var horizontal := Vector3(velocity.x, 0, velocity.z)
		horizontal = horizontal.move_toward(direction * AIR_SPEED, AIR_ACCEL * delta)
		horizontal = horizontal.limit_length(maxf(AIR_SPEED, 0.0))
		velocity.x = horizontal.x
		velocity.z = horizontal.z
	elif direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
