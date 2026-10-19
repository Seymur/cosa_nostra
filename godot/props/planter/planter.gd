extends Removable

enum State { EMPTY, PLANTED, GROWING, HARVESTABLE }

## Plant models for each growth stage, in order (seedling to harvest).
@export var stage_scenes: Array[PackedScene]
## In-game minutes spent in each stage before the next one (1440 = one game day).
@export var stage_duration_minutes := 1440

## Item dropped on the planter for each harvest.
@export var harvest_scene: PackedScene
@export var harvest_amount := 4

var state := State.EMPTY
var stage := 0
var _watered_at := 0
var _plant: Node3D

@onready var _plant_anchor: Node3D = $PlantAnchor

const STAGE_NAMES: Array[String] = ["Seedling", "Young", "Flowering", "Harvest"]

func get_hud_text() -> String:
	match state:
		State.EMPTY:
			return "Planter
Empty"
		State.PLANTED:
			return "Weed plant
Stage: %s (1/%d)
Needs watering" % [STAGE_NAMES[0], stage_scenes.size()]
		State.GROWING:
			var elapsed: int = GameClock.get_total_minutes() - _watered_at
			var total := stage_duration_minutes * (stage_scenes.size() - 1)
			return "Weed plant
Stage: %s (%d/%d)
Growth: %d%%
Next stage in: %s
Ready in: %s" % [
				STAGE_NAMES[stage], stage + 1, stage_scenes.size(),
				clampi(elapsed * 100 / maxi(total, 1), 0, 100),
				_format_minutes(stage_duration_minutes * (stage + 1) - elapsed),
				_format_minutes(total - elapsed)]
		_:
			return "Weed plant
Stage: %s (%d/%d)
Ready to harvest" % [STAGE_NAMES[stage], stage + 1, stage_scenes.size()]

func _format_minutes(minutes: int) -> String:
	minutes = maxi(minutes, 0)
	var days := minutes / 1440
	var hours := minutes % 1440 / 60
	if days > 0:
		return "%dd %dh" % [days, hours]
	return "%dh %dm" % [hours, minutes % 60]

func accepts_item(item: Interactable) -> bool:
	return (item is WeedSeed and state == State.EMPTY) or (item is WateringCan and state == State.PLANTED) or (item is GardenShears and state == State.HARVESTABLE)

func on_item_action(item: Interactable, action: GUIDEAction) -> bool:
	if item is WeedSeed and action == item.primary_action:
		_plant_seed()
		return true
	if item is WateringCan and action == item.primary_action:
		_water()
		return true
	if item is GardenShears and action == item.primary_action:
		_harvest()
		return true
	return super(item, action)

func _plant_seed() -> void:
	if state != State.EMPTY or stage_scenes.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.consume_held()
	state = State.PLANTED
	_show_stage(0)

func _water() -> void:
	if state != State.PLANTED:
		return
	state = State.GROWING
	_watered_at = GameClock.get_total_minutes()
	GameClock.minute_changed.connect(_on_minute_changed)

func _on_minute_changed() -> void:
	var elapsed: int = GameClock.get_total_minutes() - _watered_at
	var target := mini(elapsed / maxi(stage_duration_minutes, 1), stage_scenes.size() - 1)
	if target != stage:
		_show_stage(target)
	if stage == stage_scenes.size() - 1:
		state = State.HARVESTABLE
		GameClock.minute_changed.disconnect(_on_minute_changed)

func _harvest() -> void:
	if state != State.HARVESTABLE:
		return
	_plant.queue_free()
	_plant = null
	stage = 0
	state = State.EMPTY
	if harvest_scene == null:
		return
	for i in harvest_amount:
		var weed := harvest_scene.instantiate() as Node3D
		get_parent().add_child(weed)
		weed.global_position = _plant_anchor.global_position + Vector3(randf_range(-0.3, 0.3), 0.3 + 0.1 * i, randf_range(-0.15, 0.15))

func _show_stage(index: int) -> void:
	stage = index
	if _plant != null:
		_plant.queue_free()
	_plant = stage_scenes[index].instantiate()
	_plant_anchor.add_child(_plant)

# A planted planter can't be picked up, or the plant would be lost.
func _remove() -> void:
	if state == State.EMPTY:
		super()
