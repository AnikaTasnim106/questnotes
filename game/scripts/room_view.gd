class_name RoomView
extends Node2D
## Paints one room (floor, walls, the corridor above it) from 16x16 tiles at 3x.
## One node per room keeps each canvas item under the per-object light limit.

const T := 48.0

var rw := 18
var rh := 9
var corr := 2
var door_col := 8
var has_door := true
var has_south_gap := false
var seed_value := 0
var _floor: Array = []


func setup(origin: Vector2, w: int, h: int, corridor: int, dcol: int, door: bool, south_gap: bool, s: int) -> RoomView:
	position = origin
	rw = w
	rh = h
	corr = corridor
	door_col = dcol
	has_door = door
	has_south_gap = south_gap
	seed_value = s
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	for i in rw * rh + 2 * (corr + 2):
		var r := rng.randf()
		_floor.append("floor_1" if r < 0.7 else "floor_%d" % rng.randi_range(2, 8))
	return self


func _tile(name: String, col: float, row: float) -> void:
	var t := Art.tex(name)
	if t != null:
		draw_texture_rect(t, Rect2(Vector2(col, row) * T, t.get_size() * Art.SCALE), false)


func _draw() -> void:
	# Floor
	for y in rh:
		for x in rw:
			_tile(_floor[y * rw + x], x, y)
	# North wall face: two rows of brick, with a cap line above.
	for x in range(-1, rw + 1):
		var in_door := has_door and (x == door_col or x == door_col + 1)
		if in_door:
			continue
		_tile("wall_mid", x, -2)
		_tile("wall_mid", x, -1)
		var cap_blocked := has_door and (x >= door_col - 1 and x <= door_col + 2)
		if not cap_blocked:
			_tile("wall_top_mid", x, -3)
	# Side walls
	for y in range(-2, rh + 1):
		_tile("wall_edge_mid_left", -1, y)
		_tile("wall_edge_mid_right", rw, y)
	# South edge: cap line along the bottom of the floor
	for x in range(-1, rw + 1):
		if has_south_gap and (x == door_col or x == door_col + 1):
			continue
		_tile("wall_top_mid", x, rh - 1)
	# Corridor going north (floor under the door + the passage)
	if has_door:
		var k := rw * rh
		for y in range(-2 - corr, 0):
			for x in [door_col, door_col + 1]:
				if y >= -2:
					_tile("floor_1", x, y)
				else:
					_tile(_floor[k % _floor.size()], x, y)
					k += 1
			if y < -2:
				_tile("wall_edge_mid_left", door_col - 1, y)
				_tile("wall_edge_mid_right", door_col + 2, y)
