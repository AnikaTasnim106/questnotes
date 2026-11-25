class_name Player
extends CharacterBody2D
## The scholar-wizard. Carries the only real light in the dungeon.

const SPEED := 260.0

var facing := Vector2.RIGHT
var sprite: AnimatedSprite2D
var lantern: PointLight2D
var _step_t := 0.0
var _t := 0.0
var _hurt_t := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(30, 18)
	cs.shape = shape
	cs.position = Vector2(0, -9)
	add_child(cs)

	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 18.0, sin(a) * 6.0))
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.45)
	add_child(shadow)

	sprite = Art.sprite("wizzard_f")
	add_child(sprite)

	lantern = Art.light(Color(1.0, 0.82, 0.55), 330.0, 1.35)
	lantern.position = Vector2(0, -30)
	add_child(lantern)
	var core := Art.light(Color(1.0, 0.9, 0.7), 90.0, 0.6)
	core.position = Vector2(0, -30)
	add_child(core)


func _physics_process(delta: float) -> void:
	_t += delta
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	if dir != Vector2.ZERO:
		facing = dir.normalized()
	move_and_slide()
	# Lantern flicker
	lantern.energy = 1.3 + 0.08 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0)
	if _hurt_t > 0.0:
		_hurt_t -= delta
		sprite.modulate = Color(1, 0.35, 0.35) if int(_hurt_t * 16.0) % 2 == 0 else Color.WHITE
		if _hurt_t <= 0.0:
			sprite.modulate = Color.WHITE
	var moving := velocity.length() > 1.0
	if absf(velocity.x) > 1.0:
		sprite.flip_h = velocity.x < 0.0
	var anim := "run" if moving else "idle"
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	if moving:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.28
			Sfx.play("step", -16.0, 0.15)


func flash_hurt() -> void:
	_hurt_t = 0.5


func cast_point() -> Vector2:
	return global_position + Vector2(0, -36)
