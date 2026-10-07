extends Node
## Applies the player's saved window mode and persists changes.

const SETTINGS_PATH := "user://settings.cfg"

## Selectable window modes, in menu order. Each entry is [DisplayServer mode, translation key].
const WINDOW_MODES := [
	[DisplayServer.WINDOW_MODE_WINDOWED, "SETTINGS_WINDOW_MODE_WINDOWED"],
	[DisplayServer.WINDOW_MODE_FULLSCREEN, "SETTINGS_WINDOW_MODE_FULLSCREEN"],
	[DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "SETTINGS_WINDOW_MODE_EXCLUSIVE"],
]

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: int = config.get_value("graphics", "window_mode", -1)
		if saved >= 0 and saved < WINDOW_MODES.size():
			_apply(saved)

## Index into WINDOW_MODES for the current window. Maximized counts as windowed.
func get_window_mode_index() -> int:
	var current := DisplayServer.window_get_mode()
	for i in WINDOW_MODES.size():
		if WINDOW_MODES[i][0] == current:
			return i
	return 0

func set_window_mode_index(index: int) -> void:
	if index < 0 or index >= WINDOW_MODES.size():
		push_warning("Invalid window mode index: %d" % index)
		return
	_apply(index)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("graphics", "window_mode", index)
	config.save(SETTINGS_PATH)

func _apply(index: int) -> void:
	DisplayServer.window_set_mode(WINDOW_MODES[index][0])
