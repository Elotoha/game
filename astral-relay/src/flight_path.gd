class_name FlightPath
extends RefCounted

const SECTION_LENGTH := 560.0
const ROW_DISTANCE := 24.0
const FORK_START := 270.0
const FORK_END := 456.0

const NONE := 0
const DESTRUCTIBLE := 1
const SOLID := 2
const ENERGY := 3
const BOOST := 4


class Sample extends RefCounted:
	var x := 0.0
	var y := 0.0
	var radius_x := 0.0
	var radius_y := 0.0
	var open := 0.0
	var split := 0.0
	var branch_offset := 0.0
	var region := 0


class Entity extends RefCounted:
	var type := NONE
	var distance := 0.0
	var x := 0.0
	var y := 0.0
	var half_width := 0.0
	var half_height := 0.0
	var branch := 0


var _salt: int
var _phase_x: float
var _phase_y: float


func _init(seed_value: int = 0x41535452) -> void:
	_salt = seed_value & 0x7FFFFFFF
	_phase_x = float(_salt & 0xFFFF) * TAU / 65536.0
	_phase_y = float((_salt >> 15) & 0xFFFF) * TAU / 65536.0


func section(distance: float) -> int:
	return floori(distance / SECTION_LENGTH)


func split_start(distance: float) -> float:
	return float(section(distance)) * SECTION_LENGTH + FORK_START


func split_end(distance: float) -> float:
	return float(section(distance)) * SECTION_LENGTH + FORK_END


func is_split(distance: float) -> bool:
	var offset := fposmod(distance, SECTION_LENGTH)
	return offset >= FORK_START and offset < FORK_END


func has_separate_entities(distance: float) -> bool:
	var offset := fposmod(distance, SECTION_LENGTH)
	return offset >= FORK_START + 41.0 and offset < FORK_END - 34.0


func split_choice(distance: float, lateral_x: float, preferred_side: int = 1) -> int:
	var dead_zone := 0.34 if is_split(distance) else 0.55
	if absf(lateral_x) > dead_zone:
		return -1 if lateral_x < 0.0 else 1
	return -1 if preferred_side < 0 else 1


func sample(distance: float, branch: int, out: Sample) -> void:
	var section_index := section(distance)
	var offset := distance - float(section_index) * SECTION_LENGTH
	var region := section_index & 3
	var spread := _ramp(offset - FORK_START, 52.0) * _ramp(FORK_END - offset, 49.0)
	var branch_side := float(signi(branch))
	var width := 19.6 + 1.7 * sin(float(section_index) * 1.83 + _phase_y)
	var opening: float
	match region:
		0: opening = _window(offset, 116.0, 234.0, 22.0)
		1: opening = _window(offset, 78.0, 202.0, 20.0)
		2: opening = _window(offset, 130.0, 245.0, 24.0)
		_: opening = _window(offset, 96.0, 225.0, 26.0)
	var entrance := _window(offset, FORK_START - 17.0, FORK_START + 43.0, 17.0)
	var exit := _window(offset, FORK_END - 35.0, FORK_END + 17.0, 16.0)
	opening = maxf(opening, 0.87 * maxf(entrance, exit))
	if branch < 0 and region != 1:
		opening = maxf(opening, _window(offset, FORK_START + 49.0, FORK_END - 24.0, 20.0))

	out.x = (
		6.4 * sin(distance * 0.0107 + _phase_x) + 5.6 * sin(distance * 0.0047 + _phase_y)
		+ width * spread * branch_side
	)
	out.y = (
		2.2 * sin(distance * 0.016 + _phase_y) + 2.7 * sin(distance * 0.0061 + _phase_x)
		+ (1.6 + 0.8 * sin(offset * 0.031)) * spread * branch_side
	)
	out.radius_x = 8.7 + 0.43 * sin(distance * 0.027 + _phase_x) + 0.65 * opening
	out.radius_x -= 0.82 * spread * branch_side
	out.radius_y = 5.45 + 0.33 * sin(distance * 0.019 + _phase_y) + 0.47 * opening
	out.radius_y -= 0.28 * spread * branch_side
	out.open = opening
	out.split = spread
	out.branch_offset = width * spread
	out.region = region


func obstacle(row: int, branch: int, out: Entity) -> void:
	_reset_entity(row, branch, out)
	if row < 5 or _blocks_entities(out.distance, out.branch):
		return
	match row:
		5:
			_place(out, DESTRUCTIBLE, 0.0, 0.0, 1.45, 1.2)
			return
		6, 8:
			return
		7:
			_place(out, SOLID, -3.15, -0.6, 1.75, 1.75)
			return

	var key := _row_key(row, out.branch)
	var frequency := mini(87, 60 + floori(float(row) / 12.0))
	if out.branch > 0:
		frequency += 10
	if key % 100 >= frequency:
		return
	var type := DESTRUCTIBLE if ((key >> 10) & 7) < 5 else SOLID
	var lane := ((key >> 5) % 5) - 2
	var level := ((key >> 8) % 3) - 1
	var half_width := 1.25 + float((key >> 13) & 3) * 0.18
	var half_height := 1.03 + float((key >> 15) & 3) * 0.16
	if type == SOLID:
		half_width += 0.36
		half_height += 0.38
	_place(out, type, float(lane) * 2.03, float(level) * 1.9, half_width, half_height)


func pickup(row: int, branch: int, out: Entity) -> void:
	_reset_entity(row, branch, out)
	if row < 3 or _blocks_entities(out.distance, out.branch):
		return
	match row:
		3:
			_place(out, ENERGY, 0.0, 0.0, 0.82, 0.82)
			return
		4:
			_place(out, ENERGY, 1.65, 0.45, 0.82, 0.82)
			return
		5, 7:
			return
		6:
			_place(out, ENERGY, -1.5, 0.0, 0.82, 0.82)
			return
		8:
			_place(out, BOOST, 2.05, -0.35, 1.1, 0.86)
			return

	var key := _row_key(row, out.branch)
	var boost_pad := (
		out.branch > 0 and fposmod(out.distance, SECTION_LENGTH) >= FORK_START + 88.0
		and fposmod(out.distance, SECTION_LENGTH) < FORK_START + 112.0
	)
	var item_roll := (key >> 16) % 100
	if not boost_pad and item_roll > 63:
		return
	var lane := ((key >> 5) % 5) - 2
	var x := -3.55 if lane > 0 else 3.55
	if lane == 0 and ((key >> 9) & 1) == 0:
		x = -x
	var y := float(((key >> 20) % 3) - 1) * 1.6
	if boost_pad or item_roll < 13:
		_place(out, BOOST, x, y, 1.03, 0.86)
	else:
		_place(out, ENERGY, x, y, 0.82, 0.82)


func _blocks_entities(distance: float, branch: int) -> bool:
	var offset := fposmod(distance, SECTION_LENGTH)
	if offset >= FORK_START - 20.0 and offset < FORK_END + 11.0:
		return branch == 0
	return false


func _reset_entity(row: int, branch: int, out: Entity) -> void:
	out.distance = float(row) * ROW_DISTANCE
	out.branch = signi(branch) if has_separate_entities(out.distance) else 0
	_place(out, NONE, 0.0, 0.0, 0.0, 0.0)


func _place(out: Entity, type: int, x: float, y: float, half_width: float, half_height: float) -> void:
	out.type = type
	out.x = x
	out.y = y
	out.half_width = half_width
	out.half_height = half_height


func _row_key(row: int, branch: int) -> int:
	var key := (row * 97409 + (branch + 1) * 1201247 + _salt) & 0x7FFFFFFF
	key = ((key ^ (key >> 16)) * 0x45D9F3B) & 0x7FFFFFFF
	key = ((key ^ (key >> 16)) * 0x45D9F3B) & 0x7FFFFFFF
	return key ^ (key >> 16)


func _ramp(distance: float, span: float) -> float:
	var t := clampf(distance / span, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _window(distance: float, start: float, end: float, fade: float) -> float:
	return _ramp(distance - start, fade) * _ramp(end - distance, fade)
