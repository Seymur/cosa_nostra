extends Control

const BUTTONS := "ColorRect/VBoxContainer/VBoxContainer/"

func _ready() -> void:
	get_node(BUTTONS + "Resume").pressed.connect(UIManager.pop)
	get_node(BUTTONS + "Settings").pressed.connect(_on_settings_pressed)
	get_node(BUTTONS + "ExitToDesktop").pressed.connect(get_tree().quit)

func _on_settings_pressed() -> void:
	UIManager.push(UIManager.SETTINGS)
