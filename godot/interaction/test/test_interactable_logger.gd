extends Node
## Test helper: prints interactions of the sibling Interactable.

func _ready() -> void:
	get_parent().get_node("Interactable").interacted.connect(_on_interacted)

func _on_interacted(option: InteractionOption, interactor: Node) -> void:
	print("%s interacted: %s" % [interactor.name, option.id])
