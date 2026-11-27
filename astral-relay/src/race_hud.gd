extends CanvasLayer

signal launch_requested
signal pause_requested
signal resume_requested
signal mute_requested
signal music_requested
signal menu_requested

enum Screen { MENU, RUN, PAUSE, RESULT }

const DISPLAY_FONT = preload("res://assets/fonts/OpenSans-ExtraBoldItalic-Latin.ttf")
const WHITE := Color("f7f4e9")
const TEAL := Color("61f4e3")
const ORANGE := Color("ffae71")
const MUTED := Color("aabbd2")
const INK := Color("080d21")
const LINE := Color(0.66, 0.82, 0.95, 0.24)

class HudSurface extends Control:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call()

var _screen: Screen = Screen.MENU
var _surface: HudSurface
var _buttons: Dictionary[String, Button] = {}
var _font: Font
var _menu_scrim: GradientTexture2D
var _top_scrim: GradientTexture2D
var _bottom_scrim: GradientTexture2D
var _safe := Rect2()
var _modal := Rect2()
var _scale := 1.0
var _speed := 0.0
var _score := 0
var _best := 0
var _distance := 0.0
var _shield := 1.0
var _boost := 0.0
var _route_hint := ""
var _combo := 1
var _boost_active := false
var _selected_side := -1
var _muted := false
var _external_music := false
var _new_best := false
var _redraw_pending := false
var _redraw_elapsed := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_menu_scrim = _gradient(
		PackedFloat32Array([0.0, 0.35, 0.58, 0.91, 1.0]),
		PackedColorArray([Color("080d22"), Color(0.03, 0.05, 0.13, 0.95),
		Color(0.03, 0.05, 0.13, 0.49), Color(0.03, 0.05, 0.13, 0.02),
		Color(0.03, 0.05, 0.13, 0.02)]), Vector2.RIGHT)
	_top_scrim = _gradient(PackedFloat32Array([0.0, 1.0]),
		PackedColorArray([Color(0.02, 0.035, 0.09, 0.87), Color(0.02, 0.035, 0.09, 0.0)]),
		Vector2.DOWN)
	_bottom_scrim = _gradient(PackedFloat32Array([0.0, 1.0]),
		PackedColorArray([Color(0.02, 0.035, 0.09, 0.0), Color(0.02, 0.035, 0.09, 0.82)]),
		Vector2.DOWN)

	_surface = HudSurface.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.painter = _paint
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_button("start", "LANCER LE VOL   →", true, func(): launch_requested.emit())
	_add_button("pause", "Ⅱ", false, func(): pause_requested.emit())
	_add_button("resume", "REPRENDRE   →", true, func(): resume_requested.emit())
	_add_button("restart", "REJOUER   →", true, func(): launch_requested.emit())
	_add_button("retry", "RECOMMENCER", false, func(): launch_requested.emit())
	_add_button("menu", "MENU", false, func(): menu_requested.emit())
	_add_button("mute", "SON ACTIF", false, func(): mute_requested.emit())
	_add_button("music", "MUSIQUE DU JEU", false, func(): music_requested.emit())
	_buttons["pause"].tooltip_text = "Pause"
	_surface.resized.connect(_layout)
	_layout()


func show_menu(best: int) -> void:
	_best = best
	_set_screen(Screen.MENU)


func show_run() -> void:
	_set_screen(Screen.RUN)


func show_pause() -> void:
	_set_screen(Screen.PAUSE)


func show_result(score: int, best: int, distance_m: float, new_best: bool) -> void:
	_score = score
	_best = best
	_distance = distance_m
	_new_best = new_best
	_set_screen(Screen.RESULT)


func set_muted(muted: bool) -> void:
	_muted = muted
	if is_instance_valid(_surface):
		_buttons["mute"].text = "SON COUPÉ" if _muted else "SON ACTIF"
		_buttons["mute"].tooltip_text = "Activer le son" if _muted else "Couper le son"


func set_external_music(external: bool) -> void:
	_external_music = external
	if is_instance_valid(_surface):
		_buttons["music"].text = "MUSIQUE EXTERNE" if external else "MUSIQUE DU JEU"
		_buttons["music"].tooltip_text = "Rétablir la bande-son" if external else "Couper la bande-son et garder les effets"


func update_run(speed: float, score: int, shield: float, boost: float, distance_m: float,
		route_hint: String, combo: int, boost_active: bool, selected_side: int) -> void:
	_speed = speed
	_score = score
	_shield = clampf(shield, 0.0, 1.0)
	_boost = clampf(boost, 0.0, 1.0)
	_distance = distance_m
	_route_hint = route_hint
	_combo = combo
	_boost_active = boost_active
	_selected_side = selected_side
	_redraw_pending = true


func _process(delta: float) -> void:
	if _screen != Screen.RUN or not _redraw_pending:
		return
	_redraw_elapsed += delta
	if _redraw_elapsed >= 1.0 / 30.0:
		_redraw_elapsed = 0.0
		_redraw_pending = false
		_surface.queue_redraw()


func _set_screen(next: Screen) -> void:
	_screen = next
	if is_instance_valid(_surface):
		_layout()


func _add_button(key: String, caption: String, primary: bool, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", DISPLAY_FONT if primary else _font)
	button.add_theme_color_override("font_color", INK if primary else WHITE)
	button.add_theme_color_override("font_hover_color", INK if primary else TEAL)
	button.add_theme_color_override("font_pressed_color", INK if primary else TEAL)
	button.add_theme_stylebox_override("normal", _button_box(TEAL if primary else Color(0.04, 0.075, 0.16, 0.93), primary))
	button.add_theme_stylebox_override("hover", _button_box(Color("a3fff0") if primary else Color("132840"), primary))
	button.add_theme_stylebox_override("pressed", _button_box(Color("3fcdbd") if primary else Color("203d4c"), primary))
	button.pressed.connect(action)
	_surface.add_child(button)
	_buttons[key] = button


func _button_box(background: Color, primary: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.skew = Vector2(-0.13, 0.0)
	box.border_color = Color(0.45, 0.88, 0.89, 0.43)
	box.set_border_width_all(0 if primary else 1)
	box.content_margin_left = 13.0
	box.content_margin_right = 13.0
	if primary:
		box.shadow_color = Color(0.1, 0.68, 0.66, 0.23)
		box.shadow_size = 9
	return box


func _gradient(offsets: PackedFloat32Array, colors: PackedColorArray,
		direction: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.width = 256 if direction.x > 0.0 else 2
	texture.height = 256 if direction.y > 0.0 else 2
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = direction
	return texture


func _layout() -> void:
	if not is_instance_valid(_surface) or _surface.size.length_squared() < 1.0:
		return
	var viewport_size := _surface.size
	_scale = clampf(minf(viewport_size.y / 720.0, viewport_size.x / 1080.0), 0.50, 1.5)
	_safe = Rect2(Vector2.ZERO, viewport_size).grow(-28.0 * _scale)
	if OS.has_feature("mobile"):
		var usable := Rect2(DisplayServer.get_display_safe_area())
		var display := Vector2(DisplayServer.screen_get_size())
		if display.x > 0.0 and display.y > 0.0 and usable.has_area():
			var ratio := viewport_size / display
			_safe = Rect2(usable.position * ratio, usable.size * ratio).grow(-24.0 * _scale)
	_modal = _rect(viewport_size * 0.5, Rect2(-237, -196, 474, 392))
	for button in _buttons.values():
		button.hide()
	match _screen:
		Screen.MENU:
			var start_position := _menu_origin()
			var upper_right := Vector2(_safe.end.x, _safe.position.y)
			_place("start", _rect(start_position, Rect2(5, 298, 258, 57)), 23)
			_place("music", _rect(upper_right, Rect2(-315, 12, 160, 43)), 14)
			_place("mute", _rect(upper_right, Rect2(-139, 12, 128, 43)), 14)
		Screen.RUN:
			_place("pause", _rect(_safe.end, Rect2(-59, -_safe.size.y / _scale, 52, 53)), 23)
		Screen.PAUSE:
			_place("resume", _rect(_modal.position, Rect2(44, 148, 386, 55)), 22)
			_place("retry", _rect(_modal.position, Rect2(44, 221, 236, 47)), 15)
			_place("menu", _rect(_modal.position, Rect2(296, 221, 134, 47)), 15)
			_place("music", _rect(_modal.position, Rect2(44, 285, 236, 43)), 14)
			_place("mute", _rect(_modal.position, Rect2(296, 285, 134, 43)), 14)
		Screen.RESULT:
			_place("restart", _rect(_modal.position, Rect2(42, 286, 238, 54)), 21)
			_place("menu", _rect(_modal.position, Rect2(299, 286, 133, 54)), 15)
	set_muted(_muted)
	set_external_music(_external_music)
	_surface.queue_redraw()


func _place(key: String, rect: Rect2, font_size: int) -> void:
	var button := _buttons[key]
	button.add_theme_font_size_override("font_size", _px(font_size))
	button.position = rect.position
	button.size = rect.size
	button.show()


func _menu_origin() -> Vector2:
	return _safe.position + Vector2(43.0 * _scale, _safe.size.y * 0.169)


func _rect(origin: Vector2, offset: Rect2) -> Rect2:
	return Rect2(origin + offset.position * _scale, offset.size * _scale)


func _px(unscaled: int) -> int:
	return maxi(1, roundi(float(unscaled) * _scale))


func _text(at: Vector2, value: String, font_size: int, color: Color = WHITE,
		display_font: bool = false, anchor: float = 0.0) -> void:
	var face := DISPLAY_FONT if display_font else _font
	var size := _px(font_size)
	var x := at.x
	if anchor > 0.0:
		x -= face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * anchor
	_surface.draw_string(face, Vector2(x, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _position(origin: Vector2, offset: Vector2) -> Vector2:
	return origin + offset * _scale


func _paint() -> void:
	match _screen:
		Screen.MENU:
			_draw_menu()
		Screen.RUN:
			_draw_run()
		Screen.PAUSE, Screen.RESULT:
			_draw_modal()


func _draw_menu() -> void:
	var size := _surface.size
	_surface.draw_texture_rect(_menu_scrim, Rect2(Vector2.ZERO, size), false)
	_surface.draw_texture_rect(_bottom_scrim, Rect2(Vector2(0, size.y * 0.81), Vector2(size.x, size.y * 0.19)), false)
	var origin := _menu_origin()
	_draw_mark(origin)
	var version := str(ProjectSettings.get_setting("application/config/version"))
	_text(_position(origin, Vector2(54, 6)), "COURSE SPATIALE  ·  " + version, 15, TEAL)
	_text(_position(origin, Vector2(-7, 106)), "ASTRAL", 107, WHITE, true)
	_text(_position(origin, Vector2(-7, 196)), "RELAY", 107, TEAL, true)
	_text(_position(origin, Vector2(1, 241)), "Deux commandes, à pleine vitesse.", 21, WHITE)
	var record_position := _position(origin, Vector2(3, 404))
	_surface.draw_line(record_position, record_position + Vector2(254 * _scale, 0), LINE, _scale)
	_text(record_position + Vector2(0, 28 * _scale), "RECORD", 14, MUTED)
	_text(record_position + Vector2(254, 33) * _scale, _score_text(_best), 27, WHITE, true, 1.0)
	_draw_control_guide(_safe.end + Vector2(-278, -132) * _scale)


func _draw_mark(at: Vector2) -> void:
	_surface.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, 8) * _scale, at + Vector2(25, -11) * _scale,
		at + Vector2(41, -11) * _scale, at + Vector2(17, 8) * _scale]), TEAL)
	_surface.draw_colored_polygon(PackedVector2Array([
		at + Vector2(23, 8) * _scale, at + Vector2(38, -4) * _scale,
		at + Vector2(45, -4) * _scale, at + Vector2(31, 8) * _scale]), ORANGE)


func _draw_control_guide(origin: Vector2) -> void:
	var body := _rect(origin, Rect2(0, 0, 268, 122))
	_draw_panel(body, Color(0.033, 0.06, 0.14, 0.88))
	_text(_position(origin, Vector2(20, 28)), "TOUCHEZ UN CÔTÉ", 15, WHITE, true)
	var map := _rect(origin, Rect2(20, 40, 228, 44))
	_surface.draw_rect(map, Color(0.12, 0.18, 0.27, 0.72))
	var middle := map.get_center()
	_surface.draw_line(Vector2(middle.x, map.position.y), Vector2(middle.x, map.end.y), LINE, _scale)
	_draw_arrow(middle - Vector2(map.size.x * 0.25, 0), Vector2.LEFT, 16.0, TEAL)
	_draw_arrow(middle + Vector2(map.size.x * 0.25, 0), Vector2.RIGHT, 16.0, TEAL)
	_text(_position(origin, Vector2(20, 105)), "TIR AUTOMATIQUE", 12, MUTED)


func _draw_run() -> void:
	var size := _surface.size
	_surface.draw_texture_rect(_top_scrim, Rect2(0, 0, size.x, _safe.position.y + 134 * _scale), false)
	var top_left := _safe.position + Vector2(9, 0) * _scale
	var top_right := Vector2(_safe.end.x - 81 * _scale, _safe.position.y)
	var middle := Vector2(size.x * 0.5, _safe.position.y)
	_text(_position(top_left, Vector2(0, 16)), "VITESSE", 13, MUTED)
	var speed_label := str(roundi(_speed)).pad_zeros(3)
	_text(_position(top_left, Vector2(-2, 65)), speed_label, 54, WHITE, true)
	var speed_width := DISPLAY_FONT.get_string_size(speed_label, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(54)).x
	_text(Vector2(top_left.x + speed_width + 10 * _scale, top_left.y + 62 * _scale), "km/h", 15, TEAL)
	_text(_position(top_left, Vector2(1, 88)), _distance_text(_distance), 16, MUTED)

	_text(_position(top_right, Vector2(0, 16)), "SCORE", 13, MUTED, false, 1.0)
	_text(_position(top_right, Vector2(0, 52)), _score_text(_score), 37, WHITE, true, 1.0)
	if _combo > 1:
		_text(_position(top_right, Vector2(0, 78)), "COMBO  ×%d" % _combo, 16, ORANGE, true, 1.0)

	_draw_meter(_position(middle, Vector2(-133, 7)), "BOUCLIER", _shield, 3,
		TEAL if _shield > 0.35 else ORANGE)
	_draw_meter(_position(middle, Vector2(13, 7)), "TURBO", _boost,
		1 if _boost_active else 3, ORANGE)
	if not _route_hint.is_empty():
		_draw_route_hint(_position(middle, Vector2(0, 91)))
	_draw_touch_hints(size)


func _draw_meter(origin: Vector2, caption: String, value: float, count: int, color: Color) -> void:
	_text(_position(origin, Vector2(1, 13)), caption, 12, MUTED)
	var step := 120.0 / count
	var gap := 3.0 if count > 1 else 0.0
	var bar_width := step - gap
	for index in range(count):
		var x := index * step
		var bar := _rect(origin, Rect2(x, 22, bar_width, 6))
		_surface.draw_rect(bar, Color(0.68, 0.81, 0.95, 0.18))
		var fill := clampf(value * count - index, 0.0, 1.0)
		_surface.draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), color)


func _draw_route_hint(origin: Vector2) -> void:
	var lines := _route_hint.split("\n", false)
	var width := 0.0
	for line in lines:
		width = maxf(width, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _px(16)).x)
	var padding := 20.0 * _scale
	var box := Rect2(origin.x - width * 0.5 - padding, origin.y - 25 * _scale,
		width + padding * 2.0, (36.0 + (lines.size() - 1) * 23.0) * _scale)
	_surface.draw_rect(box, Color(0.035, 0.065, 0.15, 0.89))
	_surface.draw_line(box.position, Vector2(box.end.x, box.position.y), Color(TEAL, 0.48), _scale)
	for index in range(lines.size()):
		_text(_position(origin, Vector2(0, index * 23.0)), lines[index], 16, WHITE, false, 0.5)


func _draw_touch_hints(size: Vector2) -> void:
	var tone := Color(WHITE, lerpf(0.70, 0.33, smoothstep(70.0, 350.0, _distance)))
	var selected := Color(TEAL, 0.75)
	var vertical_base := size.y * 0.64
	var left := Vector2(_safe.position.x + 24 * _scale, vertical_base)
	var right := Vector2(_safe.end.x - 24 * _scale, vertical_base)
	_draw_arrow(left, Vector2.LEFT, 20, selected if _selected_side < 0 else tone)
	_draw_arrow(right, Vector2.RIGHT, 20, selected if _selected_side > 0 else tone)


func _draw_arrow(at: Vector2, direction: Vector2, length: float, color: Color) -> void:
	var normal := direction.normalized()
	var side := Vector2(-normal.y, normal.x)
	var tip := normal * length * _scale
	_surface.draw_polyline(PackedVector2Array([
		at - tip * 0.26 + side * length * _scale * 0.55,
		at + tip * 0.46,
		at - tip * 0.26 - side * length * _scale * 0.55,
	]), color, maxf(1.0, 1.7 * _scale), true)


func _draw_panel(rect: Rect2, fill: Color) -> void:
	var bevel := 13.0 * _scale
	var points := PackedVector2Array([rect.position + Vector2(bevel, 0),
		Vector2(rect.end.x, rect.position.y), rect.end - Vector2(0, bevel),
		rect.end - Vector2(bevel, 0), Vector2(rect.position.x, rect.end.y),
		rect.position + Vector2(0, bevel)])
	_surface.draw_colored_polygon(points, fill)
	points.append(points[0])
	_surface.draw_polyline(points, LINE, _scale, true)
	_surface.draw_line(points[0], points[0] + Vector2(32 * _scale, 0), TEAL, 2.0 * _scale, true)


func _draw_modal() -> void:
	_surface.draw_rect(Rect2(Vector2.ZERO, _surface.size), Color(0.01, 0.015, 0.055, 0.65))
	_draw_panel(_modal, Color(0.035, 0.058, 0.13, 0.96))
	var origin := _modal.position
	var center := _position(origin, Vector2(237, 0))
	if _screen == Screen.PAUSE:
		_text(_position(center, Vector2(0, 96)), "EN PAUSE", 57, WHITE, true, 0.5)
	else:
		var heading := "NOUVEAU RECORD" if _new_best else "VOL TERMINÉ"
		_text(_position(center, Vector2(0, 55)), heading, 22, TEAL if _new_best else WHITE, true, 0.5)
		_text(_position(center, Vector2(0, 143)), _score_text(_score), 77, WHITE, true, 0.5)
		_text(_position(center, Vector2(0, 173)), "POINTS", 14, MUTED, false, 0.5)
		var left := _position(origin, Vector2(44, 216))
		var right := _position(origin, Vector2(252, 216))
		_surface.draw_line(_position(left, Vector2(0, -25)), _position(right, Vector2(178, -25)), LINE, _scale)
		_text(left, "DISTANCE", 13, MUTED)
		_text(_position(left, Vector2(0, 35)), _distance_text(_distance), 29, WHITE, true)
		_text(right, "RECORD", 13, MUTED)
		_text(_position(right, Vector2(0, 35)), _score_text(_best), 29, TEAL, true)


func _distance_text(meters: float) -> String:
	if meters < 1000.0:
		return "%d m" % floori(meters)
	return ("%.2f km" % (meters / 1000.0)).replace(".", ",")


func _score_text(value: int) -> String:
	var digits := str(maxi(0, value)).pad_zeros(6)
	var split := digits.length() - 3
	return digits.substr(0, split) + " " + digits.substr(split)
