extends Control
## Schermata di gioco: tabellone della città, dossier del proprio ruolo (segreti dell'Assassino o taccuino del
## Detective), pannello delle decisioni, registro della partita, salvataggi (dispositivo e Firebase).

const SALVATAGGIO := "user://partita.json"

var main
var config := {}
var motore: Motore
var tavolo: Tavolo
var io := 1                         # ruolo di chi guarda: 0 Assassino, 1 Detective, -1 spettatore
var sessione: SessioneOnline

var l_stato: Label
var l_round: Label
var b_firebase: Button
var dossier: VBoxContainer
var dossier_box: ScrollContainer
var schede: HFlowContainer
var scheda := "segreti"
var p_decisione: VBoxContainer
var l_chi: Label
var l_testo: Label
var box_opzioni: VBoxContainer
var scroll_opzioni: ScrollContainer
var log_t: RichTextLabel
var anteprima: PanelContainer
var anteprima_img: TextureRect
var anteprima_testo: Label
var finale: Control
var mostra_segreti := false
var esclusi := {}                   # moventi esclusi a mano dal Detective
var esclusi_civ := {}               # civili attenuati a mano nel taccuino
var segna_innocenti := false        # timbro «innocente» sul tabellone

var _in_attesa := false
var _richiesta := {}
var _posto_richiesta := -1
var _risposta := -1
signal _scelto
var _salvate := 0
var _t_salva := 0.0
var _cambiato := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	io = int(config.get("io", 1))
	mostra_segreti = io == 0
	scheda = "segreti" if io != 1 else "taccuino"
	_costruisci()
	motore = Motore.new()
	add_child(motore)
	motore.prepara(config)
	tavolo.m = motore
	motore.messaggio.connect(_al_messaggio)
	motore.cambiato.connect(func(): _cambiato = true)
	motore.evento.connect(_evento)
	var loc := ControlloLocale.new()
	loc.vista = self
	if config.has("online"):
		var on: Dictionary = config["online"]
		sessione = SessioneOnline.new()
		add_child(sessione)
		sessione.setup(main.get_net(), on["code"], on["seat"], on["role"], on.get("backlog", []))
		sessione.view = self
		sessione.locale = loc
		motore.controllori = [sessione, sessione]
		sessione.battito()
	else:
		var ctr := []
		for i in 2:
			if motore.giocatori[i]["ia"]:
				var c := ControlloIA.new()
				c.vista = self
				c.pausa = float(config.get("pausa", 0.55))
				ctr.append(c)
			else:
				ctr.append(loc)
		motore.controllori = ctr
	var scelte: Array = config.get("riprendi", [])
	if not scelte.is_empty():
		motore.ripresa = scelte.duplicate()
		_al_messaggio("Partita ripresa: riapplico %d decisioni." % scelte.size(), -1)
	_aggiorna_tutto()
	_avvia.call_deferred()


func _avvia() -> void:
	await motore.gioca()
	_aggiorna_tutto()
	_mostra_finale()
	if sessione != null:
		sessione.chiudi()
	_salva_locale(true)


# ======================================================================
# Costruzione dell'interfaccia
# ======================================================================

var barra: HBoxContainer
var pd: PanelContainer
var pdec: PanelContainer
var plog: PanelContainer
var w_dossier := 420.0


func _costruisci() -> void:
	barra = HBoxContainer.new()
	add_child(barra)
	barra.add_child(UI.titolo("INTENT TO KILL", 38, UI.ROSSO))
	var modo := UI.titolo(" LOGICA " if config.get("modo", "logica") == "logica" else " INTUIZIONE ", 24, UI.VERDE if config.get("modo", "logica") == "logica" else UI.ROSSO)
	modo.add_theme_stylebox_override("normal", UI.stile(Color(0, 0, 0, 0), modo.get_theme_color("font_color"), 2, 2, 6))
	modo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.add_child(modo)
	l_round = UI.titolo("", 28, UI.CARTA)
	barra.add_child(l_round)
	l_stato = UI.etichetta("", 17, UI.GRIGIO)
	l_stato.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_stato.clip_text = true
	barra.add_child(l_stato)
	if io == -1:
		var bs := UI.bottone("Mostra i segreti", 16)
		bs.toggle_mode = true
		bs.toggled.connect(func(v): mostra_segreti = v; _aggiorna_tutto())
		barra.add_child(bs)
	if sessione == null and not config.has("online"):
		b_firebase = UI.bottone("Salva su Firebase", 16)
		b_firebase.pressed.connect(_salva_firebase)
		barra.add_child(b_firebase)
	var br := UI.bottone("Regole", 16)
	br.pressed.connect(_mostra_regole)
	barra.add_child(br)
	var bm := UI.bottone("Menu", 16)
	bm.pressed.connect(func(): main.show_menu())
	barra.add_child(bm)
	# tabellone
	tavolo = Tavolo.new()
	add_child(tavolo)
	tavolo.scelta.connect(_premi)
	tavolo.sopra_civile.connect(_anteprima)
	# dossier
	pd = UI.pannello()
	pd.clip_contents = true
	add_child(pd)
	var vd := VBoxContainer.new()
	pd.add_child(vd)
	schede = HFlowContainer.new()
	vd.add_child(schede)
	dossier_box = ScrollContainer.new()
	dossier_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vd.add_child(dossier_box)
	dossier = VBoxContainer.new()
	dossier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dossier_box.add_child(dossier)
	# decisione
	pdec = UI.pannello(Color(0.11, 0.09, 0.08, 0.96), UI.ORO, 1)
	pdec.clip_contents = true
	add_child(pdec)
	p_decisione = VBoxContainer.new()
	pdec.add_child(p_decisione)
	l_chi = UI.titolo("", 28, UI.ORO)
	p_decisione.add_child(l_chi)
	l_testo = UI.testo_lungo("", 18, UI.CARTA)
	p_decisione.add_child(l_testo)
	scroll_opzioni = ScrollContainer.new()
	scroll_opzioni.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_opzioni.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	p_decisione.add_child(scroll_opzioni)
	box_opzioni = VBoxContainer.new()
	box_opzioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_opzioni.add_child(box_opzioni)
	# registro
	plog = UI.pannello()
	plog.clip_contents = true
	add_child(plog)
	var vl := VBoxContainer.new()
	plog.add_child(vl)
	vl.add_child(UI.titolo("RAPPORTO DI POLIZIA", 22, UI.GRIGIO))
	log_t = RichTextLabel.new()
	log_t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_t.scroll_following = true
	log_t.bbcode_enabled = true
	log_t.add_theme_font_size_override("normal_font_size", 16)
	vl.add_child(log_t)
	# anteprima della carta sotto il mouse
	anteprima = UI.pannello(Color(0.06, 0.05, 0.05, 0.97), UI.ORO, 2)
	anteprima.visible = false
	anteprima.z_index = 40
	anteprima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anteprima)
	var va := VBoxContainer.new()
	va.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anteprima.add_child(va)
	anteprima_img = UI.immagine("", 230, 597)
	anteprima_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	va.add_child(anteprima_img)
	anteprima_testo = UI.testo_lungo("", 16, UI.CARTA)
	anteprima_testo.custom_minimum_size.x = 230
	va.add_child(anteprima_testo)
	_layout()
	get_viewport().size_changed.connect(_ridimensiona)


func _ridimensiona() -> void:
	_layout()
	if motore != null:
		tavolo._prima = true
		_aggiorna_tutto()


## Disposizione dei pannelli in base alla finestra: tabellone a sinistra, dossier, decisione e registro a destra.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var alto := 50.0
	barra.position = Vector2(14, 6)
	barra.size = Vector2(vp.x - 28, 40)
	var lato := vp.y - alto - 10
	var resto_min := 760.0
	lato = minf(lato, (vp.x - 20 - resto_min) / Tavolo.RAPP)
	lato = maxf(lato, 500.0)
	tavolo.position = Vector2(10, alto)
	tavolo.imposta_lato(lato)
	var x0 := tavolo.position.x + tavolo.larghezza() + 12
	var resto := vp.x - x0 - 10
	var h := vp.y - alto - 10
	w_dossier = floorf(resto * 0.5 - 5)
	pd.position = Vector2(x0, alto)
	pd.size = Vector2(w_dossier, h)
	var x1 := x0 + w_dossier + 10
	var w1 := vp.x - x1 - 10
	pdec.position = Vector2(x1, alto)
	pdec.size = Vector2(w1, h * 0.56)
	plog.position = Vector2(x1, alto + h * 0.56 + 8)
	plog.size = Vector2(w1, h * 0.44 - 8)
	anteprima.position = Vector2(x0 + 8, alto + 8)


func _anteprima(c: int) -> void:
	if c < 0:
		anteprima.visible = false
		return
	anteprima_img.texture = UI.tex_civile(c)
	anteprima_img.material = UI.bianco_nero() if motore.intim[c] else null
	var t := "%s\n%s" % [Dati.civile(c)["nome"], Dati.descrivi(c)]
	var ts := []
	for x in motore.testimonianze:
		if x["civ"] == c:
			ts.append("%s? %s" % [Dati.domanda(x["q"])["breve"], "Sì" if x["r"] else "No"])
	if not ts.is_empty():
		t += "\nHa detto: " + ", ".join(ts)
	if motore.pos[c] == -1:
		t += "\nVittima"
	elif motore.intim[c]:
		t += "\nIntimidito"
	anteprima_testo.text = t
	anteprima.size = Vector2.ZERO
	anteprima.visible = true


# ======================================================================
# Aggiornamento
# ======================================================================

func _process(delta: float) -> void:
	if _cambiato:
		_cambiato = false
		_aggiorna_tutto()
	_t_salva += delta
	if _t_salva > 1.5:
		_t_salva = 0.0
		_salva_locale()


func _aggiorna_tutto() -> void:
	if motore == null:
		return
	tavolo.segreti = 0 if (mostra_segreti and (io == 0 or io == -1)) else -1
	tavolo.aggiorna()
	var fasi := {"preparazione": "Preparazione", "assassino": "Fase dell'Assassino", "detective": "Fase del Detective", "citta": "Fase della Città", "accusa": "Conclusioni", "fine": "Fine della partita"}
	l_round.text = "  ROUND %d  " % maxi(motore.round, 1)
	l_stato.text = "%s  |  Vittime %d/5  |  %s" % [fasi.get(motore.fase, ""), motore.vittime.size(), _nome_ruolo()]
	_aggiorna_dossier()


func _nome_ruolo() -> String:
	if io == 0:
		return "Giochi l'Assassino"
	if io == 1:
		return "Giochi il Detective"
	return "Spettatore"


func _aggiorna_schede() -> void:
	for c in schede.get_children():
		c.queue_free()
	var tutte := []
	if io == 0 or (io == -1 and mostra_segreti):
		tutte.append(["segreti", "Dossier"])
	tutte.append(["taccuino", "Taccuino"])
	tutte.append(["deduzioni", "Deduzioni"])
	tutte.append(["moventi", "Moventi"])
	if motore.intuizione != null:
		tutte.append(["carte", "Carte"])
	var valide := tutte.map(func(x): return x[0])
	if not (scheda in valide):
		scheda = valide[0]
	for s in tutte:
		var b := UI.bottone(s[1], 16)
		b.toggle_mode = true
		b.button_pressed = scheda == s[0]
		b.pressed.connect(func(): scheda = s[0]; _aggiorna_dossier())
		schede.add_child(b)


func _aggiorna_dossier() -> void:
	_aggiorna_schede()
	if segna_innocenti and scheda != "deduzioni":
		tavolo.innocenti = IA.certezze(motore)["innocenti"]
	for c in dossier.get_children():
		c.queue_free()
	match scheda:
		"segreti":
			_dossier_assassino()
		"taccuino":
			_dossier_taccuino()
		"moventi":
			_dossier_moventi()
		"deduzioni":
			_dossier_deduzioni()
		"carte":
			_dossier_carte()


func _dossier_assassino() -> void:
	var m := motore
	dossier.add_child(UI.titolo("DOSSIER DELL'ASSASSINO", 26, UI.ROSSO))
	var hb := HBoxContainer.new()
	dossier.add_child(hb)
	var w := minf(150.0, w_dossier / 2.0 - 24)
	for x in [[m.assassino, "Sei tu"], [m.poi, "Persona Segnalata"]]:
		if x[0] < 0:
			continue
		var v := VBoxContainer.new()
		v.add_child(UI.titolo(x[1], 20, UI.ORO))
		v.add_child(UI.immagine("res://assets/civili/c%02d.webp" % x[0], w, w / 0.3853))
		var t := UI.testo_lungo(Dati.descrivi(x[0]), 14, UI.GRIGIO)
		t.custom_minimum_size.x = w
		v.add_child(t)
		hb.add_child(v)
	if m.sostenitori != "":
		var hs := HBoxContainer.new()
		hs.add_child(UI.immagine("res://assets/gruppi/%s.png" % m.sostenitori, 90, 50))
		var t := UI.testo_lungo("Sostenitori: %s.\nI civili di questo gruppo, la Persona Segnalata e tu stesso potete mentire al Detective." % Dati.nome_gruppo(m.sostenitori), 15, UI.CARTA)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hs.add_child(t)
		dossier.add_child(hs)
	var hm := HBoxContainer.new()
	hm.add_child(UI.immagine("res://assets/moventi/%s.webp" % m.movente, 140, 200))
	var mv := Dati.movente(m.movente)
	var tm := UI.testo_lungo("Movente: %s\n%s %s" % [mv["nome"], mv["testo"], mv.get("dettaglio", "")], 15, UI.CARTA)
	tm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hm.add_child(tm)
	dossier.add_child(hm)
	var possibili := m.vittime_possibili() if m.esito == "" else []
	dossier.add_child(UI.testo_lungo("Vittime possibili adesso: %s" % (", ".join(possibili.map(func(c): return m.nome(c))) if not possibili.is_empty() else "nessuna"), 15, UI.GRIGIO))
	if m.intuizione != null:
		dossier.add_child(UI.titolo("CARTE ASSASSINO IN MANO", 20, UI.ORO))
		var fl := HFlowContainer.new()
		for k in m.intuizione.mano_a:
			var im := UI.immagine("res://assets/assassino/%s.webp" % k, 96, 136)
			im.tooltip_text = "%s (%s): %s" % [Intuizione.CARTE_ASSASSINO[k]["nome"], Intuizione.CARTE_ASSASSINO[k]["quando"], Intuizione.CARTE_ASSASSINO[k]["testo"]]
			fl.add_child(im)
		if m.intuizione.mano_a.is_empty():
			fl.add_child(UI.etichetta("Nessuna carta.", 15, UI.GRIGIO))
		dossier.add_child(fl)


func _dossier_taccuino() -> void:
	var m := motore
	dossier.add_child(UI.titolo("TACCUINO DEL DETECTIVE", 26, UI.ORO))
	var foglio := UI.foglio()
	var vf := VBoxContainer.new()
	foglio.add_child(vf)
	dossier.add_child(foglio)
	# testimonianze: una riga per civile, una colonna per domanda
	var per := {}
	var ordine := []
	for t in m.testimonianze:
		if not per.has(t["civ"]):
			per[t["civ"]] = {}
			ordine.append(t["civ"])
		per[t["civ"]][t["q"]] = per[t["civ"]].get(t["q"], []) + [t["r"]]
	if ordine.is_empty():
		vf.add_child(UI.macchina("Nessuna testimonianza raccolta.", 16))
	else:
		var sigle := ["U", "D", "20", "40", "60", "Es", "Me", "Ro", "Al", "AM", "Ba"]
		var g := GridContainer.new()
		g.columns = 12
		g.add_theme_constant_override("h_separation", 2)
		g.add_theme_constant_override("v_separation", 1)
		vf.add_child(g)
		var th := UI.macchina("Testimone", 12)
		th.autowrap_mode = TextServer.AUTOWRAP_OFF
		th.custom_minimum_size.x = 92
		g.add_child(th)
		for i in sigle.size():
			var h := UI.macchina(sigle[i], 12)
			h.autowrap_mode = TextServer.AUTOWRAP_OFF
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.custom_minimum_size.x = 23
			h.tooltip_text = Dati.domanda(i)["testo"]
			h.mouse_filter = Control.MOUSE_FILTER_PASS
			g.add_child(h)
		for c in ordine:
			var nm := UI.macchina(Dati.civile(c)["nome"] + ("  +" if m.pos[c] == -1 else ""), 12, UI.colore_gruppo(Dati.civile(c)["gruppo"]).darkened(0.25))
			nm.autowrap_mode = TextServer.AUTOWRAP_OFF
			nm.clip_text = true
			nm.custom_minimum_size.x = 92
			nm.mouse_filter = Control.MOUSE_FILTER_PASS
			nm.tooltip_text = "%s (%s)%s" % [Dati.civile(c)["nome"], Dati.descrivi(c), "\nVittima" if m.pos[c] == -1 else ""]
			if esclusi_civ.has(c):
				nm.modulate = Color(1, 1, 1, 0.35)
			nm.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					if esclusi_civ.has(c):
						esclusi_civ.erase(c)
					else:
						esclusi_civ[c] = true
					_aggiorna_dossier())
			g.add_child(nm)
			for q in sigle.size():
				var risp: Array = per[c].get(q, [])
				var tx := ""
				for r in risp:
					tx += ("SI" if r else "NO")
				var cel := UI.macchina(tx, 12, Color(0.1, 0.42, 0.25) if (not risp.is_empty() and risp[-1]) else UI.ROSSO_SCURO)
				cel.autowrap_mode = TextServer.AUTOWRAP_OFF
				cel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				g.add_child(cel)
		vf.add_child(UI.macchina("U/D uomo, donna; 20/40/60 età; Es/Me/Ro corporatura; Al/AM/Ba altezza. Clic su un nome per attenuarlo come promemoria; + = vittima.", 12, Color(0.35, 0.3, 0.25)))
	# sorveglianze
	if not m.sorveglianze.is_empty():
		vf.add_child(HSeparator.new())
		for s in m.sorveglianze:
			vf.add_child(UI.macchina("Sorveglianza (round %d): può uccidere %s? %s" % [s["round"], Dati.civile(s["civ"])["nome"], "SI" if s["r"] else "NO"], 15, UI.ROSSO_SCURO))
	if m.intuizione != null:
		for p in m.intuizione.profilazioni:
			vf.add_child(UI.macchina("Profilazione: il movente NON è %s." % Dati.movente(p["non"])["nome"], 15, UI.ROSSO_SCURO))
		if m.intuizione.confessione != "":
			vf.add_child(UI.macchina("Confessione: la Persona Segnalata è del gruppo %s." % Dati.nome_gruppo(m.intuizione.confessione), 15, UI.ROSSO_SCURO))
	# gruppi sicuramente sinceri
	dossier.add_child(UI.titolo("GRUPPI CHE NON SONO SOSTENITORI", 20, UI.ORO))
	var fl := HFlowContainer.new()
	for g in Dati.d()["gruppi"]:
		if m.gruppi_rivelati.has(g["id"]):
			var vg := VBoxContainer.new()
			vg.add_theme_constant_override("separation", 0)
			var im := UI.immagine("res://assets/gruppi/%s.png" % g["id"], 92, 50)
			im.tooltip_text = "%s: tessera pescata dalla pila, quindi non sono i Sostenitori." % g["nome"]
			vg.add_child(im)
			var l := UI.etichetta(g["nome"], 14, UI.CARTA)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vg.add_child(l)
			fl.add_child(vg)
	if m.gruppi_rivelati.is_empty():
		fl.add_child(UI.etichetta("Ancora nessuna tessera pescata.", 15, UI.GRIGIO))
	dossier.add_child(fl)
	# chi può mentire
	dossier.add_child(UI.testo_lungo("Possono mentire solo l'Assassino, la Persona Segnalata%s e i civili del gruppo dei Sostenitori. Tutti gli altri dicono sempre la verità." % ("" if m.poi >= 0 else " (non in gioco)"), 14, UI.GRIGIO))
	# vittime e scene
	if not m.vittime.is_empty():
		dossier.add_child(UI.titolo("VITTIME", 20, UI.ORO))
		for u in m.uccisioni:
			var c: int = u["civ"]
			var r := "%d. %s, a %s" % [m.uccisioni.find(u) + 1, Dati.civile(c)["nome"], Dati.quartiere(u["b"])]
			if u.has("bomba"):
				r = "%d. Bomba a %s: %s" % [m.uccisioni.find(u) + 1, Dati.quartiere(u["b"]), ", ".join(u["bomba"].map(func(x): return m.nome(x)))]
			else:
				r += " (%s)" % Dati.descrivi(c)
			dossier.add_child(UI.testo_lungo(r, 14, UI.CARTA))


func _dossier_moventi() -> void:
	var m := motore
	dossier.add_child(UI.titolo("MOVENTI IN GIOCO", 26, UI.ORO))
	var cert := IA.certezze(m)
	dossier.add_child(UI.testo_lungo("I moventi che gli indizi escludono con certezza sono timbrati «Escluso dagli indizi» (passa sopra la carta per il motivo). Puoi anche cliccare su un movente per segnarlo a mano come promemoria.", 14, UI.GRIGIO))
	var g := GridContainer.new()
	g.columns = 3
	dossier.add_child(g)
	var w := floorf((w_dossier - 50) / 3.0)
	for mv in m.moventi:
		var box := Control.new()
		box.custom_minimum_size = Vector2(w, w * 1.43)
		var im := UI.immagine("res://assets/moventi/%s.webp" % mv, w, w * 1.43)
		im.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		im.tooltip_text = "%s: %s %s" % [Dati.movente(mv)["nome"], Dati.movente(mv)["testo"], Dati.movente(mv).get("dettaglio", "")]
		box.add_child(im)
		var auto_escluso: bool = cert["esclusi"].has(mv)
		if auto_escluso:
			im.tooltip_text += "\n\nESCLUSO DAGLI INDIZI: " + cert["esclusi"][mv]
		if esclusi.has(mv) or auto_escluso:
			im.modulate = Color(0.35, 0.35, 0.35)
			var x := UI.titolo("ESCLUSO" if not auto_escluso else "ESCLUSO\nDAGLI INDIZI", int(w * (0.2 if not auto_escluso else 0.15)), UI.ROSSO)
			x.rotation = deg_to_rad(-25)
			x.position = Vector2(w * 0.1, w * 0.7)
			x.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(x)
		im.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if esclusi.has(mv):
					esclusi.erase(mv)
				else:
					esclusi[mv] = true
				_aggiorna_dossier())
		g.add_child(box)


func _dossier_deduzioni() -> void:
	var m := motore
	var cert := IA.certezze(m)
	tavolo.innocenti = cert["innocenti"] if segna_innocenti else {}
	tavolo.sovra.queue_redraw()
	dossier.add_child(UI.titolo("DEDUZIONI CERTE" if io != 0 else "COSA PUÒ DEDURRE IL DETECTIVE", 26, UI.ORO))
	dossier.add_child(UI.testo_lungo("Solo conclusioni sicure, ricavate da testimonianze, Sorveglianze, omicidi e tessere pescate. Un civile è innocente se, supponendo che sia lui l'Assassino, le risposte contrarie richiederebbero più bugiardi di quanti ce ne possano essere: mentono solo l'Assassino, la Persona Segnalata e un unico gruppo di Sostenitori (mai un gruppo già pescato dalla pila).", 14, UI.GRIGIO))
	var bt := UI.bottone("Segna gli innocenti sul tabellone", 16)
	bt.toggle_mode = true
	bt.button_pressed = segna_innocenti
	bt.toggled.connect(func(v): segna_innocenti = v; _aggiorna_dossier())
	dossier.add_child(bt)
	var sosp: Array = cert["sospetti"]
	dossier.add_child(UI.titolo("SOSPETTI ANCORA POSSIBILI: %d" % sosp.size(), 21, UI.ROSSO))
	var fl := HFlowContainer.new()
	var wc := floorf((w_dossier - 60) / 6.0)
	for c in sosp:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var im := UI.immagine("res://assets/civili/c%02d.webp" % c, wc, wc / 0.3853)
		im.tooltip_text = "%s\n%s" % [Dati.civile(c)["nome"], Dati.descrivi(c)]
		v.add_child(im)
		fl.add_child(v)
	dossier.add_child(fl)
	var inn: Dictionary = cert["innocenti"]
	dossier.add_child(UI.titolo("SICURAMENTE INNOCENTI: %d" % inn.size(), 21, Color(0.45, 0.75, 0.6)))
	if inn.is_empty():
		dossier.add_child(UI.etichetta("Ancora nessuno: servono più testimonianze.", 15, UI.GRIGIO))
	for c in inn:
		var h := HBoxContainer.new()
		var im := UI.immagine("res://assets/civili/c%02d.webp" % c, 34, 88)
		im.modulate = Color(0.75, 0.75, 0.75)
		h.add_child(im)
		var t := UI.testo_lungo("%s: se fosse l'Assassino, %s" % [Dati.civile(c)["nome"], inn[c]], 14, UI.CARTA)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		dossier.add_child(h)
	dossier.add_child(HSeparator.new())
	var pos_m: Array = cert["possibili"]
	dossier.add_child(UI.titolo("MOVENTI ANCORA POSSIBILI: %s" % ", ".join(pos_m.map(func(x): return Dati.movente(x)["nome"])), 20, UI.ROSSO))
	var ex: Dictionary = cert["esclusi"]
	for mv in m.moventi:
		if ex.has(mv):
			dossier.add_child(UI.testo_lungo("%s escluso: %s" % [Dati.movente(mv)["nome"], ex[mv]], 14, UI.CARTA))
	if ex.is_empty():
		dossier.add_child(UI.etichetta("Nessun movente escluso con certezza.", 15, UI.GRIGIO))


func _dossier_carte() -> void:
	var m := motore
	var it := m.intuizione
	dossier.add_child(UI.titolo("CARTE DETECTIVE DISPONIBILI", 22, UI.ORO))
	var fl := HFlowContainer.new()
	for k in it.disponibili:
		if k == "":
			continue
		var im := UI.immagine("res://assets/detective/%s.webp" % k, 120, 172)
		im.tooltip_text = "%s: %s" % [Intuizione.CARTE_DETECTIVE[k]["nome"], Intuizione.CARTE_DETECTIVE[k]["testo"]]
		fl.add_child(im)
	dossier.add_child(fl)
	if io != 0:
		dossier.add_child(UI.titolo("CARTA CONSERVATA", 20, UI.ORO))
		if it.conservata != "":
			var im := UI.immagine("res://assets/detective/%s.webp" % it.conservata, 120, 172)
			im.tooltip_text = Intuizione.CARTE_DETECTIVE[it.conservata]["testo"]
			dossier.add_child(im)
		else:
			dossier.add_child(UI.etichetta("Nessuna.", 15, UI.GRIGIO))
		dossier.add_child(UI.titolo("PROVE", 20, UI.ORO))
		var fp := HFlowContainer.new()
		for p in it.prove:
			var im := UI.immagine("res://assets/prove/%s.png" % p, 60, 60)
			im.tooltip_text = "Prova: si scambia in un quartiere con %s." % Dati.edificio(p)["nome"]
			fp.add_child(im)
		if it.prove.is_empty():
			fp.add_child(UI.etichetta("Nessuna prova.", 15, UI.GRIGIO))
		dossier.add_child(fp)
	else:
		dossier.add_child(UI.testo_lungo("Il Detective ha %d prove e %s carta conservata." % [it.prove.size(), "una" if it.conservata != "" else "nessuna"], 15, UI.CARTA))
	if it.cordone >= 0:
		dossier.add_child(UI.testo_lungo("Cordone a %s." % Dati.quartiere(it.cordone), 15, UI.ROSSO))
	if not it.coprifuoco.is_empty() or not it.coprifuoco_attivo.is_empty():
		dossier.add_child(UI.testo_lungo("Coprifuoco in vigore.", 15, UI.ROSSO))
	dossier.add_child(UI.testo_lungo("Carte Assassino in mano all'Assassino: %d." % it.mano_a.size(), 15, UI.GRIGIO))


# ======================================================================
# Decisioni
# ======================================================================

## Decisione presa dalla persona davanti allo schermo.
func chiedi_persona(_m: Motore, posto: int, req: Dictionary) -> int:
	_in_attesa = true
	_richiesta = req
	_posto_richiesta = posto
	_risposta = -1
	_aggiorna_tutto()
	_mostra_richiesta(req, true)
	await _scelto
	_in_attesa = false
	tavolo.imposta_bersagli({}, false)
	_pulisci_opzioni()
	l_chi.text = ""
	l_testo.text = ""
	return _risposta


func _premi(i: int) -> void:
	if not _in_attesa:
		return
	_risposta = i
	_scelto.emit()


func _pulisci_opzioni() -> void:
	for c in box_opzioni.get_children():
		c.queue_free()


func _mostra_richiesta(req: Dictionary, attivo: bool) -> void:
	_pulisci_opzioni()
	var posto: int = req.get("posto", 0)
	l_chi.text = ("TOCCA A TE, " + ("ASSASSINO" if posto == 0 else "DETECTIVE")) if attivo else ""
	l_chi.add_theme_color_override("font_color", UI.ROSSO if posto == 0 else UI.ORO)
	l_testo.text = str(req.get("testo", ""))
	tavolo.imposta_bersagli(req, attivo)
	var ops: Array = req["opzioni"]
	if req["tipo"] == "domanda":
		var g := GridContainer.new()
		g.columns = 2
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in ops.size():
			var b := UI.bottone(Dati.domanda(ops[i]["q"])["breve"] + "?", 18)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = ops[i]["t"]
			b.pressed.connect(_premi.bind(i))
			g.add_child(b)
		box_opzioni.add_child(g)
		return
	if req["tipo"] == "risposta":
		var hb := HBoxContainer.new()
		for i in ops.size():
			var b := UI.bottone(ops[i]["t"], 24 if ops[i].has("v") else 16)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 56
			b.pressed.connect(_premi.bind(i))
			if ops[i].has("v"):
				hb.add_child(b)
			else:
				box_opzioni.add_child(b)
		box_opzioni.add_child(hb)
		box_opzioni.move_child(hb, 0)
		return
	for i in ops.size():
		var o: Dictionary = ops[i]
		var b := UI.bottone(str(o["t"]), 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_premi.bind(i))
		if o.has("civ"):
			b.mouse_entered.connect(func(): _anteprima(o["civ"]))
			b.mouse_exited.connect(func(): _anteprima(-1))
		if o.get("fine", false) or o.get("rinuncia", false):
			b.add_theme_color_override("font_color", UI.GRIGIO)
		box_opzioni.add_child(b)
	if not tavolo.bersagli_civ.is_empty() or not tavolo.bersagli_q.is_empty():
		l_testo.text += "\n(Puoi anche cliccare sul tabellone.)"


## Il computer sta decidendo: lo si mostra senza rivelare nulla di segreto.
func ia_pensa(posto: int, req: Dictionary) -> void:
	if _in_attesa:
		return
	_pulisci_opzioni()
	tavolo.imposta_bersagli({}, false)
	l_chi.text = ("L'ASSASSINO" if posto == 0 else "IL DETECTIVE") + " STA DECIDENDO..."
	l_chi.add_theme_color_override("font_color", UI.GRIGIO)
	var t := ""
	if io == -1 or io == posto:
		t = str(req.get("testo", ""))
	else:
		t = {"intimidisci": "Sceglie chi intimidire.", "omicidio": "Sceglie la vittima.", "risposta": "Risponde per il civile.", "sostenitori": "Sceglie i suoi Sostenitori.",
			"indagine": "Indaga.", "domanda": "Prepara la domanda.", "testimone": "Sceglie chi interrogare."}.get(req["tipo"], "")
	l_testo.text = t


func online_attesa(posto: int, req: Dictionary) -> void:
	if posto < 0:
		return
	ia_pensa(posto, req)
	l_chi.text = "IN ATTESA DI " + ("ASSASSINO" if posto == 0 else "DETECTIVE")


func online_stato(t: String) -> void:
	_al_messaggio(t, -1)


func _al_messaggio(t: String, per: int) -> void:
	if per >= 0 and per != io and not (io == -1 and mostra_segreti):
		return
	var col := "#e6d8b8"
	if per == 0:
		col = "#e06060"
	elif per == 1:
		col = "#7fc8b4"
	if t.begins_with("Round "):
		log_t.append_text("\n[color=#d9a441][b]%s[/b][/color]\n" % t.to_upper())
	elif t.begins_with("Omicidio"):
		log_t.append_text("[color=#ff5a4a]%s[/color]\n" % t)
	else:
		log_t.append_text("[color=%s]%s[/color]\n" % [col, t])


func _evento(e: Dictionary) -> void:
	match e["k"]:
		"omicidio":
			_lampo(Color(0.7, 0.0, 0.0, 0.35))
		"risposta":
			tavolo.aggiorna()
			tavolo.fumetto(e["civ"], "%s? %s" % [Dati.domanda(e["q"])["breve"], "SÌ" if e["r"] else "NO"], Color(0.1, 0.45, 0.3) if e["r"] else UI.ROSSO)
		"sorveglianza":
			tavolo.fumetto(e["civ"], "PUÒ UCCIDERLO? %s" % ("SÌ" if e["r"] else "NO"), Color(0.1, 0.25, 0.55))
		"intimidito":
			tavolo.aggiorna()


func _lampo(c: Color) -> void:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.6)
	tw.tween_callback(r.queue_free)


# ======================================================================
# Fine partita
# ======================================================================

func _mostra_finale() -> void:
	if motore.esito == "" or finale != null:
		return
	var m := motore
	finale = ColorRect.new()
	finale.z_index = 50
	finale.color = Color(0, 0, 0, 0.72)
	finale.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(finale)
	var p := UI.foglio()
	p.custom_minimum_size = Vector2(1000, 0)
	p.position = Vector2((get_viewport_rect().size.x - 1000) / 2, 120)
	finale.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var vinto_io := (m.esito == "assassino" and io == 0) or (m.esito == "detective" and io == 1)
	var titolo := "CASO RISOLTO" if m.esito == "detective" else "L'ASSASSINO È SFUGGITO"
	var t := UI.titolo(titolo, 64, UI.ROSSO if m.esito == "assassino" else Color(0.15, 0.35, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if io >= 0:
		var s := UI.titolo("HAI VINTO" if vinto_io else "HAI PERSO", 34, UI.INCHIOSTRO)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	v.add_child(UI.macchina(m.motivo_esito, 20))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	var cols := [[m.assassino, "L'Assassino"], [m.poi, "Persona Segnalata"]]
	for x in cols:
		if x[0] < 0:
			continue
		var vv := VBoxContainer.new()
		vv.add_child(UI.macchina(x[1], 18))
		vv.add_child(UI.immagine("res://assets/civili/c%02d.webp" % x[0], 150, 389))
		hb.add_child(vv)
	var vm := VBoxContainer.new()
	vm.add_child(UI.macchina("Movente", 18))
	vm.add_child(UI.immagine("res://assets/moventi/%s.webp" % m.movente, 270, 389))
	hb.add_child(vm)
	var vs := VBoxContainer.new()
	vs.add_child(UI.macchina("Sostenitori", 18))
	vs.add_child(UI.immagine("res://assets/gruppi/%s.png" % m.sostenitori, 180, 100))
	vs.add_child(UI.macchina(Dati.nome_gruppo(m.sostenitori), 18))
	if not m.accusa.is_empty():
		vs.add_child(UI.macchina("\nAccusa del Detective:\n%s, %s" % [m.nome(m.accusa["civ"]), Dati.movente(m.accusa["mov"])["nome"]], 17))
	hb.add_child(vs)
	var hb2 := HBoxContainer.new()
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb2)
	var b1 := UI.bottone("Guarda il tabellone", 20)
	b1.pressed.connect(func(): finale.visible = false)
	hb2.add_child(b1)
	if not config.has("online"):
		var b2 := UI.bottone("Rivincita", 20)
		b2.pressed.connect(func():
			var c := config.duplicate(true)
			c.erase("riprendi")
			c.erase("codice_salvataggio")
			c["seme"] = randi()
			main.start_game(c))
		hb2.add_child(b2)
	var b3 := UI.bottone("Menu", 20)
	b3.pressed.connect(func(): main.show_menu())
	hb2.add_child(b3)


func _mostra_regole() -> void:
	var r := preload("res://scripts/ui/regole.gd").new()
	r.sovrapposto = true
	r.z_index = 60
	add_child(r)


# ======================================================================
# Salvataggi
# ======================================================================

func _cfg_salvabile() -> Dictionary:
	var c := config.duplicate(true)
	c.erase("riprendi")
	c.erase("online")
	return c


func _salva_locale(forza := false) -> void:
	if config.has("online") or motore == null:
		return
	if not forza and motore.storia.size() == _salvate:
		return
	_salvate = motore.storia.size()
	if motore.esito != "":
		if FileAccess.file_exists(SALVATAGGIO):
			DirAccess.remove_absolute(SALVATAGGIO)
		return
	var f := FileAccess.open(SALVATAGGIO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"config": _cfg_salvabile(), "scelte": motore.storia}))
		f.close()


func _salva_firebase() -> void:
	var net: Net = main.get_net()
	b_firebase.disabled = true
	b_firebase.text = "Salvo..."
	var code: String = config.get("codice_salvataggio", "")
	if not await net.sign_in():
		b_firebase.text = "Firebase non raggiungibile"
		b_firebase.disabled = false
		return
	if code == "":
		code = await net.create_room(str(net.load_session().get("name", "Detective")), [0])
	if code == "":
		b_firebase.text = "Errore: riprova"
		b_firebase.disabled = false
		_al_messaggio("Salvataggio non riuscito: %s" % net.last_error, -1)
		return
	var scelte := ",".join(motore.storia.map(func(x): return str(x)))
	var r := await net.db_patch(Net.ROOT + "/" + code, {"game": {"cfg": var_to_str(_cfg_salvabile()), "scelte": scelte}, "status": "salvata"})
	b_firebase.disabled = false
	if r["code"] == 200:
		config["codice_salvataggio"] = code
		net.remember_room(code)
		b_firebase.text = "Salvata: %s" % code
		_al_messaggio("Partita salvata su Firebase con il codice %s: dal menu la riprendi su qualsiasi dispositivo." % code, -1)
	else:
		b_firebase.text = "Errore: riprova"
		_al_messaggio("Salvataggio non riuscito: %s" % net.last_error, -1)
