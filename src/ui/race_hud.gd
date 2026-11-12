class_name RaceHud
extends CanvasLayer
var speed_label: Label
var status_label: Label
var time_label: Label
var lap_label: Label
var pause_button: Button
var map: Control
var circuit: Circuit
var model: VehicleModel
var controller: PlayerInput
var reset_action: Callable
var pause_action: Callable

func label(text: String, size: int, color: Color = Color("eae9dc")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	return item

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := Panel.new()
	panel.position = Vector2(24, 22)
	panel.size = Vector2(330, 112)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152a2ded")
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var title := label("APEX  /  CLUB CIRCUIT", 17, Color("edc16b"))
	title.position = Vector2(42, 34)
	root.add_child(title)
	speed_label = label("000", 42)
	speed_label.position = Vector2(42, 53)
	root.add_child(speed_label)
	var unit := label("KM/H", 13, Color("a5b9b4"))
	unit.position = Vector2(137, 83)
	root.add_child(unit)
	status_label = label("ADHÉRENCE", 12, Color("8fd4ba"))
	status_label.position = Vector2(42, 111)
	root.add_child(status_label)
	lap_label = label("ESSAIS LIBRES", 14)
	lap_label.position = Vector2(205, 62)
	root.add_child(lap_label)
	time_label = label("00:00.00", 19)
	time_label.position = Vector2(205, 85)
	root.add_child(time_label)
	var help := label("ZQSD / FLÈCHES : PILOTER   ·   ESPACE : FREIN À MAIN   ·   R : REPLACER", 14, Color("b7c5be"))
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(390, 30)
	root.add_child(help)
	button(root, "REPLACER", Vector2(-260, 64), Vector2(130, 42), Control.PRESET_TOP_RIGHT).pressed.connect(reset_action)
	pause_button = button(root, "PAUSE  II", Vector2(-120, 64), Vector2(100, 42), Control.PRESET_TOP_RIGHT)
	pause_button.pressed.connect(pause_action)
	# Touch buttons have independent holds, allowing throttle + steering + handbrake.
	bind(button(root, "<", Vector2(28, -117), Vector2(92, 88), Control.PRESET_BOTTOM_LEFT), "left")
	bind(button(root, ">", Vector2(132, -117), Vector2(92, 88), Control.PRESET_BOTTOM_LEFT), "right")
	bind(button(root, "F. MAIN", Vector2(-322, -117), Vector2(90, 88), Control.PRESET_BOTTOM_RIGHT), "handbrake")
	bind(button(root, "FREIN", Vector2(-220, -117), Vector2(90, 88), Control.PRESET_BOTTOM_RIGHT), "brake")
	bind(button(root, "GAZ", Vector2(-118, -145), Vector2(90, 116), Control.PRESET_BOTTOM_RIGHT), "gas")
	map = Control.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map.position = Vector2(-203, 140)
	map.size = Vector2(180, 170)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(draw_map)
	root.add_child(map)

func button(root: Control, text: String, offset: Vector2, dimensions: Vector2, preset: int) -> Button:
	var b := Button.new()
	b.text = text
	b.set_anchors_and_offsets_preset(preset)
	b.position = offset
	b.size = dimensions
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("193237de")
	style.border_color = Color("718b80")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", style)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("9c7439")
	b.add_theme_stylebox_override("pressed", pressed)
	root.add_child(b)
	return b

func bind(b: Button, action: String) -> void:
	# Native touch events are tracked per finger, independent of mouse emulation.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("action", action)
	touch_buttons.append(b)

var touch_buttons: Array[Button] = []
var touches: Dictionary = {}
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
	else:
		return
	update_touches()

func update_touches() -> void:
	for b in touch_buttons:
		var down := false
		for p in touches.values():
			if b.get_global_rect().has_point(p):
				down = true
		controller.held[b.get_meta("action")] = down
		b.set_pressed_no_signal(down)

func release_touches() -> void:
	touches.clear()
	controller.clear()
	update_touches()

func draw_map() -> void:
	map.draw_style_box(CarView._box(Color("152a2ddd"), 12), Rect2(Vector2.ZERO, map.size))
	var line := PackedVector2Array()
	for p in circuit.points:
		line.append(p * 1.35 + Vector2(8, 0))
	map.draw_polyline(line, Color("889c94"), 5.0, true)
	map.draw_circle(model.position * 1.35 + Vector2(8, 0), 4.5, Color("f0c36e"))
	var center := model.position * 1.35 + Vector2(8, 0)
	map.draw_line(center, center + Vector2.from_angle(model.heading) * 10, Color("fff0c4"), 2, true)

func refresh(lap: LapTracker, surface: String, paused: bool) -> void:
	speed_label.text = "%03d" % roundi(model.velocity.length() * 3.6)
	var behavior := "ADHÉRENCE"
	if model.front_usage > 1.0 and model.front_usage > model.rear_usage:
		behavior = "SOUS-VIRAGE"
	if model.rear_usage > 1.0 and model.rear_usage >= model.front_usage:
		behavior = "SURVIRAGE"
	status_label.text = surface + "  /  " + behavior
	lap_label.text = "TOUR %02d" % (lap.laps + 1)
	time_label.text = "%02d:%05.2f" % [int(lap.elapsed / 60), fmod(lap.elapsed, 60)]
	if lap.best > 0:
		lap_label.text += "  ★ %.1f" % lap.best
	pause_button.text = "REPRENDRE" if paused else "PAUSE  II"
	map.queue_redraw()
