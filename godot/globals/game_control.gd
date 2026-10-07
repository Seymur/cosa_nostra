extends Node
## Routes shared game-clock controls (pause, speed) through the host so every
## peer stays in sync. Offline play is a host with no peers, so the same path
## serves single-player and co-op. Menus never pause the game.

const HOST_ID := 1

func request_pause(paused: bool) -> void:
	if multiplayer.is_server():
		_apply_state.rpc(paused, GameClock.speed_multiplier)
	else:
		_request_pause.rpc_id(HOST_ID, paused)

func request_speed(multiplier: float) -> void:
	if multiplayer.is_server():
		_apply_state.rpc(GameClock.paused, multiplier)
	else:
		_request_speed.rpc_id(HOST_ID, multiplier)

func toggle_pause() -> void:
	request_pause(not GameClock.paused)

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		_apply_state.rpc_id(id, GameClock.paused, GameClock.speed_multiplier)

@rpc("any_peer", "call_remote", "reliable")
func _request_pause(paused: bool) -> void:
	if multiplayer.is_server():
		_apply_state.rpc(paused, GameClock.speed_multiplier)

@rpc("any_peer", "call_remote", "reliable")
func _request_speed(multiplier: float) -> void:
	if multiplayer.is_server():
		_apply_state.rpc(GameClock.paused, multiplier)

@rpc("authority", "call_local", "reliable")
func _apply_state(paused: bool, multiplier: float) -> void:
	GameClock.set_paused_state(paused)
	GameClock.set_speed(multiplier)
