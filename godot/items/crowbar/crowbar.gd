class_name Crowbar
extends Equippable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	outline_mesh = $RigidBody3D/Mesh/Outline

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
