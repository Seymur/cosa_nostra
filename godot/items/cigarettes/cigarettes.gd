class_name Cigarettes
extends Equippable

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
