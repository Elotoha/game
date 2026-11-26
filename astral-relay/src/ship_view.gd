extends Node3D
## Procedural delta-wing racer. Geometry is built once, then bank and exhaust
## animate independently of the gameplay node and collision shape.

const IVORY := Color(0xf1f8f5ff)
const SILVER := Color(0xacc4cdff)
const STEEL := Color(0x6f8b9dff)
const GRAPHITE := Color(0x2a3c52ff)
const SHADOW := Color(0x101e30ff)
const GLASS := Color(0x28627aff)
const ICE := Color(0xb0fff4ff)
const TEAL := Color(0x38e8caff)
const ORANGE := Color(0xffa350ff)
const ENGINE_Z := 1.49

var _pivot: Node3D
var _exhaust: MeshInstance3D
var _muzzles: MeshInstance3D
var _phase: float
var _fire_time: float
var _was_firing: bool


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_build_hull()
	_exhaust = _build_exhaust()
	_exhaust.position.z = ENGINE_Z
	_muzzles = _build_muzzles()
	_muzzles.hide()


func animate(delta: float, thrust: float, steering: Vector2, firing: bool, visible_alive: bool) -> void:
	visible = visible_alive
	if not visible_alive:
		_fire_time = 0.0
		_was_firing = false
		return
	if not is_instance_valid(_pivot):
		return
	var response := 1.0 - exp(-11.0 * delta)
	_pivot.rotation.x = lerpf(_pivot.rotation.x, steering.y * 0.12, response)
	_pivot.rotation.y = lerpf(_pivot.rotation.y, -steering.x * 0.13, response)
	_pivot.rotation.z = lerpf(_pivot.rotation.z, -steering.x * 0.53, response)

	var power := clampf(thrust, 0.0, 1.0)
	_phase += delta * (20.0 + power * 14.0)
	var flicker := sin(_phase) * 0.055 + sin(_phase * 1.71) * 0.045
	_exhaust.scale.z = 0.44 + power * 0.92 + flicker
	if firing and not _was_firing:
		_fire_time = 0.09
	_was_firing = firing
	_fire_time = maxf(0.0, _fire_time - delta)
	_muzzles.visible = _fire_time > 0.0


func _build_hull() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nose := Vector3(0.0, 0.055, -2.14)
	var spine_front := Vector3(0.0, 0.34, -1.14)
	var spine_mid := Vector3(0.0, 0.46, 0.02)
	var spine_rear := Vector3(0.0, 0.28, 1.42)
	var keel := Vector3(0.0, -0.31, 0.57)
	var aft_keel := Vector3(0.0, -0.17, 1.48)
	var glass_crest := Vector3(0.0, 0.68, -0.29)
	var glass_aft := Vector3(0.0, 0.51, 0.36)

	for side: float in [-1.0, 1.0]:
		var fore_chine := _mirrored(side, 0.31, 0.055, -1.28)
		var mid_chine := _mirrored(side, 0.55, 0.055, -0.19)
		var aft_chine := _mirrored(side, 0.43, 0.02, 1.41)
		var dorsal := IVORY if side < 0.0 else SILVER.lightened(0.28)
		_triangle(mesh, nose, fore_chine, spine_front, dorsal)
		_quad(mesh, spine_front, fore_chine, mid_chine, spine_mid, dorsal)
		_quad(mesh, spine_mid, mid_chine, aft_chine, spine_rear, SILVER)
		_triangle(mesh, nose, keel, fore_chine, GRAPHITE)
		_triangle(mesh, fore_chine, keel, mid_chine, STEEL)
		_triangle(mesh, mid_chine, keel, aft_chine, GRAPHITE)
		_triangle(mesh, aft_chine, keel, aft_keel, SHADOW)
		_triangle(mesh, aft_chine, aft_keel, spine_rear, STEEL.darkened(0.24))

		var glass_side := _mirrored(side, 0.255, 0.38, -0.26)
		var glass_tail := _mirrored(side, 0.22, 0.35, 0.38)
		_triangle(mesh, spine_front, glass_side, glass_crest, GLASS.darkened(0.17))
		_quad(mesh, glass_crest, glass_side, glass_tail, glass_aft, GLASS)
		_triangle(mesh, glass_aft, glass_tail, spine_mid, SHADOW)
		_triangle(
			mesh, glass_crest + Vector3(0.0, 0.006, 0.0),
			_mirrored(side, 0.08, 0.592, -0.23),
			glass_aft + Vector3(0.0, 0.008, 0.0), ICE.darkened(0.29)
		)

		_build_wing(mesh, side)
		_build_engine(mesh, side)

	_insert(mesh, "Delta hull", false)


func _build_wing(mesh: SurfaceTool, side: float) -> void:
	var root := _mirrored(side, 0.28, 0.10, -0.87)
	var shoulder := _mirrored(side, 1.02, -0.045, -0.04)
	var tip := _mirrored(side, 1.45, -0.11, 0.66)
	var spoiler := _mirrored(side, 1.42, -0.04, 1.06)
	var notch := _mirrored(side, 1.10, -0.04, 1.21)
	var aft := _mirrored(side, 0.39, 0.03, 1.13)
	var fold := _mirrored(side, 0.88, 0.02, 0.51)
	var keel := _mirrored(side, 0.72, -0.22, 0.68)
	_triangle(mesh, root, shoulder, fold, IVORY)
	_triangle(mesh, root, fold, aft, SILVER)
	_triangle(mesh, shoulder, tip, fold, IVORY)
	_quad(mesh, fold, tip, spoiler, notch, SILVER)
	_triangle(mesh, fold, notch, aft, STEEL)
	_triangle(mesh, root, keel, shoulder, GRAPHITE)
	_triangle(mesh, shoulder, keel, tip, STEEL)
	_quad(mesh, tip, keel, notch, spoiler, GRAPHITE)
	_triangle(mesh, notch, keel, aft, SHADOW)

	# The interrupted orange leading edge stays visible from the chase camera.
	_quad(
		mesh, _mirrored(side, 1.00, -0.033, -0.02),
		_mirrored(side, 1.435, -0.097, 0.658),
		_mirrored(side, 1.31, -0.062, 0.78),
		_mirrored(side, 1.025, -0.007, 0.33), ORANGE
	)
	_triangle(
		mesh, _mirrored(side, 1.14, -0.027, 0.70),
		_mirrored(side, 1.27, -0.025, 0.96),
		_mirrored(side, 1.07, -0.02, 1.10), GRAPHITE
	)
	_quad(
		mesh, _mirrored(side, 1.415, -0.027, 1.05),
		_mirrored(side, 1.24, -0.028, 1.139),
		_mirrored(side, 1.22, -0.027, 1.095),
		_mirrored(side, 1.387, -0.024, 1.01), TEAL
	)
	var fin_front := _mirrored(side, 0.97, 0.04, 0.20)
	var fin_tip := _mirrored(side, 1.08, 0.31, 0.92)
	var fin_tail := _mirrored(side, 1.02, 0.01, 1.17)
	var fin_base := _mirrored(side, 0.90, 0.03, 0.89)
	_triangle(mesh, fin_front, fin_tip, fin_base, IVORY)
	_triangle(mesh, fin_base, fin_tip, fin_tail, STEEL)
	_triangle(mesh, fin_front, fin_tail, fin_tip, GRAPHITE)
	_triangle(
		mesh, fin_tip + Vector3(side * 0.005, 0.006, 0.0),
		_mirrored(side, 1.04, 0.215, 0.70),
		_mirrored(side, 1.065, 0.19, 1.025), ORANGE
	)


func _build_engine(mesh: SurfaceTool, side: float) -> void:
	var x := side * 0.70
	var y := 0.045
	var aft_center := Vector3(x, y, ENGINE_Z - 0.025)
	for segment in range(8):
		var theta := TAU * (float(segment) + 0.5) / 8.0
		var next := theta + TAU / 8.0
		var front := _engine_ring(x, y, -0.41, 0.10, theta)
		var front_next := _engine_ring(x, y, -0.41, 0.10, next)
		var mid := _engine_ring(x, y, 0.21, 0.225, theta)
		var mid_next := _engine_ring(x, y, 0.21, 0.225, next)
		var casing := _engine_ring(x, y, 1.23, 0.225, theta)
		var casing_next := _engine_ring(x, y, 1.23, 0.225, next)
		var rim := _engine_ring(x, y, ENGINE_Z, 0.245, theta)
		var rim_next := _engine_ring(x, y, ENGINE_Z, 0.245, next)
		var inner := _engine_ring(x, y, ENGINE_Z, 0.165, theta)
		var inner_next := _engine_ring(x, y, ENGINE_Z, 0.165, next)
		var plume := _engine_ring(x, y, ENGINE_Z - 0.026, 0.112, theta)
		var plume_next := _engine_ring(x, y, ENGINE_Z - 0.026, 0.112, next)
		var light := (sin(theta + TAU / 16.0) + 1.0) * 0.5
		_quad(mesh, front, front_next, mid_next, mid, GRAPHITE.lerp(IVORY, light))
		_quad(mesh, mid, mid_next, casing_next, casing, GRAPHITE.lerp(SILVER, light))
		_quad(mesh, casing, casing_next, rim_next, rim, GRAPHITE.lerp(STEEL, light))
		_quad(mesh, rim, rim_next, inner_next, inner, IVORY.darkened(0.18))
		_quad(mesh, inner, inner_next, plume_next, plume, TEAL.darkened(0.2))
		_triangle(mesh, plume, plume_next, aft_center, ICE)


func _build_exhaust() -> MeshInstance3D:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var origin := Vector3(side * 0.70, 0.045, -0.01)
		for angle in [0.0, TAU / 6.0, TAU / 3.0]:
			var axis := Vector3(cos(angle), sin(angle), 0.0)
			_plume(mesh, origin, axis, 0.23, 2.80, Color(0x20e4b779), Color(0x3391d900))
			_plume(mesh, origin, axis, 0.09, 1.64, Color(0xcafff4d2), Color(0x50ffe500))
	return _insert(mesh, "Twin ion trails", true)


func _plume(mesh: SurfaceTool, origin: Vector3, axis: Vector3, width: float, length: float, head: Color, tail: Color) -> void:
	var a := origin - axis * width
	var b := origin + axis * width
	var c := origin + Vector3(0.0, 0.0, length) + axis * width * 0.10
	var d := origin + Vector3(0.0, 0.0, length) - axis * width * 0.10
	_vertex(mesh, a, head)
	_vertex(mesh, b, head)
	_vertex(mesh, c, tail)
	_vertex(mesh, a, head)
	_vertex(mesh, c, tail)
	_vertex(mesh, d, tail)


func _build_muzzles() -> MeshInstance3D:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var origin := Vector3(side * 0.50, 0.10, -1.02)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP]:
			_plume(mesh, origin, axis, 0.15, -0.61, Color(0xfeffffff), Color(0x61fff100))
	return _insert(mesh, "Pulse muzzles", true)


func _insert(surface: SurfaceTool, label: String, translucent: bool) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(instance)
	return instance


func _engine_ring(x: float, y: float, z: float, radius: float, theta: float) -> Vector3:
	return Vector3(x + cos(theta) * radius, y + sin(theta) * radius * 0.83, z)


func _mirrored(side: float, x: float, y: float, z: float) -> Vector3:
	return Vector3(side * x, y, z)


func _vertex(mesh: SurfaceTool, position_3d: Vector3, color: Color) -> void:
	mesh.set_color(color)
	mesh.add_vertex(position_3d)


func _triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	_vertex(mesh, a, color)
	_vertex(mesh, b, color)
	_vertex(mesh, c, color)


func _quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(mesh, a, b, c, color)
	_triangle(mesh, a, c, d, color)
