extends Control

@onready var tab_bar: TabBar = $ColorRect/MarginContainer/TabContainer.get_tab_bar()
@onready var language_stepper: StepperSelect = $ColorRect/MarginContainer/TabContainer/General/ScrollContainer/VBoxContainer/HBoxContainer/StepperSelect
@onready var window_mode_stepper: StepperSelect = $ColorRect/MarginContainer/TabContainer/Graphics/ScrollContainer/VBoxContainer/HBoxContainer/StepperSelect

var _locales: Array = Localization.LANGUAGES.keys()

func _ready() -> void:
	# 1. Reset the global tab bar cursor so it defaults to a regular arrow
	tab_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	language_stepper.set_items(PackedStringArray(Localization.LANGUAGES.values()), _current_locale_index())
	language_stepper.selected.connect(_on_language_selected)

	_refresh_window_mode_items()
	window_mode_stepper.selected.connect(DisplaySettings.set_window_mode_index)
	Localization.language_changed.connect(_refresh_window_mode_items.unbind(1))

func _refresh_window_mode_items() -> void:
	var names := PackedStringArray()
	for mode in DisplaySettings.WINDOW_MODES:
		names.append(tr(mode[1]))
	window_mode_stepper.set_items(names, DisplaySettings.get_window_mode_index())

func _current_locale_index() -> int:
	var current := TranslationServer.get_locale()
	var exact := _locales.find(current)
	if exact != -1:
		return exact
	# Fall back to the base language, e.g. "en_US" -> "en".
	return maxi(_locales.find(current.get_slice("_", 0)), 0)

func _on_language_selected(index: int) -> void:
	Localization.set_language(_locales[index])
