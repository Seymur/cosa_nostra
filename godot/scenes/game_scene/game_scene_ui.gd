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
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

func _set_game_clock_text():
	var month: String = MONTHS[GameClock.get_month() - 1]
	$GameClockContainer/GameClock/Label.text = "%d %s %d %02d:%02d" % [
		GameClock.get_day(),
		month,
		GameClock.get_year(),
		GameClock.get_hour(),
		GameClock.get_minute(),
	]

func _set_speed_text():
	$GameClockContainer/GameClock/PanelContainer/HBoxContainer/Label.text = "x" + str(int(GameClock.speed_multiplier))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
