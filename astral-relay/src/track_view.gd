extends Node3D

const CHUNK_LENGTH := 48.0
const STEP := 4.0
const FACETS := 12
const CHUNKS_AHEAD := 9
const CHUNKS_BEHIND := 2
const SPLIT_RADIUS := 7.7
const FLIGHT_PATH := preload("res://src/flight_path.gd")

const REGION_COLORS := [
	Color("#61dcfc"),
	Color("#af8cff"),
	Color("#8dfabf"),
	Color("#8daeff"),
]
const LEFT_COLOR := Color("#ff7e92")
const RIGHT_COLOR := Color("#c4fa80")

const PANEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying float view_depth;

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec2 tile = vec2(UV.x, fract(UV.y));
	float edge_x = min(tile.x, 1.0 - tile.x);
	float edge_y = min(tile.y, 1.0 - tile.y);
	float aa = clamp(fwidth(UV.y), 0.003, 0.06);
	float seam = smoothstep(0.016, 0.031 + aa, edge_y);
	float border = smoothstep(0.016, 0.054, edge_x);
	float rail = (1.0 - smoothstep(0.005, 0.017, abs(tile.x - 0.077))) * seam;
	float inset = smoothstep(0.07, 0.15, edge_x) * smoothstep(0.04, 0.13, edge_y);
	float rail_shine = (1.0 - smoothstep(0.0, 0.038, abs(tile.x - 0.077))) * seam;
	float cell = fract(UV.x * 12.0);
	float marker = (1.0 - smoothstep(0.07, 0.24, abs(cell - 0.5)))
		* (1.0 - smoothstep(0.012, 0.034 + aa, abs(tile.y - 0.125)))
		* smoothstep(0.71, 0.78, tile.x);
	float depth = 1.0 - smoothstep(92.0, 355.0, view_depth);
	float detail = 1.0 - smoothstep(48.0, 135.0, view_depth);
	vec3 tint = COLOR.rgb;
	vec3 panel = vec3(0.016, 0.021, 0.046) + tint * (0.031 + COLOR.a * 0.049);
	panel *= 0.65 + 0.23 * seam * border + inset * 0.12;
	panel += tint * detail * (rail * (0.15 + COLOR.a * 0.27) + rail_shine * 0.05 + marker * 0.19);
	ALBEDO = mix(vec3(0.011, 0.015, 0.034), panel, depth);
}
"""

const TRIM_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying float view_depth;

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float depth = 1.0 - smoothstep(85.0, 340.0, view_depth);
	ALBEDO = mix(vec3(0.011, 0.015, 0.034), COLOR.rgb, depth);
}
"""

const SKY_SHADER := """
shader_type sky;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 id = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(id).x, hash2(id + vec2(1, 0)).x, w.x),
		mix(hash2(id + vec2(0, 1)).x, hash2(id + vec2(1, 1)).x, w.x), w.y);
}

vec3 stars(vec2 coords, vec2 density, float cutoff) {
	vec2 p = coords * density;
	vec2 h = hash2(floor(p));
	vec2 center = mix(vec2(0.22), vec2(0.78), h);
	float r = length(fract(p) - center);
	float lit = step(cutoff, h.x);
	float point = 1.0 - smoothstep(0.035, mix(0.15, 0.26, h.y), r);
	vec3 color = mix(vec3(0.44, 0.67, 1.0), vec3(1.0, 0.76, 0.57), h.y * h.y);
	return color * point * lit * mix(0.27, 0.92, h.y);
}

void sky() {
	vec3 ray = normalize(EYEDIR);
	vec2 screen = vec2(atan(ray.x, -ray.z), ray.y);
	float cloud = noise(screen * vec2(3.2, 4.0) + vec2(4.4, 8.7));
	cloud = cloud * 0.72 + noise(screen * vec2(9.7, 15.0) + vec2(11.2, 20.0)) * 0.28;
	float band = exp(-pow((ray.y - ray.x * 0.28 - 0.04) * 3.2, 2.0));
	vec3 field = vec3(0.014, 0.021, 0.053) + vec3(0.023, 0.030, 0.074) * band;
	field += mix(vec3(0.043, 0.059, 0.102), vec3(0.048, 0.031, 0.080), cloud) * cloud * band;
	field += stars(screen + vec2(2.0), vec2(159.0, 195.0), 0.913);
	field += stars(screen + vec2(5.2), vec2(312.0, 355.0), 0.976) * 0.47;

	vec3 planet_dir = normalize(vec3(0.285, 0.147, -1.0));
	vec3 axis_x = normalize(cross(planet_dir, vec3(0.0, 1.0, 0.0)));
	vec3 axis_y = normalize(cross(axis_x, planet_dir));
	vec2 orb = vec2(dot(ray, axis_x), dot(ray, axis_y)) / 0.068;
	float disk_radius = length(orb);
	float edge = 1.0 - smoothstep(0.993, 1.005, disk_radius);
	float is_forward = step(0.0, dot(ray, planet_dir));
	vec2 ring_plane = vec2(orb.x - orb.y * 0.28, (orb.y + orb.x * 0.28) * 4.6);
	float ring_radius = length(ring_plane);
	float rings = smoothstep(1.23, 1.33, ring_radius) * (1.0 - smoothstep(2.33, 2.45, ring_radius));
	rings *= 0.30 + 0.27 * sin(ring_radius * 23.0) + 0.20 * sin(ring_radius * 57.0);
	rings *= smoothstep(0.10, 1.40, abs(orb.x)) * is_forward;
	vec3 ring_color = vec3(0.27, 0.57, 0.69);
	field += ring_color * rings * step(0.0, ring_plane.y);
	float z = sqrt(max(0.0, 1.0 - dot(orb, orb)));
	vec3 sphere = vec3(orb, z);
	float light = smoothstep(-0.46, 0.76, dot(sphere, normalize(vec3(-0.62, 0.65, 0.47))));
	float latitude = dot(sphere, vec3(0.24, 0.95, -0.18)) + sin(orb.x * 8.8) * 0.021;
	float belts = sin(latitude * 18.0) * 0.14 + sin(latitude * 56.0) * 0.07 + 0.52;
	vec3 gas = mix(vec3(0.049, 0.136, 0.228), vec3(0.37, 0.68, 0.70), belts);
	gas *= 0.25 + light * 0.86;
	gas += vec3(0.16, 0.56, 0.76) * pow(1.0 - z, 5.0) * (0.22 + 0.75 * light);
	field += vec3(0.045, 0.19, 0.34) * exp(-abs(disk_radius - 0.99) * 35.0) * is_forward;
	field = mix(field, gas, edge * is_forward);
	field += ring_color * rings * step(ring_plane.y, 0.0);
	COLOR = field;
}
"""


class MeshDraft:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()

	func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color,
			uv_front: float = 0.0, uv_back: float = 1.0) -> void:
		points.append(a)
		points.append(b)
		points.append(c)
		points.append(a)
		points.append(c)
		points.append(d)
		colors.append(color)
		colors.append(color)
		colors.append(color)
		colors.append(color)
		colors.append(color)
		colors.append(color)
		uvs.append(Vector2(0.0, uv_front))
		uvs.append(Vector2(1.0, uv_front))
		uvs.append(Vector2(1.0, uv_back))
		uvs.append(Vector2(0.0, uv_front))
		uvs.append(Vector2(1.0, uv_back))
		uvs.append(Vector2(0.0, uv_back))

	func append_to(mesh: ArrayMesh, material: Material) -> void:
		if points.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


var _path: FLIGHT_PATH
var _chunks: Dictionary = {}
var _current_chunk := -1000
var _panel_material: ShaderMaterial
var _trim_material: ShaderMaterial
var _ring := PackedVector2Array()
var _main_a := FLIGHT_PATH.Sample.new()
var _main_b := FLIGHT_PATH.Sample.new()
var _split_a := FLIGHT_PATH.Sample.new()
var _split_b := FLIGHT_PATH.Sample.new()
var _previous := FLIGHT_PATH.Sample.new()


func configure(path: FLIGHT_PATH) -> void:
	_path = path
	_current_chunk = -1000
	for instance: MeshInstance3D in _chunks.values():
		remove_child(instance)
		instance.queue_free()
	_chunks.clear()
	if _panel_material == null:
		_panel_material = _make_material(PANEL_SHADER)
		_trim_material = _make_material(TRIM_SHADER)
		_ring.resize(FACETS)
		for facet: int in range(FACETS):
			var angle := (float(facet) + 0.5) * TAU / FACETS
			_ring[facet] = Vector2(cos(angle), sin(angle))


func update_track(distance: float, _branch: int) -> void:
	var current := floori(distance / CHUNK_LENGTH)
	if current == _current_chunk:
		return
	_current_chunk = current
	var first := maxi(-1, current - CHUNKS_BEHIND)
	var last := current + CHUNKS_AHEAD
	for index: int in _chunks.keys():
		if index < first or index > last:
			var old: MeshInstance3D = _chunks[index]
			remove_child(old)
			old.queue_free()
			_chunks.erase(index)
	for index: int in range(first, last + 1):
		if not _chunks.has(index):
			_chunks[index] = _build_chunk(index)


func make_environment() -> Environment:
	var shader := Shader.new()
	shader.code = SKY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.sky_material = material

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b5cafc")
	environment.ambient_light_energy = 0.65
	return environment


func _make_material(source: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = source
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _build_chunk(index: int) -> MeshInstance3D:
	var origin := float(index) * CHUNK_LENGTH
	var panels := MeshDraft.new()
	var trim := MeshDraft.new()
	for segment: int in range(roundi(CHUNK_LENGTH / STEP)):
		var begin := origin + float(segment) * STEP
		var end := begin + STEP
		_path.sample(maxf(0.0, begin), 0, _main_a)
		_path.sample(maxf(0.0, end), 0, _main_b)

		var separated: bool = minf(_main_a.branch_offset, _main_b.branch_offset) >= SPLIT_RADIUS
		if separated:
			_path.sample(maxf(0.0, begin - STEP), 0, _previous)
			var opens_here: bool = _previous.branch_offset < SPLIT_RADIUS
			for branch: int in [-1, 1]:
				_path.sample(begin, branch, _split_a)
				_path.sample(end, branch, _split_b)
				var accent := LEFT_COLOR if branch < 0 else RIGHT_COLOR
				_add_segment(panels, trim, _split_a, _split_b, origin, begin, accent, false, opens_here)
		else:
			var accent: Color = REGION_COLORS[_main_a.region]
			_add_segment(panels, trim, _main_a, _main_b, origin, begin, accent, true, false)

	var mesh := ArrayMesh.new()
	panels.append_to(mesh, _panel_material)
	trim.append_to(mesh, _trim_material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.z = -origin
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _add_segment(panels: MeshDraft, trim: MeshDraft, a: FLIGHT_PATH.Sample, b: FLIGHT_PATH.Sample, origin: float,
		distance: float, accent: Color, shared: bool, fork_entry: bool) -> void:
	var start_z := origin - distance
	var end_z := start_z - STEP
	var center_a := Vector2(a.x, a.y)
	var center_b := Vector2(b.x, b.y)
	var radius_a := Vector2(a.radius_x, a.radius_y)
	var radius_b := Vector2(b.radius_x, b.radius_y)
	if shared:
		radius_a += Vector2(a.branch_offset, a.branch_offset * 0.05)
		radius_b += Vector2(b.branch_offset, b.branch_offset * 0.05)
	var opening := (float(a.open) + float(b.open)) * 0.5
	var cell := roundi(distance / STEP)
	var heavy_rib := fork_entry or (a.open < 0.18 and b.open >= 0.18) or (b.open < 0.18 and a.open >= 0.18)
	var has_rib := heavy_rib or posmod(cell, 4) == 0

	for facet: int in range(FACETS):
		var side_a := _ring[facet]
		var side_b := _ring[(facet + 1) % FACETS]
		var height := (side_a.y + side_b.y) * 0.5
		var cutoff := 0.16 + (1.0 - height) * 0.36
		if opening > cutoff:
			continue

		var wall := accent
		wall.a = 0.39 + absf(height) * 0.30
		if facet % 3 == 1:
			wall.a += 0.24
		panels.add_quad(_point(center_a, radius_a, side_a, start_z),
			_point(center_a, radius_a, side_b, start_z),
			_point(center_b, radius_b, side_b, end_z),
			_point(center_b, radius_b, side_a, end_z),
			wall, distance / 12.0, (distance + STEP) / 12.0)
		if has_rib:
			_add_rib(trim, center_a, center_b, radius_a, radius_b, side_a, side_b,
				start_z, accent, heavy_rib, wall.a)

	if opening > 0.52:
		if posmod(cell, 3) == 0:
			_add_beacons(trim, center_a, radius_a, start_z, accent)
		_add_guide_rails(trim, center_a, center_b, radius_a, radius_b, start_z, end_z, accent)
	if posmod(cell, 3) == 0:
		var marker_color := accent.darkened(0.48)
		var edge := Vector3(0.12, 0.0, 0.0)
		for lane: float in [-FLIGHT_PATH.LANE_X, FLIGHT_PATH.LANE_X]:
			var start_marker := Vector3(center_a.x + lane, center_a.y - radius_a.y * 0.72, start_z)
			var end_marker := Vector3(center_b.x + lane, center_b.y - radius_b.y * 0.72, end_z)
			end_marker = start_marker.lerp(end_marker, 0.67)
			trim.add_quad(start_marker - edge, start_marker + edge, end_marker + edge, end_marker - edge, marker_color)


func _point(center: Vector2, radius: Vector2, side: Vector2, z: float) -> Vector3:
	var position_2d := center + side * radius
	return Vector3(position_2d.x, position_2d.y, z)


func _add_rib(trim: MeshDraft, center_a: Vector2, center_b: Vector2, radius_a: Vector2,
		radius_b: Vector2, side_a: Vector2, side_b: Vector2, z: float, accent: Color,
		heavy: bool, strength: float) -> void:
	var inset := Vector2(0.22, 0.21) if heavy else Vector2(0.10, 0.09)
	var depth := 1.05 if heavy else 0.38
	var end := depth / STEP
	var inner_a := radius_a - inset
	var center_end := center_a.lerp(center_b, end)
	var inner_end := radius_a.lerp(radius_b, end) - inset
	var outer := accent.darkened(0.78 if heavy else 0.87)
	trim.add_quad(_point(center_a, radius_a, side_a, z), _point(center_a, radius_a, side_b, z),
		_point(center_a, inner_a, side_b, z), _point(center_a, inner_a, side_a, z), outer)
	trim.add_quad(_point(center_a, inner_a, side_a, z), _point(center_a, inner_a, side_b, z),
		_point(center_end, inner_end, side_b, z - depth),
		_point(center_end, inner_end, side_a, z - depth), outer)

	var edge_depth := 0.18 if heavy else 0.11
	var intensity := 0.82 if heavy else 0.27 + strength * 0.15
	var edge := accent.darkened(1.0 - intensity)
	var edge_end := edge_depth / STEP
	var edge_center := center_a.lerp(center_b, edge_end)
	var edge_inset := inset + Vector2(0.013, 0.013)
	var edge_radius := radius_a.lerp(radius_b, edge_end) - edge_inset
	var edge_start := radius_a - edge_inset
	trim.add_quad(_point(center_a, edge_start, side_a, z + 0.02),
		_point(center_a, edge_start, side_b, z + 0.02),
		_point(edge_center, edge_radius, side_b, z - edge_depth),
		_point(edge_center, edge_radius, side_a, z - edge_depth), edge)
	if heavy:
		var back_center := center_a.lerp(center_b, end - edge_end)
		var back_radius := radius_a.lerp(radius_b, end - edge_end) - edge_inset
		var end_radius := radius_a.lerp(radius_b, end) - edge_inset
		trim.add_quad(_point(back_center, back_radius, side_a, z - depth + edge_depth),
			_point(back_center, back_radius, side_b, z - depth + edge_depth),
			_point(center_end, end_radius, side_b, z - depth),
			_point(center_end, end_radius, side_a, z - depth), edge.darkened(0.23))


func _add_guide_rails(trim: MeshDraft, center_a: Vector2, center_b: Vector2, radius_a: Vector2,
		radius_b: Vector2, start_z: float, end_z: float, accent: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var marker_a := center_a + Vector2(side * radius_a.x * 0.74, -radius_a.y * 0.78)
		var marker_b := center_b + Vector2(side * radius_b.x * 0.74, -radius_b.y * 0.78)
		var a := Vector3(marker_a.x, marker_a.y, start_z)
		var b := Vector3(marker_b.x, marker_b.y, end_z)
		var thickness := Vector3(0.067, 0.0, 0.0)
		trim.add_quad(a - thickness, a + thickness, b + thickness, b - thickness, accent.darkened(0.70))


func _add_beacons(trim: MeshDraft, center: Vector2, radius: Vector2, z: float, accent: Color) -> void:
	var support := accent.darkened(0.86)
	var marker := accent.lightened(0.18)
	for side: float in [-1.0, 1.0]:
		var base := Vector3(center.x + side * radius.x * 0.96, center.y - radius.y * 0.91, z)
		var shoulder := base + Vector3(side * 0.30, 0.50, -0.22)
		var top := shoulder + Vector3(-side * 0.14, 0.63, -0.42)
		var breadth := Vector3(side * 0.20, 0.0, 0.0)
		var body_depth := Vector3(0.0, 0.0, -1.04)
		trim.add_quad(base - breadth, base + breadth, shoulder + breadth, shoulder - breadth, support)
		trim.add_quad(shoulder - breadth, shoulder + breadth, top + breadth, top - breadth, marker)
		trim.add_quad(shoulder + breadth, shoulder + breadth + body_depth,
			top + breadth + body_depth, top + breadth, marker.darkened(0.52))
		trim.add_quad(top - breadth, top + breadth, top + breadth + body_depth,
			top - breadth + body_depth, marker.darkened(0.25))
