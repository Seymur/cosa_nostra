class_name ItemPickup
extends StaticBody3D
## An item lying in the world. Interacting equips it and removes the pickup.

@export var item: ItemData

func _ready() -> void:
	if item.world_scene:
		add_child(item.world_scene.instantiate())
	$Interactable.display_name = item.display_name
	$Interactable.interacted.connect(_on_interacted)

func _on_interacted(_option: InteractionOption, _interactor: Node) -> void:
	Equipment.equip(item)
	queue_free()
