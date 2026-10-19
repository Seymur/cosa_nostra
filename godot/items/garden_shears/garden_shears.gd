class_name GardenShears
extends Equippable

## Pressed while a fully grown plant is focused to harvest it.
@export var primary_action: GUIDEAction

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
