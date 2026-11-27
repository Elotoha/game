extends SceneTree

const Rules = preload("res://src/flight_path.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)


func _run() -> void:
	_check_course()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game._launch()
	_check(game.selected_side == -1 and is_equal_approx(game.offset.x, -Rules.LANE_X), "The left lane should be selected at launch")
	_fly_to(game, 230.0)
	_check(game.stored_cells == 1, "The first cell should be reachable in the default lane")
	_check(game.consumed.has(game._entity_key(9, 0, false)), "The first destructible obstacle should be hit by automatic fire")
	_check(game.shield == game.MAX_SHIELD, "Automatic fire should clear the first obstacle ahead of the player")
	_fly_to(game, 320.0)
	game._update_hud()
	_check(game.hud._route_hint == "PASSAGE LIBRE  →", "The first solid obstacle should show the right lane well in advance")
	_fly_to(game, 381.0)
	_tap(0.8, true)
	_tap(0.8, false)
	_fly_to(game, 465.0)
	_check(game.selected_side == 1 and is_equal_approx(game.offset.y, 0.0), "A tap on the right half should select only the right lane")
	_check(game.shield == game.MAX_SHIELD, "A delayed lane change should clear the first solid obstacle")
	_check(game.branch == 0, "The first former fork must not switch routes")

	game._pause()
	_tap(0.2, true)
	_tap(0.2, false)
	_check(game.selected_side == 1 and game.state == game.State.PAUSE, "Pause should block steering")
	game._resume()
	game._launch()
	var full_shield := int(game.MAX_SHIELD)
	game.best = 2147483647
	_check_delayed_reactions(game)
	_check(game.state == game.State.FLIGHT and game.shield == full_shield,
		"A 0.75-second response to warnings should keep the ship safe through the 12 km run")
	_check(game.distance >= 12000.0 and game.speed >= game.TOP_SPEED, "The run should reach the original top speed")
	game.queue_free()
	await process_frame
	print("Astral Relay flight tests: %d failures" % failures)
	quit(failures)


func _check_course() -> void:
	var path := Rules.new(8317204, false)
	var left := Rules.Sample.new()
	var right := Rules.Sample.new()
	var open_seen := false
	for distance in range(0, 12000, 4):
		path.sample(distance, -1, left)
		path.sample(distance, 1, right)
		_check(not path.is_split(distance) and not path.has_separate_entities(distance)
			and left.branch_offset == 0.0 and left.x == right.x and left.y == right.y,
			"Disabled forks must generate one continuous path")
		open_seen = open_seen or left.open >= 0.9
	_check(open_seen, "The course should still have open-space sections")
	var branching_path := Rules.new(8317204, true)
	branching_path.sample(360.0, -1, left)
	branching_path.sample(360.0, 1, right)
	_check(branching_path.is_split(360.0) and right.x - left.x > 30.0, "Forks should remain available for future versions")

	var hazard := Rules.Entity.new()
	var pickup := Rules.Entity.new()
	var previous := 0.0
	for row in range(500):
		path.obstacle(row, 0, hazard)
		path.pickup(row, 0, pickup)
		if hazard.type != Rules.NONE:
			_check(hazard.distance - previous >= 216.0, "Obstacles should always be spaced at least 216 meters apart")
			_check(absf(hazard.x) == Rules.LANE_X and hazard.y == 0.0 and hazard.half_width + 0.64 < Rules.LANE_X * 2,
				"An obstacle must leave the other lane available")
			_check(pickup.type == Rules.NONE, "Pickups should have their own rows")
			previous = hazard.distance
		if pickup.type != Rules.NONE:
			_check(absf(pickup.x) == Rules.LANE_X and pickup.y == 0.0, "Every pickup should be reachable without vertical steering")


func _tap(fraction: float, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 1
	event.position = root.get_visible_rect().size * Vector2(fraction, 0.5)
	event.pressed = pressed
	root.push_input(event, true)


func _fly_to(game: Node, finish: float) -> void:
	while game.distance < finish and game.state == game.State.FLIGHT:
		game._step(game.STEP)


func _check_delayed_reactions(game: Node) -> void:
	var pending_side := 0
	var wait := 0.0
	for frame in range(21000):
		if game.state != game.State.FLIGHT or game.distance >= 12000.0:
			return
		game._step(game.STEP)
		if frame % 8 == 0:
			game._update_hud()
			var hint: String = game.hud._route_hint
			if pending_side == 0 and hint.contains("PASSAGE LIBRE"):
				pending_side = 1 if hint.ends_with("→") else -1
				wait = 0.75
		if pending_side != 0:
			wait -= game.STEP
			if wait <= 0.0:
				var touch_x := 0.8 if pending_side > 0 else 0.2
				_tap(touch_x, true)
				_tap(touch_x, false)
				pending_side = 0
