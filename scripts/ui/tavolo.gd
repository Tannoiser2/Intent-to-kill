class_name Tavolo
extends Control
## Il tabellone della città: 16 quartieri, civili, edifici, segnalino Detective, Scene del Crimine e area delle Vittime.
## Le carte si muovono con una breve animazione; i bersagli della decisione in corso si illuminano e si cliccano.

signal scelta(indice: int)
signal sopra_civile(c: int)

const RAPP := 1200.0 / 1208.0          # proporzioni dell'immagine del tabellone
const CITTA_U := 1095.0 / 1200.0       # larghezza della città sul tabellone
const CITTA_V := 1100.0 / 1208.0
const VITT_U := 1143.0 / 1200.0        # centro dell'area delle Vittime
const VITT_V0 := 116.0 / 1208.0
const VITT_DV := 241.5 / 1208.0
const VITT_H := 205.0 / 1208.0
const CARTA := 0.3853                  # larghezza / altezza delle carte Civile

var m: Motore
var lato := 1000.0                     # altezza del tabellone in pixel
var sfondo: TextureRect
var carte := {}                        # civile -> TextureRect
var segni := {}                        # civile -> segnalino Sorveglianza
var edifici_n := {}                    # quartiere -> TextureRect
var scene_n: Array = []                # carte Scena del Crimine
var auto: TextureRect
var sovra: Control
var bersagli_civ := {}                 # civile -> indice opzione
var bersagli_q := {}                   # quartiere -> indice opzione
var segreti := -1                      # -1 niente, 0 mostra i segreti dell'Assassino
var evidenzia := -1                    # civile sotto il mouse
var innocenti := {}                    # civili sicuramente innocenti da timbrare
var _prima := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	sfondo = TextureRect.new()
	sfondo.texture = UI.tex("res://assets/tabellone.webp")
	sfondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sfondo)
	# velo scuro per l'atmosfera
	var velo := ColorRect.new()
	velo.color = Color(0.05, 0.03, 0.02, 0.18)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sfondo.add_child(velo)
	auto = TextureRect.new()
	auto.texture = UI.tex("res://assets/segnalini/detective.png")
	auto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	auto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	auto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	auto.visible = false
	add_child(auto)
	_legenda()
	sovra = Control.new()
	sovra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sovra.draw.connect(_disegna_sovra)
	add_child(sovra)


func imposta_lato(h: float) -> void:
	lato = h
	custom_minimum_size = Vector2(h * RAPP, h)
	size = custom_minimum_size
	sfondo.size = size
	sovra.size = size
	var w := larghezza()
	legenda.position = Vector2(4, lato * 1103.0 / 1208.0)
	legenda.size = Vector2(w * 905.0 / 1200.0 - 8, lato * 103.0 / 1208.0)
	l_pila.position = Vector2(w * 912.0 / 1200.0, lato * 1110.0 / 1208.0)
	l_pila.size = Vector2(w * 180.0 / 1200.0, 30)


var legenda: PanelContainer
var l_pila: Label


## Promemoria delle fasi in italiano, sopra la striscia inglese del tabellone.
func _legenda() -> void:
	var fondo := PanelContainer.new()
	fondo.add_theme_stylebox_override("panel", UI.stile(Color(0.80, 0.68, 0.58), Color(0.5, 0.35, 0.28), 0, 2, 6))
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	legenda = fondo
	var riga := HBoxContainer.new()
	riga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(riga)
	var fasi := [["FASE DELL'ASSASSINO", "1. Intimidisci 2 civili\n2. Scegli e uccidi la vittima\n3. Scena del Crimine al posto della vittima"],
		["FASE DEL DETECTIVE", "1. Vai sulla Scena del Crimine e sposta i civili\n2. Fai 2 azioni diverse\n3. 2 punti movimento e azioni gratuite"],
		["FASE DELLA CITTÀ", "1. Conforta i civili nel tuo quartiere\n2. L'Assassino muove un gruppo sociale\n3. Il Detective muove un gruppo sociale"]]
	for f in fasi:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := UI.titolo(f[0], 19, UI.INCHIOSTRO)
		v.add_child(t)
		var l := UI.etichetta(f[1], 12, UI.INCHIOSTRO)
		l.add_theme_constant_override("line_spacing", -3)
		v.add_child(l)
		riga.add_child(v)
	l_pila = UI.titolo("", 18, UI.CARTA)
	l_pila.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_pila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l_pila)


func larghezza() -> float:
	return lato * RAPP


func rett_quartiere(b: int) -> Rect2:
	var w := larghezza() * CITTA_U / 4.0
	var h := lato * CITTA_V / 4.0
	return Rect2((b % 4) * w, (b / 4) * h, w, h)


func centro_quartiere(b: int) -> Vector2:
	return rett_quartiere(b).get_center()


func rett_vittima(k: int, i := 0, n := 1) -> Rect2:
	var h := lato * VITT_H
	var w := h * CARTA
	var cx := larghezza() * VITT_U
	var cy := lato * (VITT_V0 + VITT_DV * k)
	if n > 1:
		var sc := 0.62
		h *= sc
		w *= sc
		cx += (i - (n - 1) / 2.0) * w * 0.55
		cy += (i - (n - 1) / 2.0) * 10
	return Rect2(cx - w / 2, cy - h / 2, w, h)


## Ogni quartiere del tabellone è diviso in tre colonne (le linee sottili): una carta per colonna.
## Un civile va nella colonna centrale, due nelle colonne esterne, tre in tutte e tre.
func _rett_carte(b: int, n: int) -> Array:
	var r := rett_quartiere(b)
	var col := r.size.x / 3.0
	var cw := col * 0.80
	var ch := cw / CARTA
	var y0 := r.position.y + r.size.y * 0.155
	if y0 + ch > r.position.y + r.size.y * 0.86:
		ch = r.size.y * 0.705
		cw = ch * CARTA
	var colonne: Array = [[1], [0, 2], [0, 1, 2]][clampi(n, 1, 3) - 1]
	var out := []
	for i in n:
		var k: int = colonne[mini(i, 2)]
		out.append(Rect2(r.position.x + col * k + (col - cw) / 2.0, y0, cw, ch))
	return out


func _nuova_carta(c: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.tex_civile(c)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.gui_input.connect(_input_carta.bind(c))
	t.mouse_entered.connect(func(): evidenzia = c; sopra_civile.emit(c); sovra.queue_redraw())
	t.mouse_exited.connect(func():
		if evidenzia == c:
			evidenzia = -1
			sopra_civile.emit(-1)
			sovra.queue_redraw())
	add_child(t)
	move_child(t, auto.get_index())
	var s := TextureRect.new()
	s.texture = UI.tex("res://assets/prove/polizia.png")
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	t.add_child(s)
	segni[c] = s
	return t


func _input_carta(ev: InputEvent, c: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if bersagli_civ.has(c):
			scelta.emit(bersagli_civ[c])
			accept_event()
		elif m != null and m.pos[c] >= 0 and bersagli_q.has(m.pos[c]):
			scelta.emit(bersagli_q[m.pos[c]])
			accept_event()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for b in bersagli_q:
			if rett_quartiere(b).has_point(ev.position):
				scelta.emit(bersagli_q[b])
				accept_event()
				return


func _metti(n: Control, r: Rect2, rot := 0.0, anima := true) -> void:
	if anima and not _prima and n.visible and (n.position.distance_to(r.position) > 2 or absf(n.size.x - r.size.x) > 2):
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "position", r.position, 0.45)
		tw.tween_property(n, "size", r.size, 0.45)
		tw.tween_property(n, "rotation", rot, 0.45)
	else:
		n.position = r.position
		n.size = r.size
		n.rotation = rot
	n.visible = true


func aggiorna() -> void:
	if m == null:
		return
	# edifici
	for b in edifici_n.keys():
		if not m.edifici.has(b) or edifici_n[b].get_meta("tipo") != m.edifici[b]:
			edifici_n[b].queue_free()
			edifici_n.erase(b)
	for b in m.edifici:
		if not edifici_n.has(b):
			var e := TextureRect.new()
			e.texture = UI.tex("res://assets/edifici/%s.png" % m.edifici[b])
			e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			e.mouse_filter = Control.MOUSE_FILTER_PASS
			e.tooltip_text = "%s: %s" % [Dati.edificio(m.edifici[b])["nome"], Dati.edificio(m.edifici[b])["testo"]]
			e.set_meta("tipo", m.edifici[b])
			add_child(e)
			move_child(e, 1)
			edifici_n[b] = e
		var r := rett_quartiere(b)
		var s := r.size.x * 0.25
		_metti(edifici_n[b], Rect2(r.position.x + r.size.x * 0.85 - s / 2, r.position.y + r.size.y * 0.02, s, s * 0.95), 0.0, false)
	# Scene del Crimine: sul tabellone nel loro quartiere, le altre nell'area delle Vittime
	while scene_n.size() < 5:
		var sc := TextureRect.new()
		sc.texture = UI.tex("res://assets/scene/scena%d.webp" % (scene_n.size() + 1))
		sc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sc.stretch_mode = TextureRect.STRETCH_SCALE
		sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc.pivot_offset = Vector2.ZERO
		add_child(sc)
		move_child(sc, 1)
		scene_n.append(sc)
	for k in 5:
		var sc: TextureRect = scene_n[k]
		if k < m.scene.size():
			var r := rett_quartiere(m.scene[k])
			var h := r.size.y * 0.78
			var w := h * 0.385
			var rr := Rect2(r.get_center() - Vector2(w, h) / 2, Vector2(w, h))
			sc.pivot_offset = Vector2(w, h) / 2
			_metti(sc, rr, deg_to_rad(-38))
		else:
			var rv := rett_vittima(k)
			sc.pivot_offset = rv.size / 2
			_metti(sc, rv, 0.0, false)
	# civili
	var per_q := {}
	for c in m.civili:
		if m.pos[c] >= 0:
			per_q[m.pos[c]] = per_q.get(m.pos[c], []) + [c]
	for c in m.civili:
		if not carte.has(c):
			carte[c] = _nuova_carta(c)
		var t: TextureRect = carte[c]
		var r: Rect2
		if m.pos[c] >= 0:
			var lista: Array = per_q[m.pos[c]]
			r = _rett_carte(m.pos[c], lista.size())[lista.find(c)]
			t.z_index = 0
		elif m.pos[c] == -1:
			var k := m.vittime.find(c)
			var gruppo := [c]
			if m.intuizione != null:
				for kk in m.intuizione.bombe:
					if c in m.intuizione.bombe[kk]:
						k = kk
						gruppo = m.intuizione.bombe[kk]
			if k < 0:
				t.visible = false
				continue
			r = rett_vittima(k, gruppo.find(c), gruppo.size())
			t.z_index = 1
		else:
			t.visible = false
			continue
		_metti(t, r)
		t.material = UI.bianco_nero() if m.intim[c] else null
		t.tooltip_text = "%s\n%s%s" % [Dati.civile(c)["nome"], Dati.descrivi(c), "\nIntimidito: non si può interrogare" if m.intim[c] else ""]
		var sg: TextureRect = segni[c]
		sg.visible = m.sorveglianza == c
		var sz := r.size.x * 0.62
		sg.position = Vector2(r.size.x - sz * 0.8, -sz * 0.25)
		sg.size = Vector2(sz, sz)
	# segnalino Detective
	if m.det >= 0:
		var r := rett_quartiere(m.det)
		var h := r.size.y * 0.15
		var w := h / 0.53
		var rr := Rect2(r.position.x + r.size.x * 0.03, r.position.y + r.size.y * 0.855, w, h)
		_metti(auto, rr)
	else:
		auto.visible = false
	l_pila.text = "PILA: %d TESSERE" % m.pila.size()
	_prima = false
	sovra.queue_redraw()


func imposta_bersagli(req: Dictionary, attivo: bool) -> void:
	bersagli_civ.clear()
	bersagli_q.clear()
	if attivo:
		var ops: Array = req.get("opzioni", [])
		for i in ops.size():
			var o: Dictionary = ops[i]
			if o.has("civ") and not o.has("bomba") and req["tipo"] != "risposta" and req["tipo"] != "domanda":
				if not bersagli_civ.has(o["civ"]):
					bersagli_civ[o["civ"]] = i
			elif o.has("b") and not o.has("da") and not o.has("bomba"):
				if not bersagli_q.has(o["b"]):
					bersagli_q[o["b"]] = i
	sovra.queue_redraw()


func _disegna_sovra() -> void:
	if m == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var puls := 0.55 + 0.45 * sin(t * 4.0)
	for b in bersagli_q:
		var r := rett_quartiere(b).grow(-4)
		sovra.draw_rect(r, Color(0.95, 0.75, 0.3, 0.10 * puls), true)
		sovra.draw_rect(r, Color(0.98, 0.78, 0.30, 0.85), false, 3.0)
	for c in bersagli_civ:
		if carte.has(c) and carte[c].visible:
			var r: Rect2 = Rect2(carte[c].position, carte[c].size).grow(3)
			sovra.draw_rect(r, Color(1.0, 0.82, 0.35, 0.55 + 0.45 * puls), false, 3.0)
	if segreti == 0 and m.assassino >= 0:
		_cornice(m.assassino, UI.ROSSO, "TU")
		if m.poi >= 0 and m.pos[m.poi] >= -1:
			_cornice(m.poi, Color(0.95, 0.55, 0.15), "PS")
		for c in m.civili:
			if c != m.assassino and c != m.poi and Dati.civile(c)["gruppo"] == m.sostenitori and carte.has(c) and carte[c].visible:
				_cornice(c, Color(0.9, 0.3, 0.6), "S")
	for c in innocenti:
		if carte.has(c) and carte[c].visible and m.pos[c] >= 0:
			var r: Rect2 = Rect2(carte[c].position, carte[c].size)
			sovra.draw_rect(r, Color(0.05, 0.12, 0.08, 0.55), true)
			var fs := int(clampf(r.size.x * 0.24, 10, 18))
			var cy := r.position.y + r.size.y * 0.45
			sovra.draw_rect(Rect2(r.position.x, cy - fs, r.size.x, fs * 1.3), Color(0.12, 0.42, 0.28, 0.92), true)
			sovra.draw_string(UI.f_titoli, Vector2(r.position.x, cy), "INNOCENTE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color.WHITE)
	if evidenzia >= 0 and carte.has(evidenzia) and carte[evidenzia].visible:
		var r: Rect2 = Rect2(carte[evidenzia].position, carte[evidenzia].size).grow(2)
		sovra.draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)


func _cornice(c: int, col: Color, sigla: String) -> void:
	if not carte.has(c) or not carte[c].visible:
		return
	var r: Rect2 = Rect2(carte[c].position, carte[c].size).grow(2)
	sovra.draw_rect(r, col, false, 3.0)
	var f := UI.f_titoli
	var fs := int(clampf(r.size.x * 0.32, 12, 22))
	var tw := f.get_string_size(sigla, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(r.position.x, r.position.y, tw + 8, fs + 2)
	sovra.draw_rect(box, col, true)
	sovra.draw_string(f, Vector2(box.position.x + 4, box.position.y + fs - 1), sigla, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _process(_d: float) -> void:
	if not bersagli_q.is_empty() or not bersagli_civ.is_empty():
		sovra.queue_redraw()


## Fumetto sopra una carta (risposte agli interrogatori e alla Sorveglianza).
func fumetto(c: int, testo: String, col: Color) -> void:
	if not carte.has(c):
		return
	var t: TextureRect = carte[c]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.stile(UI.CARTA, col, 3, 8, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 20
	var l := UI.titolo(testo, 34, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	add_child(p)
	p.reset_size()
	var pos0 := t.position + Vector2(t.size.x / 2 - p.size.x / 2, -p.size.y * 0.3)
	pos0.x = clampf(pos0.x, 0, size.x - p.size.x)
	pos0.y = maxf(pos0.y, 0)
	p.position = pos0 + Vector2(0, 14)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(p, "position", pos0, 0.25)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
