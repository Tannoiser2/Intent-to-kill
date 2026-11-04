extends SceneTree
## Fotografie dell'interfaccia per controllo visivo: menu, partita come Detective e come Assassino, finale.
## Uso: xvfb-run godot --path . --rendering-driver opengl3 -s tests/foto.gd -- cartella [logica|intuizione] [ruolo]

var out := "/tmp/foto"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var modo := a[1] if a.size() > 1 else "logica"
	var io := int(a[2]) if a.size() > 2 else 1
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await _attendi(1.2)
	_scatta("1_menu")
	var cfg := {"modo": modo, "moventi": "casuali", "persona_segnalata": true, "citta": "base", "seme": 4242, "io": io, "pausa": 0.0,
		"giocatori": [{"nome": "Assassino", "ia": io != 0}, {"nome": "Detective", "ia": io != 1}]}
	main.start_game(cfg)
	await _attendi(1.5)
	_scatta("2_inizio")
	var p = main.current
	var ia := IA.new()
	var scatti := {6: "3_round1", 20: "4_avanti", 60: "5_avanti"}
	var k := 0
	while p.motore.esito == "" and k < 400:
		if p._in_attesa:
			k += 1
			if scatti.has(k):
				_scatta(scatti[k])
			p._premi(ia.scegli(p.motore, p._posto_richiesta, p._richiesta))
		await _attendi(0.05)
	await _attendi(1.2)
	_scatta("6_finale")
	p.finale.visible = false
	p.scheda = "taccuino"
	p._aggiorna_tutto()
	await _attendi(0.5)
	_scatta("7_taccuino")
	p.scheda = "deduzioni"
	p.segna_innocenti = true
	p._aggiorna_tutto()
	await _attendi(0.5)
	_scatta("7b_deduzioni")
	p.scheda = "moventi"
	p._aggiorna_tutto()
	await _attendi(0.5)
	_scatta("8_moventi")
	main.show_rules()
	await _attendi(0.8)
	_scatta("9_regole")
	quit()


func _attendi(s: float) -> void:
	await create_timer(s).timeout


func _scatta(nome: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, nome])
	print("foto ", nome)
