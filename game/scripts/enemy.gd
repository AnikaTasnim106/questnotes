class_name QuestionEnemy
extends Area2D
## A question monster. Wanders, chases you when you get close, and asks its
## question when it touches you. The boss holds a queue of questions (HP).

signal touched(enemy: QuestionEnemy)

const CHASE_RANGE := 230.0

## Each entry: {"q": question Dictionary, "concept": concept Dictionary}
var queue: Array = []
var is_boss := false
var max_hp := 1
var bounds := Rect2()
var active := false
var cooldown := 0.0
var color := Color.WHITE
var speed := 50.0
var dying := false
var kind := "goblin"
var sprite: AnimatedSprite2D
var glow: PointLight2D

var _t := 0.0
var _target := Vector2.ZERO
var _player: Node2D
var _bubble: Node2D
var _hp_bar: Node2D
## Unlit layer for the "?" bubble and HP bar, so they stay readable in the dark.
var ui_parent: Node
var _bubble_y := -78.0


func setup(entries: Array, room_bounds: Rect2, diff: int, boss: bool, monster_kind: String) -> QuestionEnemy:
	queue = entries
	bounds = room_bounds
	is_boss = boss
	kind = monster_kind
	color = UI.BAD if boss else UI.diff_color(diff)
	speed = 40.0 if boss else 45.0 + 12.0 * diff
	max_hp = maxi(1, entries.size())
	return self


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = false
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 62.0 if is_boss else 22.0
	cs.shape = circle
	cs.position = Vector2(0, -58 if is_boss else -22)
	add_child(cs)

	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	var w := 56.0 if is_boss else 18.0
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * w, sin(a) * w * 0.33))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.5)
	add_child(shadow)

	sprite = Art.sprite(kind)
	if is_boss:
		sprite.scale *= 1.5
		sprite.offset.y *= 1.0
	add_child(sprite)
	glow = Art.light(color, 120.0 if is_boss else 70.0, 0.75 if is_boss else 0.55)
	glow.position = Vector2(0, -85 if is_boss else -24)
	add_child(glow)

	var host: Node = ui_parent if ui_parent != null else self
	_bubble_y = -195.0 if is_boss else -78.0
	_bubble = Node2D.new()
	_bubble.draw.connect(_draw_bubble)
	host.add_child(_bubble)
	if is_boss:
		_hp_bar = Node2D.new()
		_hp_bar.draw.connect(_draw_hp)
		host.add_child(_hp_bar)
	_place_ui()
	_t = randf() * TAU
	_pick_target()


func _place_ui() -> void:
	_bubble.global_position = global_position + Vector2(0, _bubble_y + sin(_t * 3.0) * 4.0)
	if _hp_bar:
		_hp_bar.global_position = global_position + Vector2(0, -232)


func _exit_tree() -> void:
	if is_instance_valid(_bubble) and _bubble.get_parent() != self:
		_bubble.queue_free()
	if is_instance_valid(_hp_bar) and _hp_bar.get_parent() != self:
		_hp_bar.queue_free()


func hp() -> int:
	return queue.size()


func current() -> Dictionary:
	return queue[0] if not queue.is_empty() else {}


func set_player(p: Node2D) -> void:
	_player = p


func _pick_target() -> void:
	var inner := bounds.grow(-30.0)
	_target = Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y + 40.0, inner.end.y))


func _physics_process(delta: float) -> void:
	_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	_place_ui()
	_bubble.queue_redraw()
	if _hp_bar:
		_hp_bar.queue_redraw()
	sprite.modulate.a = 0.55 if cooldown > 0.0 and not dying else 1.0
	if not active or dying:
		return
	var chasing := false
	if _player != null and cooldown <= 0.0 and not is_boss:
		var d := position.distance_to(_player.position)
		if d < CHASE_RANGE and bounds.has_point(_player.position):
			_target = _player.position
			chasing = true
	if not chasing and position.distance_to(_target) < 8.0:
		_pick_target()
	var spd := speed * (1.35 if chasing else 1.0)
	var old := position
	position = position.move_toward(_target, spd * delta)
	var inner := bounds.grow(-20.0)
	position = position.clamp(inner.position, inner.end)
	var vel := position - old
	if absf(vel.x) > 0.05:
		sprite.flip_h = vel.x < 0.0
	var anim := "run" if vel.length() > 0.05 else "idle"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	if cooldown <= 0.0:
		for b in get_overlapping_bodies():
			if b is Player:
				touched.emit(self)
				return


## Wrong answer: lunge at the player, then back off and wait.
func lunge_and_retreat() -> void:
	cooldown = 2.6 if is_boss else 1.8
	if is_boss and queue.size() > 1:
		var entry = queue.pop_front()
		queue.append(entry)  # ask it again later
	var away := Vector2.RIGHT.rotated(randf() * TAU)
	var lunge := position
	if _player != null:
		away = (position - _player.position).normalized()
		lunge = position.lerp(_player.position, 0.35)
	var inner := bounds.grow(-30.0)
	var back := (position + away * 200.0).clamp(inner.position, inner.end)
	_target = back
	var tw := create_tween()
	tw.tween_property(self, "position", lunge, 0.08)
	tw.tween_property(self, "position", back, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func flash_hit() -> void:
	var tw := create_tween()
	sprite.modulate = Color(3, 3, 3)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)


## Correct answer. Returns true if the monster is defeated.
func take_hit() -> bool:
	if not queue.is_empty():
		queue.pop_front()
	cooldown = 2.6 if is_boss else 1.2
	flash_hit()
	if _player != null:
		var away := (position - _player.position).normalized()
		var inner := bounds.grow(-30.0)
		var tw := create_tween()
		tw.tween_property(self, "position", (position + away * (140.0 if is_boss else 60.0)).clamp(inner.position, inner.end), 0.2)
	if queue.is_empty():
		_die()
		return true
	_pick_target()
	return false


func _die() -> void:
	dying = true
	active = false
	set_deferred("monitoring", false)
	_bubble.visible = false
	if _hp_bar:
		_hp_bar.visible = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale", sprite.scale * Vector2(1.6, 0.2), 0.3).set_delay(0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.12)
	tw.tween_property(glow, "energy", 2.5, 0.12)
	tw.chain().tween_callback(queue_free)


func _draw_bubble() -> void:
	if dying:
		return
	var font := UI.title_font()
	var c := Color(UI.TEXT, 0.25 if cooldown > 0.0 else 1.0)
	var r := Rect2(-14, -16, 28, 28)
	_bubble.draw_rect(r, Color(UI.PANEL, c.a * 0.95))
	_bubble.draw_rect(r, Color(color, c.a), false, 2.0)
	_bubble.draw_colored_polygon(PackedVector2Array([Vector2(-5, 12), Vector2(5, 12), Vector2(0, 19)]), Color(color, c.a))
	_bubble.draw_string(font, Vector2(-14, 6), "?", HORIZONTAL_ALIGNMENT_CENTER, 28, 22, Color(color.lightened(0.3), c.a))


func _draw_hp() -> void:
	var w := 120.0
	_hp_bar.draw_rect(Rect2(-w / 2.0 - 2, -2, w + 4, 12), Color(0, 0, 0, 0.8))
	_hp_bar.draw_rect(Rect2(-w / 2.0, 0, w * float(hp()) / float(max(1, max_hp)), 8), UI.BAD)
	_hp_bar.draw_rect(Rect2(-w / 2.0 - 2, -2, w + 4, 12), UI.BORDER_LIGHT, false, 2.0)
