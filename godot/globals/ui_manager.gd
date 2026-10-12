extends Node
## Owns a stack of modal/full-screen menus. Menus are plain scenes; they never
## free themselves. Esc (ui_cancel) pops the top screen.

signal screen_changed(top: Control)

const SETTINGS := preload("res://ui/settings_menu/settings_menu.tscn")
const PAUSE := preload("res://ui/pause_menu/pause_menu.tscn")
const INVENTORY := preload("res://ui/inventory/inventory.tscn")

var _layer := CanvasLayer.new()
var _stack: Array[Control] = []
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.layer = 10
	add_child(_layer)

func _unhandled_input(event: InputEvent) -> void:
	if not _stack.is_empty() and event.is_action_pressed("ui_cancel"):
		pop()
		get_viewport().set_input_as_handled()

func top() -> Control:
	return null if _stack.is_empty() else _stack.back()

## Opens a screen on top of the current one. Does not pause the game: pausing
## is shared state owned by GameControl.
func push(scene: PackedScene) -> Control:
	var below := top()
	if below:
		below.hide()
	else:
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var screen: Control = scene.instantiate()
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.add_child(screen)
	_stack.push_back(screen)
	_focus_first(screen)
	screen_changed.emit(screen)
	return screen

## Closes the top screen.
func pop() -> void:
	if _stack.is_empty():
		return
	_stack.pop_back().queue_free()
	var below := top()
	if below:
		below.show()
		_focus_first(below)
	else:
		Input.mouse_mode = _previous_mouse_mode
	screen_changed.emit(below)

func replace(scene: PackedScene) -> Control:
	pop()
	return push(scene)

func clear() -> void:
	while not _stack.is_empty():
		pop()

func _focus_first(screen: Control) -> void:
	var target := screen.find_next_valid_focus()
	if target:
		target.grab_focus()
