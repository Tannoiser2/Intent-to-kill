class_name ControlloIA
extends RefCounted
## Le decisioni dei posti giocati dal computer, con una piccola pausa per seguire la partita.

var ia := IA.new()
var vista
var pausa := 0.55


func decide(m: Motore, posto: int, req: Dictionary):
	if vista != null:
		vista.ia_pensa(posto, req)
		var t := pausa
		if req["opzioni"].size() <= 1:
			t = 0.1
		if t > 0.0:
			await vista.get_tree().create_timer(t).timeout
	return ia.scegli(m, posto, req)
