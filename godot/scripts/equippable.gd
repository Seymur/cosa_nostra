class_name Equippable
extends Interactable

## Mapping context enabled by the player while this item is held. Bind the
## item's own actions here; inputs shared with the default context (e.g. left
## click) are taken over from it.
@export var mapping_context: GUIDEMappingContext
## Placement relative to the holder (the player's head) while held.
@export var held_position := Vector3(0.3, -0.3, -0.6)
@export var held_rotation_degrees := Vector3(-70, 0, 0)
@export var body: RigidBody3D
## When true, a click on a focused interactable that has no item-specific
## reaction interacts with it as if nothing were held. Set false for items
## (e.g. a gun) whose click should always go to the item.
@export var allows_interact_fallthrough := true
## Name shown for this item in the hotbar.
@export var display_name := ""
## Icon shown for this item in the hotbar. The name is shown instead when unset.
@export var icon: Texture2D

## How many of this item fit in one slot. 1 means the item does not stack. Only
## stateless items should stack: extras are folded into `stack_count` and respawned
## from the scene on drop.
@export var max_stack := 1

## How many items this node stands for in its slot.
var stack_count := 1

var _saved_layer: int
var _saved_mask: int
var _is_carried := false

## True when `other` can be folded into this stack: the same stackable item and
## room left.
func can_stack_with(other: Equippable) -> bool:
	return other != self and max_stack > 1 and stack_count < max_stack 		and scene_file_path != "" and other.scene_file_path == scene_file_path

## Throws one item of the stack into the world, leaving the stack one smaller.
func drop_one(world: Node, from: Transform3D, impulse: Vector3) -> void:
	var copy := load(scene_file_path).instantiate() as Equippable
	world.add_child(copy)
	copy.global_transform = from
	copy.body.linear_velocity = impulse
	stack_count -= 1

## Takes the item into the holder's hand.
func equip(holder: Node3D) -> void:
	_carry(holder)
	visible = true
	position = held_position
	rotation_degrees = held_rotation_degrees

## Keeps the item on the holder but out of sight and out of the world, e.g. while it
## sits in an unselected hotbar slot.
func stow(holder: Node3D) -> void:
	_carry(holder)
	visible = false

func _carry(holder: Node3D) -> void:
	hide_outline()
	if not _is_carried:
		_is_carried = true
		_saved_layer = body.collision_layer
		_saved_mask = body.collision_mask
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
	reparent(holder, false)
	# The body simulates independently of this root, so it may have fallen away from it.
	body.transform = Transform3D.IDENTITY

func drop(world: Node, from: Transform3D, impulse: Vector3) -> void:
	_is_carried = false
	visible = true
	reparent(world, false)
	global_transform = from
	body.collision_layer = _saved_layer
	body.collision_mask = _saved_mask
	body.freeze = false
	body.linear_velocity = impulse
