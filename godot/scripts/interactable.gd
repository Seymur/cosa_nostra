class_name Interactable
extends Node

var outline_mesh: Node3D

func show_outline():
	if outline_mesh:
		outline_mesh.visible = true

func hide_outline():
	if outline_mesh:
		outline_mesh.visible = false

## Called by the player when one of its interaction actions fires while this
## interactable is focused. Override and compare `action` against your own
## exported actions to decide what it does.
func on_action(action: GUIDEAction) -> void:
	pass
