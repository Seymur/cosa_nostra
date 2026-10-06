extends Control

@onready var tab_bar: TabBar = $ColorRect/MarginContainer/TabContainer.get_tab_bar()

func _ready() -> void:
	# 1. Reset the global tab bar cursor so it defaults to a regular arrow
	tab_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
