class_name Removable
extends Interactable

## Hold this action on the focused prop to pick it up into the hotbar.
@export var remove_action: GUIDEAction
## Item scene the prop turns into. A path rather than a PackedScene because the item
## usually instances this prop as its visual, which would be a cyclic reference.
@export_file("*.tscn") var item_scene_path := ""

func on_action(action: GUIDEAction) -> void:
	if action == remove_action:
		_remove()

# Handled while holding something too, so the hold never falls through to the held item.
func on_item_action(item: Interactable, action: GUIDEAction) -> bool:
	return action == remove_action

func _remove() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.held_item != null or item_scene_path.is_empty():
		return
	var world := get_parent()
	var item := (load(item_scene_path) as PackedScene).instantiate() as Equippable
	world.add_child(item)
	item.global_transform = global_transform
	player.pick_up(item)
	# Nowhere to put it (hotbar and inventory full): leave the prop where it is.
	if item.get_parent() == world:
		item.queue_free()
		return
	queue_free()
