class_name WateringCan
extends Equippable

## Pressed while a planted planter is focused to water it.
@export var primary_action: GUIDEAction

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
