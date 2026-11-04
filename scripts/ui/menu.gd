extends Control
## Menu iniziale: ruolo, modalità e opzioni, partita contro l'IA, partita online, salvataggi (dispositivo e Firebase).

const SALVATAGGIO := "user://partita.json"

var main
var ruolo := 1          # 0 Assassino, 1 Detective, 2 IA contro IA
var modo := "logica"
var moventi := "principianti"
var poi := true
var citta := "base"
var scenario := ""
var l_scenario: Label
var nome: LineEdit
var codice: LineEdit
var stato: Label
var b_avvia_online: Button
var lobby := {}
var _gruppi := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_carica_impostazioni()
	var vp := get_viewport_rect().size
	# copertina a sinistra
	var cop := UI.immagine("res://assets/varie/copertina.webp", 620, 620)
	cop.position = Vector2(110, (vp.y - 700) / 2)
	cop.size = Vector2(620, 620)
	add_child(cop)
	var sotto := UI.macchina("Ogni cittadino è un sospettato. Un Assassino si nasconde fra i civili e colpisce ogni notte: il Detective deve scoprire chi è e perché uccide prima del quinto omicidio.", 19, UI.CARTA)
	sotto.position = Vector2(110, cop.position.y + 640)
	sotto.size = Vector2(620, 80)
	add_child(sotto)
	var cred := UI.etichetta("Gioco di Artur Khodzhikov (Hobby World, 2023). Versione digitale per la ludoteca, materiale dall'edizione italiana.", 14, UI.GRIGIO)
	cred.position = Vector2(110, vp.y - 40)
	add_child(cred)
	# pannello a destra
	var p := UI.pannello()
	p.position = Vector2(820, 60)
	p.size = Vector2(vp.x - 900, vp.y - 120)
	add_child(p)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	v.add_child(UI.titolo("NUOVA INDAGINE", 40, UI.ROSSO))
	_riga(v, "Il tuo ruolo", "ruolo", [["Assassino", 0], ["Detective", 1], ["IA contro IA", 2]], ruolo)
	_riga(v, "Modalità", "modo", [["Logica", "logica"], ["Intuizione", "intuizione"]], modo)
	_riga(v, "Moventi", "moventi", [["Prima partita", "principianti"], ["A caso", "casuali"]], moventi)
	_riga(v, "Persona Segnalata", "poi", [["Sì", true], ["No (prima partita)", false]], poi)
	_riga(v, "Edifici", "citta", [["Come nel regolamento", "base"], ["A caso", "casuale"]], citta)
	var hs := HBoxContainer.new()
	var ls := UI.etichetta("Scenario", 19, UI.CARTA)
	ls.custom_minimum_size.x = 190
	hs.add_child(ls)
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 18)
	ob.focus_mode = Control.FOCUS_NONE
	ob.add_item("Nessuno: partita normale")
	var ids := [""]
	for scn in Dati.d()["scenari"]:
		ob.add_item("%s (Detective: %s)" % [scn["nome"], scn["detective"]])
		ids.append(scn["id"])
	ob.select(maxi(0, ids.find(scenario)))
	ob.item_selected.connect(func(i): scenario = ids[i]; _salva_impostazioni(); _mostra_scenario())
	hs.add_child(ob)
	v.add_child(hs)
	l_scenario = UI.testo_lungo("", 15, UI.CARTA)
	v.add_child(l_scenario)
	_mostra_scenario()
	v.add_child(UI.testo_lungo("Logica: battaglia di deduzione pura (6 moventi). Intuizione: carte Assassino e Detective, prove sulle Scene del Crimine e 8 moventi.", 15, UI.GRIGIO))
	var hb := HBoxContainer.new()
	v.add_child(hb)
	var b_gioca := UI.bottone("Gioca contro l'IA", 24)
	b_gioca.custom_minimum_size = Vector2(320, 56)
	b_gioca.pressed.connect(_nuova)
	hb.add_child(b_gioca)
	var salv := salvataggio()
	if not salv.is_empty():
		var b_rip := UI.bottone("Riprendi la partita salvata", 20)
		b_rip.custom_minimum_size.y = 56
		b_rip.pressed.connect(func(): _riprendi(salv))
		hb.add_child(b_rip)
	var b_reg := UI.bottone("Regole del gioco", 20)
	b_reg.custom_minimum_size.y = 56
	b_reg.pressed.connect(func(): main.show_rules())
	hb.add_child(b_reg)
	v.add_child(HSeparator.new())
	v.add_child(UI.titolo("ONLINE E SALVATAGGI SU FIREBASE", 30, UI.ORO))
	v.add_child(UI.testo_lungo("Per giocare con un amico: scegli il tuo ruolo e le opzioni, crea la stanza e passagli il codice di 4 lettere; lui giocherà l'altro ruolo. Con lo stesso codice si rientra in una partita interrotta o si riprende una partita salvata su Firebase.", 15, UI.GRIGIO))
	var hn := HBoxContainer.new()
	v.add_child(hn)
	hn.add_child(UI.etichetta("Nome", 18))
	nome = LineEdit.new()
	nome.custom_minimum_size.x = 220
	nome.max_length = 20
	hn.add_child(nome)
	hn.add_child(UI.etichetta("Codice", 18))
	codice = LineEdit.new()
	codice.custom_minimum_size.x = 120
	codice.max_length = 4
	hn.add_child(codice)
	var ho := HBoxContainer.new()
	v.add_child(ho)
	var b_crea := UI.bottone("Crea stanza", 19)
	b_crea.pressed.connect(_crea)
	ho.add_child(b_crea)
	var b_entra := UI.bottone("Entra nella stanza", 19)
	b_entra.pressed.connect(_entra)
	ho.add_child(b_entra)
	var b_fb := UI.bottone("Carica da Firebase", 19)
	b_fb.pressed.connect(_carica_firebase)
	ho.add_child(b_fb)
	b_avvia_online = UI.bottone("Avvia la partita online", 19)
	b_avvia_online.visible = false
	b_avvia_online.pressed.connect(_avvia_online)
	ho.add_child(b_avvia_online)
	stato = UI.testo_lungo("", 16, UI.CARTA)
	v.add_child(stato)
	var net: Net = main.get_net()
	var s := net.load_session()
	nome.text = str(s.get("name", ""))
	if str(s.get("room", "")) != "":
		codice.text = str(s["room"])
		stato.text = "Ultima stanza o salvataggio: %s." % s["room"]


func _riga(v: VBoxContainer, titolo: String, chiave: String, scelte: Array, attuale) -> void:
	var h := HBoxContainer.new()
	var l := UI.etichetta(titolo, 19, UI.CARTA)
	l.custom_minimum_size.x = 190
	h.add_child(l)
	var g := ButtonGroup.new()
	for s in scelte:
		var b := UI.bottone(s[0], 18)
		b.toggle_mode = true
		b.button_group = g
		b.button_pressed = s[1] == attuale
		b.pressed.connect(func(): set(chiave, s[1]); _salva_impostazioni())
		h.add_child(b)
	v.add_child(h)


func _mostra_scenario() -> void:
	if l_scenario == null:
		return
	for sc in Dati.d()["scenari"]:
		if sc["id"] == scenario:
			var mv := []
			for x in sc["moventi"]:
				mv.append(Dati.movente(x)["nome"])
			l_scenario.text = "%s\nModalità Logica: %s. Intuizione: anche %s.\n%s Con uno scenario edifici, civili e moventi seguono lo scenario." % [sc["trama"], ", ".join(mv.slice(0, 6)), " e ".join(mv.slice(6)), sc["regole"]]
			l_scenario.visible = true
			return
	l_scenario.text = ""
	l_scenario.visible = false


func _carica_impostazioni() -> void:
	var c := ConfigFile.new()
	if c.load("user://impostazioni.cfg") == OK:
		ruolo = c.get_value("m", "ruolo", ruolo)
		modo = c.get_value("m", "modo", modo)
		moventi = c.get_value("m", "moventi", moventi)
		poi = c.get_value("m", "poi", poi)
		citta = c.get_value("m", "citta", citta)
		scenario = c.get_value("m", "scenario", scenario)


func _salva_impostazioni() -> void:
	var c := ConfigFile.new()
	for k in ["ruolo", "modo", "moventi", "poi", "citta", "scenario"]:
		c.set_value("m", k, get(k))
	c.save("user://impostazioni.cfg")


func _config() -> Dictionary:
	return {"modo": modo, "moventi": moventi, "persona_segnalata": poi, "citta": citta, "scenario": scenario, "seme": randi() % 1000000000,
		"io": ruolo if ruolo < 2 else -1,
		"giocatori": [{"nome": "Assassino", "ia": ruolo != 0}, {"nome": "Detective", "ia": ruolo != 1}]}


func _nuova() -> void:
	main.start_game(_config())


static func salvataggio() -> Dictionary:
	if not FileAccess.file_exists(SALVATAGGIO):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SALVATAGGIO))
	return d if d is Dictionary and d.has("config") else {}


func _riprendi(s: Dictionary) -> void:
	var cfg: Dictionary = s["config"]
	cfg["riprendi"] = s.get("scelte", [])
	main.start_game(cfg)


# ------------------------------------------------------------------------------------
# Firebase
# ------------------------------------------------------------------------------------

func _carica_firebase() -> void:
	var code := codice.text.strip_edges().to_upper()
	if code.length() != 4:
		stato.text = "Scrivi il codice di 4 lettere del salvataggio."
		return
	stato.text = "Carico %s..." % code
	var net: Net = main.get_net()
	if not await net.sign_in():
		stato.text = "Firebase non raggiungibile: %s" % net.last_error
		return
	var room := await net.room(code)
	var g = room.get("game", {})
	if not (g is Dictionary) or not g.has("cfg"):
		stato.text = "Nessuna partita con il codice %s." % code
		return
	if room.get("status", "") == "playing":
		_entra()
		return
	var cfg = str_to_var(str(g["cfg"]))
	if not (cfg is Dictionary):
		stato.text = "Salvataggio non valido."
		return
	var scelte := []
	for x in str(g.get("scelte", "")).split(",", false):
		scelte.append(int(x))
	cfg["riprendi"] = scelte
	cfg["codice_salvataggio"] = code
	net.remember_room(code)
	main.start_game(cfg)


func _crea() -> void:
	if ruolo == 2:
		stato.text = "Per giocare online scegli il tuo ruolo: Assassino o Detective."
		return
	var nm := nome.text.strip_edges()
	if nm == "":
		stato.text = "Scrivi il tuo nome."
		return
	var net: Net = main.get_net()
	stato.text = "Creo la stanza..."
	var code := await net.create_room(nm, [ruolo, 1 - ruolo])
	if code == "":
		stato.text = "Non riesco a creare la stanza.\n%s" % net.last_error
		return
	lobby = {"role": "host", "code": code, "seat": ruolo}
	net.remember_room(code, ruolo)
	net._save({"name": nm})
	codice.text = code
	stato.text = "Stanza %s creata: giochi %s. Passa il codice all'altro giocatore e aspetta che entri." % [code, "l'Assassino" if ruolo == 0 else "il Detective"]
	_lobby_poll(code)


func _entra() -> void:
	var code := codice.text.strip_edges().to_upper()
	var nm := nome.text.strip_edges()
	if code.length() != 4 or nm == "":
		stato.text = "Scrivi il tuo nome e il codice di 4 lettere."
		return
	var net: Net = main.get_net()
	stato.text = "Entro nella stanza %s..." % code
	var seat := await net.join_room(code, nm)
	if seat < 0:
		stato.text = "Stanza %s non trovata, piena, oppure la partita è già iniziata.%s" % [code, ("\n" + net.last_error) if net.last_error != "" else ""]
		return
	var room: Dictionary = net.last_room
	lobby = {"role": "host" if room.get("host", "") == net.uid else "guest", "code": code, "seat": seat}
	net.remember_room(code, seat)
	net._save({"name": nm})
	if room.get("status", "") == "playing" and room.has("game"):
		await _avvia(room["game"])
		return
	stato.text = "Sei nella stanza %s: giocherai %s. Aspetta che chi l'ha creata avvii la partita." % [code, "l'Assassino" if seat == 0 else "il Detective"]
	_lobby_poll(code)


func _lobby_poll(code: String) -> void:
	var net: Net = main.get_net()
	while is_inside_tree() and lobby.get("code", "") == code:
		var room := await net.room(code)
		if not is_inside_tree() or lobby.get("code", "") != code:
			return
		if room.is_empty():
			stato.text = "La stanza %s non esiste più." % code
			lobby = {}
			return
		var seats := Net._as_dict(room.get("seats", {}))
		if lobby["role"] == "host":
			b_avvia_online.visible = seats.size() >= 2
			if seats.size() >= 2:
				var altro: Dictionary = seats.get(str(1 - int(lobby["seat"])), {})
				stato.text = "%s è entrato nella stanza %s. Puoi avviare la partita." % [altro.get("name", "L'altro giocatore"), code]
		elif room.get("status", "") == "playing" and room.has("game"):
			await _avvia(room["game"])
			return
		await get_tree().create_timer(1.5).timeout


func _avvia_online() -> void:
	var net: Net = main.get_net()
	var cfg := _config()
	cfg["giocatori"] = [{"nome": "Assassino", "ia": false}, {"nome": "Detective", "ia": false}]
	var room := await net.room(lobby["code"])
	var seats := Net._as_dict(room.get("seats", {}))
	for k in seats:
		cfg["giocatori"][int(k)]["nome"] = str(seats[k].get("name", cfg["giocatori"][int(k)]["nome"]))
	cfg.erase("io")
	var game := {"cfg": var_to_str(cfg)}
	if not await net.start_room(lobby["code"], game):
		stato.text = "Non riesco ad avviare la partita: %s" % net.last_error
		return
	await _avvia(game)


func _avvia(game: Dictionary) -> void:
	var net: Net = main.get_net()
	var cfg = str_to_var(str(game.get("cfg", "")))
	if not (cfg is Dictionary):
		stato.text = "Partita non valida."
		return
	var backlog := await net.get_acts(lobby["code"])
	cfg["io"] = int(lobby["seat"])
	cfg["online"] = {"code": lobby["code"], "seat": int(lobby["seat"]), "role": lobby["role"], "backlog": backlog}
	lobby = {}
	main.start_game(cfg)
