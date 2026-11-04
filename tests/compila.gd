extends SceneTree
## Carica tutti gli script del gioco: si ferma con errore se uno non compila.
## Uso: godot --headless --path . -s tests/compila.gd

func _init() -> void:
	var errori := 0
	for dir in ["res://scripts/core", "res://scripts/ui", "res://scripts/net"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s = load(dir + "/" + f)
				if s == null or not s.can_instantiate():
					print("NON COMPILA ", f)
					errori += 1
	print("COMPILA: %d errori" % errori)
	quit(1 if errori else 0)
