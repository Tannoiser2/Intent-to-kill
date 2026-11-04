class_name Dati
extends RefCounted
## Dati del gioco (civili, gruppi sociali, moventi, quartieri, edifici, domande), letti una volta da data/gioco.json.

static var _d := {}


static func d() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open("res://data/gioco.json", FileAccess.READ)
		_d = JSON.parse_string(f.get_as_text())
		f.close()
	return _d


static func civile(i: int) -> Dictionary:
	return d()["civili"][i]


static func movente(id: String) -> Dictionary:
	for m in d()["moventi"]:
		if m["id"] == id:
			return m
	return {}


static func gruppo(id: String) -> Dictionary:
	for g in d()["gruppi"]:
		if g["id"] == id:
			return g
	return {}


static func nome_gruppo(id: String) -> String:
	return str(gruppo(id).get("nome", id))


static func edificio(id: String) -> Dictionary:
	for e in d()["edifici"]:
		if e["id"] == id:
			return e
	return {}


static func quartiere(b: int) -> String:
	return d()["quartieri"][b]


static func domanda(i: int) -> Dictionary:
	return d()["domande"][i]


## Quartieri adiacenti (con un lato in comune): la città non si richiude su se stessa.
static func adiacenti(b: int) -> Array:
	var r := b / 4
	var c := b % 4
	var out := []
	if r > 0:
		out.append(b - 4)
	if r < 3:
		out.append(b + 4)
	if c > 0:
		out.append(b - 1)
	if c < 3:
		out.append(b + 1)
	return out


## Distanza in passi fra due quartieri.
static func distanza(a: int, b: int) -> int:
	return absi(a / 4 - b / 4) + absi(a % 4 - b % 4)


## Gli 8 quartieri intorno (anche in diagonale).
static func intorno(b: int) -> Array:
	var out := []
	for k in 16:
		if k != b and absi(k / 4 - b / 4) <= 1 and absi(k % 4 - b % 4) <= 1:
			out.append(k)
	return out


const CENTRALI := [5, 6, 9, 10]
const NOMI_SESSO := {"M": "uomo", "F": "donna"}
const NOMI_CORPORATURA := {"E": "esile", "M": "media", "R": "robusta"}
const NOMI_ALTEZZA := {"B": "basso", "M": "media", "A": "alto"}
const NOMI_ETA := {20: "giovane (20)", 40: "mezza età (40)", 60: "anziano (60)"}


static func descrivi(i: int) -> String:
	var c := civile(i)
	return "%s, %s, %d anni, corporatura %s, altezza %s" % [NOMI_SESSO[c["sesso"]], nome_gruppo(c["gruppo"]), int(c["eta"]),
		NOMI_CORPORATURA[c["corporatura"]], NOMI_ALTEZZA[c["altezza"]]]


## Risposta vera di un testimone alla domanda q, se l'Assassino è il civile a.
static func vero(q: int, a: int) -> bool:
	var dq := domanda(q)
	var c := civile(a)
	return c[dq["attr"]] == dq["val"] or (dq["attr"] == "eta" and int(c["eta"]) == int(dq["val"]))
