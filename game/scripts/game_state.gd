extends Node
## Autoload "Game": the current deck, this run's answers, and score.

## Change this to your Render URL after deploying, e.g. "https://questnotes-api.onrender.com".
## On the web build you can also override it with ?api=https://... in the page URL.
const DEFAULT_API_URL := "http://127.0.0.1:8000"

var api_url: String = DEFAULT_API_URL

var deck: Dictionary = {}
var run_concepts: Array = []
var is_replay := false
## question id -> {"attempts": int, "first_try": bool, "concept_id": String, "concept_name": String, "question": Dictionary}
var stats: Dictionary = {}
var score := 0
var max_hearts := 5
var hearts := 5
var won := false
var settings := ConfigFile.new()
const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings.load(SETTINGS_PATH)
	_add_wasd()
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('api') || ''")
		if typeof(q) == TYPE_STRING and q != "":
			api_url = q
	api_url = api_url.trim_suffix("/")


func _unhandled_input(event: InputEvent) -> void:
	# F11 or Alt+Enter: toggle fullscreen (pixel art looks best at full size).
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


func _add_wasd() -> void:
	var keys := {"ui_up": KEY_W, "ui_down": KEY_S, "ui_left": KEY_A, "ui_right": KEY_D}
	for action in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)


func start_run(d: Dictionary, concepts: Array = [], replay: bool = false) -> void:
	deck = d
	if concepts.is_empty():
		run_concepts = (d.get("concepts", []) as Array).duplicate(true)
	else:
		run_concepts = concepts
	is_replay = replay
	stats.clear()
	score = 0
	hearts = max_hearts
	won = false
	Transition.go("res://scenes/dungeon.tscn")


## Rooms in play order: easiest concepts first, the hardest one last as the boss.
func ordered_concepts() -> Array:
	var list := run_concepts.duplicate()
	if list.size() <= 1:
		return list
	var boss_i := 0
	for i in list.size():
		var c: Dictionary = list[i]
		var b: Dictionary = list[boss_i]
		var cd := int(c.get("difficulty", 1))
		var bd := int(b.get("difficulty", 1))
		if cd > bd or (cd == bd and (c.questions as Array).size() > (b.questions as Array).size()):
			boss_i = i
	var boss = list[boss_i]
	list.remove_at(boss_i)
	list.sort_custom(func(a, b): return int(a.get("difficulty", 1)) < int(b.get("difficulty", 1)))
	list.append(boss)
	return list


func record_answer(q: Dictionary, concept: Dictionary, correct: bool) -> bool:
	## Returns true if this was the first attempt at this question.
	var id := str(q.get("id", q.get("prompt", "")))
	if not stats.has(id):
		stats[id] = {
			"attempts": 0, "first_try": false,
			"concept_id": str(concept.get("id", "")), "concept_name": str(concept.get("name", "")),
			"question": q,
		}
	var s: Dictionary = stats[id]
	s.attempts = int(s.attempts) + 1
	if correct and int(s.attempts) == 1:
		s.first_try = true
	return int(s.attempts) == 1


func missed_entries(exclude_concept_id: String = "") -> Array:
	## Questions answered wrong at least once, as {"q", "concept"} entries.
	var out: Array = []
	for id in stats:
		var s: Dictionary = stats[id]
		if not s.first_try and str(s.concept_id) != exclude_concept_id:
			out.append({"q": s.question, "concept": {"id": s.concept_id, "name": s.concept_name}})
	return out


func concept_mastery() -> Array:
	## [{name, difficulty, answered, first_try}] for every concept in this run.
	var out: Array = []
	for c in run_concepts:
		var answered := 0
		var first := 0
		for id in stats:
			var s: Dictionary = stats[id]
			if str(s.concept_id) == str(c.get("id", "")):
				answered += 1
				if s.first_try:
					first += 1
		out.append({"name": c.get("name", "?"), "difficulty": int(c.get("difficulty", 1)),
			"answered": answered, "first_try": first})
	return out


func build_replay_concepts() -> Array:
	## A smaller dungeon made only of what the player got wrong.
	var out: Array = []
	for c in run_concepts:
		var cid := str(c.get("id", ""))
		var missed: Array = []
		var others: Array = []
		for q in c.get("questions", []):
			var s = stats.get(str(q.get("id", "")))
			if s != null and not s.first_try:
				missed.append(q)
			else:
				others.append(q)
		if missed.is_empty():
			continue
		others.shuffle()
		while missed.size() < 2 and not others.is_empty():
			missed.append(others.pop_back())
		var nc: Dictionary = (c as Dictionary).duplicate(true)
		nc["questions"] = missed.duplicate(true)
		out.append(nc)
	return out


func accuracy() -> float:
	if stats.is_empty():
		return 0.0
	var first := 0
	for id in stats:
		if stats[id].first_try:
			first += 1
	return float(first) / float(stats.size())


func seen(key: String) -> bool:
	return bool(settings.get_value("seen", key, false))


func mark_seen(key: String) -> void:
	settings.set_value("seen", key, true)
	settings.save(SETTINGS_PATH)
