class_name Equippable
extends Node3D

@onready var _outline: MeshInstance3D = $RigidBody3D/Mesh/Outline

@onready var _body: RigidBody3D = $RigidBody3D

var _held := false
var _saved_collision_layer := 0
var _saved_collision_mask := 0

# A frozen RigidBody3D does not reliably follow its parent, so while held the body is
# explicitly kept at the Equippable root's pose.
func _process(_delta: float) -> void:
	if _held:
		_body.global_transform = global_transform

# Stops physics and collision so the item can be carried without falling or blocking the player.
# Note: the RigidBody3D simulates in world space, so the Equippable root stays where it was
# placed while the body moves away from it; the player controller then positions the root.
func hold() -> void:
	_saved_collision_layer = _body.collision_layer
	_saved_collision_mask = _body.collision_mask
	_body.freeze = true
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.linear_velocity = Vector3.ZERO
	_body.angular_velocity = Vector3.ZERO
	# Physics moved the body away from the Equippable root; snap it back.
	_body.transform = Transform3D.IDENTITY
	_held = true

# Gives physics back to the item and launches it. Call after reparenting it into the world.
func release(launch_velocity: Vector3) -> void:
	_held = false
	_body.collision_layer = _saved_collision_layer
	_body.collision_mask = _saved_collision_mask
	_body.freeze = false
	_body.sleeping = false
	_body.linear_velocity = launch_velocity

func set_outlined(value: bool) -> void:
	_outline.visible = value
