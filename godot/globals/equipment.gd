extends Node
## Currently equipped item. Placeholder until a real inventory exists.

signal equipped_changed(item: ItemData)

var equipped: ItemData

func equip(item: ItemData) -> void:
	if item == equipped:
		return
	equipped = item
	equipped_changed.emit(item)

func unequip() -> void:
	equip(null)
