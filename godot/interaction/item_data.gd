class_name ItemData
extends Resource
## Static description of an item that can be equipped.

@export var id: StringName
## Translation key.
@export var display_name: String
## Scene shown in the player's hand while equipped.
@export var held_scene: PackedScene
## Scene shown when the item lies in the world.
@export var world_scene: PackedScene
