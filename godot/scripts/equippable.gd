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

var _saved_layer: int
var _saved_mask: int

func equip(holder: Node3D) -> void:
	hide_outline()
	_saved_layer = body.collision_layer
	_saved_mask = body.collision_mask
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	reparent(holder, false)
	position = held_position
	rotation_degrees = held_rotation_degrees

func drop(world: Node, from: Transform3D, impulse: Vector3) -> void:
	reparent(world, false)
	global_transform = from
	body.collision_layer = _saved_layer
	body.collision_mask = _saved_mask
	body.freeze = false
	body.linear_velocity = impulse
