class_name OutlineEffect
extends CompositorEffect
## Draws a constant pixel width outline around everything on the outline layer by
## dilating the silhouette rendered by OutlineMask.

@export var outline_color := Color(0.8, 1.0, 0.0, 1.0)
@export_range(1, 8) var radius := 3
## How much nearer than the highlighted object the scene may be at an outline pixel
## before something in front is considered to hide the outline (relative depth).
@export_range(0.0, 0.5) var occlusion_tolerance := 0.05

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID

func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_motion_vectors = false
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _shader.is_valid():
			_rd.free_rid(_shader)
		if _sampler.is_valid():
			_rd.free_rid(_sampler)

func _initialize_compute() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return
	var shader_file := load("res://effects/outline/outline.glsl") as RDShaderFile
	_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	_pipeline = _rd.compute_pipeline_create(_shader)
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_sampler = _rd.sampler_create(sampler_state)

func _render_callback(_callback_type: int, render_data: RenderData) -> void:
	if not OutlineMask.active or not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0 or Vector2i(size) != OutlineMask.mask_size:
		return # the mask is still being resized
	var mask := RenderingServer.texture_get_rd_texture(OutlineMask.mask_texture)
	if not mask.is_valid():
		return

	var color := outline_color.srgb_to_linear() # the buffer is linear, before tonemapping
	var push_constants := PackedFloat32Array([
		size.x, size.y, radius, occlusion_tolerance,
		color.r, color.g, color.b, color.a,
	]).to_byte_array()
	var groups := Vector3i((size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1, 1)

	for view in buffers.get_view_count():
		var color_uniform := RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color_uniform.binding = 0
		color_uniform.add_id(buffers.get_color_layer(view))
		var depth_uniform := RDUniform.new()
		depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth_uniform.binding = 1
		depth_uniform.add_id(_sampler)
		depth_uniform.add_id(buffers.get_depth_layer(view))
		var mask_uniform := RDUniform.new()
		mask_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		mask_uniform.binding = 2
		mask_uniform.add_id(_sampler)
		mask_uniform.add_id(mask)
		var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [color_uniform, depth_uniform, mask_uniform])

		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		_rd.compute_list_bind_uniform_set(list, uniform_set, 0)
		_rd.compute_list_set_push_constant(list, push_constants, push_constants.size())
		_rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
		_rd.compute_list_end()
