class_name QuestionPanel
extends CanvasLayer
## The battle screen: the monster on the left, its question and four answers.
## Right -> explanation. Wrong -> AI hint + the exact line from the notes
## (the correct answer is NOT revealed, so the player has to come back and earn it).

signal closed(correct: bool)

enum State { HIDDEN, ASKING, WAITING, RESULT }

var state := State.HIDDEN
var q: Dictionary = {}
var concept_name := ""
var last_correct := false

var root: Control
var portrait: TextureRect
var portrait_glow: ColorRect
var concept_label: Label
var prompt_label: Label
var buttons: Array[Button] = []
var feedback_label: Label
var quote_box: PanelContainer
var quote_label: Label
var continue_btn: Button
var panel_box: PanelContainer
var _anim_t := 0.0
var _kind := ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.theme = UI.make_theme()
	UI.full_rect(root)
	root.visible = false
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.03, 0.78)
	UI.full_rect(dim)
	root.add_child(dim)
	root.add_child(UI.vignette())
	var center := CenterContainer.new()
	UI.full_rect(center)
	root.add_child(center)
	panel_box = PanelContainer.new()
	panel_box.custom_minimum_size = Vector2(1000, 0)
	panel_box.add_theme_stylebox_override("panel", UI.box(Color(UI.PANEL, 0.98), UI.BORDER_LIGHT, 3))
	center.add_child(panel_box)
	var h := UI.hbox(22)
	panel_box.add_child(UI.margin(h, 12))

	# Left: the monster
	var left := UI.vbox(8)
	left.custom_minimum_size = Vector2(200, 0)
	h.add_child(left)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(200, 230)
	left.add_child(stage)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color("0c090e"), UI.BORDER, 2))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(frame)
	portrait_glow = ColorRect.new()
	portrait_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_glow.offset_left = 3
	portrait_glow.offset_top = 3
	portrait_glow.offset_right = -3
	portrait_glow.offset_bottom = -3
	stage.add_child(portrait_glow)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_top = 20
	portrait.offset_bottom = -20
	stage.add_child(portrait)
	concept_label = UI.title("", 17, UI.MUTED, true)
	concept_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(concept_label)

	# Right: question
	var v := UI.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	prompt_label = UI.label("", 25, UI.TEXT, true)
	v.add_child(prompt_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for i in 4:
		var b := UI.button("", 0)
		b.custom_minimum_size = Vector2(350, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UI.body_font())
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_choose.bind(i))
		grid.add_child(b)
		buttons.append(b)

	feedback_label = UI.label("", 19, UI.TEXT, true)
	v.add_child(feedback_label)
	quote_box = PanelContainer.new()
	quote_box.add_theme_stylebox_override("panel", UI.box(Color("120e0a"), UI.ACCENT.darkened(0.45), 2))
	quote_label = UI.label("", 17, UI.ACCENT.lightened(0.15), true)
	quote_box.add_child(quote_label)
	v.add_child(quote_box)
	continue_btn = UI.button("Continue  (Space)", 240, true)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	continue_btn.pressed.connect(_close)
	v.add_child(continue_btn)


func _process(delta: float) -> void:
	if state == State.HIDDEN or _kind == "":
		return
	_anim_t += delta
	var f := int(_anim_t * 8.0) % 4
	var t := Art.tex("%s_idle_anim_f%d" % [_kind, f])
	if t == null:
		t = Art.tex("%s_anim_f%d" % [_kind, f])
	if t != null:
		portrait.texture = t


func ask(question: Dictionary, concept: String, boss: bool, kind: String = "", color: Color = UI.MAGIC) -> void:
	q = question
	concept_name = concept
	_kind = kind
	_anim_t = 0.0
	concept_label.text = ("BOSS\n" if boss else "") + concept
	concept_label.add_theme_color_override("font_color", color)
	portrait_glow.color = Color(color, 0.08)
	prompt_label.text = str(q.get("prompt", "?"))
	var choices: Array = q.get("choices", [])
	for i in 4:
		var b := buttons[i]
		b.text = "%d   %s" % [i + 1, str(choices[i]) if i < choices.size() else "-"]
		b.disabled = false
		b.remove_theme_stylebox_override("disabled")
		b.remove_theme_color_override("font_disabled_color")
	feedback_label.text = "Press 1-4 or click an answer."
	feedback_label.add_theme_color_override("font_color", UI.MUTED)
	quote_box.visible = false
	continue_btn.visible = false
	root.visible = true
	state = State.ASKING
	panel_box.pivot_offset = panel_box.size / 2.0
	panel_box.scale = Vector2(0.9, 0.9)
	panel_box.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_box, "modulate:a", 1.0, 0.12)


func _mark(i: int, c: Color) -> void:
	var s := UI.box(Color(c, 0.22), c, 3)
	buttons[i].add_theme_stylebox_override("disabled", s)
	buttons[i].add_theme_color_override("font_disabled_color", UI.TEXT)


func _shake_panel() -> void:
	var base := panel_box.position
	var tw := create_tween()
	for k in 5:
		tw.tween_property(panel_box, "position", base + Vector2(randf_range(-10, 10), 0), 0.03)
	tw.tween_property(panel_box, "position", base, 0.03)


func _choose(i: int) -> void:
	if state != State.ASKING:
		return
	state = State.WAITING
	for b in buttons:
		b.disabled = true
	var answer := int(q.get("answer_index", 0))
	last_correct = (i == answer)
	if last_correct:
		Sfx.play("coin", -6.0)
		_mark(i, UI.GOOD)
		feedback_label.add_theme_color_override("font_color", UI.GOOD)
		feedback_label.text = "Correct!  " + str(q.get("explanation", ""))
		_show_continue()
		return
	Sfx.play("wrong", -4.0)
	_shake_panel()
	_mark(i, UI.BAD)
	feedback_label.add_theme_color_override("font_color", UI.BAD)
	feedback_label.text = "Not quite. Asking your notes for a hint..."
	var quote := str(q.get("source_quote", ""))
	if quote != "":
		quote_label.text = "From your notes:\n“%s”" % quote
		quote_box.visible = true
	var res: Dictionary = await Api.hint(concept_name, q, i)
	if state != State.WAITING:
		return
	var hint_text := "Re-read this line from your notes, then come back for it."
	if res.ok and res.data is Dictionary and bool(res.data.get("from_ai", false)):
		hint_text = str(res.data.get("hint", hint_text))
	feedback_label.text = "Hint: " + hint_text
	_show_continue()


func _show_continue() -> void:
	state = State.RESULT
	continue_btn.visible = true


func _close() -> void:
	if state != State.RESULT:
		return
	state = State.HIDDEN
	root.visible = false
	closed.emit(last_correct)


func _input(event: InputEvent) -> void:
	if state == State.HIDDEN or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k: int = (event as InputEventKey).keycode
	if state == State.ASKING and k >= KEY_1 and k <= KEY_4:
		_choose(k - KEY_1)
		get_viewport().set_input_as_handled()
	elif state == State.ASKING and k >= KEY_KP_1 and k <= KEY_KP_4:
		_choose(k - KEY_KP_1)
		get_viewport().set_input_as_handled()
	elif state == State.RESULT and (k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER):
		_close()
		get_viewport().set_input_as_handled()
