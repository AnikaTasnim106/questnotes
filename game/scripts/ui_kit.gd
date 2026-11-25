class_name UI
extends RefCounted
## Palette, fonts and widget helpers. Gothic dungeon look: near-black stone,
## parchment text, torch-gold accents, sickly green magic.

const BG := Color("0b090d")
const VOID := Color("060508")
const PANEL := Color("17121a")
const PANEL_LIGHT := Color("231b26")
const BORDER := Color("4a3a3f")
const BORDER_LIGHT := Color("7a6253")
const ACCENT := Color("e9b54f")      # torch gold
const MAGIC := Color("6ee7a8")       # spectral green
const GOOD := Color("7fd48a")
const BAD := Color("e0524a")
const TEXT := Color("efe4d2")        # parchment
const MUTED := Color("9c8f86")
const DIFF_COLORS := [Color("8fd3ff"), Color("c58bff"), Color("ff7a59")]

static var _title_font: Font
static var _body_font: Font


static func diff_color(difficulty: int) -> Color:
	return DIFF_COLORS[clampi(difficulty, 1, 3) - 1]


static func _bengali() -> Font:
	return load("res://assets/fonts/NotoSansBengali.ttf")


static func title_font() -> Font:
	if _title_font == null:
		var f: FontFile = load("res://assets/fonts/PixelifySans.ttf")
		var v := FontVariation.new()
		v.base_font = f
		v.variation_opentype = {"wght": 600}
		v.fallbacks = [load("res://assets/fonts/NotoSans.ttf"), _bengali()]
		_title_font = v
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		var f: FontFile = load("res://assets/fonts/NotoSans.ttf")
		var v := FontVariation.new()
		v.base_font = f
		v.fallbacks = [_bengali()]
		_body_font = v
	return _body_font


static func box(color: Color, border: Color = BORDER, border_w: int = 3, radius: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 4)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 19
	var normal := box(PANEL_LIGHT, BORDER, 3)
	normal.shadow_size = 1
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", box(PANEL_LIGHT.lightened(0.08), ACCENT, 3))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.55), ACCENT, 3))
	t.set_stylebox("disabled", "Button", box(PANEL, PANEL_LIGHT, 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", title_font())
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "TextEdit", box(Color("0f0c11"), BORDER, 3))
	t.set_stylebox("focus", "TextEdit", box(Color("0f0c11"), ACCENT, 3))
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("font_placeholder_color", "TextEdit", MUTED.darkened(0.15))
	t.set_color("caret_color", "TextEdit", ACCENT)
	t.set_color("selection_color", "TextEdit", Color(ACCENT, 0.3))
	t.set_stylebox("panel", "PanelContainer", box(Color(PANEL, 0.97), BORDER, 3))
	t.set_stylebox("background", "ProgressBar", box(Color("0f0c11"), BORDER, 2))
	t.set_stylebox("fill", "ProgressBar", box(GOOD.darkened(0.15), GOOD.darkened(0.15), 0))
	t.set_stylebox("panel", "TooltipPanel", box(PANEL, BORDER, 2))
	t.set_constant("scrollbar_margin_left", "ScrollContainer", 8)
	var grab := box(BORDER, BORDER, 0)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", box(ACCENT, ACCENT, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, ACCENT, 0))
	t.set_stylebox("scroll", "VScrollBar", box(Color("0f0c11"), Color("0f0c11"), 0))
	return t


## Pixel-font heading.
static func title(text: String, size: int = 28, color: Color = ACCENT, wrap: bool = false) -> Label:
	var l := label(text, size, color, wrap)
	l.add_theme_font_override("font", title_font())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


static func label(text: String, size: int = 19, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, min_w: int = 0, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 50)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", box(ACCENT.darkened(0.62), ACCENT.darkened(0.15), 3))
		b.add_theme_stylebox_override("hover", box(ACCENT.darkened(0.5), ACCENT, 3))
		b.add_theme_color_override("font_color", ACCENT.lightened(0.2))
	b.mouse_entered.connect(func(): Sfx.play("hover", -14.0))
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	return b


static func icon(tex_name: String, scale: float = 3.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.tex(tex_name)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if r.texture != null:
		r.custom_minimum_size = r.texture.get_size() * scale
	return r


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(c: Control, px: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, px)
	m.add_child(c)
	return m


static func vignette() -> TextureRect:
	## Dark corners over the whole screen (mouse-transparent).
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.85))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	var r := TextureRect.new()
	r.texture = gt
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(r)
	return r
