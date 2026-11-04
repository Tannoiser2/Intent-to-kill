extends SceneTree
## Verifica dei salvataggi: una partita riapplicata dalle sue decisioni deve arrivare identica.
## Uso: godot --headless --path . -s tests/ripresa.gd

class ControlloSim:
	var ia := IA.new()
	func decide(m, posto, req):
		return ia.scegli(m, posto, req)


func _init() -> void:
	var ok := 0
	var tot := 0
	for modo in ["logica", "intuizione"]:
		for k in 10:
			var cfg := {"seme": 777 + k, "modo": modo, "moventi": "casuali", "persona_segnalata": k % 2 == 0}
			var a := Motore.new()
			root.add_child(a)
			a.prepara(cfg)
			a.controllori = [ControlloSim.new(), ControlloSim.new()]
			await a.gioca()
			# ripresa a metà: si riapplicano le prime decisioni, poi continua l'IA
			var b := Motore.new()
			root.add_child(b)
			b.prepara(cfg)
			b.controllori = [ControlloSim.new(), ControlloSim.new()]
			b.ripresa = a.storia.duplicate()
			await b.gioca()
			tot += 1
			if a.impronta() == b.impronta():
				ok += 1
			else:
				print("DIVERSA ", modo, " ", k, " ", a.impronta(), " / ", b.impronta())
			a.queue_free()
			b.queue_free()
	print("RIPRESA %d/%d identiche" % [ok, tot])
	quit()
