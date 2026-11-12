class_name CarView
extends Node2D
var steering := 0.0
func _draw() -> void:
	draw_style_box(_box(Color(0, 0, 0, 0.3), 9), Rect2(-37, -16, 82, 39))
	for x in [-23.0, 23.0]:
		for y in [-18.0, 18.0]:
			draw_set_transform(Vector2(x, y), steering if x > 0 else 0.0)
			draw_style_box(_box(Color("121c23"), 3), Rect2(-10, -4, 20, 8))
	draw_set_transform(Vector2.ZERO)
	draw_style_box(_box(Color("edc16b"), 9), Rect2(-40, -17, 80, 34))
	draw_rect(Rect2(-31, -2, 61, 4), Color("fff0c4"))
	draw_style_box(_box(Color("233b46"), 4), Rect2(-17, -13, 34, 26))
	draw_style_box(_box(Color("d39c47"), 3), Rect2(-12, -12, 20, 24))
	for y in [-13.0, 8.0]:
		draw_rect(Rect2(33, y, 5, 5), Color("fff2ce"))
		draw_rect(Rect2(-39, y, 4, 5), Color("e26f52"))
	draw_rect(Rect2(-35, -21, 5, 42), Color("273336"))
static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box
