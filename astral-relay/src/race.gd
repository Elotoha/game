extends Node3D

const FlightPath = preload("res://src/flight_path.gd")
const TrackView = preload("res://src/track_view.gd")
const ShipView = preload("res://src/ship_view.gd")
const RaceAudio = preload("res://src/race_audio.gd")
const RaceHud = preload("res://src/race_hud.gd")
const Flotsam = preload("res://src/race_objects.gd")

const SAVE_PATH := "user://pilot.cfg"
const COURSE_SEED := 8317204
const START_SPEED := 73.0
const TOP_SPEED := 137.0
const BOOST_TIME := 3.2
const MAX_SHIELD := 3
const STEP := 1.0 / 120.0
const SHIP_RADIUS := 0.64

enum State { MENU, FLIGHT, PAUSE, RESULTS }

class Pulse:
	var distance := 0.0
	var offset := Vector2.ZERO
	var branch := 0
	var active := false

var path := FlightPath.new(COURSE_SEED)
var track := TrackView.new()
var ship := ShipView.new()
var audio := RaceAudio.new()
var hud := RaceHud.new()
var objects := Flotsam.new()
var camera := Camera3D.new()
var ship_path := FlightPath.Sample.new()
var camera_path := FlightPath.Sample.new()
var aim_path := FlightPath.Sample.new()
var scratch_path := FlightPath.Sample.new()
var entity := FlightPath.Entity.new()
var pulses: Array[Pulse] = []
var consumed := {}
var touches := {}
var held_keys := {}
var mouse_held := false
var mouse_position := Vector2.ZERO
var firing := false
var tap_fire := false
var steer := Vector2.ZERO
var state := State.MENU
var distance := 0.0
var speed := START_SPEED
var offset := Vector2.ZERO
var velocity := Vector2.ZERO
var branch := 0
var preferred_side := 1
var shield := MAX_SHIELD
var stored_cells := 0
var boost := 0.0
var invulnerable := 0.0
var hit_kick := 0.0
var shot_cooldown := 0.0
var combo := 1
var chain := 0
var chain_time := 0.0
var bonus := 0
var best := 0
var elapsed := 0.0
var accumulator := 0.0
var hud_clock := 0.0
var ambient_clock := 0.0
var viewport_camera_ready := false
var route_message := ""
var route_time := 0.0
var muted := false
var app_suspended := false


func _ready() -> void:
	_load_pilot()
	track.configure(path)
	add_child(track)
	var world := WorldEnvironment.new()
	world.environment = track.make_environment()
	add_child(world)
	add_child(objects)
	add_child(ship)
	add_child(camera)
	camera.current = true
	camera.fov = 58.0
	camera.near = 0.16
	camera.far = 490.0
	add_child(audio)
	add_child(hud)
	for i in 18:
		pulses.append(Pulse.new())
	hud.launch_requested.connect(_launch)
	hud.pause_requested.connect(_pause)
	hud.resume_requested.connect(_resume)
	hud.mute_requested.connect(_toggle_mute)
	hud.menu_requested.connect(_go_to_menu)
	audio.set_muted(muted)
	hud.set_muted(muted)
	if OS.has_feature("android"):
		get_viewport().size_changed.connect(_fit_mobile_rendering)
		_fit_mobile_rendering()
	_go_to_menu()


func _fit_mobile_rendering() -> void:
	var size := get_window().size
	var pixels := maxf(1.0, float(size.x) * float(size.y))
	get_viewport().scaling_3d_scale = minf(1.0, sqrt(1440000.0 / pixels))


func _load_pilot() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		best = maxi(0, int(file.get_value("pilot", "best", 0)))
		muted = bool(file.get_value("pilot", "muted", false))


func _save_pilot() -> void:
	var file := ConfigFile.new()
	file.set_value("pilot", "best", best)
	file.set_value("pilot", "muted", muted)
	file.save(SAVE_PATH)


func _toggle_mute() -> void:
	muted = not muted
	audio.set_muted(muted)
	hud.set_muted(muted)
	_save_pilot()


func _reset(where: float) -> void:
	distance = where
	speed = START_SPEED
	offset = Vector2.ZERO
	velocity = Vector2.ZERO
	branch = 0
	preferred_side = 1
	shield = MAX_SHIELD
	stored_cells = 0
	boost = 0.0
	invulnerable = 0.0
	hit_kick = 0.0
	shot_cooldown = 0.0
	combo = 1
	chain = 0
	chain_time = 0.0
	bonus = 0
	elapsed = 0.0
	accumulator = 0.0
	hud_clock = 0.0
	viewport_camera_ready = false
	route_message = ""
	route_time = 0.0
	consumed.clear()
	for pulse in pulses:
		pulse.active = false
	objects.clear_effects()
	_clear_controls()


func _go_to_menu() -> void:
	state = State.MENU
	_reset(2.0)
	audio.set_racing(false)
	hud.show_menu(best)


func _launch() -> void:
	_reset(0.0)
	state = State.FLIGHT
	audio.set_racing(true)
	hud.show_run()
	_update_hud()


func _pause() -> void:
	if state != State.FLIGHT:
		return
	state = State.PAUSE
	accumulator = 0.0
	_clear_controls()
	audio.set_racing(false)
	hud.show_pause()


func _resume() -> void:
	if state != State.PAUSE or app_suspended:
		return
	state = State.FLIGHT
	_clear_controls()
	audio.set_racing(true)
	hud.show_run()
	_update_hud()


func _finish() -> void:
	state = State.RESULTS
	_clear_controls()
	audio.cue(RaceAudio.CRASH)
	audio.set_racing(false)
	var total := _score()
	var new_best := total > best
	if new_best:
		best = total
		_save_pilot()
	hud.show_result(total, best, distance, new_best)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			app_suspended = true
			_pause()
			audio.set_paused(true)
		NOTIFICATION_APPLICATION_RESUMED:
			app_suspended = false
			audio.set_paused(false)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if state == State.FLIGHT:
				_pause()
			elif state == State.MENU:
				get_tree().quit()
			else:
				_go_to_menu()


func _clear_controls() -> void:
	touches.clear()
	held_keys.clear()
	mouse_held = false
	firing = false
	tap_fire = false
	steer = Vector2.ZERO


func _input(event: InputEvent) -> void:
	# Consume releases even when a drag ends over a menu control.
	if event is InputEventScreenTouch and not event.pressed:
		touches.erase(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		mouse_held = false
	elif event is InputEventKey and not event.pressed:
		held_keys.erase(event.keycode)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state == State.FLIGHT:
			_pause()
		elif state == State.PAUSE:
			_resume()
		elif state == State.RESULTS:
			_go_to_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if state == State.MENU or state == State.RESULTS:
				_launch()
			elif state == State.PAUSE:
				_resume()
			return
		if state == State.FLIGHT:
			held_keys[event.keycode] = true
			if event.keycode == KEY_SPACE:
				tap_fire = true
	if state != State.FLIGHT:
		return
	if event is InputEventScreenTouch and event.pressed:
		var p := _touch_position(event.position)
		touches[event.index] = p
		tap_fire = tap_fire or _zone(p) == Vector2.ZERO
	elif event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index] = _touch_position(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed:
			mouse_held = true
			mouse_position = _touch_position(event.position)
			tap_fire = tap_fire or _zone(mouse_position) == Vector2.ZERO
	elif event is InputEventMouseMotion and mouse_held:
		mouse_position = _touch_position(event.position)


func _touch_position(p: Vector2) -> Vector2:
	return p / get_viewport().get_visible_rect().size


func _zone(p: Vector2) -> Vector2:
	return Vector2(
		float(p.x > 0.65) - float(p.x < 0.35),
		float(p.y < 0.30) - float(p.y > 0.70)
	)


func _read_controls() -> void:
	var right := held_keys.has(KEY_RIGHT) or held_keys.has(KEY_D)
	var left := held_keys.has(KEY_LEFT) or held_keys.has(KEY_A) or held_keys.has(KEY_Q)
	var up := held_keys.has(KEY_UP) or held_keys.has(KEY_W) or held_keys.has(KEY_Z)
	var down := held_keys.has(KEY_DOWN) or held_keys.has(KEY_S)
	steer = Vector2(float(right) - float(left), float(up) - float(down))
	firing = held_keys.has(KEY_SPACE)
	for p: Vector2 in touches.values():
		var input := _zone(p)
		steer += input
		firing = firing or input == Vector2.ZERO
	if mouse_held:
		var input := _zone(mouse_position)
		steer += input
		firing = firing or input == Vector2.ZERO
	steer = Vector2(clampf(steer.x, -1, 1), clampf(steer.y, -1, 1)).limit_length()


func _process(delta: float) -> void:
	ambient_clock += delta
	if state == State.FLIGHT:
		_read_controls()
		accumulator += minf(delta, 0.06)
		while accumulator >= STEP and state == State.FLIGHT:
			_step(STEP)
			accumulator -= STEP
		hud_clock -= delta
		if hud_clock <= 0.0 and state == State.FLIGHT:
			hud_clock = 0.065
			_update_hud()
	elif state == State.RESULTS:
		hit_kick = maxf(0.0, hit_kick - delta)
	if state != State.PAUSE:
		_draw_world(minf(delta, 0.052))


func _step(dt: float) -> void:
	elapsed += dt
	boost = maxf(0.0, boost - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	hit_kick = maxf(0.0, hit_kick - dt)
	shot_cooldown = maxf(0.0, shot_cooldown - dt)
	route_time = maxf(0.0, route_time - dt)
	chain_time = maxf(0.0, chain_time - dt)
	if chain_time == 0.0:
		chain = 0
		combo = 1

	var target_speed := minf(TOP_SPEED, START_SPEED + elapsed * 1.38)
	if boost > 0.0:
		target_speed += 47.0
	if hit_kick > 0.0:
		target_speed *= 0.68
	speed = lerpf(speed, target_speed, 1.0 - exp(-5.2 * dt))
	var previous := distance
	distance += speed * dt

	var target_velocity := steer * Vector2(22.0, 17.0)
	velocity = velocity.move_toward(target_velocity, (132.0 if steer != Vector2.ZERO else 175.0) * dt)
	offset += velocity * dt
	if absf(steer.x) > 0.2:
		preferred_side = 1 if steer.x > 0.0 else -1

	if path.is_split(distance):
		if branch == 0:
			branch = path.split_choice(distance, offset.x, preferred_side)
			route_message = "←  FAILLE" if branch < 0 else "ORBITALE  →"
			route_time = 1.6
	else:
		branch = 0
	path.sample(distance, branch, ship_path)
	var limits := Vector2(ship_path.radius_x * 0.78, ship_path.radius_y * 0.75)
	var normalized_offset := offset / limits
	if normalized_offset.length_squared() > 1.0:
		offset = normalized_offset.normalized() * limits

	if (firing or tap_fire) and shot_cooldown <= 0.0:
		_fire()
		tap_fire = false
	_step_pulses(dt)
	_step_entities(previous)


func _fire() -> void:
	for pulse in pulses:
		if not pulse.active:
			pulse.active = true
			pulse.distance = distance + 1.5
			pulse.offset = offset + Vector2(0.0, 0.10)
			pulse.branch = branch
			shot_cooldown = 0.145
			audio.cue(RaceAudio.FIRE)
			return


func _pulse_side(pulse: Pulse) -> int:
	if not path.is_split(pulse.distance):
		return 0
	if pulse.branch != 0:
		return pulse.branch
	if branch != 0 and path.section(distance) == path.section(pulse.distance):
		return branch
	return path.split_choice(pulse.distance, pulse.offset.x, preferred_side)


func _step_pulses(dt: float) -> void:
	for pulse in pulses:
		if not pulse.active:
			continue
		var previous := pulse.distance
		pulse.distance += (speed + 138.0) * dt
		if pulse.distance - distance > 133.0:
			pulse.active = false
			continue
		var lane := _pulse_side(pulse)
		for row in range(maxi(0, floori(previous / FlightPath.ROW_DISTANCE) - 1), floori(pulse.distance / FlightPath.ROW_DISTANCE) + 2):
			path.obstacle(row, lane, entity)
			if entity.type == FlightPath.NONE or entity.distance <= previous or entity.distance > pulse.distance:
				continue
			var key := _entity_key(row, entity.branch, false)
			if consumed.has(key) or not _overlaps(pulse.offset, 0.32, entity):
				continue
			pulse.active = false
			var origin := _entity_position(entity)
			if entity.type == FlightPath.DESTRUCTIBLE:
				consumed[key] = true
				objects.burst(origin, 0)
				_gain(140)
			else:
				objects.burst(origin, 3)
			audio.cue(RaceAudio.HIT)
			break


func _step_entities(previous: float) -> void:
	for row in range(maxi(0, floori(previous / FlightPath.ROW_DISTANCE) - 1), floori(distance / FlightPath.ROW_DISTANCE) + 2):
		path.obstacle(row, branch, entity)
		if entity.type != FlightPath.NONE and entity.distance > previous and entity.distance <= distance:
			var key := _entity_key(row, entity.branch, false)
			if not consumed.has(key) and _overlaps(offset, SHIP_RADIUS, entity):
				if invulnerable <= 0.0:
					consumed[key] = true
					_take_hit()
					if state != State.FLIGHT:
						return
			elif not consumed.has(key) and _overlaps(offset, SHIP_RADIUS + 1.05, entity):
				_gain(45)

		path.pickup(row, branch, entity)
		if entity.type != FlightPath.NONE and entity.distance > previous and entity.distance <= distance:
			var key := _entity_key(row, entity.branch, true)
			if not consumed.has(key) and _overlaps(offset, SHIP_RADIUS, entity):
				consumed[key] = true
				objects.burst(_entity_position(entity), 1 if entity.type == FlightPath.ENERGY else 2)
				if entity.type == FlightPath.BOOST:
					_trigger_boost()
					_gain(230)
				else:
					_collect_energy()

	var old_row := floori(previous / FlightPath.ROW_DISTANCE) - 5
	if old_row >= 0 and distance >= (old_row + 6) * FlightPath.ROW_DISTANCE:
		for lane in [-1, 0, 1]:
			consumed.erase(_entity_key(old_row, lane, false))
			consumed.erase(_entity_key(old_row, lane, true))


func _collect_energy() -> void:
	_gain(105)
	stored_cells += 1
	if stored_cells >= 3:
		stored_cells = 0
		shield = mini(shield + 1, MAX_SHIELD)
		_trigger_boost()
	else:
		audio.cue(RaceAudio.PICKUP)


func _trigger_boost() -> void:
	boost = BOOST_TIME
	audio.cue(RaceAudio.BOOST)


func _take_hit() -> void:
	shield -= 1
	chain_time = 0.0
	chain = 0
	combo = 1
	boost = 0.0
	hit_kick = 0.42
	invulnerable = 1.05
	objects.burst(Vector3(ship_path.x + offset.x, ship_path.y + offset.y, -distance), 0)
	if shield <= 0:
		_finish()
	else:
		audio.cue(RaceAudio.HIT)


func _gain(amount: int) -> void:
	chain += 1
	combo = clampi(1 + chain / 2, 1, 5)
	chain_time = 5.0
	bonus += amount * combo


func _score() -> int:
	return floori(distance * 1.5) + bonus


func _overlaps(p: Vector2, radius: float, item: FlightPath.Entity) -> bool:
	return absf(p.x - item.x) < radius + item.half_width and absf(p.y - item.y) < radius + item.half_height


func _entity_key(row: int, lane: int, item: bool) -> int:
	return row * 6 + (lane + 1) * 2 + int(item)


func _entity_position(item: FlightPath.Entity) -> Vector3:
	path.sample(item.distance, item.branch, scratch_path)
	return Vector3(scratch_path.x + item.x, scratch_path.y + item.y, -item.distance)


func _update_hud() -> void:
	var hint := ""
	if boost > 0.0:
		hint = "SURVITESSE"
	elif route_time > 0.0:
		hint = route_message
	elif branch == 0 and path.is_split(distance + 115.0):
		hint = "←  FAILLE  /  ORBITALE  →"
	var charge := boost / BOOST_TIME if boost > 0.0 else stored_cells / 3.0
	hud.update_run(speed * 3.6, _score(), shield / float(MAX_SHIELD), charge, distance, hint, combo)


func _draw_world(dt: float) -> void:
	var render_distance := distance
	if state == State.FLIGHT:
		render_distance += speed * accumulator
	elif state == State.MENU:
		render_distance += sin(ambient_clock * 0.64) * 2.0
	path.sample(render_distance, branch, ship_path)
	track.update_track(render_distance, branch)
	var render_offset := offset
	if state == State.MENU:
		render_offset = Vector2(1.4 + sin(ambient_clock * 1.05) * 0.38, 0.74 + sin(ambient_clock * 1.6) * 0.21)
	ship.position = Vector3(ship_path.x + render_offset.x, ship_path.y + render_offset.y, -render_distance)
	path.sample(render_distance + 9.0, branch, scratch_path)
	ship.rotation.y = -atan2(scratch_path.x - ship_path.x, 9.0)
	ship.rotation.x = atan2(scratch_path.y - ship_path.y, 9.0)
	var ship_alive := state != State.RESULTS and (invulnerable < 0.85 or int(ambient_clock * 33.0) % 2 == 0)
	ship.animate(dt, 1.0 if boost > 0.0 else clampf(speed / 170.0, 0.42, 0.92), steer, shot_cooldown > 0.096, ship_alive)
	_update_camera(render_distance, render_offset, dt)
	_draw_entities(render_distance)
	objects.begin_pulses()
	for pulse in pulses:
		if pulse.active:
			path.sample(pulse.distance, _pulse_side(pulse), scratch_path)
			objects.put_pulse(Vector3(scratch_path.x + pulse.offset.x, scratch_path.y + pulse.offset.y, -pulse.distance))
	objects.end_pulses()
	objects.advance(dt, render_distance, speed, boost > 0.0, state == State.FLIGHT, camera.position)


func _update_camera(where: float, relative_ship: Vector2, dt: float) -> void:
	path.sample(where - 11.5, branch, camera_path)
	path.sample(where + 28.0, branch, aim_path)
	var shake := hit_kick * hit_kick * 2.5
	var base := Vector3(camera_path.x, camera_path.y + 3.15, -where + 11.5)
	base.x += relative_ship.x * 0.58 + sin(ambient_clock * 83.0) * shake
	base.y += relative_ship.y * 0.55 + cos(ambient_clock * 75.0) * shake
	var target := Vector3(lerpf(ship_path.x, aim_path.x, 0.48), lerpf(ship_path.y, aim_path.y, 0.40) + 0.78, -where - 26.0)
	target.x += relative_ship.x * 0.24
	target.y += relative_ship.y * 0.20
	if state == State.MENU:
		base.x -= 2.0
		target.x -= 3.25
	if not viewport_camera_ready:
		camera.position = base
		viewport_camera_ready = true
	else:
		camera.position.x = lerpf(camera.position.x, base.x, 1.0 - exp(-12.0 * dt))
		camera.position.y = lerpf(camera.position.y, base.y, 1.0 - exp(-12.0 * dt))
		camera.position.z = base.z
	camera.look_at(target, Vector3.UP)
	var desired_fov := 59.0 + clampf((speed - START_SPEED) * 0.085, 0.0, 8.0)
	camera.fov = lerpf(camera.fov, desired_fov, 1.0 - exp(-4.0 * dt))


func _draw_entities(where: float) -> void:
	objects.begin_entities()
	var first_row := maxi(0, floori((where - 12.0) / FlightPath.ROW_DISTANCE))
	var last_row := floori((where + 210.0) / FlightPath.ROW_DISTANCE) + 1
	for row in range(first_row, last_row + 1):
		_draw_row(row, -1)
		if path.has_separate_entities(row * FlightPath.ROW_DISTANCE):
			_draw_row(row, 1, true)
	objects.end_entities()


func _draw_row(row: int, lane: int, skip_common := false) -> void:
	path.obstacle(row, lane, entity)
	if entity.type != FlightPath.NONE and (not skip_common or entity.branch != 0) and not consumed.has(_entity_key(row, entity.branch, false)):
		objects.put_entity(entity.type, _entity_position(entity), Vector2(entity.half_width, entity.half_height), row, ambient_clock)
	path.pickup(row, lane, entity)
	if entity.type != FlightPath.NONE and (not skip_common or entity.branch != 0) and not consumed.has(_entity_key(row, entity.branch, true)):
		objects.put_entity(entity.type, _entity_position(entity), Vector2(entity.half_width, entity.half_height), row, ambient_clock)
