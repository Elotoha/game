class_name Circuit
extends Node2D
const SCALE := 20.0
const WIDTH := 11.0
var points := PackedVector2Array()
var distances := PackedFloat32Array()
var length := 0.0

func _init() -> void:
	z_index = -10
	var anchors := PackedVector2Array([Vector2(23, 25), Vector2(75, 25), Vector2(103, 37), Vector2(109, 63), Vector2(91, 82), Vector2(66, 75), Vector2(55, 100), Vector2(26, 104), Vector2(10, 83), Vector2(21, 61), Vector2(7, 43)])
	for i in anchors.size():
		var a := anchors[(i - 1 + anchors.size()) % anchors.size()]
		var b := anchors[i]
		var c := anchors[(i + 1) % anchors.size()]
		var d := anchors[(i + 2) % anchors.size()]
		for j in 16:
			var t := j / 16.0
			points.append(0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t))
	points.append(points[0])
	distances.append(0.0)
	for i in range(1, points.size()):
		length += points[i].distance_to(points[i - 1])
		distances.append(length)

func sample(at: Vector2) -> Dictionary:
	var best := INF
	var progress := 0.0
	var nearest := Vector2.ZERO
	var tangent := Vector2.RIGHT
	for i in points.size() - 1:
		var segment := points[i + 1] - points[i]
		var t := clampf((at - points[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var foot := points[i] + segment * t
		var distance := at.distance_squared_to(foot)
		if distance < best:
			best = distance
			nearest = foot
			tangent = segment.normalized()
			progress = distances[i] + segment.length() * t
	return {"distance": sqrt(best), "progress": progress / length, "nearest": nearest, "tangent": tangent}

func _draw() -> void:
	draw_rect(Rect2(-3000, -3000, 8500, 8500), Color("243d33"))
	# Deterministic infield decoration; no imported assets required.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 340:
		var p := Vector2(rng.randf_range(-15, 135), rng.randf_range(-10, 130))
		if sample(p).distance > 10:
			draw_circle(p * SCALE + Vector2(5, 8), 16, Color("192f29"))
			draw_circle(p * SCALE, rng.randf_range(8, 18), Color("325444"))
	var line := PackedVector2Array()
	for p in points:
		line.append(p * SCALE)
	draw_polyline(line, Color("142824"), (WIDTH + 3.2) * SCALE, true)
	draw_polyline(line, Color("c6bca0"), (WIDTH + 1.4) * SCALE, true)
	for i in points.size() - 1:
		draw_line(line[i], line[i + 1], Color("b95e4e") if i % 4 < 2 else Color("e7dec6"), (WIDTH + 0.8) * SCALE, true)
	draw_polyline(line, Color("353e42"), WIDTH * SCALE, true)
	for i in range(0, points.size() - 1, 3):
		draw_line(line[i], line[i + 1], Color("758080"), 2.0, true)
	draw_set_transform(points[0] * SCALE, (points[1] - points[0]).angle())
	for x in 8:
		for y in 2:
			draw_rect(Rect2(Vector2(y * 10, -WIDTH * SCALE / 2 + x * WIDTH * SCALE / 8), Vector2(10, WIDTH * SCALE / 8)), Color("eee9d7") if (x + y) % 2 == 0 else Color("202a2c"))
