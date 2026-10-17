class_name OutlineMask
extends SubViewport
## Renders a silhouette of everything on the outline layer into a transparent texture
## from a camera that mirrors the main one. OutlineEffect reads that texture and
## dilates it into the outline.

## Set by Interactable while something is highlighted; idle otherwise so the extra
## render pass and the compositor pass cost nothing.
static var active := false
## Read from the render thread by OutlineEffect.
static var mask_texture: RID
static var mask_size := Vector2i.ZERO

var _camera: Camera3D
var _source_viewport: Viewport

func _ready() -> void:
	process_priority = 100 # after the player has moved and looked this frame
	transparent_bg = true
	msaa_3d = Viewport.MSAA_DISABLED
	positional_shadow_atlas_size = 0
	gui_disable_input = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	_camera = Camera3D.new()
	_camera.cull_mask = 1 << (Interactable.OUTLINE_LAYER - 1)
	add_child(_camera)
	_source_viewport = get_parent().get_viewport()
	mask_texture = get_texture().get_rid()

func _exit_tree() -> void:
	active = false
	mask_texture = RID()
	mask_size = Vector2i.ZERO

func _process(_delta: float) -> void:
	var update_mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if render_target_update_mode != update_mode:
		render_target_update_mode = update_mode
	if not active:
		return

	# Match the main camera's 3D render resolution so mask pixels line up with screen pixels.
	var target := Vector2i((Vector2(get_window().size) * _source_viewport.scaling_3d_scale).round())
	target = target.max(Vector2i.ONE)
	if size != target:
		size = target
	mask_size = target

	var source := _source_viewport.get_camera_3d()
	if source == null:
		return
	_camera.global_transform = source.global_transform
	_camera.projection = source.projection
	_camera.fov = source.fov
	_camera.size = source.size
	_camera.near = source.near
	_camera.far = source.far
	_camera.keep_aspect = source.keep_aspect
