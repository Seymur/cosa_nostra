class_name Crowbar
extends Equippable

## Fired by the left click while the crowbar is held.
@export var primary_action: GUIDEAction

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D

func on_action(action: GUIDEAction) -> void:
	if action == primary_action:
		print("Crowbar swing")
