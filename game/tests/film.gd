extends Node
## Plays the game like a person would, for recording the demo video with
## Godot's Movie Maker (--write-movie). Prints "MARK <name> <seconds>" for editing.

var t := 0.0
var dun: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not has_meta("runner"):
		var r: Node = (get_script() as GDScript).new()
		r.set_meta("runner", true)
		get_tree().root.add_child.call_deferred(r)
		return
	await get_tree().process_frame
	_run()


func _process(delta: float) -> void:
	t += delta


func mark(name: String) -> void:
	print("MARK %s %.2f" % [name, t])


func wait(sec: float) -> void:
	var end := t + sec
	while t < end:
		await get_tree().process_frame


func release_all() -> void:
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		Input.action_release(a)


func steer(dir: Vector2) -> void:
	release_all()
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	if dir.x > 0.05: Input.action_press("ui_right", dir.x)
	if dir.x < -0.05: Input.action_press("ui_left", -dir.x)
	if dir.y > 0.05: Input.action_press("ui_down", dir.y)
	if dir.y < -0.05: Input.action_press("ui_up", -dir.y)


## Walk to a point (or a moving node). Stops early if a battle starts.
func walk_to(target, max_time: float = 8.0, stop_dist: float = 10.0) -> void:
	var end := t + max_time
	while t < end:
		if dun.busy or dun.panel.state != QuestionPanel.State.HIDDEN:
			break
		var p: Vector2 = target.global_position if target is Node2D else target
		var d: Vector2 = p - dun.player.global_position
		if d.length() < stop_dist:
			break
		steer(d)
		await get_tree().process_frame
	release_all()


## Walk into an enemy, answer (right or wrong), and let the result play out.
func fight(e: QuestionEnemy, correct: bool, read_time: float = 2.2, after_time: float = 2.4) -> void:
	await walk_to(e, 10.0, 4.0)
	var end := t + 4.0
	while dun.panel.state != QuestionPanel.State.ASKING and t < end:
		await get_tree().process_frame
	if dun.panel.state != QuestionPanel.State.ASKING:
		return
	mark("ask")
	await wait(read_time)
	var right := int(dun.panel.q.get("answer_index", 0))
	dun.panel._choose(right if correct else (right + 1) % 4)
	end = t + 12.0
	while dun.panel.state != QuestionPanel.State.RESULT and t < end:
		await get_tree().process_frame
	mark("result_right" if correct else "result_wrong")
	await wait(after_time)
	dun.panel._close()
	mark("closed")
	end = t + 3.0
	while dun.busy and t < end:
		await get_tree().process_frame


func alive(room: Dictionary) -> Array:
	var out: Array = []
	for e in room["enemies"]:
		if is_instance_valid(e) and not e.dying:
			out.append(e)
	return out


## Clears a room fast (off-camera in the edit).
func quick_clear(ri: int) -> void:
	var room: Dictionary = dun.rooms[ri]
	var rect: Rect2 = room["rect"]
	dun.player.global_position = Vector2(rect.get_center().x, rect.end.y - 60)
	await wait(0.3)
	var guard := 0
	while not room["cleared"] and guard < 30:
		guard += 1
		var list := alive(room)
		if list.is_empty():
			await wait(0.2)
			continue
		var e: QuestionEnemy = list[0]
		while is_instance_valid(e) and e.cooldown > 0.0:
			await get_tree().process_frame
		await wait(1.05)
		if not is_instance_valid(e):
			continue
		dun.player.global_position = e.global_position + Vector2(0, 10)
		var end := t + 2.0
		while dun.panel.state != QuestionPanel.State.ASKING and t < end:
			await get_tree().process_frame
		if dun.panel.state == QuestionPanel.State.ASKING:
			dun.panel._choose(int(dun.panel.q.get("answer_index", 0)))
			while dun.panel.state != QuestionPanel.State.RESULT:
				await get_tree().process_frame
			dun.panel._close()
			while dun.busy:
				await get_tree().process_frame
		dun.player.global_position = Vector2(rect.get_center().x, rect.end.y - 60)
	await wait(0.6)


func _run() -> void:
	Game.settings.set_value("seen", "tutorial", true)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	await wait(0.5)
	mark("menu")
	await wait(6.0)
	var deck: Dictionary = {}
	for d in SampleDecks.DECKS:
		if d.id == "stacks-queues":
			deck = d.duplicate(true)
	Game.start_run(deck)
	await wait(1.2)
	dun = get_tree().current_scene
	Game.settings.set_value("seen", "tutorial", false)
	dun._show_tutorial()
	mark("tutorial")
	await wait(4.5)
	dun._close_tutorial()
	mark("room1")
	await wait(2.5)
	# Room 1: right, wrong (hint), then right again on the same monster, then the last one.
	var room: Dictionary = dun.rooms[0]
	var list := alive(room)
	list.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	await fight(list[0], true)
	mark("bolt_done")
	await wait(1.0)
	list = alive(room)
	var target: QuestionEnemy = list[0]
	await fight(target, false, 2.2, 4.2)
	mark("hurt_done")
	await wait(2.2)
	await fight(target, true, 1.6, 1.6)
	await wait(1.0)
	for e in alive(room):
		await wait(1.0)
		await fight(e, true, 1.4, 1.4)
	mark("cleared")
	await wait(1.6)
	var door_pos := Vector2(dun.RW * dun.T / 2.0, room["rect"].position.y - dun.T * 1.0)
	await walk_to(door_pos, 4.0)
	mark("through_door")
	await walk_to(door_pos + Vector2(0, -dun.T * 4), 3.0)
	await wait(1.5)
	mark("room2_seen")
	# Middle rooms: clear quickly (cut in the edit)
	for ri in range(1, dun.rooms.size() - 1):
		await quick_clear(ri)
	mark("mid_done")
	# Boss
	var boss_room: Dictionary = dun.rooms[dun.rooms.size() - 1]
	var br: Rect2 = boss_room["rect"]
	dun.player.global_position = Vector2(br.get_center().x, br.end.y + dun.T * 1.0)
	await wait(0.4)
	mark("boss_enter")
	await walk_to(Vector2(br.get_center().x, br.end.y - 80), 3.0)
	await wait(3.6)
	var boss: QuestionEnemy = alive(boss_room)[0]
	# Put an echo (a past mistake) first, if there is one, to show it on camera.
	for k in boss.queue.size():
		if str(boss.queue[k]["concept"].get("id", "")) != str(boss.get_meta("home_id", "")):
			var echo = boss.queue[k]
			boss.queue.remove_at(k)
			boss.queue.push_front(echo)
			break
	mark("boss_fight")
	await fight(boss, true, 2.4, 2.0)
	var guard := 0
	while is_instance_valid(boss) and not boss.dying and guard < 20:
		guard += 1
		while is_instance_valid(boss) and boss.cooldown > 0.0:
			await get_tree().process_frame
		await wait(1.1)
		if not is_instance_valid(boss) or boss.dying:
			break
		await fight(boss, true, 1.0, 0.9)
	mark("boss_dead")
	await wait(3.2)
	mark("results")
	await wait(4.0)
	var res := get_tree().current_scene
	var sc := res.find_children("*", "ScrollContainer", true, false)
	if not sc.is_empty():
		var s: ScrollContainer = sc[0]
		var tw := create_tween()
		tw.tween_property(s, "scroll_vertical", 520, 2.5)
	await wait(4.0)
	mark("replay_click")
	Game.start_run(Game.deck, Game.build_replay_concepts(), true)
	await wait(4.5)
	mark("end")
	await wait(0.5)
	get_tree().quit(0)
