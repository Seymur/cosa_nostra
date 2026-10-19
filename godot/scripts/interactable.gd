class_name Interactable
extends Node3D

## Visual layer (1-based, as shown in the project settings) the outline mask camera renders.
const OUTLINE_LAYER := 20

var _outline_meshes: Array[MeshInstance3D] = []

## Puts every mesh of this interactable on the outline layer, in addition to the
## normal one, so the screen-space outline effect draws a border around it.
func show_outline():
	_outline_meshes.clear()
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.set_layer_mask_value(OUTLINE_LAYER, true)
		_outline_meshes.append(mesh)
	OutlineMask.active = true

func hide_outline():
	for mesh in _outline_meshes:
		if is_instance_valid(mesh):
			mesh.set_layer_mask_value(OUTLINE_LAYER, false)
	_outline_meshes.clear()
	OutlineMask.active = false

## Called by the player when one of its interaction actions fires while this
## interactable is focused. Override and compare `action` against your own
## exported actions to decide what it does.
func on_action(action: GUIDEAction) -> void:
	pass

## Whether `item` can currently be used on this interactable through
## `on_item_action`. Controls whether it is highlighted while that item is held.
func accepts_item(item: Interactable) -> bool:
	return false

## Text shown in the HUD while this interactable is focused, given the item in hand
## (or null). Empty shows nothing.
func get_hud_text(held: Equippable) -> String:
	return ""

## Called when a held item's action fires while this interactable is focused.
## Return true to handle it with an item-specific interaction; when false the
## player falls back to the plain interact action, as if nothing were held.
func on_item_action(item: Interactable, action: GUIDEAction) -> bool:
	return false
