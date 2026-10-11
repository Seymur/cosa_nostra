class_name Crowbar
extends Equippable

## Fired by the left click while the crowbar is held.
@export var primary_action: GUIDEAction

func _ready() -> void:
	outline_mesh = $RigidBody3D/Mesh/Outline
	body = $RigidBody3D

func on_action(action: GUIDEAction) -> void:
	if action == primary_action:
		print("Crowbar swing")
