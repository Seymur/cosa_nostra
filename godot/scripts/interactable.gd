class_name Interactable
extends Node3D

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

## Called when a held item's action fires while this interactable is focused.
## Return true to handle it with an item-specific interaction; when false the
## player falls back to the plain interact action, as if nothing were held.
func on_item_action(item: Interactable, action: GUIDEAction) -> bool:
	return false
