class_name Art
extends RefCounted
## Sprite helpers for the 0x72 DungeonTileset II (CC0) frames in assets/sprites.

const DIR := "res://assets/sprites/"
const SCALE := 3.0

## Monsters by difficulty. Each must have *_idle_anim_f0..3 / *_run_anim_f0..3
## or *_anim_f0..3 frames.
const MONSTERS := {
	1: ["goblin", "skelet", "tiny_zombie", "imp"],
	2: ["orc_warrior", "masked_orc", "wogol", "chort"],
	3: ["necromancer", "orc_shaman", "ice_zombie"],
}
const BOSSES := ["big_demon", "ogre", "big_zombie"]

static var _cache: Dictionary = {}
static var _light_tex: Texture2D
static var _atlas: Texture2D
static var _regions: Dictionary = {}


## All sprites come from one packed atlas (tools/pack_atlas.py) so Godot can batch
## them into a few draw calls. Falls back to the loose PNGs if the atlas is missing.
static func tex(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	if _atlas == null and ResourceLoader.exists("res://assets/atlas.png"):
		_atlas = load("res://assets/atlas.png")
		_regions = AtlasRegions.REGIONS
	var t: Texture2D = null
	if _atlas != null and _regions.has(name):
		var r: Array = _regions[name]
		var at := AtlasTexture.new()
		at.atlas = _atlas
		at.region = Rect2(r[0], r[1], r[2], r[3])
		t = at
	else:
		var path := DIR + name + ".png"
		if ResourceLoader.exists(path):
			t = load(path)
	_cache[name] = t
	return t


static func _anim_frames(base: String, kind: String) -> Array:
	var out: Array = []
	for i in 4:
		var t := tex("%s_%s_anim_f%d" % [base, kind, i])
		if t == null and kind == "idle":
			t = tex("%s_anim_f%d" % [base, i])
		if t == null and kind == "run":
			t = tex("%s_anim_f%d" % [base, i])
		if t != null:
			out.append(t)
	return out


static func frames(base: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for kind in ["idle", "run"]:
		var list := _anim_frames(base, kind)
		if list.is_empty():
			continue
		sf.add_animation(kind)
		sf.set_animation_speed(kind, 8.0 if kind == "idle" else 12.0)
		sf.set_animation_loop(kind, true)
		for t in list:
			sf.add_frame(kind, t)
	var hit := tex(base + "_hit_anim_f0")
	if hit != null:
		sf.add_animation("hit")
		sf.set_animation_loop("hit", false)
		sf.add_frame("hit", hit)
	return sf


static func sprite(base: String) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(base)
	s.scale = Vector2(SCALE, SCALE)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if s.sprite_frames.has_animation("idle"):
		s.play("idle")
	# Feet at the node origin.
	var first := s.sprite_frames.get_frame_texture("idle", 0) if s.sprite_frames.has_animation("idle") else null
	if first != null:
		s.offset = Vector2(0, -first.get_height() / 2.0)
	return s


static func monster_for(difficulty: int, seed_text: String) -> String:
	var list: Array = MONSTERS.get(clampi(difficulty, 1, 3), MONSTERS[1])
	return list[absi(hash(seed_text)) % list.size()]


static func boss_for(seed_text: String) -> String:
	return BOSSES[absi(hash(seed_text)) % BOSSES.size()]


static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.7))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 256
		gt.height = 256
		_light_tex = gt
	return _light_tex


static func light(color: Color, radius_px: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = radius_px * 2.0 / 256.0
	l.color = color
	l.energy = energy
	return l
