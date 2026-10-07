extends Node
## Applies the player's saved window mode and persists changes.

const SETTINGS_PATH := "user://settings.cfg"

## Selectable window modes, in menu order. Each entry is [DisplayServer mode, translation key].
const WINDOW_MODES := [
	[DisplayServer.WINDOW_MODE_WINDOWED, "SETTINGS_WINDOW_MODE_WINDOWED"],
	[DisplayServer.WINDOW_MODE_FULLSCREEN, "SETTINGS_WINDOW_MODE_FULLSCREEN"],
	[DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "SETTINGS_WINDOW_MODE_EXCLUSIVE"],
]

## Selectable windowed-mode resolutions, in menu order.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _resolution_index := 0

func _ready() -> void:
	_resolution_index = _closest_resolution_index(Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_res: int = config.get_value("graphics", "resolution", -1)
		if saved_res >= 0 and saved_res < RESOLUTIONS.size():
			_resolution_index = saved_res
		var saved: int = config.get_value("graphics", "window_mode", -1)
		if saved >= 0 and saved < WINDOW_MODES.size():
			_apply(saved)
		elif saved_res >= 0:
			_apply_resolution()

func get_resolution_index() -> int:
	return _resolution_index

func set_resolution_index(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		push_warning("Invalid resolution index: %d" % index)
		return
	_resolution_index = index
	_apply_resolution()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("graphics", "resolution", index)
	config.save(SETTINGS_PATH)

func _closest_resolution_index(size: Vector2i) -> int:
	var best := 0
	for i in RESOLUTIONS.size():
		if absi(RESOLUTIONS[i].x - size.x) < absi(RESOLUTIONS[best].x - size.x):
			best = i
	return best

## Resizing only makes sense in a regular window; fullscreen modes ignore it.
func _apply_resolution() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var size := RESOLUTIONS[_resolution_index]
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	@warning_ignore("integer_division")
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)

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
	_apply_resolution()
