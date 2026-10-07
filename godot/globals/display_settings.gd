extends Node
## Applies the player's saved graphics settings (window, frame pacing, quality) and persists changes.

## Emitted after any quality setting or preset changes, so menus can refresh dependent rows.
signal quality_changed
## Emitted when a quality setting changes. WorldEnvironment nodes listen to this.
signal environment_changed

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

## Selectable vsync modes, in menu order.
const VSYNC_MODES := [
	DisplayServer.VSYNC_DISABLED,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_ADAPTIVE,
	DisplayServer.VSYNC_MAILBOX,
]
const DEFAULT_VSYNC_INDEX := 1

## Selectable frame rate caps, in menu order. 0 means unlimited.
const FPS_CAPS: Array[int] = [30, 60, 120, 144, 0]
const DEFAULT_FPS_CAP_INDEX := 4

## Quality settings, in the order presets list their values. Each value is an index into
## the matching option list below (or 0 = off / 1 = on for the toggles).
const QUALITY_KEYS := ["msaa", "ssaa", "taa", "render_scale", "shadows", "glow", "ssao", "ssr"]
const QUALITY_OPTION_COUNTS := {
	"msaa": 4, "ssaa": 3, "taa": 2, "render_scale": 5,
	"shadows": 3, "glow": 2, "ssao": 2, "ssr": 2,
}

const MSAA_MODES := [
	Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X,
]
const SCREEN_SPACE_AA_MODES := [
	Viewport.SCREEN_SPACE_AA_DISABLED, Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_SMAA,
]
const RENDER_SCALES: Array[float] = [0.5, 0.67, 0.75, 0.85, 1.0]
## Shadow atlas size and soft-shadow filter per shadows level (Low, Medium, High).
const SHADOW_ATLAS_SIZES: Array[int] = [1024, 2048, 4096]
const SHADOW_FILTERS := [
	RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
]

## Quality presets, in menu order: Low, Medium, High. Values follow QUALITY_KEYS.
## Settings that match none of them show as Custom.
const QUALITY_PRESETS := [
	[0, 0, 0, 2, 0, 0, 0, 0],
	[1, 1, 0, 4, 1, 1, 0, 0],
	[3, 2, 1, 4, 2, 1, 1, 0],
]
const DEFAULT_PRESET := 2

var _resolution_index := 0
var _vsync_index := DEFAULT_VSYNC_INDEX
var _fps_cap_index := DEFAULT_FPS_CAP_INDEX
var _show_fps := false
var _quality := {}
var _fps_overlay: CanvasLayer
var _fps_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fps_overlay()
	_resolution_index = _closest_resolution_index(Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")))
	_set_quality_from_preset(DEFAULT_PRESET)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_res: int = config.get_value("graphics", "resolution", -1)
		if saved_res >= 0 and saved_res < RESOLUTIONS.size():
			_resolution_index = saved_res
		_vsync_index = _saved_index(config, "vsync", VSYNC_MODES.size(), DEFAULT_VSYNC_INDEX)
		_fps_cap_index = _saved_index(config, "fps_cap", FPS_CAPS.size(), DEFAULT_FPS_CAP_INDEX)
		_show_fps = config.get_value("graphics", "show_fps", false)
		for key in QUALITY_KEYS:
			_quality[key] = _saved_index(config, "q_" + key, QUALITY_OPTION_COUNTS[key], _quality[key])
		var saved_monitor: int = config.get_value("graphics", "monitor", -1)
		if saved_monitor >= 0 and saved_monitor < DisplayServer.get_screen_count():
			DisplayServer.window_set_current_screen(saved_monitor)
		var saved: int = config.get_value("graphics", "window_mode", -1)
		if saved >= 0 and saved < WINDOW_MODES.size():
			_apply(saved)
		elif saved_res >= 0:
			_apply_resolution()
	_apply_vsync()
	_apply_fps_cap()
	_apply_show_fps()
	_apply_quality()

func _saved_index(config: ConfigFile, key: String, count: int, fallback: int) -> int:
	var value: int = config.get_value("graphics", key, fallback)
	return value if value >= 0 and value < count else fallback

func _save(key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("graphics", key, value)
	config.save(SETTINGS_PATH)

func get_resolution_index() -> int:
	return _resolution_index

func set_resolution_index(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		push_warning("Invalid resolution index: %d" % index)
		return
	_resolution_index = index
	_apply_resolution()
	_save("resolution", index)

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
	_save("window_mode", index)

func _apply(index: int) -> void:
	DisplayServer.window_set_mode(WINDOW_MODES[index][0])
	_apply_resolution()

## One entry per connected screen, e.g. "1 (1920 x 1080)".
func get_monitor_names() -> PackedStringArray:
	var names := PackedStringArray()
	for i in DisplayServer.get_screen_count():
		var size := DisplayServer.screen_get_size(i)
		names.append("%d (%d x %d)" % [i + 1, size.x, size.y])
	return names

func get_monitor_index() -> int:
	return DisplayServer.window_get_current_screen()

func set_monitor_index(index: int) -> void:
	if index < 0 or index >= DisplayServer.get_screen_count():
		push_warning("Invalid monitor index: %d" % index)
		return
	DisplayServer.window_set_current_screen(index)
	_apply_resolution()
	_save("monitor", index)

func get_vsync_index() -> int:
	return _vsync_index

func set_vsync_index(index: int) -> void:
	if index < 0 or index >= VSYNC_MODES.size():
		push_warning("Invalid vsync index: %d" % index)
		return
	_vsync_index = index
	_apply_vsync()
	_save("vsync", index)

func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(VSYNC_MODES[_vsync_index])

func get_fps_cap_index() -> int:
	return _fps_cap_index

func set_fps_cap_index(index: int) -> void:
	if index < 0 or index >= FPS_CAPS.size():
		push_warning("Invalid FPS cap index: %d" % index)
		return
	_fps_cap_index = index
	_apply_fps_cap()
	_save("fps_cap", index)

func _apply_fps_cap() -> void:
	Engine.max_fps = FPS_CAPS[_fps_cap_index]

## 0 = hidden, 1 = shown.
func get_show_fps_index() -> int:
	return int(_show_fps)

func set_show_fps_index(index: int) -> void:
	_show_fps = index == 1
	_apply_show_fps()
	_save("show_fps", _show_fps)

func _apply_show_fps() -> void:
	_fps_overlay.visible = _show_fps
	set_process(_show_fps)

func _build_fps_overlay() -> void:
	_fps_overlay = CanvasLayer.new()
	_fps_overlay.layer = 128
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 4)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_overlay.add_child(_fps_label)
	add_child(_fps_overlay)

func _process(_delta: float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

## Current value (an option index) for one of QUALITY_KEYS.
func get_quality_value(key: String) -> int:
	return _quality[key]

func set_quality_value(index: int, key: String) -> void:
	if not QUALITY_OPTION_COUNTS.has(key) or index < 0 or index >= QUALITY_OPTION_COUNTS[key]:
		push_warning("Invalid quality setting: %s = %d" % [key, index])
		return
	_quality[key] = index
	_save("q_" + key, index)
	_apply_quality()

## Index into QUALITY_PRESETS matching the current settings, or QUALITY_PRESETS.size() for Custom.
func get_preset_index() -> int:
	for i in QUALITY_PRESETS.size():
		if _matches_preset(i):
			return i
	return QUALITY_PRESETS.size()

## Picking Custom (the entry past the last preset) leaves the current values alone.
func set_preset_index(index: int) -> void:
	if index < 0 or index > QUALITY_PRESETS.size():
		push_warning("Invalid quality preset index: %d" % index)
		return
	if index == QUALITY_PRESETS.size():
		return
	_set_quality_from_preset(index)
	for key in QUALITY_KEYS:
		_save("q_" + key, _quality[key])
	_apply_quality()

func _matches_preset(preset: int) -> bool:
	for i in QUALITY_KEYS.size():
		if _quality[QUALITY_KEYS[i]] != QUALITY_PRESETS[preset][i]:
			return false
	return true

func _set_quality_from_preset(preset: int) -> void:
	for i in QUALITY_KEYS.size():
		_quality[QUALITY_KEYS[i]] = QUALITY_PRESETS[preset][i]

func is_glow_enabled() -> bool:
	return _quality["glow"] == 1

func is_ssao_enabled() -> bool:
	return _quality["ssao"] == 1

func is_ssr_enabled() -> bool:
	return _quality["ssr"] == 1

func _apply_quality() -> void:
	var root := get_viewport()
	root.msaa_2d = MSAA_MODES[_quality["msaa"]]
	root.msaa_3d = MSAA_MODES[_quality["msaa"]]
	root.screen_space_aa = SCREEN_SPACE_AA_MODES[_quality["ssaa"]]
	root.use_taa = _quality["taa"] == 1
	root.scaling_3d_scale = RENDER_SCALES[_quality["render_scale"]]
	var shadows: int = _quality["shadows"]
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZES[shadows], true)
	root.positional_shadow_atlas_size = SHADOW_ATLAS_SIZES[shadows]
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTERS[shadows])
	RenderingServer.positional_soft_shadow_filter_set_quality(SHADOW_FILTERS[shadows])
	quality_changed.emit()
	environment_changed.emit()
