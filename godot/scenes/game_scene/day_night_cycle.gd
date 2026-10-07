extends Node3D
## Drives the sun, sky and ambient light from GameClock. Visual only; each peer runs it locally.

@export var sun: DirectionalLight3D
@export var world_env: WorldEnvironment
@export var sun_azimuth_degrees := -30.0
@export var night_ambient_energy := 0.15
@export var day_ambient_energy := 1.0

const SUNRISE_HOUR := 6.0
const NIGHT_SUN_COLOR := Color(0.35, 0.45, 0.8)
const TWILIGHT_SUN_COLOR := Color(1.0, 0.55, 0.3)
const DAY_SUN_COLOR := Color(1.0, 0.97, 0.9)

const NIGHT_SKY_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_SKY_HORIZON := Color(0.06, 0.08, 0.15)
const DAY_SKY_TOP := Color(0.38, 0.45, 0.55)
const DAY_SKY_HORIZON := Color(0.64, 0.65, 0.67)

var _sky: ProceduralSkyMaterial


func _ready() -> void:
	if world_env and world_env.environment and world_env.environment.sky:
		_sky = world_env.environment.sky.sky_material as ProceduralSkyMaterial
		world_env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_update()


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	var hour: float = GameClock.get_hour_float()
	var elevation_deg := (hour - SUNRISE_HOUR) / 12.0 * 180.0
	# Drive everything from the sun's actual height, not GameClock.get_daylight(),
	# so the disc and light are in sync with where the sun is in the sky.
	var s := sin(deg_to_rad(elevation_deg))
	var daylight := smoothstep(-0.1, 0.4, s)

	if sun:
		sun.rotation_degrees = Vector3(-elevation_deg, sun_azimuth_degrees, 0.0)
		# Keep a floor of energy at the horizon so the sky disc is visible as it rises.
		sun.light_energy = smoothstep(-0.05, 0.0, s) * lerpf(0.3, 1.0, smoothstep(0.0, 0.3, s))
		sun.visible = s > -0.05
		sun.light_color = _sun_color(daylight)

	if world_env and world_env.environment:
		world_env.environment.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, daylight)
		world_env.environment.ambient_light_color = NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, daylight)

	if _sky:
		_sky.sky_top_color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight)
		_sky.sky_horizon_color = NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, daylight)
		_sky.ground_horizon_color = _sky.sky_horizon_color
		_sky.ground_bottom_color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight * 0.5)


## Night blue -> orange twilight -> white day, peaking orange at daylight ~0.5.
func _sun_color(daylight: float) -> Color:
	if daylight < 0.5:
		return NIGHT_SUN_COLOR.lerp(TWILIGHT_SUN_COLOR, daylight * 2.0)
	return TWILIGHT_SUN_COLOR.lerp(DAY_SUN_COLOR, (daylight - 0.5) * 2.0)
