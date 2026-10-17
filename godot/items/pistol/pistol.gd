class_name Pistol
extends Equippable

## Fired by the left click while the pistol is held.
@export var primary_action: GUIDEAction

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D

func on_action(action: GUIDEAction) -> void:
	if action == primary_action:
		print("Pistol fire")
