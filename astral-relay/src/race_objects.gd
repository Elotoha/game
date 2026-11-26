extends Node3D

# Each object family uses one instanced draw call, including the transient effects.
const FlightPath = preload("res://src/flight_path.gd")
const SHARDS := 100
const STREAKS := 44
const MINT := Color("4af6ce")
const ORANGE := Color("ff8456")
const GOLD := Color("ffd377")
const ICE := Color("dffdf5")

class Spark:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var life := 0.0
	var duration := 1.0
	var size := 1.0
	var color := Color.WHITE

var pools: Array[MultiMesh] = []
var counts := PackedInt32Array([0, 0, 0, 0, 0])
var beams: MultiMesh
var spark_mesh: MultiMesh
var streak_mesh: MultiMesh
var sparks: Array[Spark] = []
var spark_cursor := 0
var pulse_count := 0
var mesh_material: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var streak_positions := PackedVector3Array()
var streak_scale := PackedFloat32Array()
var streak_clock := 0.0


func _ready() -> void:
	mesh_material = StandardMaterial3D.new()
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_material.vertex_color_use_as_albedo = true
	mesh_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rng.seed = 386123672
	pools.resize(5)
	pools[FlightPath.DESTRUCTIBLE] = _pool(_hazard(false), 24)
	pools[FlightPath.SOLID] = _pool(_hazard(true), 24)
	pools[FlightPath.ENERGY] = _pool(_energy(), 24)
	pools[FlightPath.BOOST] = _pool(_boost(), 24)
	beams = _pool(_box(Vector3(0.085, 0.09, 1.48), ICE, MINT), 36)
	spark_mesh = _pool(_box(Vector3.ONE, Color.WHITE, Color("b4c9ff")), SHARDS, true)
	streak_mesh = _pool(_box(Vector3.ONE, Color.WHITE, Color("a8bad8")), STREAKS, true)
	for i in SHARDS:
		sparks.append(Spark.new())
	for i in STREAKS:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(7.0, 32.0)
		streak_positions.append(Vector3(cos(angle) * radius, sin(angle) * radius * 0.62, rng.randf_range(0.0, 180.0)))
		streak_scale.append(rng.randf_range(0.40, 1.45))


func _pool(mesh: Mesh, capacity: int, color := false) -> MultiMesh:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = color
	instances.mesh = mesh
	instances.instance_count = capacity
	instances.visible_instance_count = 0
	var display := MultiMeshInstance3D.new()
	display.multimesh = instances
	display.material_override = mesh_material
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Bounds encompass each moving pool at any point of the procedural course.
	display.custom_aabb = AABB(Vector3(-150, -150, -10000000), Vector3(300, 300, 10000200))
	add_child(display)
	return instances


func begin_entities() -> void:
	counts.fill(0)


func put_entity(kind: int, at: Vector3, half: Vector2, row: int, time: float) -> void:
	var pool := pools[kind]
	var current := counts[kind]
	if current >= pool.instance_count:
		return
	var transform_basis := Basis.from_scale(Vector3(half.x, half.y, 1.0))
	if kind == FlightPath.ENERGY:
		transform_basis = transform_basis * Basis(Vector3.UP, time * 2.9 + row)
		at.y += sin(time * 5.2 + row) * half.y * 0.12
	elif kind == FlightPath.BOOST:
		transform_basis = transform_basis * Basis(Vector3.BACK, sin(time * 2.5 + row) * 0.13)
	pool.set_instance_transform(current, Transform3D(transform_basis, at))
	counts[kind] += 1


func end_entities() -> void:
	for kind in range(1, pools.size()):
		pools[kind].visible_instance_count = counts[kind]


func begin_pulses() -> void:
	pulse_count = 0


func put_pulse(at: Vector3) -> void:
	if pulse_count + 2 > beams.instance_count:
		return
	beams.set_instance_transform(pulse_count, Transform3D(Basis.IDENTITY, at + Vector3(-0.43, 0.0, 0.0)))
	beams.set_instance_transform(pulse_count + 1, Transform3D(Basis.IDENTITY, at + Vector3(0.43, 0.0, 0.0)))
	pulse_count += 2


func end_pulses() -> void:
	beams.visible_instance_count = pulse_count


func clear_effects() -> void:
	for spark in sparks:
		spark.life = 0.0
	spark_mesh.visible_instance_count = 0
	streak_clock = 0.0


func burst(at: Vector3, kind: int) -> void:
	var primary: Color = [ORANGE, MINT, GOLD, ORANGE][kind]
	var pieces := 8 if kind == 3 else 24
	for i in pieces:
		var particle := sparks[spark_cursor]
		spark_cursor = (spark_cursor + 1) % SHARDS
		particle.position = at
		particle.velocity = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0), rng.randf_range(-30.0, 15.0))
		particle.duration = rng.randf_range(0.23, 0.67)
		particle.life = particle.duration
		particle.size = rng.randf_range(0.048, 0.20)
		particle.color = primary.lerp(ICE, rng.randf_range(0.0, 0.44))


func advance(dt: float, distance: float, speed: float, boosted: bool, racing: bool, view: Vector3) -> void:
	var visible := 0
	for spark in sparks:
		if spark.life <= 0.0:
			continue
		spark.life -= dt
		spark.position += spark.velocity * dt
		var fraction := maxf(0.0, spark.life / spark.duration)
		var size := spark.size * fraction
		var basis := Basis(Vector3.UP, spark.life * 7.0).scaled(Vector3(size, size, size * 2.7))
		spark_mesh.set_instance_transform(visible, Transform3D(basis, spark.position))
		spark_mesh.set_instance_color(visible, spark.color.lerp(Color("161826"), 1.0 - fraction))
		visible += 1
	spark_mesh.visible_instance_count = visible
	if not racing:
		streak_mesh.visible_instance_count = 0
		return
	streak_clock += dt * (speed + 14.0)
	var amount := STREAKS if boosted else 16
	var light := Color("5c8d9f") if boosted else Color("3b566f")
	for i in amount:
		var streak := streak_positions[i]
		var depth := fposmod(streak.z - streak_clock, 174.0)
		var location := Vector3(view.x + streak.x, view.y + streak.y, -distance - depth + 6.0)
		var width := 0.018 * streak_scale[i] * (1.65 if boosted else 1.0)
		var length := streak_scale[i] * (5.2 if boosted else 1.6)
		streak_mesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(width, width, length)), location))
		streak_mesh.set_instance_color(i, light)
	streak_mesh.visible_instance_count = amount


func _hazard(solid: bool) -> ArrayMesh:
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var armor := Color("30314b") if solid else Color("5b2338")
	var face := Color("252239") if solid else Color("311e34")
	var trim := GOLD if solid else ORANGE
	var front := _corners(1.0, 1.0, 0.60, 0.21)
	var inner := _corners(0.76, 0.72, 0.69, 0.18)
	var back := _corners(0.93, 0.90, -0.72, 0.20)
	for i in 8:
		var k := (i + 1) % 8
		_quad(surf, front[i], back[i], back[k], front[k], armor.darkened(0.22 + float(i % 3) * 0.10))
		_quad(surf, inner[i], front[i], front[k], inner[k], armor.lightened(0.12 if i % 2 == 0 else 0.0))
		_tri(surf, Vector3(0, 0, 0.69), inner[i], inner[k], face)
		_tri(surf, Vector3(0, 0, -0.72), back[i], back[k], armor.darkened(0.28))
		if i % 2 == 0:
			_strip(surf, front[i].lerp(inner[i], 0.38) + Vector3.BACK * 0.014, front[k].lerp(inner[k], 0.38) + Vector3.BACK * 0.014, 0.045, trim)
	if solid:
		for x in [-0.37, 0.0, 0.37]:
			_strip(surf, Vector3(x - 0.11, -0.26, 0.71), Vector3(x + 0.11, 0.26, 0.71), 0.095, trim)
	else:
		for direction in [-1.0, 1.0]:
			_strip(surf, Vector3(-0.39, -0.35 * direction, 0.71), Vector3(0.39, 0.35 * direction, 0.71), 0.07, trim)
	return surf.commit()


func _energy() -> ArrayMesh:
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [Vector3(0, 0.77, 0), Vector3(0.67, 0, 0), Vector3(0, 0, 0.65), Vector3(-0.67, 0, 0), Vector3(0, 0, -0.65)]
	for i in 4:
		var a: Vector3 = vertices[1 + i]
		var b: Vector3 = vertices[1 + (i + 1) % 4]
		_tri(surf, vertices[0], a, b, MINT.lerp(ICE, float(i) * 0.15))
		_tri(surf, -vertices[0], b, a, Color("187f80").lerp(MINT, float(i) * 0.18))
		var edge := (a + b).normalized() * 0.032
		_quad(surf, a + edge + Vector3.UP * 0.055, b + edge + Vector3.UP * 0.055, b + edge - Vector3.UP * 0.055, a + edge - Vector3.UP * 0.055, ICE)
	return surf.commit()


func _boost() -> ArrayMesh:
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var border := _corners(0.91, 0.91, 0.14, 0.41)
	var inset := _corners(0.68, 0.68, 0.17, 0.30)
	for i in 8:
		var k := (i + 1) % 8
		_quad(surf, border[i], border[k], inset[k], inset[i], GOLD if i % 2 == 0 else Color("ed7951"))
		_quad(surf, border[i], border[i] - Vector3.BACK * 0.44, border[k] - Vector3.BACK * 0.44, border[k], Color("633a47"))
	for y in [-0.26, 0.14]:
		_strip(surf, Vector3(-0.43, y, 0.14), Vector3(0.0, y + 0.27, 0.14), 0.105, ICE)
		_strip(surf, Vector3(0.0, y + 0.27, 0.14), Vector3(0.43, y, 0.14), 0.105, ICE)
	return surf.commit()


func _box(extent: Vector3, light: Color, dark: Color) -> ArrayMesh:
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := extent * 0.5
	var a := Vector3(-p.x, -p.y, p.z)
	var b := Vector3(p.x, -p.y, p.z)
	var c := Vector3(p.x, p.y, p.z)
	var d := Vector3(-p.x, p.y, p.z)
	var depth := Vector3(0, 0, extent.z)
	_quad(surf, a, b, c, d, light)
	_quad(surf, a - depth, b - depth, c - depth, d - depth, dark)
	_quad(surf, a, b, b - depth, a - depth, dark)
	_quad(surf, b, c, c - depth, b - depth, light)
	_quad(surf, c, d, d - depth, c - depth, light)
	_quad(surf, d, a, a - depth, d - depth, dark)
	return surf.commit()


func _corners(x: float, y: float, z: float, bevel: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-x + bevel, -y, z), Vector3(x - bevel, -y, z), Vector3(x, -y + bevel, z), Vector3(x, y - bevel, z),
		Vector3(x - bevel, y, z), Vector3(-x + bevel, y, z), Vector3(-x, y - bevel, z), Vector3(-x, -y + bevel, z),
	])


func _strip(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var side := (b - a).cross(Vector3.BACK).normalized() * width * 0.5
	_quad(surface, a - side, a + side, b + side, b - side, color)


func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(surface, a, b, c, color)
	_tri(surface, a, c, d, color)
