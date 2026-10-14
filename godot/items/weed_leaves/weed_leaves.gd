class_name WeedLeaves
extends Equippable

func _ready() -> void:
	allows_interact_fallthrough = false
	outline_mesh = $RigidBody3D/Mesh/Outline
	body = $RigidBody3D
