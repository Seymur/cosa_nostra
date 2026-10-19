class_name WeedSeed
extends Equippable

## Pressed while a planter is focused to plant this seed.
@export var primary_action: GUIDEAction

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
