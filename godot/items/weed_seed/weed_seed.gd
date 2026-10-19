class_name WeedSeed
extends Equippable

## Pressed while a planter is focused to plant this seed.
@export var primary_action: GUIDEAction

## Seeds left in the pouch. The pouch is used up when the last one is planted.
@export var seed_count := 10

func get_display_count() -> int:
	return seed_count

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
