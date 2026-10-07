extends Control

@onready var tab_bar: TabBar = $ColorRect/MarginContainer/TabContainer.get_tab_bar()
@onready var language_stepper: StepperSelect = $ColorRect/MarginContainer/TabContainer/General/ScrollContainer/VBoxContainer/HBoxContainer/StepperSelect
@onready var window_mode_stepper: StepperSelect = $ColorRect/MarginContainer/TabContainer/Graphics/ScrollContainer/VBoxContainer/HBoxContainer/StepperSelect

@onready var resolution_stepper: StepperSelect = $ColorRect/MarginContainer/TabContainer/Graphics/ScrollContainer/VBoxContainer/ResolutionRow/StepperSelect
@onready var graphics_box: VBoxContainer = $ColorRect/MarginContainer/TabContainer/Graphics/ScrollContainer/VBoxContainer

const STEPPER_SCENE := preload("res://ui/widgets/stepper_select/stepper_select.tscn")

## Rows added from code. Each entry is [StepperSelect, items Callable, index Callable];
## the callables are re-read whenever the language or a dependent setting changes.
var _rows: Array = []

var _locales: Array = Localization.LANGUAGES.keys()

func _ready() -> void:
	# 1. Reset the global tab bar cursor so it defaults to a regular arrow
	tab_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	language_stepper.set_items(PackedStringArray(Localization.LANGUAGES.values()), _current_locale_index())
	language_stepper.selected.connect(_on_language_selected)

	_refresh_window_mode_items()
	window_mode_stepper.selected.connect(DisplaySettings.set_window_mode_index)
	Localization.language_changed.connect(_refresh_window_mode_items.unbind(1))

	var res_names := PackedStringArray()
	for res in DisplaySettings.RESOLUTIONS:
		res_names.append("%d x %d" % [res.x, res.y])
	resolution_stepper.set_items(res_names, DisplaySettings.get_resolution_index())
	resolution_stepper.selected.connect(DisplaySettings.set_resolution_index)

	_build_graphics_rows()
	Localization.language_changed.connect(_refresh_rows.unbind(1))
	DisplaySettings.quality_changed.connect(_refresh_rows)

func _build_graphics_rows() -> void:
	_add_row("SETTINGS_MONITOR", DisplaySettings.get_monitor_names, DisplaySettings.get_monitor_index,
		DisplaySettings.set_monitor_index)
	_add_row("SETTINGS_VSYNC", _vsync_names, DisplaySettings.get_vsync_index,
		DisplaySettings.set_vsync_index)
	_add_row("SETTINGS_FPS_CAP", _fps_cap_names, DisplaySettings.get_fps_cap_index,
		DisplaySettings.set_fps_cap_index)
	_add_row("SETTINGS_SHOW_FPS", _on_off_names, DisplaySettings.get_show_fps_index,
		DisplaySettings.set_show_fps_index)
	_add_row("SETTINGS_QUALITY_PRESET", _preset_names, DisplaySettings.get_preset_index,
		DisplaySettings.set_preset_index)
	_add_quality_row("SETTINGS_RENDER_SCALE", "render_scale", _render_scale_names)
	_add_quality_row("SETTINGS_MSAA", "msaa", _msaa_names)
	_add_quality_row("SETTINGS_SSAA", "ssaa", _ssaa_names)
	_add_quality_row("SETTINGS_TAA", "taa", _on_off_names)
	_add_quality_row("SETTINGS_SHADOWS", "shadows", _shadow_names)
	_add_quality_row("SETTINGS_GLOW", "glow", _on_off_names)
	_add_quality_row("SETTINGS_SSAO", "ssao", _on_off_names)
	_add_quality_row("SETTINGS_SSR", "ssr", _on_off_names)
	_refresh_rows()

func _add_quality_row(label_key: String, key: String, items: Callable) -> void:
	_add_row(label_key, items, DisplaySettings.get_quality_value.bind(key),
		DisplaySettings.set_quality_value.bind(key))

func _add_row(label_key: String, items: Callable, index: Callable, on_selected: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_key
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stepper: StepperSelect = STEPPER_SCENE.instantiate()
	row.add_child(label)
	row.add_child(spacer)
	row.add_child(stepper)
	graphics_box.add_child(row)
	stepper.selected.connect(on_selected)
	_rows.append([stepper, items, index])

func _refresh_rows() -> void:
	for row in _rows:
		row[0].set_items(row[1].call(), row[2].call())

func _on_off_names() -> PackedStringArray:
	return PackedStringArray([tr("SETTINGS_OFF"), tr("SETTINGS_ON")])

func _vsync_names() -> PackedStringArray:
	return PackedStringArray([tr("SETTINGS_OFF"), tr("SETTINGS_ON"), tr("SETTINGS_ADAPTIVE"), "Mailbox"])

func _fps_cap_names() -> PackedStringArray:
	var names := PackedStringArray()
	for cap in DisplaySettings.FPS_CAPS:
		names.append(str(cap) if cap > 0 else tr("SETTINGS_UNLIMITED"))
	return names

func _preset_names() -> PackedStringArray:
	return PackedStringArray([
		tr("SETTINGS_QUALITY_LOW"), tr("SETTINGS_QUALITY_MEDIUM"),
		tr("SETTINGS_QUALITY_HIGH"), tr("SETTINGS_QUALITY_CUSTOM")])

func _render_scale_names() -> PackedStringArray:
	var names := PackedStringArray()
	for scale in DisplaySettings.RENDER_SCALES:
		names.append("%d%%" % roundi(scale * 100.0))
	return names

func _msaa_names() -> PackedStringArray:
	return PackedStringArray([tr("SETTINGS_OFF"), "2x", "4x", "8x"])

func _ssaa_names() -> PackedStringArray:
	return PackedStringArray([tr("SETTINGS_OFF"), "FXAA", "SMAA"])

func _shadow_names() -> PackedStringArray:
	return PackedStringArray([
		tr("SETTINGS_QUALITY_LOW"), tr("SETTINGS_QUALITY_MEDIUM"), tr("SETTINGS_QUALITY_HIGH")])

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
