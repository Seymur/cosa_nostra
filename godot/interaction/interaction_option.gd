class_name InteractionOption
extends Resource
## One thing the player can do to an Interactable.

@export var id: StringName
## Translation key.
@export var label: String
## Item that must be equipped to run this option. Null means no item is needed.
@export var required_item: ItemData
