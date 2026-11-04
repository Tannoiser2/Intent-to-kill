extends SceneTree
## Partite automatiche IA contro IA: verifica che il motore arrivi sempre in fondo senza errori.
## Uso: godot --headless --path . -s tests/sim.gd -- [partite] [logica|intuizione] [seme]

class ControlloSim:
	var ia := IA.new()
	func _init(liv := "normale"):
		ia.livello = liv
	func decide(m, posto, req):
		return ia.scegli(m, posto, req)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 10
	var modo := args[1] if args.size() > 1 else "logica"
	var primo := int(args[2]) if args.size() > 2 else 1000
	var conta := {}
	var mov := {}
	for k in n:
		var m := Motore.new()
		m.in_simulazione = true
		root.add_child(m)
		if OS.get_environment("SIM_TRACE") != "":
			m.messaggio.connect(func(t, per): print("   > ", t))
		var cfg := {"seme": primo + k, "modo": modo, "moventi": "casuali" if k % 2 == 1 else "principianti", "persona_segnalata": k % 3 != 0, "scenario": ["", "tmen", "terreno", "infernale", "doa", "panico", "strada", "terzo", "attimo"][k % 9] if OS.get_environment("SIM_SCENARI") != "" else "",
			"giocatori": [{"nome": "A", "ia": true}, {"nome": "D", "ia": true}]}
		m.prepara(cfg)
		var la := OS.get_environment("SIM_LIV_A")
		var ld := OS.get_environment("SIM_LIV_D")
		m.controllori = [ControlloSim.new(la if la != "" else "normale"), ControlloSim.new(ld if ld != "" else "normale")]
		await m.gioca()
		var cert := IA.certezze(m)
		if cert["innocenti"].has(m.assassino) or cert["esclusi"].has(m.movente):
			print("CERTEZZA SBAGLIATA seme %d: %s" % [primo + k, str(cert)])
		conta["certezze_ok"] = conta.get("certezze_ok", 0) + 1
		conta[m.esito] = conta.get(m.esito, 0) + 1
		var chiave: String = m.movente + ":" + m.esito
		mov[chiave] = mov.get(chiave, 0) + 1
		print("seme %d (%s): %s al round %d, vittime %d, scelte %d, movente %s, accusa %s" % [primo + k, modo, m.esito, m.round, m.vittime.size(), m._scelte_fatte, m.movente, str(m.accusa)])
		m.queue_free()
	print("RISULTATI ", conta)
	print("PER MOVENTE ", mov)
	quit()
