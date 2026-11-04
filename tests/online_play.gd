extends SceneTree
## Prova del gioco online: due istanze (Assassino e Detective) giocano sul finto Firebase
## (tests/firebase_mock.py). PL_ROLE=host|guest, PL_CODEFILE=file per il codice della stanza.
## Alla fine ognuno stampa l'impronta della partita: devono coincidere.

var main
var t0 := 0
var ia := IA.new()


func _init() -> void:
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_msec()
	_run()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _run() -> void:
	await _wait(0.5)
	var role := OS.get_environment("PL_ROLE")
	var cf := OS.get_environment("PL_CODEFILE")
	var menu = main.current
	menu.ruolo = 0
	menu.modo = OS.get_environment("PL_MODO") if OS.get_environment("PL_MODO") != "" else "logica"
	menu.nome.text = "Killer" if role == "host" else "Sherlock"
	if role == "host":
		await menu._crea()
		var code: String = menu.lobby.get("code", "")
		print("PLTEST stanza ", code)
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(code)
		f.close()
		while true:
			var room: Dictionary = await main.net.room(code)
			if Net._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _wait(0.5)
		await menu._avvia_online()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _wait(0.3)
		menu.codice.text = code
		await menu._entra()
	while true:
		await process_frame
		if Time.get_ticks_msec() - t0 > 600000:
			print("PLTEST tempo scaduto")
			quit(2)
			return
		var view = main.current
		if view == null or not ("motore" in view) or view.motore == null:
			continue
		var m: Motore = view.motore
		if view._in_attesa:
			view._premi(ia.scegli(m, view._posto_richiesta, view._richiesta))
		if m.esito != "":
			await _wait(1.0)
			print("PLTEST impronta | %s | io %d" % [m.impronta(), view.io])
			quit(0)
			return
