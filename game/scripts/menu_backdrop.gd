class_name MenuBackdrop
extends Node2D
## A small lit dungeon scene behind the title screen.

const T := 48.0


func _ready() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.08, 0.065, 0.1)
	add_child(cm)
	var view := RoomView.new().setup(Vector2(-T * 2, T * 3), 32, 14, 0, 0, false, false, 42)
	add_child(view)
	# Fire fountains along the back wall
	for c in [3, 11, 19, 27]:
		var col := Vector2(-T * 2 + c * T, T * 3)
		var top := Sprite2D.new()
		top.texture = Art.tex("wall_fountain_top_1")
		top.centered = false
		top.scale = Vector2(Art.SCALE, Art.SCALE)
		top.position = col + Vector2(0, -2 * T)
		add_child(top)
		for part in [["mid", -1], ["basin", 0]]:
			var a := AnimatedSprite2D.new()
			var sf := SpriteFrames.new()
			sf.set_animation_speed("default", 6.0)
			for f in 3:
				sf.add_frame("default", Art.tex("wall_fountain_%s_red_anim_f%d" % [part[0], f]))
			a.sprite_frames = sf
			a.centered = false
			a.scale = Vector2(Art.SCALE, Art.SCALE)
			a.position = col + Vector2(0, part[1] * T)
			add_child(a)
			a.play("default")
		var l := Art.light(Color(1.0, 0.45, 0.2), 240.0, 0.75)
		l.position = col + Vector2(T * 0.5, T * 0.3)
		add_child(l)
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "energy", 1.1, 0.4 + randf() * 0.2)
		tw.tween_property(l, "energy", 0.75, 0.45 + randf() * 0.2)
	# The scholar, lantern raised, facing a pack of monsters in the dark
	var hero := Art.sprite("wizzard_f")
	hero.position = Vector2(110, 650)
	add_child(hero)
	var lantern := Art.light(Color(1.0, 0.82, 0.55), 300.0, 1.3)
	lantern.position = Vector2(110, 610)
	add_child(lantern)
	var pack := [["skelet", Vector2(250, 660)], ["orc_warrior", Vector2(340, 615)], ["necromancer", Vector2(420, 672)],
		["big_demon", Vector2(540, 630)], ["imp", Vector2(470, 600)]]
	for m in pack:
		var s := Art.sprite(m[0])
		s.position = m[1]
		s.flip_h = true
		s.frame = randi() % 4
		add_child(s)
		var g := Art.light(UI.MAGIC if m[0] != "big_demon" else UI.BAD, 90.0 if m[0] != "big_demon" else 170.0, 0.5)
		g.position = m[1] + Vector2(0, -30)
		add_child(g)
