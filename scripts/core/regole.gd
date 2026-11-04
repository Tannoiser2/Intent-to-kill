class_name Regole
extends RefCounted
## Le condizioni per scegliere una vittima, a partire da una «fotografia» della città.
## La stessa funzione serve al motore (omicidi e Sorveglianza) e all'IA del Detective (che rilegge le fotografie
## dei vecchi omicidi per capire quali moventi sono ancora possibili).
##
## Fotografia s: {pos: Array (quartiere di ogni civile, -1 morto, -2 fuori dal gioco), intim: Array di bool,
## det: quartiere del Detective, edifici: {quartiere: tipo}, scene: quartieri delle Scene del Crimine in ordine,
## vittime: civili uccisi in ordine, round, coprifuoco: {"eta": n} o {"gruppo": id}, cordone: quartiere o -1}

const VITTIME_TOTALI := 5


static func quanti_nel(s: Dictionary, b: int) -> int:
	var n := 0
	for p in s["pos"]:
		if p == b:
			n += 1
	return n


## Condizioni comuni a tutti i moventi (esclusa la regola «non sé stesso», che conosce solo l'Assassino).
static func base(s: Dictionary, c: int) -> bool:
	var b: int = s["pos"][c]
	if b < 0 or b == s["det"]:
		return false
	if s.get("cordone", -1) == b:
		return false
	var cf: Dictionary = s.get("coprifuoco", {})
	if cf.has("eta") and int(Dati.civile(c)["eta"]) == int(cf["eta"]):
		return false
	if cf.has("gruppo") and Dati.civile(c)["gruppo"] == cf["gruppo"]:
		return false
	return true


## Il civile c si può uccidere con il movente mov? poi = Persona Segnalata (-1 se sconosciuta o non in gioco).
## poi_ignota = true quando chi controlla non conosce la Persona Segnalata (IA del Detective): per il Cultista
## si considerano tutte le possibilità.
static func ammesso(mov: String, s: Dictionary, c: int, poi := -1, poi_ignota := false) -> bool:
	if not base(s, c):
		return false
	var v: Array = s["vittime"]
	var b: int = s["pos"][c]
	var cc := Dati.civile(c)
	var restano := VITTIME_TOTALI - v.size() - 1
	match mov:
		"maniaco":
			return v.is_empty() or Dati.civile(v[0])["sesso"] == cc["sesso"]
		"psicopatico":
			var eta := {}
			for x in v:
				eta[int(Dati.civile(x)["eta"])] = true
			eta[int(cc["eta"])] = true
			return eta.size() <= 2
		"sadico":
			return not s["intim"][c]
		"tagliagole":
			return not (b in Dati.CENTRALI)
		"vigilante":
			return not (b in Dati.intorno(s["det"]))
		"killer":
			return quanti_nel(s, b) == 1
		"terrorista":
			for x in v:
				if Dati.civile(x)["gruppo"] == cc["gruppo"]:
					return false
			return true
		"spia":
			return s["edifici"].has(b)
		"rapinatore":
			if s["scene"].is_empty():
				return true
			return not (b in Dati.adiacenti(s["scene"][-1]))
		"cannibale":
			var corp := {}
			for x in v:
				corp[Dati.civile(x)["corporatura"]] = true
			corp[cc["corporatura"]] = true
			return 3 - corp.size() <= restano
		"estremista":
			var conta := {}
			for x in v:
				var g: String = Dati.civile(x)["gruppo"]
				conta[g] = conta.get(g, 0) + 1
			conta[cc["gruppo"]] = conta.get(cc["gruppo"], 0) + 1
			var mx := 0
			for g in conta:
				mx = maxi(mx, conta[g])
			return mx + restano >= 3
		"cultista":
			return _cultista(s, c, poi, poi_ignota)
	return true


static func _cultista(s: Dictionary, c: int, poi: int, ignota: bool) -> bool:
	var v: Array = s["vittime"]
	var cc := Dati.civile(c)
	if ignota:
		# Chi non conosce la Persona Segnalata: c potrebbe esserla (dal secondo round), altrimenti vale il gruppo diverso.
		if s.get("round", 1) > 1 and v.size() >= 1:
			return true
		return v.is_empty() or Dati.civile(v[-1])["gruppo"] != cc["gruppo"]
	if poi < 0:
		return v.is_empty() or Dati.civile(v[-1])["gruppo"] != cc["gruppo"]
	if c == poi:
		return s.get("round", 1) > 1
	if v.size() >= VITTIME_TOTALI - 1 and not (poi in v):
		return false
	if v.is_empty():
		return Dati.civile(poi)["gruppo"] != cc["gruppo"]
	return Dati.civile(v[-1])["gruppo"] != cc["gruppo"]


## Tutte le vittime possibili adesso per l'Assassino a con movente mov.
static func vittime_possibili(mov: String, s: Dictionary, a: int, poi: int) -> Array:
	var out := []
	for c in s["pos"].size():
		if c != a and s["pos"][c] >= 0 and ammesso(mov, s, c, poi):
			out.append(c)
	return out
