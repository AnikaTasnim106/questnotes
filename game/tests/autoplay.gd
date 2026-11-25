extends Node
## Automated playthrough used for testing (not part of the game).
## godot --path game res://tests/autoplay.tscn -- [shots_dir] [deck_id] [mode]
## mode: "win" answers mostly right, "lose" answers everything wrong, "menu" = build from notes via backend.

var shots := ""
var deck_id := "stacks-queues"
var mode := "win"
var errors := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not has_meta("runner"):
		# This scene gets freed on the first scene change, so hand off to a node on root.
		var r: Node = (get_script() as GDScript).new()
		r.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(r)
		return
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: shots = args[0]
	if args.size() > 1: deck_id = args[1]
	if args.size() > 2: mode = args[2]
	await get_tree().create_timer(0.3).timeout
	_run()


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [shots, name])
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _scene() -> Node:
	return get_tree().current_scene


func _wait_scene(name_part: String, timeout: float = 10.0) -> bool:
	var t := 0.0
	while t < timeout:
		var s := _scene()
		if s != null and s.scene_file_path.contains(name_part):
			return true
		await _wait(0.1)
		t += 0.1
	push_error("timeout waiting for scene " + name_part)
	return false


func _run() -> void:
	# ---- Menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait_scene("main_menu")
	await _wait(1.0)
	await _shot("01_menu")
	var menu := _scene()
	var deck: Dictionary = {}
	if mode == "menu":
		var src: String = FileAccess.get_file_as_string("res://tests/notes_sample.txt")
		menu.notes_edit.text = src
		menu._update_count()
		menu._on_build()
		await _wait(0.5)
		await _shot("02_loading")
		var t := 0.0
		while menu.ready_deck.is_empty() and t < 60.0:
			await _wait(0.5)
			t += 0.5
		if menu.ready_deck.is_empty():
			print("FAIL: no deck from backend. status=", menu.status_label.text)
			get_tree().quit(1)
			return
		await _wait(0.5)
		await _shot("03_ready_card")
		deck = menu.ready_deck
	else:
		for d in SampleDecks.DECKS:
			if d.id == deck_id:
				deck = d.duplicate(true)
	Game.start_run(deck)
	await _wait_scene("dungeon")
	await _wait(1.0)
	var dun := _scene()
	if dun.tutorial != null:
		await _shot("04_tutorial")
		dun._close_tutorial()
	await _wait(0.6)
	await _shot("05_room1")
	# ---- Play
	var answered := 0
	for ri in dun.rooms.size():
		var room: Dictionary = dun.rooms[ri]
		var rect: Rect2 = room["rect"]
		dun.player.global_position = Vector2(rect.get_center().x, rect.end.y - 60)
		await _wait(0.5)
		await _wait(1.5)
		print("PERF t=%d room=%d fps=%d nodes=%d orphans=%d draws=%d objs=%d" % [Time.get_ticks_msec() / 1000, ri, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_COUNT)])
		if ri == 1:
			await _shot("06_room2_enter")
		if room["is_boss"]:
			await _wait(0.8)
			await _shot("11_boss")
		var guard := 0
		while not room["cleared"] and not dun.ending and guard < 40:
			guard += 1
			var alive: Array = []
			for e in room["enemies"]:
				if is_instance_valid(e) and not e.dying:
					alive.append(e)
			if alive.is_empty():
				await _wait(0.3)
				continue
			var e: QuestionEnemy = alive[0]
			while is_instance_valid(e) and e.cooldown > 0.0 and dun.panel.state == QuestionPanel.State.HIDDEN:
				await _wait(0.1)
			await _wait(1.05)  # player's post-battle safety window
			if not is_instance_valid(e):
				continue
			dun.player.global_position = e.global_position + Vector2(0, 10)
			var t := 0.0
			while dun.panel.state != QuestionPanel.State.ASKING and t < 3.0:
				await _wait(0.05)
				t += 0.05
			if dun.panel.state != QuestionPanel.State.ASKING:
				print("WARN: panel didn't open for enemy in room ", ri)
				continue
			var q: Dictionary = dun.panel.q
			var right := int(q.get("answer_index", 0))
			var pick := right
			if mode == "lose" or (answered % 5 == 2):
				pick = (right + 1) % 4
			if answered == 0:
				await _shot("07_question")
			dun.panel._choose(pick)
			t = 0.0
			while dun.panel.state != QuestionPanel.State.RESULT and t < 15.0:
				await _wait(0.1)
				t += 0.1
			if answered == 2:
				await _shot("08_wrong_hint")
			if answered == 0:
				await _shot("08b_correct")
			answered += 1
			dun.panel._close()
			if pick == right and answered == 1:
				await _wait(0.15)
				await _shot("09_bolt")
			t = 0.0
			while dun.busy and t < 5.0:
				await _wait(0.05)
				t += 0.05
			dun.player.global_position = Vector2(rect.get_center().x, rect.end.y - 60)
			await _wait(0.3)
			if dun.ending:
				break
		if dun.ending:
			break
		if room["is_boss"] and ri == dun.rooms.size() - 1:
			pass
		elif room["cleared"]:
			await _wait(0.7)
			if ri == 0:
				dun.player.global_position = Vector2(rect.get_center().x, rect.position.y + 40)
				await _wait(0.4)
				await _shot("10_door_open")
		if ri == dun.rooms.size() - 2:
			pass
	# boss shot handled above via room loop; take one when entering boss
	print("answered=", answered, " hearts=", Game.hearts, " score=", Game.score, " won=", Game.won)
	await _wait_scene("results", 15.0)
	await _wait(0.8)
	await _shot("12_results")
	var res := _scene()
	print("RESULT_OK scene=", res.scene_file_path, " stats=", Game.stats.size())
	get_tree().quit(0)
