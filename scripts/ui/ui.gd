class_name UI
extends RefCounted
## Tema grafico noir (anni '50) e piccoli aiuti per costruire l'interfaccia.

const FONDO := Color(0.05, 0.05, 0.06)
const CARTA := Color(0.91, 0.85, 0.71)
const CARTA_SCURA := Color(0.78, 0.69, 0.52)
const INCHIOSTRO := Color(0.17, 0.13, 0.10)
const ROSSO := Color(0.74, 0.12, 0.11)
const ROSSO_SCURO := Color(0.42, 0.06, 0.06)
const ORO := Color(0.88, 0.67, 0.30)
const TESTO := Color(0.90, 0.88, 0.84)
const GRIGIO := Color(0.62, 0.60, 0.58)
const VERDE := Color(0.35, 0.72, 0.62)
const BLU := Color(0.33, 0.50, 0.80)
const PANNELLO := Color(0.09, 0.085, 0.09, 0.94)

static var f_titoli: Font
static var f_testo: Font
static var f_macchina: Font
static var _tex := {}
static var _bn: ShaderMaterial


static func carica_font() -> void:
	if f_titoli != null:
		return
	f_titoli = load("res://assets/font/BebasNeue-Regular.ttf")
	f_testo = load("res://assets/font/Oswald.ttf")
	f_macchina = load("res://assets/font/SpecialElite-Regular.ttf")


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


static func tex_civile(c: int) -> Texture2D:
	return tex("res://assets/civili/c%02d.webp" % c)


## Materiale in bianco e nero per i civili intimiditi.
static func bianco_nero() -> ShaderMaterial:
	if _bn == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
void fragment(){
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	g = pow(g, 1.15) * 0.85;
	COLOR = vec4(vec3(g), c.a);
}"""
		_bn = ShaderMaterial.new()
		_bn.shader = sh
	return _bn


static func stile(bg: Color, bordo: Color, spessore := 2, raggio := 4, margine := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bordo
	s.set_border_width_all(spessore)
	s.set_corner_radius_all(raggio)
	s.content_margin_left = margine
	s.content_margin_right = margine
	s.content_margin_top = margine * 0.6
	s.content_margin_bottom = margine * 0.6
	return s


static func make_theme() -> Theme:
	carica_font()
	var t := Theme.new()
	t.default_font = f_testo
	t.default_font_size = 18
	t.set_color("font_color", "Label", TESTO)
	t.set_stylebox("normal", "Button", stile(Color(0.13, 0.11, 0.10), Color(0.45, 0.36, 0.24), 1, 3, 12))
	t.set_stylebox("hover", "Button", stile(Color(0.25, 0.10, 0.09), ORO, 1, 3, 12))
	t.set_stylebox("pressed", "Button", stile(ROSSO_SCURO, ORO, 2, 3, 12))
	t.set_stylebox("disabled", "Button", stile(Color(0.1, 0.1, 0.1), Color(0.25, 0.25, 0.25), 1, 3, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CARTA)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.45))
	t.set_stylebox("normal", "LineEdit", stile(Color(0.12, 0.11, 0.10), Color(0.45, 0.36, 0.24), 1, 3, 10))
	t.set_stylebox("focus", "LineEdit", stile(Color(0.15, 0.13, 0.11), ORO, 1, 3, 10))
	t.set_color("font_color", "LineEdit", CARTA)
	t.set_stylebox("panel", "PanelContainer", stile(PANNELLO, Color(0.30, 0.22, 0.14), 1, 4, 12))
	t.set_stylebox("panel", "TooltipPanel", stile(Color(0.1, 0.09, 0.08, 0.97), ORO, 1, 3, 8))
	t.set_color("font_color", "TooltipLabel", CARTA)
	t.set_font("normal_font", "RichTextLabel", f_testo)
	t.set_color("default_color", "RichTextLabel", TESTO)
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.5, 0.4, 0.3, 0.5)
	sb.set_corner_radius_all(3)
	t.set_stylebox("grabber", "VScrollBar", sb)
	t.set_stylebox("grabber_highlight", "VScrollBar", sb)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 8)
	return t


static func titolo(t: String, size := 34, col := ORO) -> Label:
	carica_font()
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", f_titoli)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func etichetta(t: String, size := 18, col := TESTO) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func testo_lungo(t: String, size := 17, col := TESTO) -> Label:
	var l := etichetta(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


static func macchina(t: String, size := 18, col := INCHIOSTRO) -> Label:
	carica_font()
	var l := etichetta(t, size, col)
	l.add_theme_font_override("font", f_macchina)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func bottone(t: String, size := 18) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func pannello(bg := PANNELLO, bordo := Color(0.30, 0.22, 0.14), spessore := 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stile(bg, bordo, spessore, 4, 12))
	return p


static func foglio() -> PanelContainer:
	return pannello(CARTA, CARTA_SCURA, 1)


static func colore_gruppo(g: String) -> Color:
	return Color(str(Dati.gruppo(g).get("colore", "#888888")))


static func immagine(path: String, w: float, h: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r
