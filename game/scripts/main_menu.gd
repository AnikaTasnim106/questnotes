extends Control
## Title screen. Main path: upload or paste your notes. Demo decks are secondary.

const MIN_CHARS := 300
const LOADING_LINES := [
	"Reading your notes...",
	"Finding the key concepts...",
	"Summoning question monsters...",
	"Checking every question against your notes...",
	"Lighting the torches...",
]
const DEMO_ORDER := ["stacks-queues", "photosynthesis"]

var ui: Control
var notes_edit: TextEdit
var count_label: Label
var status_label: Label
var build_btn: Button
var upload_btn: Button
var overlay: Control
var overlay_title: Label
var overlay_sub: Label
var overlay_actions: HBoxContainer
var overlay_sprite: AnimatedSprite2D
var loading_timer: Timer
var loading_i := 0
var loading_elapsed := 0
var ready_deck: Dictionary = {}
var web_picker: WebFilePicker
var file_dialog: FileDialog


func _ready() -> void:
	get_tree().paused = false
	add_child(MenuBackdrop.new())
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	ui = Control.new()
	ui.theme = UI.make_theme()
	UI.full_rect(ui)
	layer.add_child(ui)
	ui.add_child(UI.vignette())
	_build_ui()
	_build_overlay()
	web_picker = WebFilePicker.new()
	add_child(web_picker)
	web_picker.picked.connect(_on_file_picked)
	Sfx.ambient(true)
	Api.wake()  # start waking the free-tier server while the player reads the menu


func _build_ui() -> void:
	var root := UI.hbox(48)
	var m := UI.margin(root, 44)
	UI.full_rect(m)
	ui.add_child(m)

	# Left: title, how it works
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	left.add_child(UI.title("QuestNotes", 80, UI.ACCENT))
	left.add_child(UI.label("Turn your notes into a dungeon.\nEvery monster is a question from your own material.", 21, UI.TEXT, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	left.add_child(gap)
	var steps := [
		["flask_big_green", "1  Upload your notes", "Lecture PDF, textbook section, or just paste text."],
		["orc_warrior_idle_anim_f0", "2  Fight your questions", "Each room is a concept. Answer right to banish its monsters."],
		["chest_full_open_anim_f0", "3  Review your weak spots", "Missed questions come back: in the boss, and in a review run."],
	]
	for s in steps:
		var row := UI.hbox(14)
		var ic := UI.icon(s[0], 2.5)
		ic.custom_minimum_size = Vector2(56, 56)
		row.add_child(ic)
		var col := UI.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.title(s[1], 21, UI.TEXT))
		col.add_child(UI.label(s[2], 16, UI.MUTED, true))
		row.add_child(col)
		left.add_child(row)

	# Right: build from notes (the main action)
	var right := UI.vbox(14)
	right.custom_minimum_size = Vector2(560, 0)
	root.add_child(right)
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(panel)
	var pv := UI.vbox(12)
	panel.add_child(UI.margin(pv, 8))
	pv.add_child(UI.title("Start with your notes", 28))
	upload_btn = UI.button("Upload PDF or TXT", 0, true)
	upload_btn.custom_minimum_size = Vector2(0, 62)
	upload_btn.add_theme_font_size_override("font_size", 24)
	upload_btn.pressed.connect(_on_upload)
	pv.add_child(upload_btn)
	pv.add_child(UI.label("or paste text:", 16, UI.MUTED))
	notes_edit = TextEdit.new()
	notes_edit.placeholder_text = "Paste lecture notes, a textbook section or your own summary (at least %d characters)." % MIN_CHARS
	notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_edit.custom_minimum_size = Vector2(0, 150)
	notes_edit.add_theme_font_size_override("font_size", 16)
	notes_edit.text_changed.connect(_update_count)
	pv.add_child(notes_edit)
	var row2 := UI.hbox(10)
	pv.add_child(row2)
	count_label = UI.label("0 characters", 15, UI.MUTED)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row2.add_child(count_label)
	build_btn = UI.button("Build my dungeon", 230)
	build_btn.pressed.connect(_on_build)
	row2.add_child(build_btn)
	status_label = UI.label("", 16, UI.BAD, true)
	pv.add_child(status_label)
	pv.add_child(UI.label("Every question is checked against your notes. If the AI can't point to the exact line, the question is thrown out.", 14, UI.MUTED, true))

	# Demos (secondary)
	var demo := UI.vbox(6)
	right.add_child(demo)
	demo.add_child(UI.label("No notes handy? Try a demo dungeon:", 16, UI.MUTED))
	var drow := UI.hbox(8)
	demo.add_child(drow)
	for id in DEMO_ORDER:
		for d in SampleDecks.DECKS:
			if d.id != id:
				continue
			var b := UI.button(str(d.subject), 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 42)
			b.add_theme_font_size_override("font_size", 16)
			b.add_theme_font_override("font", UI.body_font())
			b.pressed.connect(_play_sample.bind(d))
			drow.add_child(b)
	_update_count()


func _build_overlay() -> void:
	overlay = Control.new()
	UI.full_rect(overlay)
	overlay.visible = false
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	UI.full_rect(dim)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	UI.full_rect(center)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)
	var v := UI.vbox(16)
	panel.add_child(UI.margin(v, 16))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 90)
	v.add_child(stage)
	overlay_sprite = Art.sprite("wizzard_f")
	overlay_sprite.play("run")
	overlay_sprite.position = Vector2(314, 88)
	stage.add_child(overlay_sprite)
	overlay_title = UI.title("", 30, UI.ACCENT, true)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(overlay_title)
	overlay_sub = UI.label("", 18, UI.TEXT, true)
	overlay_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(overlay_sub)
	overlay_actions = UI.hbox(12)
	overlay_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(overlay_actions)
	loading_timer = Timer.new()
	loading_timer.wait_time = 2.2
	loading_timer.timeout.connect(_tick_loading)
	add_child(loading_timer)


func _update_count() -> void:
	var n := notes_edit.text.strip_edges().length()
	count_label.text = "%d characters" % n if n >= MIN_CHARS else "%d / %d characters" % [n, MIN_CHARS]
	count_label.add_theme_color_override("font_color", UI.GOOD if n >= MIN_CHARS else UI.MUTED)


func _set_busy(on: bool) -> void:
	build_btn.disabled = on
	upload_btn.disabled = on


func _show_loading() -> void:
	status_label.text = ""
	_set_busy(true)
	loading_i = 0
	loading_elapsed = 0
	overlay_sprite.play("run")
	overlay_title.text = LOADING_LINES[0]
	overlay_sub.text = "This takes 10-30 seconds."
	_clear_actions()
	overlay.visible = true
	loading_timer.start()


func _tick_loading() -> void:
	loading_i = (loading_i + 1) % LOADING_LINES.size()
	loading_elapsed += 1
	overlay_title.text = LOADING_LINES[loading_i]
	if loading_elapsed >= 6:
		overlay_sub.text = "Still working. If the server was asleep (free hosting), the first build can take up to a minute."


func _hide_overlay() -> void:
	loading_timer.stop()
	overlay.visible = false
	_set_busy(false)


func _clear_actions() -> void:
	for c in overlay_actions.get_children():
		c.queue_free()


func _on_build() -> void:
	var text := notes_edit.text.strip_edges()
	if text.length() < MIN_CHARS:
		status_label.text = "Add a bit more: at least %d characters of notes are needed." % MIN_CHARS
		return
	_show_loading()
	var res: Dictionary = await Api.generate_text(text)
	_handle_generated(res)


func _on_upload() -> void:
	status_label.text = ""
	if OS.has_feature("web"):
		web_picker.open(".pdf,.txt")
		return
	if file_dialog == null:
		file_dialog = FileDialog.new()
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.filters = PackedStringArray(["*.pdf ; PDF files", "*.txt ; Text files"])
		file_dialog.use_native_dialog = true
		file_dialog.file_selected.connect(_on_desktop_file)
		add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(900, 600))


func _on_desktop_file(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		status_label.text = "Couldn't read that file."
		return
	_on_file_picked(path.get_file(), bytes)


func _on_file_picked(filename: String, bytes: PackedByteArray) -> void:
	if bytes.size() > 8 * 1024 * 1024:
		status_label.text = "That file is too big (max 8 MB)."
		return
	_show_loading()
	overlay_sub.text = "Reading %s..." % filename
	var res: Dictionary = await Api.generate_file(filename, bytes)
	_handle_generated(res)


func _handle_generated(res: Dictionary) -> void:
	loading_timer.stop()
	if not res.ok:
		_hide_overlay()
		status_label.text = str(res.error)
		Sfx.play("wrong", -8.0)
		return
	var deck = res.data
	if not (deck is Dictionary) or (deck.get("concepts", []) as Array).is_empty():
		_hide_overlay()
		status_label.text = "The server sent back an empty dungeon. Try different notes."
		return
	ready_deck = deck
	_show_ready_card()


func _show_ready_card() -> void:
	Sfx.play("clear", -4.0)
	overlay_sprite.play("idle")
	var concepts: Array = ready_deck.get("concepts", [])
	var monsters := 0
	for c in concepts:
		monsters += (c.get("questions", []) as Array).size()
	overlay_title.text = str(ready_deck.get("title", "Your dungeon"))
	var lines := PackedStringArray()
	lines.append("%d rooms  ·  %d question monsters  ·  1 boss" % [concepts.size(), monsters])
	var dropped := int(ready_deck.get("dropped_ungrounded", 0))
	if dropped > 0:
		lines.append("%d question(s) were thrown out because your notes didn't back them up." % dropped)
	else:
		lines.append("Every question is backed by a line from your notes.")
	if ready_deck.get("truncated", false):
		lines.append("Your notes were long, so only the first part was used.")
	if ready_deck.get("mock", false):
		lines.append("(Demo mode: the server has no AI key, so this is a sample dungeon.)")
	overlay_sub.text = "\n".join(lines)
	_clear_actions()
	var back := UI.button("Back", 140)
	back.pressed.connect(_hide_overlay)
	overlay_actions.add_child(back)
	var go := UI.button("Enter the dungeon", 260, true)
	go.pressed.connect(func(): Game.start_run(ready_deck))
	overlay_actions.add_child(go)


func _play_sample(d: Dictionary) -> void:
	Game.start_run(d.duplicate(true))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and overlay.visible and loading_timer.is_stopped():
		_hide_overlay()
