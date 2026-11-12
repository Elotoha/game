extends Node2D
## Composition root: one simulation, view and controller per entrant in future races.
var circuit := Circuit.new()
var model := VehicleModel.new()
var controller := PlayerInput.new()
var lap := LapTracker.new()
var car := CarView.new()
var camera := Camera2D.new()
var hud := RaceHud.new()
var paused := false
var surface := "ASPHALTE"
var skid_segments: Array[PackedVector2Array] = []
var last_rear := Vector2.ZERO
var was_sliding := false

func _ready() -> void:
	add_child(circuit)
	add_child(car)
	add_child(camera)
	camera.zoom = Vector2(0.84, 0.84)
	hud.circuit = circuit
	hud.model = model
	hud.controller = controller
	hud.reset_action = reset_car
	hud.pause_action = toggle_pause
	add_child(hud)
	reset_car()

func reset_car() -> void:
	# First anchor defines the start gate and ordered lap progress.
	model.reset(circuit.points[0], (circuit.points[1] - circuit.points[0]).angle())
	lap = LapTracker.new()
	controller.clear()
	hud.release_touches()
	was_sliding = false
	camera.position = model.position * Circuit.SCALE
	car.position = camera.position
	car.rotation = model.heading

func toggle_pause() -> void:
	paused = not paused
	hud.release_touches()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		paused = true
		controller.clear()
		if is_instance_valid(hud) and hud.is_inside_tree():
			hud.release_touches()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			reset_car()
		if event.keycode == KEY_ESCAPE:
			toggle_pause()

func _physics_process(dt: float) -> void:
	if not paused:
		controller.poll()
		var road := circuit.sample(model.position)
		var on_road: bool = road.distance <= Circuit.WIDTH / 2
		surface = "ASPHALTE" if on_road else "HERBE"
		model.step(dt, controller.command, controller.handbrake, 1.0 if on_road else 0.43)
		if not on_road:
			model.velocity *= exp(-0.65 * dt)
		lap.step(dt, road.progress, on_road)
		var rear := (model.position - Vector2.from_angle(model.heading) * model.config.rear_length) * Circuit.SCALE
		var sliding := model.velocity.length() > 4 and (model.rear_usage > 0.9 or controller.handbrake)
		if sliding and was_sliding:
			var side := Vector2.from_angle(model.heading).orthogonal() * 14
			skid_segments.append(PackedVector2Array([last_rear + side, rear + side, last_rear - side, rear - side]))
			if skid_segments.size() > 1600:
				skid_segments.pop_front()
		last_rear = rear
		was_sliding = sliding
		car.position = model.position * Circuit.SCALE
		car.rotation = model.heading
		car.steering = model.steering
		car.queue_redraw()
		var target := car.position + model.velocity * 7.0
		camera.position = camera.position.lerp(target, 1.0 - exp(-5.0 * dt))
	queue_redraw()
	hud.refresh(lap, surface, paused)

func _draw() -> void:
	for segment in skid_segments:
		draw_line(segment[0], segment[1], Color(0.06, 0.09, 0.10, 0.48), 4, true)
		draw_line(segment[2], segment[3], Color(0.06, 0.09, 0.10, 0.48), 4, true)
