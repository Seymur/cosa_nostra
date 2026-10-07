class_name Interactable
extends Node
## Add as a child of a body (physics layer 2) to make it interactable. The
## owner connects to `interacted` and implements the behaviour.

signal interacted(option: InteractionOption, interactor: Node)

@export var options: Array[InteractionOption] = []
## Translation key shown in the crosshair prompt.
@export var display_name: String

## First option that requires `item`, or null. Such an option runs directly,
## without opening the menu.
func get_direct_option(item: ItemData) -> InteractionOption:
	if item == null:
		return null
	for option in options:
		if option.required_item == item:
			return option
	return null

func is_available(option: InteractionOption, item: ItemData) -> bool:
	return option.required_item == null or option.required_item == item

func interact(option: InteractionOption, interactor: Node) -> void:
	interacted.emit(option, interactor)
