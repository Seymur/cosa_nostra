extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_set_game_clock_text()
	_set_speed_text()
	GameClock.minute_changed.connect(_on_minute_changed)
	GameClock.speed_changed.connect(_on_speed_changed)

func _on_speed_changed(speed, paused):
	_set_speed_text()

func _on_minute_changed():
	_set_game_clock_text()
	
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_set_game_clock_text()

func _set_game_clock_text():
	$GameClockContainer/GameClock/Label.text = tr("DATE_FORMAT").format({
		"day": GameClock.get_day(),
		"month": tr("MONTH_%d" % GameClock.get_month()),
		"year": GameClock.get_year(),
		"time": "%02d:%02d" % [GameClock.get_hour(), GameClock.get_minute()],
	})

func _set_speed_text():
	$GameClockContainer/GameClock/PanelContainer/HBoxContainer/Label.text = "x" + str(int(GameClock.speed_multiplier))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and UIManager.top() == null:
		UIManager.push(UIManager.PAUSE)
		get_viewport().set_input_as_handled()
