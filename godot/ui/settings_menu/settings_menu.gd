extends Control

@onready var tab_bar: TabBar = $ColorRect/MarginContainer/TabContainer.get_tab_bar()
@onready var language_stepper: StepperSelect = $ColorRect/MarginContainer/TabContainer/General/ScrollContainer/VBoxContainer/HBoxContainer/StepperSelect

var _locales: Array = Localization.LANGUAGES.keys()

func _ready() -> void:
	# 1. Reset the global tab bar cursor so it defaults to a regular arrow
	tab_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Tab titles default to node names; swap in keys (TabContainer auto-translates them).
	# var tabs: TabContainer = $ColorRect/MarginContainer/TabContainer
	# for i in tabs.get_tab_count():
	# 	tabs.set_tab_title(i, "SETTINGS_TAB_" + tabs.get_child(i).name.to_upper())

	language_stepper.set_items(PackedStringArray(Localization.LANGUAGES.values()), _current_locale_index())
	language_stepper.selected.connect(_on_language_selected)

func _current_locale_index() -> int:
	var current := TranslationServer.get_locale()
	var exact := _locales.find(current)
	if exact != -1:
		return exact
	# Fall back to the base language, e.g. "en_US" -> "en".
	return maxi(_locales.find(current.get_slice("_", 0)), 0)

func _on_language_selected(index: int) -> void:
	Localization.set_language(_locales[index])
