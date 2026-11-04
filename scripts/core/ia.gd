class_name IA
extends RefCounted
## Intelligenza artificiale per i due ruoli.
## - Assassino: sceglie vittime che lasciano aperti più moventi possibili, intimidisce i testimoni sinceri vicini alla
##   prossima Scena del Crimine e fa mentire i suoi complici in modo coerente, come se l'Assassino fosse un altro civile
##   (il «sosia»).
## - Detective: usa solo le informazioni pubbliche. Tiene conto di tutte le ipotesi (Assassino, Sostenitori, Persona
##   Segnalata, movente) compatibili con testimonianze, omicidi e Sorveglianze, e sceglie domande e azioni che
##   dividono meglio le ipotesi rimaste.

var _cache_n := -1
var _cache: Dictionary = {}
var sosia := -1


func scegli(m: Motore, posto: int, req: Dictionary) -> int:
	var ops: Array = req["opzioni"]
	if ops.size() <= 1:
		return 0
	if posto == Motore.ASSASSINO:
		return _assassino(m, req)
	return _detective(m, req)


# ======================================================================
# Deduzioni del Detective (solo dati pubblici)
# ======================================================================

## Pesi delle ipotesi: {pc: {civ: prob}, pm: {mov: prob}, w: {civ: {mov: peso}}}
func deduzioni(m: Motore) -> Dictionary:
	var chiave := m.storia.size() * 1000 + m.testimonianze.size() * 10 + m.sorveglianze.size()
	if chiave == _cache_n:
		return _cache
	var cand := m.vivi()
	var gruppi := []
	for g in Dati.d()["gruppi"]:
		if not m.gruppi_rivelati.has(g["id"]):
			gruppi.append(g["id"])
	var con_poi: bool = m.config.get("persona_segnalata", true)
	var confessione := ""
	var profilati := {}
	if m.intuizione != null:
		confessione = m.intuizione.confessione
		for p in m.intuizione.profilazioni:
			profilati[p["non"]] = true
	# moventi compatibili con gli omicidi (indipendenti dall'Assassino)
	var km := {}
	for mv in m.moventi:
		var ok := not profilati.has(mv)
		if ok:
			for u in m.uccisioni:
				if u.has("bomba"):
					continue
				if not Regole.ammesso(mv, u["foto"], u["civ"], -1, true):
					ok = false
					break
		km[mv] = ok
	var w := {}
	var tot := 0.0
	for c in cand:
		# testimoni che hanno detto il falso se l'Assassino fosse c
		var falsi := {}
		for t in m.testimonianze:
			if t["civ"] != c and Dati.vero(t["q"], c) != t["r"]:
				falsi[t["civ"]] = true
		var n := 0.0
		for g in gruppi:
			var resto := []
			for x in falsi:
				if Dati.civile(x)["gruppo"] != g:
					resto.append(x)
			if not con_poi:
				n += 1.0 if resto.is_empty() else 0.0
			elif resto.is_empty():
				n += 1.0
			elif resto.size() == 1 and (confessione == "" or Dati.civile(resto[0])["gruppo"] == confessione):
				n += 0.15
		if n <= 0.0:
			continue
		var wc := {}
		for mv in m.moventi:
			if not km[mv]:
				continue
			var ok := true
			for s in m.sorveglianze:
				var t: int = s["civ"]
				var leg: bool = t != c and Regole.ammesso(mv, s["foto"], t, -1, true)
				if s["r"] and not leg:
					ok = false
					break
				if not s["r"] and leg and t != c and mv != "cultista":
					ok = false
					break
			if ok:
				wc[mv] = n
				tot += n
		if not wc.is_empty():
			w[c] = wc
	var pc := {}
	var pm := {}
	if tot <= 0.0:
		# niente torna (per esempio bugie della Bomba): si riparte da zero
		for c in cand:
			pc[c] = 1.0 / cand.size()
		for mv in m.moventi:
			pm[mv] = 1.0 / m.moventi.size()
	else:
		for c in w:
			for mv in w[c]:
				var p: float = w[c][mv] / tot
				pc[c] = pc.get(c, 0.0) + p
				pm[mv] = pm.get(mv, 0.0) + p
	_cache_n = chiave
	_cache = {"pc": pc, "pm": pm, "w": w, "tot": tot}
	return _cache


## Quanto vale fare la domanda migliore al civile x: {v, q}.
func _valore_testimone(m: Motore, x: int, d: Dictionary) -> Dictionary:
	var pc: Dictionary = d["pc"]
	var sinc: float = 1.0 - pc.get(x, 0.0) - 1.0 / 7.0
	var gia := {}
	for t in m.testimonianze:
		if t["civ"] == x:
			gia[t["q"]] = true
	var best := 0.0
	var bq := 0
	for q in Dati.d()["domande"].size():
		var py := 0.0
		for c in pc:
			if Dati.vero(q, c):
				py += pc[c]
		var v := minf(py, 1.0 - py)
		if gia.has(q):
			v *= 0.35
		if v > best + 0.0001:
			best = v
			bq = q
	return {"v": best * 2.0 * maxf(sinc, 0.1), "q": bq}


func _valore_sorveglianza(m: Motore, t: int, d: Dictionary) -> float:
	var s := m.foto()
	var si := 0.0
	var tot := 0.0
	for c in d["w"]:
		for mv in d["w"][c]:
			var p: float = d["w"][c][mv]
			tot += p
			if t != c and Regole.ammesso(mv, s, t, -1, true):
				si += p
	if tot <= 0.0:
		return 0.0
	var f := si / tot
	return minf(f, 1.0 - f) * 2.0


func _incertezza_movente(d: Dictionary) -> float:
	var mx := 0.0
	for mv in d["pm"]:
		mx = maxf(mx, d["pm"][mv])
	return 1.0 - mx


func _valore_azione(m: Motore, a: String, b: int, d: Dictionary) -> float:
	var vicini := [b] + Dati.adiacenti(b)
	match a:
		"interroga":
			var v := 0.0
			for c in m.nel_quartiere(b):
				if not m.intim[c] and (m.intuizione == null or m.intuizione.interrogabile(c)):
					v += _valore_testimone(m, c, d)["v"]
			return v
		"ristorante":
			var v := 0.0
			for c in m.vivi():
				if m.pos[c] in vicini and not m.intim[c] and (m.intuizione == null or m.intuizione.interrogabile(c)):
					v = maxf(v, _valore_testimone(m, c, d)["v"])
			return v * 0.95
		"polizia":
			var v := 0.0
			for c in m.vivi():
				if m.pos[c] in vicini:
					v = maxf(v, _valore_sorveglianza(m, c, d))
			return v * (0.4 + _incertezza_movente(d))
		"ospedale":
			var v := 0.0
			for c in m.vivi():
				if m.pos[c] in vicini and m.intim[c]:
					v = maxf(v, _valore_testimone(m, c, d)["v"])
			return v * 0.3
		"pompieri":
			return 0.12
		"scena":
			return 0.45
	return 0.0


func _detective(m: Motore, req: Dictionary) -> int:
	var ops: Array = req["opzioni"]
	var d := deduzioni(m)
	match req["tipo"]:
		"inizio":
			var best := 0
			var bv := -1.0
			for i in ops.size():
				var b: int = ops[i]["b"]
				var v := 0.0
				for c in m.vivi():
					if Dati.distanza(m.pos[c], b) <= 1:
						v += 1.0
				if m.edifici.has(b):
					v += 0.5
				if v > bv:
					bv = v
					best = i
			return best
		"indagine":
			return _scegli_indagine(m, req, d)
		"testimone":
			var best := ops.size() - 1
			var bv := 0.02
			for i in ops.size():
				if ops[i].has("civ"):
					var v: float = _valore_testimone(m, ops[i]["civ"], d)["v"]
					if v > bv:
						bv = v
						best = i
			return best
		"domanda":
			return _valore_testimone(m, req["civ"], d)["q"]
		"ristorante":
			return _miglior_civ(ops, func(c): return _valore_testimone(m, c, d)["v"])
		"ospedale", "raddoppiare":
			return _miglior_civ(ops, func(c): return _valore_testimone(m, c, d)["v"])
		"polizia", "copertura":
			return _miglior_civ(ops, func(c): return _valore_sorveglianza(m, c, d) - d["pc"].get(c, 0.0))
		"sgombera", "destinazione", "sequestro":
			return _verso(m, ops, m.det)
		"scegli_mossa":
			# avvicina al Detective i testimoni più utili, lascia stare gli altri
			var best := ops.size() - 1
			var bv := 0.3
			for i in ops.size():
				if ops[i].has("civ"):
					var c: int = ops[i]["civ"]
					if Dati.distanza(m.pos[c], m.det) >= 2:
						var v: float = _valore_testimone(m, c, d)["v"]
						if v > bv:
							bv = v
							best = i
			return best
		"accusa_civile":
			return _miglior_civ(ops, func(c): return d["pc"].get(c, 0.0))
		"accusa_movente":
			var c: int = m.accusa.get("civ", -1)
			var best := 0
			var bv := -1.0
			for i in ops.size():
				var mv: String = ops[i]["mov"]
				var v: float = d["pm"].get(mv, 0.0)
				if d["w"].has(c):
					v += d["w"][c].get(mv, 0.0) * 1000.0
				if v > bv:
					bv = v
					best = i
			return best
		"anticipo":
			var mx := 0.0
			for c in d["pc"]:
				mx = maxf(mx, d["pc"][c])
			var mm := 0.0
			for mv in d["pm"]:
				mm = maxf(mm, d["pm"][mv])
			return 1 if mx > 0.995 and mm > 0.995 else 0
		"sesto_senso":
			return 1
		"rifiuta_sorv":
			return 0
		"prendi_carta":
			return _priorita(ops, ["copertura", "testimonianza", "confessione", "profilazione", "aiuto", "raddoppiare", "sequestro", "coprifuoco", "blitz", "cordone", "sesto"])
		"ricevi_carta":
			for i in ops.size():
				if ops[i]["a"] == "gioca" and not ("Sesto" in ops[i]["t"]):
					return i
			for i in ops.size():
				if ops[i]["a"] == "tieni":
					return i
			return 0
		"aiuto":
			return 0
		"testimonianza1", "testimonianza2":
			return _miglior_civ(ops, func(c): return _valore_testimone(m, c, d)["v"])
		"profilazione":
			var ord := m.moventi.duplicate()
			ord.sort_custom(func(a, b): return d["pm"].get(a, 0.0) > d["pm"].get(b, 0.0))
			for i in ops.size():
				if (ops[i]["m1"] == ord[0] and ops[i]["m2"] == ord[1]) or (ops[i]["m1"] == ord[1] and ops[i]["m2"] == ord[0]):
					return i
			return 0
		"cordone":
			return _verso(m, ops, m.det)
		"evacua":
			var best := 0
			var bd := -1
			for i in ops.size():
				var dd := Dati.distanza(ops[i]["b"], m.det)
				if dd > bd:
					bd = dd
					best = i
			return best
	return 0


func _priorita(ops: Array, lista: Array) -> int:
	for k in lista:
		var nome: String = Intuizione.CARTE_DETECTIVE[k]["nome"]
		for i in ops.size():
			if str(ops[i]["t"]).begins_with(nome):
				return i
	return 0


func _miglior_civ(ops: Array, f: Callable) -> int:
	var best := 0
	var bv := -INF
	for i in ops.size():
		if ops[i].has("civ"):
			var v: float = f.call(ops[i]["civ"])
			if v > bv:
				bv = v
				best = i
	return best


func _verso(_m: Motore, ops: Array, b: int) -> int:
	var best := 0
	var bd := 99
	for i in ops.size():
		if ops[i].has("b"):
			var dd := Dati.distanza(ops[i]["b"], b)
			if dd < bd:
				bd = dd
				best = i
	return best


func _scegli_indagine(m: Motore, req: Dictionary, d: Dictionary) -> int:
	var ops: Array = req["opzioni"]
	var mp: int = req.get("mp", 0)
	# azioni gratuite utili: Sorveglianza già posata, verifica delle prove, carta conservata
	for i in ops.size():
		if ops[i].get("sorveglia", false):
			return i
	for i in ops.size():
		if ops[i].get("gratuita", "") in ["verifica", "gioca"]:
			return i
	var usate: Array = req.get("usate", [])
	# valore dell'azione migliore da qui
	var best_qui := 0.0
	var i_qui := -1
	for i in ops.size():
		if ops[i].has("azione"):
			var v := _valore_azione(m, ops[i]["azione"], m.det, d)
			if v > best_qui:
				best_qui = v
				i_qui = i
	# valore delle azioni raggiungibili muovendosi
	var best_via := 0.0
	var i_via := -1
	if mp > 0 and req.get("azioni", 0) > 0:
		for i in ops.size():
			if not ops[i].has("muovi"):
				continue
			var b: int = ops[i]["muovi"]
			for dest in 16:
				if Dati.distanza(b, dest) > mp - 1:
					continue
				var vv := 0.0
				for a in ["interroga", "ristorante", "polizia", "ospedale", "pompieri", "scena"]:
					if a in usate:
						continue
					var ammessa: bool = a == "interroga"
					if a in ["ristorante", "polizia", "ospedale", "pompieri"]:
						ammessa = m.edifici.get(dest, "") == a
					if a == "scena":
						ammessa = m.intuizione != null and dest in m.scene
					if ammessa:
						vv = maxf(vv, _valore_azione(m, a, dest, d))
				vv *= 0.97
				if vv > best_via:
					best_via = vv
					i_via = i
	if i_via >= 0 and best_via > best_qui * 1.15 + 0.05:
		return i_via
	if i_qui >= 0 and best_qui > 0.04:
		return i_qui
	if i_via >= 0 and best_via > 0.04:
		return i_via
	return ops.size() - 1


# ======================================================================
# Assassino
# ======================================================================

func _sinceri_vicini(m: Motore, b: int, r := 1) -> int:
	var n := 0
	for c in m.vivi():
		if not m.bugiardo(c) and not m.intim[c] and Dati.distanza(m.pos[c], b) <= r:
			n += 1
	return n


## Quanti moventi in gioco restano compatibili (agli occhi del Detective) se si uccide v.
func _ambiguita(m: Motore, v: int) -> int:
	var s := m.foto()
	var n := 0
	for mv in m.moventi:
		var ok := Regole.ammesso(mv, s, v, -1, true)
		if ok:
			for u in m.uccisioni:
				if not u.has("bomba") and not Regole.ammesso(mv, u["foto"], u["civ"], -1, true):
					ok = false
					break
		if ok:
			n += 1
	return n


func _punteggio_vittima(m: Motore, v: int) -> float:
	var b: int = m.pos[v]
	var sc := 2.0 * _ambiguita(m, v)
	if m.bugiardo(v):
		sc -= 2.0
	else:
		sc += 1.0
	if v == sosia:
		sc -= 3.0
	# il Detective arriverà qui: meglio pochi testimoni sinceri intorno
	sc -= 0.6 * _sinceri_vicini(m, b, 1)
	# deve restare almeno una vittima possibile per il prossimo round
	var vecchia_p: int = m.pos[v]
	var vecchio_det := m.det
	m.pos[v] = -1
	m.vittime.append(v)
	m.scene.append(b)
	m.det = b
	var dopo := Regole.vittime_possibili(m.movente, m.foto(), m.assassino, m.poi).size()
	m.det = vecchio_det
	m.scene.pop_back()
	m.vittime.pop_back()
	m.pos[v] = vecchia_p
	if m.vittime.size() < Regole.VITTIME_TOTALI - 1:
		sc += -6.0 if dopo == 0 else minf(dopo, 6) * 0.35
	if m.movente == "cultista" and v == m.poi:
		sc += 1.0 if m.vittime.size() >= 2 else -1.0
	return sc


func _vittima_migliore(m: Motore) -> int:
	var best := -1
	var bv := -INF
	for v in m.vittime_possibili():
		var s := _punteggio_vittima(m, v)
		if s > bv:
			bv = s
			best = v
	return best


func _scegli_sosia(m: Motore) -> void:
	if sosia >= 0 and m.pos[sosia] >= 0:
		return
	var a := Dati.civile(m.assassino)
	var best := -1
	var bv := -1
	for c in m.vivi():
		if c == m.assassino or m.bugiardo(c):
			continue
		var x := Dati.civile(c)
		var diff := 0
		for k in ["sesso", "eta", "corporatura", "altezza"]:
			if str(x[k]) != str(a[k]):
				diff += 1
		if diff > bv:
			bv = diff
			best = c
	sosia = best


func _minaccia(m: Motore, c: int, v: int, scena: int) -> float:
	if m.bugiardo(c):
		return -5.0 - Dati.distanza(m.pos[c], scena)
	if c == v and m.movente == "sadico":
		return -10.0
	return 4.0 - Dati.distanza(m.pos[c], scena) - 0.3 * Dati.distanza(m.pos[c], m.det)


func _assassino(m: Motore, req: Dictionary) -> int:
	var ops: Array = req["opzioni"]
	match req["tipo"]:
		"sostenitori":
			var best := 0
			var bv := -1
			for i in ops.size():
				var n := 0
				for c in m.civili:
					if c != m.assassino and Dati.civile(c)["gruppo"] == ops[i]["gruppo"]:
						n += 1
				if n > bv:
					bv = n
					best = i
			return best
		"intimidisci":
			var v := _vittima_migliore(m)
			var scena: int = m.pos[v] if v >= 0 else m.det
			return _miglior_civ(ops, func(c): return _minaccia(m, c, v, scena))
		"omicidio":
			var best := ops.size() - 1
			var bv := -INF
			for i in ops.size():
				if ops[i].has("civ") and not ops[i].has("bomba"):
					var s := _punteggio_vittima(m, ops[i]["civ"])
					if s > bv:
						bv = s
						best = i
			if bv == -INF:
				for i in ops.size():
					if ops[i].has("bomba"):
						return i
			return best
		"risposta":
			var c: int = req["civ"]
			var q: int = req["q"]
			for i in ops.size():
				if ops[i].has("ricatto") and not m.bugiardo(c):
					return i
			if not m.bugiardo(c):
				return 0
			_scegli_sosia(m)
			var finta := Dati.vero(q, sosia) if sosia >= 0 else not Dati.vero(q, m.assassino)
			for i in ops.size():
				if ops[i].has("v") and ops[i]["v"] == finta:
					return i
			return 0
		"scegli_mossa":
			# i complici vanno verso il Detective (per mentire), i testimoni sinceri si allontanano
			var best := ops.size() - 1
			var bv := 0.5
			for i in ops.size():
				if ops[i].has("civ"):
					var c: int = ops[i]["civ"]
					var dd := Dati.distanza(m.pos[c], m.det)
					var v := (3.0 - dd) if not m.bugiardo(c) else (dd - 1.0) * 0.8
					if v > bv:
						bv = v
						best = i
			return best
		"destinazione":
			var c: int = req.get("civ", -1)
			var lontano := c >= 0 and not m.bugiardo(c)
			var best := 0
			var bv := -INF
			for i in ops.size():
				var dd := Dati.distanza(ops[i]["b"], m.det)
				var v := float(dd) if lontano else -float(dd)
				if v > bv:
					bv = v
					best = i
			return best
		"carte_assassino":
			for i in ops.size():
				var k: String = ops[i].get("carta", "")
				if k == "messaggio" or k == "testimoni" or k == "manomettere":
					return i
				if k == "rapimento" and m.vittime_possibili().is_empty():
					return i
				if k == "sciopero" and m.round >= 2:
					return i
				if k == "graffiti" and m.movente == "spia":
					return i
			return 0
		"sciopero":
			var best := 0
			var bv := -1
			for i in ops.size():
				var n := 0
				for c in m.vivi():
					if Dati.civile(c)["gruppo"] == ops[i]["gruppo"] and not m.bugiardo(c):
						n += 1
				if n > bv:
					bv = n
					best = i
			return best
		"testimoni":
			var best := 0
			var bv := -1
			for i in ops.size():
				var n := _sinceri_vicini(m, ops[i]["b"], 0) * 2 - Dati.distanza(ops[i]["b"], m.det)
				if n > bv:
					bv = n
					best = i
			return best
		"rapimento":
			# cerca uno spostamento che crei una vittima possibile
			return 0
		"falsa":
			return 1
		"falsa_dest":
			var best := 0
			var bv := 99
			for i in ops.size():
				var n := _sinceri_vicini(m, ops[i]["b"], 1)
				if n < bv:
					bv = n
					best = i
			return best
		"nascondersi":
			var t := m.sorveglianza
			var leg: bool = t != m.assassino and Regole.ammesso(m.movente, m.foto(), t, m.poi)
			return 1 if (t == m.assassino or not leg) else 0
		"nascondersi_dest":
			return _miglior_civ(ops, func(c): return 1.0 if (c != m.assassino and Regole.ammesso(m.movente, m.foto(), c, m.poi)) else 0.0)
		"corrompere":
			return 1
		"carta_scena":
			var pri := ["messaggio", "bomba", "nascondersi", "corrompere", "falsa", "testimoni", "sciopero", "rapimento", "ricatto", "manomettere", "graffiti"]
			var best := 0
			var bv := 99
			for i in ops.size():
				var p := pri.find(ops[i]["carta"])
				if p >= 0 and p < bv:
					bv = p
					best = i
			return best
		"testimonianza_scelta":
			for i in ops.size():
				if m.bugiardo(ops[i]["civ"]):
					return i
			return 0
		"gruppo_libero":
			return 0
	return 0


# ======================================================================
# Certezze per il taccuino (solo dati pubblici)
# ======================================================================

## Che cosa si può dire con certezza dagli indizi raccolti:
## {innocenti: {civile: motivo}, sospetti: [civili], esclusi: {movente: motivo}, possibili: [moventi]}
static func certezze(m: Motore) -> Dictionary:
	var gruppi := []
	for g in Dati.d()["gruppi"]:
		if not m.gruppi_rivelati.has(g["id"]):
			gruppi.append(g["id"])
	var con_poi: bool = m.poi >= 0 or m.config.get("persona_segnalata", true)
	var confessione := ""
	var profilati := {}
	if m.intuizione != null:
		confessione = m.intuizione.confessione
		for p in m.intuizione.profilazioni:
			profilati[p["non"]] = true
	var esclusi := {}
	for mv in m.moventi:
		if profilati.has(mv):
			esclusi[mv] = "La Profilazione criminale lo ha escluso."
			continue
		for k in m.uccisioni.size():
			var u: Dictionary = m.uccisioni[k]
			if u.has("bomba"):
				continue
			if not Regole.ammesso(mv, u["foto"], u["civ"], -1, true):
				esclusi[mv] = "Con questo movente l'omicidio n. %d (%s) non sarebbe stato possibile." % [k + 1, m.nome(u["civ"])]
				break
		if esclusi.has(mv):
			continue
		for s in m.sorveglianze:
			if s["r"] and not Regole.ammesso(mv, s["foto"], s["civ"], -1, true):
				esclusi[mv] = "La Sorveglianza su %s (round %d) ha risposto Sì: con questo movente sarebbe stato No." % [m.nome(s["civ"]), s["round"]]
				break
	var innocenti := {}
	var sospetti := []
	var sostegno := {}
	for c in m.vivi():
		var motivo := ""
		for s in m.sorveglianze:
			if s["civ"] == c and s["r"]:
				motivo = "la Sorveglianza su di lui avrebbe risposto No, invece ha risposto Sì."
		if motivo == "":
			var falsi := []
			for t in m.testimonianze:
				if t["civ"] != c and Dati.vero(t["q"], c) != t["r"] and not (t["civ"] in falsi):
					falsi.append(t["civ"])
			var ok := false
			for g in gruppi:
				var resto := []
				for x in falsi:
					if Dati.civile(x)["gruppo"] != g:
						resto.append(x)
				if resto.is_empty() or (con_poi and resto.size() == 1 and (confessione == "" or Dati.civile(resto[0])["gruppo"] == confessione)):
					ok = true
					break
			if not ok:
				var nomi := []
				for x in falsi:
					nomi.append(m.nome(x))
				var elenco := ", ".join(nomi.slice(0, 3)) + ((" e un altro" if nomi.size() == 4 else " e altri %d" % (nomi.size() - 3)) if nomi.size() > 3 else "")
				motivo = "avrebbero mentito %s: troppi bugiardi di gruppi diversi." % elenco
		if motivo == "":
			var mov_ok := []
			for mv in m.moventi:
				if esclusi.has(mv):
					continue
				var ok2 := true
				for s in m.sorveglianze:
					if not s["r"] and s["civ"] != c and mv != "cultista" and Regole.ammesso(mv, s["foto"], s["civ"], -1, true):
						ok2 = false
						break
				if ok2:
					mov_ok.append(mv)
			if mov_ok.is_empty():
				motivo = "nessun movente rimasto torna con le risposte della Sorveglianza."
			for mv in mov_ok:
				sostegno[mv] = true
		if motivo == "":
			sospetti.append(c)
		else:
			innocenti[c] = motivo
	var possibili := []
	for mv in m.moventi:
		if esclusi.has(mv):
			continue
		if not sostegno.has(mv) and not sospetti.is_empty():
			esclusi[mv] = "Con questo movente le Sorveglianze con risposta No indicherebbero come Assassino un civile già escluso."
			continue
		possibili.append(mv)
	return {"innocenti": innocenti, "sospetti": sospetti, "esclusi": esclusi, "possibili": possibili}
