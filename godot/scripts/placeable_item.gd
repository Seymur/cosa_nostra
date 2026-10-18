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

## Toggles snapping the ghost flush against nearby placed props and walls. Free
## placement while off.
@export var snap_action: GUIDEAction
## How close (in metres) a prop or wall must be for the ghost to snap to it.
@export var snap_distance := 0.3

## Size of the prop's footprint, used to check there is room. Slightly smaller than
## the prop so touching neighbours are fine.
@export var footprint := Vector3(0.98, 0.46, 0.56)
## Scale of the prop while carried.
@export var held_scale := 0.4

## Lift of the overlap box off the surface so the supporting floor doesn't count.
const PLACEMENT_CLEARANCE := 0.03
## Gap left between snapped neighbours. The room check uses the footprint, which is a
## little smaller than the real collider, so exact contact would count as overlap.
const SNAP_GAP := 0.04
const VALID_COLOR := Color(0.2, 1.0, 0.3, 0.5)
const INVALID_COLOR := Color(1.0, 0.2, 0.2, 0.5)
const MAX_PLACE_DISTANCE := 4.0
## Steepest surface (surface normal . up) the item can stand on.
const MIN_FLOOR_NORMAL_Y := 0.7

## Whether snapping is on. Shared by all placeables so the choice survives swapping items.
static var snapping := false

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

# Connected on entering the tree rather than in _ready: carrying the item reparents it,
# which runs _exit_tree and would otherwise leave it disconnected for good.
func _enter_tree() -> void:
	if snap_action and not snap_action.just_triggered.is_connected(_on_snap_pressed):
		snap_action.just_triggered.connect(_on_snap_pressed)

func _exit_tree() -> void:
	if snap_action and snap_action.just_triggered.is_connected(_on_snap_pressed):
		snap_action.just_triggered.disconnect(_on_snap_pressed)
	_clear_ghost()

func _on_snap_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.held_item == self:
		snapping = not snapping

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

## Where the item would stand: {transform, valid, snapped}, or an empty dictionary when
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
	var snapped := false
	if snapping:
		var snap := _snap(space, xform, player)
		if not snap.is_empty():
			xform = snap.transform
			snapped = true
	var valid: bool = hit.normal.y >= MIN_FLOOR_NORMAL_Y and _is_valid_surface(hit.collider) and _has_room(space, xform)
	return {"transform": xform, "valid": valid, "snapped": snapped}

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

## Moves `xform` flush against the nearest placed prop, else the nearest wall, within
## snap_distance. Returns {transform}, or an empty dictionary when nothing is close.
func _snap(space: PhysicsDirectSpaceState3D, xform: Transform3D, player: Node) -> Dictionary:
	var snap := _snap_to_prop(space, xform)
	if snap.is_empty():
		snap = _snap_to_wall(space, xform, player)
	return snap

## Flush against a side of the nearest snappable prop, matching its rotation and
## sliding freely along that side. Props are assumed to share this item's footprint.
func _snap_to_prop(space: PhysicsDirectSpaceState3D, xform: Transform3D) -> Dictionary:
	var sphere := SphereShape3D.new()
	sphere.radius = snap_distance + Vector2(footprint.x, footprint.z).length()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, xform.origin)
	var nearest: Node3D
	var nearest_distance := INF
	for result in space.intersect_shape(query, 16):
		var prop := _find_snappable(result.collider)
		if prop == null:
			continue
		var distance := prop.global_position.distance_squared_to(xform.origin)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = prop
	if nearest == null:
		return {}
	var basis := Basis(Vector3.UP, nearest.global_rotation.y)
	var local := basis.inverse() * (xform.origin - nearest.global_position)
	var height := local.y
	local.y = 0.0
	# Touching means the centres are one footprint (plus the gap) apart along the side's axis.
	var spacing := Vector2(footprint.x, footprint.z) + Vector2.ONE * SNAP_GAP
	var along_x := absf(local.x) / footprint.x >= absf(local.z) / footprint.z
	if along_x:
		var gap := absf(local.x) - spacing.x
		if gap > snap_distance:
			return {}
		local.x = signf(local.x) * spacing.x
		local.z = clampf(local.z, -footprint.z, footprint.z)
	else:
		var gap := absf(local.z) - spacing.y
		if gap > snap_distance:
			return {}
		local.z = signf(local.z) * spacing.y
		local.x = clampf(local.x, -footprint.x, footprint.x)
	local.y = height
	return {"transform": Transform3D(basis, nearest.global_position + basis * local)}

func _find_snappable(node: Node) -> Node3D:
	while node:
		if node.is_in_group(&"snappable"):
			return node as Node3D
		node = node.get_parent()
	return null

## Backs the nearest side of the item against a wall, turning it to face along the wall.
func _snap_to_wall(space: PhysicsDirectSpaceState3D, xform: Transform3D, player: Node) -> Dictionary:
	var start := xform.origin + Vector3.UP * (footprint.y * 0.5 + PLACEMENT_CLEARANCE)
	var best := {}
	var best_distance := INF
	# The four sides of the item: direction, and half the footprint along it.
	for side in [[xform.basis.x, footprint.x * 0.5], [-xform.basis.x, footprint.x * 0.5], [xform.basis.z, footprint.z * 0.5], [-xform.basis.z, footprint.z * 0.5]]:
		var direction: Vector3 = side[0]
		var half: float = side[1]
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * (half + snap_distance))
		query.exclude = [player.get_rid()]
		var hit := space.intersect_ray(query)
		# Only upright walls count, not the floor or other props' tops.
		if hit.is_empty() or absf(hit.normal.y) > 0.1 or _find_snappable(hit.collider) != null:
			continue
		var distance: float = start.distance_to(hit.position)
		if distance < best_distance:
			best_distance = distance
			best = {"hit": hit, "direction": direction, "half": half}
	if best.is_empty():
		return {}
	var normal: Vector3 = best.hit.normal
	normal.y = 0.0
	normal = normal.normalized()
	# Turn so the side that faced the wall now faces straight into it.
	var turn: float = (best.direction as Vector3).signed_angle_to(-normal, Vector3.UP)
	var basis := Basis(Vector3.UP, turn) * xform.basis
	# Slide along the wall normal until that side touches.
	var origin := xform.origin
	origin += normal * (best.half + SNAP_GAP * 0.5 - (origin - best.hit.position).dot(normal))
	return {"transform": Transform3D(basis, origin)}
