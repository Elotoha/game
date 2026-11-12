extends SceneTree
var failures := 0
var checks := 0
const DT := 1.0 / 120.0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var car := VehicleModel.new()
	for i in 600:
		car.step(DT, Vector3.ZERO, false, 1.0)
	check(car.position.length() < 0.001 and absf(car.yaw_rate) < 0.001, "Rest must remain stable")
	for i in 600:
		car.step(DT, Vector3(0, 1, 0), false, 1.0)
	check(car.velocity.x > 15 and absf(car.position.y) < 0.001, "Straight acceleration without lateral drift")
	var speed := car.velocity.length()
	for i in 360:
		car.step(DT, Vector3(0, 0, 1), false, 1.0)
	check(car.velocity.length() < speed * 0.05 and car.velocity.x >= -0.05, "Brakes stop without reversing")
	var grip_car := VehicleModel.new()
	var slide_car := VehicleModel.new()
	grip_car.velocity = Vector2(22, 0)
	slide_car.velocity = Vector2(22, 0)
	for i in 90:
		grip_car.step(DT, Vector3(0.7, 0.3, 0), false, 1.0)
		slide_car.step(DT, Vector3(0.7, 0.3, 0), true, 1.0)
	check(absf(slide_car.rear_slip) > absf(grip_car.rear_slip) + 0.05, "Handbrake must break rear traction")
	check(absf(slide_car.yaw_rate) > 2.0 and absf(slide_car.rear_slip) > 0.7, "Handbrake can initiate a spin")
	var under := VehicleModel.new()
	under.config.front_stiffness = 90000
	under.velocity = Vector2(35, 0)
	for i in 100:
		under.step(DT, Vector3(1, 0, 0.5), false, 1.0)
	check(under.front_usage > 1, "Hard braking and steering saturate front tires")
	var peak := absf(car.tire_force(0.2, 65000, 5000, 1.0))
	check(peak <= 5000 and absf(car.tire_force(1, 65000, 5000, 1.0)) < peak, "Tire force bounded with sliding falloff")
	var left := VehicleModel.new()
	var right := VehicleModel.new()
	left.velocity = Vector2(15, 0)
	right.velocity = Vector2(15, 0)
	for i in 120:
		left.step(DT, Vector3(-0.3, 0, 0), false, 1.0)
		right.step(DT, Vector3(0.3, 0, 0), false, 1.0)
	check(left.position.y < 0 and right.position.y > 0 and is_equal_approx(left.position.y, -right.position.y), "Left/right forces have correct mirrored orientation")
	var a := VehicleModel.new()
	var b := VehicleModel.new()
	for i in 1200:
		var input := Vector3(sin(i * 0.01), 0.8, 0)
		a.step(DT, input, i % 300 > 250, 0.43)
		b.step(DT, input, i % 300 > 250, 0.43)
	check(a.position.is_equal_approx(b.position) and is_finite(a.yaw_rate) and a.velocity.length() < 100, "Repeatable finite off-road simulation")
	var track := Circuit.new()
	check(track.points[0] == track.points[-1] and track.length > 300, "Closed substantial circuit")
	check(track.sample(track.points[50]).distance < 0.01 and track.sample(Vector2(-50, -50)).distance > 5.5, "Surface detection")
	track.free()
	var lap := LapTracker.new()
	for p in [0.26, 0.51, 0.76, 0.95, 0.02]:
		lap.step(1, p, true)
	check(lap.laps == 1 and lap.best == 5, "Ordered complete lap")
	lap = LapTracker.new()
	for p in [0.95, 0.02, 0.95, 0.02]:
		lap.step(1, p, true)
	check(lap.laps == 0, "Crossing start backwards cannot award laps")
	print("PHYSICS / TRACK: %d checks, %d failures" % [checks, failures])
	call_deferred("scene_smoke")
func scene_smoke() -> void:
	var scene := load("res://scenes/race.tscn").instantiate() as Node2D
	root.add_child(scene)
	await physics_frame
	await physics_frame
	check(scene.camera.is_inside_tree(), "Main scene camera present")
	var start: Vector2 = scene.model.position
	scene.controller.held["gas"] = true
	for i in 60:
		await physics_frame
	check(scene.model.position.distance_to(start) > 0.2 and scene.camera.position.distance_to(start * Circuit.SCALE) > 1, "Throttle moves car and following camera")
	scene.hud.touches[0] = scene.hud.touch_buttons[0].get_global_rect().get_center()
	scene.hud.touches[1] = scene.hud.touch_buttons[4].get_global_rect().get_center()
	scene.hud.touches[2] = scene.hud.touch_buttons[2].get_global_rect().get_center()
	scene.hud.update_touches()
	scene.controller.poll()
	check(scene.controller.command.x == -1 and scene.controller.command.y == 1 and scene.controller.handbrake, "Three simultaneous touch controls")
	scene.toggle_pause()
	check(scene.hud.touches.is_empty() and scene.controller.held.values().all(func(v): return not v), "Pausing releases all touches")
	var before: Vector2 = scene.model.position
	await physics_frame
	check(scene.model.position == before, "Pause freezes simulation")
	scene.reset_car()
	check(scene.model.velocity == Vector2.ZERO and scene.lap.laps == 0, "Recovery resets car and lap")
	scene.free()
	print("TOTAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
