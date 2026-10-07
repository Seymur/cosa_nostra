extends WorldEnvironment
## Applies the player's glow, SSAO and SSR settings to this node's Environment.

func _ready() -> void:
	DisplaySettings.environment_changed.connect(_apply)
	_apply()

func _apply() -> void:
	if environment == null:
		return
	environment.glow_enabled = DisplaySettings.is_glow_enabled()
	environment.ssao_enabled = DisplaySettings.is_ssao_enabled()
	environment.ssr_enabled = DisplaySettings.is_ssr_enabled()
