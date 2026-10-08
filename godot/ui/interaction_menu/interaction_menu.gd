extends Control
## Lists an Interactable's options as buttons on the right edge of the screen.
## Scroll to highlight one, hold E to choose it. Pushed through UIManager, so
## Esc closes it.

const BUTTON_SIZE := Vector2(180, 36)
const EDGE_MARGIN := 32.0
const SLIDE_TIME := 0.25
const STAGGER := 0.06
const HOLD_TIME := 0.6
const RING_SIZE := 26.0
const RING_WIDTH := 3.0
const RING_TRACK_ALPHA := 0.25

## "E" key inside a circular bar that fills while the key is held.
class KeyRing extends Control:
	var color := Color.WHITE
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius := (RING_SIZE - RING_WIDTH) / 2.0
		draw_arc(center, radius, 0.0, TAU, 32, Color(color, RING_TRACK_ALPHA), RING_WIDTH, true)
		if progress > 0.0:
			draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, color, RING_WIDTH, true)
		var font := get_theme_default_font()
		var font_size := 14
		var text_size := font.get_string_size("E", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0),
			"E", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

@onready var _list: VBoxContainer = $List

var _interactable: Interactable
var _interactor: Node
var _options: Array[InteractionOption] = []
var _buttons: Array[Button] = []
var _rings: Array[KeyRing] = []
## Ignores the press of E that opened the menu.
var _armed := false
var _holding := false
var _hold := 0.0

func _ready() -> void:
	await get_tree().process_frame
	_armed = true

## Call right after UIManager.push().
func setup(interactable: Interactable, interactor: Node) -> void:
	_interactable = interactable
	_interactor = interactor
	var first_focus: Button = null
	for i in interactable.options.size():
		var option := interactable.options[i]
		var slot := Control.new()
		slot.custom_minimum_size = BUTTON_SIZE
		_list.add_child(slot)

		var button := Button.new()
		button.text = option.label
		button.size = BUTTON_SIZE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.disabled = not interactable.is_available(option, Equipment.equipped)
		slot.add_child(button)
		_options.append(option)
		_buttons.append(button)
		_rings.append(_add_key_ring(button))
		if first_focus == null and not button.disabled:
			first_focus = button

		# Slide in from beyond the right edge, one button after another.
		button.position.x = BUTTON_SIZE.x + EDGE_MARGIN
		var tween := create_tween()
		tween.tween_property(button, "position:x", 0.0, SLIDE_TIME) \
			.set_delay(i * STAGGER) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	if first_focus:
		first_focus.grab_focus()

## "E" key inside the button, shown only on the highlighted one.
func _add_key_ring(button: Button) -> KeyRing:
	var ring := KeyRing.new()
	ring.color = button.get_theme_color("font_focus_color")
	ring.custom_minimum_size = Vector2(RING_SIZE, RING_SIZE)
	ring.size = Vector2(RING_SIZE, RING_SIZE)
	ring.position = Vector2(8, (BUTTON_SIZE.y - RING_SIZE) / 2.0)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	button.add_child(ring)
	button.focus_entered.connect(ring.show)
	button.focus_exited.connect(ring.hide)
	return ring

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and not event.echo:
		if not event.pressed:
			_cancel_hold()
		elif _armed:
			_holding = true
			get_viewport().set_input_as_handled()
	elif _armed and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-1)
		else:
			return
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Close as soon as the crosshair leaves the target.
	if _interactor.get_target_interactable() != _interactable:
		if UIManager.top() == self:
			UIManager.pop()
		return
	if not _holding:
		return
	var index := _buttons.find(get_viewport().gui_get_focus_owner())
	if index < 0 or _buttons[index].disabled:
		_cancel_hold()
		return
	_hold += delta
	_rings[index].progress = minf(_hold / HOLD_TIME, 1.0)
	if _hold >= HOLD_TIME:
		_cancel_hold()
		UIManager.pop()
		_interactable.interact(_options[index], _interactor)

func _cancel_hold() -> void:
	_holding = false
	_hold = 0.0
	for ring in _rings:
		ring.progress = 0.0

## Moves focus to the next enabled button in direction `step`, wrapping around.
func _scroll(step: int) -> void:
	_cancel_hold()
	var from := _buttons.find(get_viewport().gui_get_focus_owner())
	for i in range(1, _buttons.size() + 1):
		var button := _buttons[posmod(from + step * i, _buttons.size())]
		if not button.disabled:
			button.grab_focus()
			return
