extends Control
## End screen: score, mastery per concept, and a review of every missed question
## (here the correct answer IS shown, with the line from the notes).
## "Replay weak spots" builds a new mini-dungeon from only the missed questions.

func _ready() -> void:
	get_tree().paused = false
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	UI.full_rect(bg)
	add_child(bg)
	add_child(UI.vignette())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := UI.margin(scroll, 40)
	UI.full_rect(m)
	add_child(m)
	var v := UI.vbox(18)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var head := UI.hbox(20)
	v.add_child(head)
	var ic := UI.icon("chest_full_open_anim_f2" if Game.won else "skull", 4.0)
	ic.custom_minimum_size = Vector2(80, 80)
	head.add_child(ic)
	var hv := UI.vbox(4)
	head.add_child(hv)
	hv.add_child(UI.title("Dungeon conquered!" if Game.won else "The dungeon got you this time.", 46, UI.GOOD if Game.won else UI.BAD))
	var acc := int(round(Game.accuracy() * 100.0))
	var n := Game.stats.size()
	hv.add_child(UI.label("Score %d   ·   First-try accuracy %d%%   ·   %d question%s faced" % [
		Game.score, acc, n, "" if n == 1 else "s"], 21, UI.TEXT))

	# Buttons
	var row := UI.hbox(12)
	v.add_child(row)
	var replay_concepts := Game.build_replay_concepts()
	if not replay_concepts.is_empty():
		var rb := UI.button("Replay weak spots", 250, true)
		rb.pressed.connect(func(): Game.start_run(Game.deck, replay_concepts, true))
		row.add_child(rb)
	var again := UI.button("Play full dungeon again", 270)
	again.pressed.connect(func(): Game.start_run(Game.deck))
	row.add_child(again)
	var menu := UI.button("Main menu", 160)
	menu.pressed.connect(func(): Transition.go("res://scenes/main_menu.tscn"))
	row.add_child(menu)

	# Mastery per concept
	v.add_child(UI.title("Mastery by topic", 26))
	for c in Game.concept_mastery():
		var line := UI.hbox(14)
		var name_l := UI.label(str(c.name), 18, UI.diff_color(int(c.difficulty)))
		name_l.custom_minimum_size = Vector2(340, 0)
		line.add_child(name_l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(320, 22)
		bar.show_percentage = false
		bar.max_value = maxi(1, int(c.answered))
		bar.value = int(c.first_try)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var txt := "not reached" if int(c.answered) == 0 else "%d / %d right first try" % [int(c.first_try), int(c.answered)]
		line.add_child(UI.label(txt, 16, UI.MUTED))
		v.add_child(line)

	# Review of missed questions
	var missed: Array = []
	for id in Game.stats:
		var s: Dictionary = Game.stats[id]
		if not s.first_try:
			missed.append(s)
	if missed.is_empty():
		v.add_child(UI.label("No mistakes. Your notes have nothing left to teach this dungeon.", 20, UI.GOOD, true))
		return
	v.add_child(UI.title("Review what tripped you up", 26))
	for s in missed:
		var q: Dictionary = s.question
		var card := PanelContainer.new()
		var cv := UI.vbox(6)
		card.add_child(UI.margin(cv, 4))
		cv.add_child(UI.label(str(s.concept_name), 14, UI.MUTED))
		cv.add_child(UI.label(str(q.get("prompt", "")), 19, UI.TEXT, true))
		var choices: Array = q.get("choices", [])
		var ai := int(q.get("answer_index", 0))
		if ai < choices.size():
			cv.add_child(UI.label("Answer: " + str(choices[ai]), 17, UI.GOOD, true))
		cv.add_child(UI.label(str(q.get("explanation", "")), 16, UI.TEXT, true))
		cv.add_child(UI.label("From your notes:  “%s”" % str(q.get("source_quote", "")), 15, UI.ACCENT, true))
		v.add_child(card)
