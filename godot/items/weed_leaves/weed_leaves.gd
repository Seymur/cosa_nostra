class_name WeedLeaves
extends Equippable

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
