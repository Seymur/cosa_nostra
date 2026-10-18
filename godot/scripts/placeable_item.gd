class_name PlaceableItem
extends Equippable

## A carried prop that can be set back into the world. Removable props turn into one
## of these; the scene needs a RigidBody3D child holding a "Visual" instance of the
## placed prop and a collision shape.

## Fired by the left click while the item is held.
@export var primary_action: GUIDEAction
## The prop placed into the world. A path to avoid a cyclic scene reference.
@export_file("*.tscn") var placed_scene_path := ""

## Surfaces the item may stand on: the aimed collider (or one of its ancestors)
## must be in one of these groups. Add the group to a floor, table, etc. to allow it.
@export var valid_surface_groups: Array[StringName] = [&"ground", &"table"]

## Size of the prop's footprint, used to check there is room. Slightly smaller than
## the prop so touching neighbours are fine.
@export var footprint := Vector3(0.98, 0.46, 0.56)
## Scale of the prop while carried.
@export var held_scale := 0.4

## Lift of the overlap box off the surface so the supporting floor doesn't count.
const PLACEMENT_CLEARANCE := 0.03
const VALID_COLOR := Color(0.2, 1.0, 0.3, 0.5)
const INVALID_COLOR := Color(1.0, 0.2, 0.2, 0.5)
const MAX_PLACE_DISTANCE := 4.0
## Steepest surface (surface normal . up) the item can stand on.
const MIN_FLOOR_NORMAL_Y := 0.7

var _ghost: Node3D
## Last aimed placement, refreshed every physics frame (the physics space is off limits elsewhere).
var _target := {}
var _placed_scene: PackedScene
var _ghost_material := StandardMaterial3D.new()

func _ready() -> void:
	allows_interact_fallthrough = false
	body = $RigidBody3D
	_placed_scene = load(placed_scene_path)
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The visual is the placed prop's scene; only the rigid body should collide.
	_disable_prop_collision($RigidBody3D/Visual)

func _disable_prop_collision(prop: Node) -> void:
	for node in prop.find_children("*", "CollisionObject3D", true, false):
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0

func equip(holder: Node3D) -> void:
	super(holder)
	$RigidBody3D/Visual.scale = Vector3.ONE * held_scale

func stow(holder: Node3D) -> void:
	super(holder)
	_clear_ghost()

func drop(world: Node, from: Transform3D, impulse: Vector3) -> void:
	_clear_ghost()
	$RigidBody3D/Visual.scale = Vector3.ONE
	super(world, from, impulse)

func _exit_tree() -> void:
	_clear_ghost()

func on_action(action: GUIDEAction) -> void:
	if action != primary_action:
		return
	var player := get_tree().get_first_node_in_group("player")
	var target := _target
	if target.is_empty() or not target.valid or player.held_item != self:
		return
	var placed := _placed_scene.instantiate() as Node3D
	player.get_parent().add_child(placed)
	placed.global_transform = target.transform
	player.consume_held()

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.held_item != self:
		_target = {}
		_clear_ghost()
		return
	var target := _placement_target(player)
	_target = target
	if target.is_empty():
		_clear_ghost()
		return
	if _ghost == null:
		_ghost = _placed_scene.instantiate() as Node3D
		_disable_prop_collision(_ghost)
		for mesh in _ghost.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = _ghost_material
		player.get_parent().add_child(_ghost)
	_ghost.global_transform = target.transform
	_ghost_material.albedo_color = VALID_COLOR if target.valid else INVALID_COLOR

func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

## Where the item would stand: {transform, valid}, or an empty dictionary when
## nothing is within reach. It is valid on an allowed surface, facing up, with room
## for the item.
func _placement_target(player: Node) -> Dictionary:
	var camera: Camera3D = player.camera
	var from := camera.global_position
	var to := from - camera.global_basis.z * MAX_PLACE_DISTANCE
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var xform := Transform3D(Basis(Vector3.UP, player.global_rotation.y), hit.position)
	var valid: bool = hit.normal.y >= MIN_FLOOR_NORMAL_Y and _is_valid_surface(hit.collider) and _has_room(space, xform)
	return {"transform": xform, "valid": valid}

func _is_valid_surface(collider: Node) -> bool:
	while collider:
		for group in valid_surface_groups:
			if collider.is_in_group(group):
				return true
		collider = collider.get_parent()
	return false

func _has_room(space: PhysicsDirectSpaceState3D, xform: Transform3D) -> bool:
	var box := BoxShape3D.new()
	box.size = footprint
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = xform * Transform3D(Basis.IDENTITY, Vector3(0, footprint.y * 0.5 + PLACEMENT_CLEARANCE, 0))
	return space.intersect_shape(query, 1).is_empty()
