extends Node2D
## Builds the dungeon from Game.run_concepts and runs the play loop.
## Rooms stack northward: you start at the bottom and climb toward the boss.
## One room per concept, one monster per question, hardest concept = boss.

const T := 48.0
const RW := 18
const RH := 9
const CORR := 2
const DOOR_COL := 8
const STRIDE := RH + CORR + 2
const DARK := Color(0.085, 0.07, 0.105)
const DARK_BOSS := Color(0.13, 0.05, 0.07)
const ZOOM := 1.0

var rooms: Array = []
var player: Player
var camera: Camera2D
var panel: QuestionPanel
var overlay: CanvasLayer      # unlit world-space layer (bubbles, popups)
var modulate_node: CanvasModulate
var current_room := -1
var combo := 0
var busy := false
var safe_until := 0.0   # seconds; touches are ignored until then
var ending := false

var hud_root: Control
var fps_label: Label
var hearts_box: HBoxContainer
var pips_ctrl: Control
var hud_score: Label
var hud_combo: Label
var objective: Label
var banner_box: Control
var banner: Label
var banner_sub: Label
var banner_tw: Tween
var flash_rect: ColorRect
var tutorial: Control


func _ready() -> void:
	get_tree().paused = false
	var concepts: Array = Game.ordered_concepts()
	if concepts.is_empty():
		Transition.go("res://scenes/main_menu.tscn")
		return
	modulate_node = CanvasModulate.new()
	modulate_node.color = DARK
	add_child(modulate_node)
	overlay = CanvasLayer.new()
	overlay.layer = 1
	overlay.follow_viewport_enabled = true
	add_child(overlay)

	for i in concepts.size():
		_build_room(i, concepts[i], i == concepts.size() - 1)
	_spawn_player()
	_build_hud()
	panel = QuestionPanel.new()
	add_child(panel)
	Api.wake()
	Sfx.ambient(true)
	_update_hud()
	if not Game.seen("tutorial"):
		_show_tutorial()


func _room_origin(i: int) -> Vector2:
	return Vector2(0.0, -float(i * STRIDE) * T)


# ---------------------------------------------------------------- building

func _spawn_player() -> void:
	player = Player.new()
	player.position = Vector2(RW * T / 2.0, (RH - 1.2) * T)
	add_child(player)
	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()


func _process(_delta: float) -> void:
	if fps_label and fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	if camera == null or player == null:
		return
	# Inside a room: frame the whole room. In a corridor: follow the player.
	var target := Vector2(RW * T / 2.0, player.position.y)
	for r in rooms:
		var rect: Rect2 = r["rect"]
		if rect.grow(T * 0.4).has_point(player.position):
			target.y = rect.position.y + 157.0
			break
	camera.position = target


func _wall(rect_tiles: Rect2, origin: Vector2) -> void:
	add_child(Block.new().setup(Rect2(origin + rect_tiles.position * T, rect_tiles.size * T)))


func _build_room(i: int, concept: Dictionary, is_boss: bool) -> void:
	var origin := _room_origin(i)
	var has_door := not is_boss
	var view := RoomView.new().setup(origin, RW, RH, CORR, DOOR_COL, has_door, i > 0, hash(str(concept.get("id", i))) + i)
	add_child(view)

	# Collision
	if has_door:
		_wall(Rect2(-1, -2, DOOR_COL + 1, 2), origin)
		_wall(Rect2(DOOR_COL + 2, -2, RW - DOOR_COL - 1, 2), origin)
		_wall(Rect2(DOOR_COL - 1, -2 - CORR, 1, CORR), origin)
		_wall(Rect2(DOOR_COL + 2, -2 - CORR, 1, CORR), origin)
	else:
		_wall(Rect2(-1, -2, RW + 2, 2), origin)
	_wall(Rect2(-1, -2, 1, RH + 3), origin)
	_wall(Rect2(RW, -2, 1, RH + 3), origin)
	if i == 0:
		_wall(Rect2(-1, RH, RW + 2, 1), origin)
	else:
		_wall(Rect2(-1, RH, DOOR_COL + 1, 1), origin)
		_wall(Rect2(DOOR_COL + 2, RH, RW - DOOR_COL - 1, 1), origin)

	var door: Door = null
	if has_door:
		door = Door.new().setup(origin + Vector2(DOOR_COL, -2) * T, T)
		add_child(door)

	_decorate(i, origin, is_boss)

	var rect := Rect2(origin, Vector2(RW, RH) * T)
	var room := {"rect": rect, "concept": concept, "enemies": [], "door": door,
		"is_boss": is_boss, "entered": false, "cleared": false, "index": i}

	# Trigger: fires when the player steps into the room
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size - Vector2(T, T) * 1.5
	cs.shape = shape
	cs.position = rect.get_center()
	area.add_child(cs)
	area.body_entered.connect(_on_room_body_entered.bind(i))
	add_child(area)

	# Monsters
	var bounds := Rect2(rect.position + Vector2(T * 0.6, T * 0.9), rect.size - Vector2(T * 1.2, T * 1.3))
	var diff := int(concept.get("difficulty", 1))
	var questions: Array = concept.get("questions", [])
	var cid := str(concept.get("id", ""))
	if is_boss:
		var entries: Array = []
		for q in questions:
			entries.append({"q": q, "concept": concept})
		entries.shuffle()
		var boss := QuestionEnemy.new().setup(entries, bounds, 3, true, Art.boss_for(cid + str(Game.deck.get("id", ""))))
		boss.position = Vector2(rect.get_center().x, rect.position.y + T * 4.5)
		boss.set_meta("home_id", cid)
		_add_enemy(boss, room)
	else:
		var n := questions.size()
		for k in n:
			var q: Dictionary = questions[k]
			var e := QuestionEnemy.new().setup([{"q": q, "concept": concept}], bounds, diff, false,
				Art.monster_for(diff, str(q.get("id", k))))
			var fx := (float(k) + 0.5) / float(n)
			e.position = Vector2(
				rect.position.x + T * 1.5 + fx * (rect.size.x - T * 3.0),
				rect.position.y + T * randf_range(1.6, 4.8))
			e.set_meta("home_id", cid)
			_add_enemy(e, room)
	rooms.append(room)


func _decorate(i: int, origin: Vector2, is_boss: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919 + 13
	# Fountains of fire (light sources) on the north wall, left and right of the door.
	var cols := [3, RW - 4]
	for c in cols:
		var color := "red" if (is_boss or rng.randf() < 0.6) else "blue"
		_fountain(origin, c, color)
	# Banners on the remaining wall
	var banners := ["wall_banner_red", "wall_banner_green", "wall_banner_blue", "wall_banner_yellow"]
	for c in [1, 6, RW - 7, RW - 2]:
		if c in cols or (not is_boss and (c == DOOR_COL - 1 or c == DOOR_COL + 2)):
			continue
		var s := Sprite2D.new()
		s.texture = Art.tex(banners[rng.randi() % banners.size()])
		s.centered = false
		s.scale = Vector2(Art.SCALE, Art.SCALE)
		s.position = origin + Vector2(c, -2) * T
		add_child(s)
	# A few skulls on the floor
	for k in rng.randi_range(1, 3):
		var s := Sprite2D.new()
		s.texture = Art.tex("skull")
		s.scale = Vector2(Art.SCALE, Art.SCALE)
		s.position = origin + Vector2(rng.randf_range(1, RW - 1), rng.randf_range(5.5, RH - 1)) * T
		s.modulate = Color(1, 1, 1, 0.85)
		add_child(s)


func _fountain(origin: Vector2, col: int, color: String) -> void:
	var top := Sprite2D.new()
	top.texture = Art.tex("wall_fountain_top_1")
	top.centered = false
	top.scale = Vector2(Art.SCALE, Art.SCALE)
	top.position = origin + Vector2(col, -2) * T
	add_child(top)
	for part in [["mid", -1], ["basin", 0]]:
		var a := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", 6.0)
		for f in 3:
			var t := Art.tex("wall_fountain_%s_%s_anim_f%d" % [part[0], color, f])
			if t != null:
				sf.add_frame("default", t)
		a.sprite_frames = sf
		a.centered = false
		a.scale = Vector2(Art.SCALE, Art.SCALE)
		a.position = origin + Vector2(col, part[1]) * T
		add_child(a)
		a.play("default")
		a.frame = randi() % 3
	add_child(Block.new().setup(Rect2(origin + Vector2(col, 0) * T, Vector2(T, T * 0.6))))
	var lc := Color(1.0, 0.45, 0.2) if color == "red" else Color(0.35, 0.6, 1.0)
	var light := Art.light(lc, 230.0, 0.75)
	light.position = origin + Vector2(col + 0.5, 0.2) * T
	add_child(light)
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "energy", 0.9, 0.35 + randf() * 0.2)
	tw.tween_property(light, "energy", 0.6, 0.4 + randf() * 0.2)


func _add_enemy(e: QuestionEnemy, room: Dictionary) -> void:
	e.ui_parent = overlay
	add_child(e)
	e.set_player(player)
	e.touched.connect(_on_enemy_touched)
	(room["enemies"] as Array).append(e)


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud_root = Control.new()
	hud_root.theme = UI.make_theme()
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(hud_root)
	layer.add_child(hud_root)
	hud_root.add_child(UI.vignette())

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(flash_rect)
	hud_root.add_child(flash_rect)

	# Top bar
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.85), UI.BORDER, 0, 0))
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	hud_root.add_child(bar)
	var top := UI.hbox(22)
	bar.add_child(top)
	hearts_box = UI.hbox(4)
	top.add_child(hearts_box)
	var title := UI.title(str(Game.deck.get("title", "")), 20, UI.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	top.add_child(title)
	pips_ctrl = Control.new()
	pips_ctrl.custom_minimum_size = Vector2(rooms.size() * 22 + 8, 24)
	pips_ctrl.draw.connect(_draw_pips)
	pips_ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(pips_ctrl)
	hud_combo = UI.title("", 20, UI.MAGIC)
	top.add_child(hud_combo)
	hud_score = UI.title("", 22, UI.ACCENT)
	hud_score.custom_minimum_size = Vector2(110, 0)
	hud_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(hud_score)
	var help := UI.button("?", 50)
	help.tooltip_text = "How to play"
	help.pressed.connect(_show_tutorial)
	top.add_child(help)
	var mute := UI.button("Sound", 90)
	mute.pressed.connect(func():
		Sfx.toggle_mute()
		mute.text = "Muted" if Sfx.muted else "Sound")
	top.add_child(mute)
	fps_label = UI.label("", 14, UI.MUTED)
	fps_label.visible = false
	top.add_child(fps_label)
	var quit := UI.button("Menu", 90)
	quit.pressed.connect(_quit)
	top.add_child(quit)

	# Banner
	banner_box = UI.vbox(4)
	banner = UI.title("", 38, UI.ACCENT, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner)
	banner_sub = UI.label("", 19, UI.TEXT, true)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	banner_sub.add_theme_constant_override("shadow_offset_y", 2)
	banner_box.add_child(banner_sub)
	var bm := MarginContainer.new()
	bm.add_theme_constant_override("margin_left", 180)
	bm.add_theme_constant_override("margin_right", 180)
	bm.add_theme_constant_override("margin_top", 92)
	bm.add_child(banner_box)
	bm.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bm)
	banner_box.modulate.a = 0.0

	# Objective line at the bottom
	var obar := PanelContainer.new()
	obar.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.8), UI.BORDER, 0, 0))
	obar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	obar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	obar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(obar)
	objective = UI.label("", 18, UI.TEXT)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obar.add_child(objective)


func _draw_pips() -> void:
	for k in rooms.size():
		var r: Dictionary = rooms[k]
		var c := Vector2(12 + k * 22, 12)
		var col := UI.MUTED.darkened(0.4)
		if r["cleared"]:
			col = UI.GOOD
		elif k == current_room:
			col = UI.ACCENT
		if r["is_boss"]:
			pips_ctrl.draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), col, k == current_room or r["cleared"])
			pips_ctrl.draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), col, false, 2.0)
		else:
			pips_ctrl.draw_circle(c, 7.0, col)


func _update_hud() -> void:
	hud_score.text = "%d" % Game.score
	hud_combo.text = ("x%d combo" % combo) if combo >= 2 else ""
	for c in hearts_box.get_children():
		c.queue_free()
	for k in Game.max_hearts:
		hearts_box.add_child(UI.icon("ui_heart_full" if k < Game.hearts else "ui_heart_empty", 2.5))
	pips_ctrl.queue_redraw()
	objective.text = _objective_text()


func _objective_text() -> String:
	if current_room < 0:
		return "Walk up into the first room  ·  WASD / Arrow keys to move"
	var r: Dictionary = rooms[current_room]
	var left := 0
	for e in r["enemies"]:
		if is_instance_valid(e) and not e.dying:
			left += 1
	if r["is_boss"]:
		return "BOSS  ·  Walk into it to answer. Each right answer takes one bar of its health."
	if r["cleared"]:
		return "Room cleared!  The door to the north is open. Keep climbing."
	return "%d monster%s left  ·  Walk into a  ?  monster to answer its question" % [left, "" if left == 1 else "s"]


func _show_banner(title: String, sub: String) -> void:
	banner.text = title
	banner_sub.text = sub
	if banner_tw != null and banner_tw.is_valid():
		banner_tw.kill()
	banner_box.modulate.a = 0.0
	banner_tw = create_tween()
	banner_tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	banner_tw.tween_interval(2.8)
	banner_tw.tween_property(banner_box, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------- tutorial

func _show_tutorial() -> void:
	if tutorial != null or busy:
		return
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	tutorial = Control.new()
	tutorial.theme = UI.make_theme()
	UI.full_rect(tutorial)
	layer.add_child(tutorial)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	UI.full_rect(dim)
	tutorial.add_child(dim)
	var center := CenterContainer.new()
	UI.full_rect(center)
	tutorial.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(700, 0)
	center.add_child(p)
	var v := UI.vbox(16)
	p.add_child(UI.margin(v, 14))
	v.add_child(UI.title("How to play", 34))
	var rows := [
		["wizzard_f_idle_anim_f0", "Move with  WASD  or the  arrow keys."],
		["goblin_idle_anim_f0", "Every monster holds one question from your notes. Walk into it to answer (keys 1-4 or click)."],
		["ui_heart_full", "Right answer: your magic destroys it. Wrong answer: you lose a heart, but get a hint and the exact line from your notes."],
		["doors_leaf_closed", "Defeat every monster in a room to open the door. The boss waits at the top, and it remembers your mistakes."],
	]
	for row in rows:
		var h := UI.hbox(18)
		var ic := UI.icon(row[0], 2.5)
		ic.custom_minimum_size = Vector2(80, 64)
		h.add_child(ic)
		var l := UI.label(row[1], 19, UI.TEXT, true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		v.add_child(h)
	var go := UI.button("Got it, let's go  (Space)", 300, true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_close_tutorial)
	v.add_child(go)
	tutorial.set_meta("layer", layer)
	var kc := KeyCatcher.new()
	layer.add_child(kc)
	kc.key.connect(func(k: int):
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_tutorial())


func _close_tutorial() -> void:
	if tutorial == null:
		return
	Game.mark_seen("tutorial")
	(tutorial.get_meta("layer") as Node).queue_free()
	tutorial = null
	get_tree().paused = false


# ---------------------------------------------------------------- play loop

func _on_room_body_entered(body: Node2D, i: int) -> void:
	if not (body is Player) or ending:
		return
	current_room = i
	var r: Dictionary = rooms[i]
	if r["entered"]:
		_update_hud()
		return
	r["entered"] = true
	for e in r["enemies"]:
		e.active = true
	var concept: Dictionary = r["concept"]
	if r["is_boss"]:
		var extra := ""
		var enemies: Array = r["enemies"]
		if not enemies.is_empty():
			var boss: QuestionEnemy = enemies[0]
			# Spaced repetition: the boss also asks up to 2 questions you missed earlier.
			var echoes := Game.missed_entries(str(concept.get("id", "")))
			echoes.shuffle()
			for k in mini(2, echoes.size()):
				boss.queue.append(echoes[k])
			boss.max_hp = boss.queue.size()
			if not echoes.is_empty():
				extra = "\nIt remembers the questions you got wrong..."
		Sfx.play("boss", 0.0)
		var tw := create_tween()
		tw.tween_property(modulate_node, "color", DARK_BOSS, 1.2)
		_shake(10.0)
		_show_banner("BOSS  ·  " + str(concept.get("name", "")), "Defeat it to conquer the dungeon." + extra)
	else:
		var sub := str(concept.get("summary", ""))
		if Game.is_replay and i == 0:
			sub = "Review run: only the questions you missed.\n" + sub
		_show_banner("Room %d of %d  ·  %s" % [i + 1, rooms.size(), str(concept.get("name", ""))], sub)
	_update_hud()


func _on_enemy_touched(e: QuestionEnemy) -> void:
	if busy or ending or e.dying or tutorial != null:
		return
	if Time.get_ticks_msec() / 1000.0 < safe_until:
		return
	var entry := e.current()
	if entry.is_empty():
		return
	busy = true
	Sfx.play("battle", -3.0)
	_flash(Color(1, 1, 1, 0.35), 0.18)
	var zoom_tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	zoom_tw.tween_property(camera, "zoom", Vector2(1.25, 1.25), 0.12)
	get_tree().paused = true
	var q: Dictionary = entry["q"]
	var concept: Dictionary = entry["concept"]
	var label := str(concept.get("name", ""))
	if e.is_boss and str(concept.get("id", "")) != str(e.get_meta("home_id", "")):
		label = "Echo of a past mistake  ·  " + label
	panel.ask(q, label, e.is_boss, e.kind, e.color)
	var correct: bool = await panel.closed
	get_tree().paused = false
	var zt := create_tween()
	zt.tween_property(camera, "zoom", Vector2(ZOOM, ZOOM), 0.2)
	if not is_instance_valid(e):
		busy = false
		return
	var first := Game.record_answer(q, concept, correct)
	if correct:
		await _on_correct(e, first)
	else:
		_on_wrong(e)
	safe_until = Time.get_ticks_msec() / 1000.0 + 1.0
	busy = false
	_update_hud()


func _on_correct(e: QuestionEnemy, first: bool) -> void:
	var pts := 40
	if first:
		pts = 100 + 25 * combo
		combo += 1
	if e.is_boss:
		pts += 50
	Game.score += pts
	await _cast_bolt(e)
	if not is_instance_valid(e):
		return
	Sfx.play("correct", -2.0)
	_float_text(e.global_position + Vector2(0, -90), "+%d" % pts, UI.ACCENT)
	var pos := e.global_position + Vector2(0, -30)
	var boss := e.is_boss
	var c := e.color
	if e.take_hit():
		Sfx.play("poof", 0.0, 0.1)
		_burst(pos, c, 46 if boss else 28)
		_shake(14.0 if boss else 6.0)
		await get_tree().create_timer(0.05).timeout
		_on_enemy_defeated(e)
	else:
		_burst(pos, c, 12)
		_shake(5.0)


func _cast_bolt(e: QuestionEnemy) -> void:
	Sfx.play("cast", -4.0, 0.1)
	var bolt := Node2D.new()
	bolt.global_position = player.cast_point()
	var orb := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0)
	orb.polygon = pts
	orb.color = UI.MAGIC.lightened(0.4)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	orb.material = mat
	bolt.add_child(orb)
	bolt.add_child(Art.light(UI.MAGIC, 140.0, 1.6))
	var trail := CPUParticles2D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 5.0
	trail.initial_velocity_max = 20.0
	trail.scale_amount_min = 3.0
	trail.scale_amount_max = 5.0
	trail.color = UI.MAGIC
	trail.local_coords = false
	trail.material = mat
	bolt.add_child(trail)
	add_child(bolt)
	var target := e.global_position + Vector2(0, -85 if e.is_boss else -26)
	var tw := create_tween()
	tw.tween_property(bolt, "global_position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	bolt.queue_free()


func _on_wrong(e: QuestionEnemy) -> void:
	combo = 0
	Game.hearts -= 1
	Sfx.play("hurt", 0.0)
	player.flash_hurt()
	_shake(12.0)
	_flash(Color(0.9, 0.1, 0.1, 0.35), 0.35)
	_float_text(player.global_position + Vector2(0, -90), "-1 heart", UI.BAD)
	e.lunge_and_retreat()
	if Game.hearts <= 0:
		_end_run(false)


func _on_enemy_defeated(e: QuestionEnemy) -> void:
	for r in rooms:
		var enemies: Array = r["enemies"]
		if not enemies.has(e):
			continue
		enemies.erase(e)
		if enemies.is_empty() and not r["cleared"]:
			r["cleared"] = true
			if r["is_boss"]:
				_end_run(true)
			else:
				Sfx.play("clear", -2.0)
				var door: Door = r["door"]
				if door != null:
					get_tree().create_timer(0.5).timeout.connect(door.open)
				_show_banner("Room cleared!", "The door to the north is open.")
		_update_hud()
		return


func _end_run(won: bool) -> void:
	if ending:
		return
	ending = true
	Game.won = won
	for r in rooms:
		for e in r["enemies"]:
			if is_instance_valid(e):
				e.active = false
	if won:
		Sfx.play("victory", 0.0)
		_show_banner("Dungeon conquered!", "")
	else:
		Sfx.play("defeat", 0.0)
		_show_banner("The dungeon got you...", "Let's see what to review.")
	await get_tree().create_timer(2.4).timeout
	Transition.go("res://scenes/results.tscn")


func _quit() -> void:
	get_tree().paused = false
	Transition.go("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_F3:
		fps_label.visible = not fps_label.visible
		return
	if event.is_action_pressed("ui_cancel") and not busy and tutorial == null:
		_quit()


# ---------------------------------------------------------------- juice

func _flash(c: Color, dur: float) -> void:
	flash_rect.color = c
	var tw := flash_rect.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash_rect, "color:a", 0.0, dur)


func _shake(strength: float) -> void:
	var tw := create_tween()
	for k in 6:
		tw.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength, 0.035)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func _burst(pos: Vector2, c: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 7.0
	var g := Gradient.new()
	g.set_color(0, c.lightened(0.4))
	g.set_color(1, Color(c, 0.0))
	p.color_ramp = g
	overlay.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _float_text(pos: Vector2, text: String, c: Color) -> void:
	var l := UI.title(text, 30, c)
	l.position = pos + Vector2(-60, 0)
	l.size = Vector2(120, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
