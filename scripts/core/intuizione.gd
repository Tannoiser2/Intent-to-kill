class_name Intuizione
extends RefCounted
## Modalità Intuizione: carte Assassino, carte Detective e prove.
## Il motore chiama queste funzioni nei momenti giusti del round; ogni scelta passa sempre da m.chiedi().

var m: Motore

const CARTE_ASSASSINO := {
	"rapimento": {"nome": "Rapimento", "quando": "Prima dell'omicidio", "testo": "Muovi un qualsiasi civile di 1 o 2 quartieri.", "n": 2},
	"sciopero": {"nome": "Sciopero sindacale", "quando": "Durante la fase dell'Assassino", "testo": "Scegli un gruppo sociale. I civili di quel gruppo non possono essere interrogati durante la prossima fase del Detective.", "n": 1, "prova": true},
	"manomettere": {"nome": "Manomettere le prove", "quando": "Durante la fase dell'Assassino", "testo": "Scarta 1 delle carte Detective disponibili. Non rimpiazzarla fino alla fase della Città.", "n": 1},
	"nascondersi": {"nome": "Nascondersi tra la folla", "quando": "Quando il Detective usa la Sorveglianza", "testo": "Sposta il segnalino Sorveglianza su un altro civile nello stesso quartiere o in uno adiacente. Il Detective può rifiutare la Sorveglianza.", "n": 2},
	"messaggio": {"nome": "Messaggio segreto", "quando": "All'inizio della fase dell'Assassino", "testo": "Puoi intimidire 2 civili in più.", "n": 2},
	"ricatto": {"nome": "Ricatto", "quando": "Durante un interrogatorio di 2 o 3 civili", "testo": "Dopo che è stata posta la domanda: non sei obbligato a rispondere.", "n": 1, "prova": true},
	"testimoni": {"nome": "Testimoni ostinati", "quando": "Durante la fase dell'Assassino", "testo": "Scegli un quartiere: i civili che vi si trovano non possono essere interrogati durante la prossima fase del Detective.", "n": 1},
	"graffiti": {"nome": "Graffiti minatori", "quando": "Durante la fase dell'Assassino", "testo": "Sposta un segnalino Edificio in un quartiere adiacente privo di edifici.", "n": 1, "prova": true},
	"bomba": {"nome": "Bomba artigianale", "quando": "Anziché uccidere", "testo": "Scegli un quartiere: tutti i suoi civili finiscono nel prossimo spazio delle Vittime. Uno solo è la vittima vera.", "n": 1},
	"corrompere": {"nome": "Corrompere la polizia", "quando": "Quando viene giocata una carta Detective", "testo": "Il Detective scarta la carta senza applicarne l'effetto.", "n": 1, "prova": true},
	"falsa": {"nome": "Falsa segnalazione", "quando": "Nella fase del Detective, dopo la Risposta iniziale", "testo": "Muovi il segnalino Detective di 1 o 2 quartieri.", "n": 1},
}
const CARTE_DETECTIVE := {
	"cordone": {"nome": "Cordone", "testo": "Colloca questa carta in un quartiere: i civili non possono entrarvi, uscirne o esservi uccisi fino alla prossima fase del Detective.", "n": 1},
	"raddoppiare": {"nome": "Raddoppiare le pattuglie", "testo": "Gira una carta Civile intimidita in un quartiere qualsiasi.", "n": 2},
	"aiuto": {"nome": "Aiuto alle indagini", "testo": "Utilizza l'azione di un qualsiasi edificio, anche se non sei nel suo quartiere.", "n": 1, "carta": true},
	"sequestro": {"nome": "Sequestro del veicolo", "testo": "Sposta il segnalino Detective in un quartiere adiacente senza spendere punti movimento.", "n": 2},
	"testimonianza": {"nome": "Testimonianza", "testo": "Scegli due civili non intimiditi e interrogane subito uno (l'Assassino decide quale).", "n": 1},
	"copertura": {"nome": "Sorveglianza sotto copertura", "testo": "Colloca il segnalino Sorveglianza su un qualsiasi civile della città.", "n": 1, "carta": true},
	"sesto": {"nome": "Sesto senso", "testo": "Quando viene giocata una carta Assassino: l'Assassino la scarta senza applicarne l'effetto.", "n": 1, "carta": true},
	"profilazione": {"nome": "Profilazione criminale", "testo": "Nomina 2 moventi: l'Assassino deve dire quale dei 2 non è il suo movente.", "n": 1},
	"blitz": {"nome": "Blitz della polizia", "testo": "Scegli un gruppo sociale: puoi muovere quanti civili vuoi di quel gruppo nei quartieri adiacenti.", "n": 2},
	"coprifuoco": {"nome": "Coprifuoco", "testo": "Scegli un'età o un gruppo sociale: nella prossima fase dell'Assassino non può uccidere un civile con quell'età o di quel gruppo.", "n": 1},
	"confessione": {"nome": "Confessione completa", "testo": "L'Assassino deve rivelare il gruppo sociale a cui appartiene la Persona Segnalata.", "n": 1, "carta": true},
}

var mazzo_a: Array = []
var scarti_a: Array = []
var sotto_scene: Array = []     # due carte sotto ogni Scena del Crimine
var mano_a: Array = []          # carte Assassino in mano
var mazzo_d: Array = []
var scarti_d: Array = []
var disponibili: Array = []     # 3 carte Detective scoperte (stringa vuota = posto vuoto)
var conservata := ""            # carta Detective tenuta da parte
var conservate_max := 1
var prove_pool: Array = []
var prove: Array = []           # prove del Detective (tipi di edificio)
var prove_note := 0             # quante prove ha visto l'Assassino (sono coperte)
var coprifuoco := {}
var coprifuoco_attivo := {}
var cordone := -1
var sciopero := ""
var ostinati := -1
var manomesso := false
var bombe := {}                 # numero della vittima -> civili uccisi dalla bomba
var _multiplo := false
var _ricatto_usato := false
var profilazioni: Array = []    # {a, b, non}
var confessione := ""


func prepara() -> void:
	for k in CARTE_ASSASSINO:
		for i in CARTE_ASSASSINO[k]["n"]:
			mazzo_a.append(k)
	m._mescola(mazzo_a)
	for i in 5:
		sotto_scene.append([mazzo_a.pop_back(), mazzo_a.pop_back()])
	for k in CARTE_DETECTIVE:
		for i in CARTE_DETECTIVE[k]["n"]:
			mazzo_d.append(k)
	m._mescola(mazzo_d)
	for i in 3:
		disponibili.append(_pesca_d())
	for t in ["polizia", "ristorante", "ospedale", "pompieri"]:
		for i in 6:
			prove_pool.append(t)
	m._mescola(prove_pool)


func preparazione() -> void:
	m.scrivi("Modalità Intuizione: sotto ogni Scena del Crimine ci sono 2 carte Assassino; le carte Detective disponibili sono %s." % _elenco(disponibili))


func _elenco(a: Array) -> String:
	var n := []
	for k in a:
		if k != "":
			n.append(CARTE_DETECTIVE[k]["nome"])
	return ", ".join(n) if not n.is_empty() else "nessuna"


func _pesca_d() -> String:
	if mazzo_d.is_empty():
		mazzo_d = scarti_d.duplicate()
		scarti_d.clear()
		m._mescola(mazzo_d)
	return mazzo_d.pop_back() if not mazzo_d.is_empty() else ""


func _pesca_a() -> String:
	if mazzo_a.is_empty():
		mazzo_a = scarti_a.duplicate()
		scarti_a.clear()
		m._mescola(mazzo_a)
	return mazzo_a.pop_back() if not mazzo_a.is_empty() else ""


func aggiungi_a_foto(s: Dictionary) -> void:
	s["coprifuoco"] = coprifuoco_attivo.duplicate()
	s["cordone"] = cordone


func puo_entrare(b: int) -> bool:
	return b != cordone


func puo_uscire(b: int) -> bool:
	return b != cordone


func interrogabile(c: int) -> bool:
	if sciopero != "" and Dati.civile(c)["gruppo"] == sciopero:
		return false
	if ostinati >= 0 and m.pos[c] == ostinati:
		return false
	return true


func si_puo_interrogare_quartiere(_b: int) -> bool:
	return true


# ---------------------------------------------------------------------- carte Assassino

func _giocabili_a(tipi: Array) -> Array:
	var out := []
	var visti := {}
	for k in mano_a:
		if k in tipi and not visti.has(k):
			visti[k] = true
			out.append(k)
	return out


## Il Detective può annullare una carta Assassino con Sesto senso. Restituisce true se la carta è annullata.
func _sesto_senso(k: String) -> bool:
	if conservata != "sesto":
		return false
	var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "sesto_senso", "testo": "L'Assassino gioca %s. Usi Sesto senso per annullarla?" % CARTE_ASSASSINO[k]["nome"],
		"opzioni": [{"t": "No, lascia stare"}, {"t": "Sì, gioca Sesto senso"}]})
	if r == 1:
		conservata = ""
		scarti_d.append("sesto")
		m.scrivi("Il Detective gioca Sesto senso: %s non ha effetto." % CARTE_ASSASSINO[k]["nome"])
		_dopo_carta_d("sesto")
		return true
	return false


## Gioca una carta Assassino: la toglie dalla mano, gestisce Sesto senso e la prova. true = l'effetto va applicato.
func _usa_a(k: String) -> bool:
	mano_a.erase(k)
	scarti_a.append(k)
	m.scrivi("L'Assassino gioca %s." % CARTE_ASSASSINO[k]["nome"])
	m.evento.emit({"k": "carta", "posto": 0, "carta": k})
	if await _sesto_senso(k):
		return false
	if CARTE_ASSASSINO[k].get("prova", false):
		_dai_prova("per la carta %s" % CARTE_ASSASSINO[k]["nome"])
	return true


func _menu_carte_a(tipi: Array, testo: String) -> int:
	var extra := 0
	while m.esito == "":
		var g := _giocabili_a(tipi)
		if g.is_empty():
			break
		var ops := [{"t": "Continua senza giocare carte"}]
		for k in g:
			ops.append({"t": "Gioca %s: %s" % [CARTE_ASSASSINO[k]["nome"], CARTE_ASSASSINO[k]["testo"]], "carta": k})
		m.cambiato.emit()
		var r := await m.chiedi(Motore.ASSASSINO, {"tipo": "carte_assassino", "testo": testo, "opzioni": ops})
		if r == 0:
			break
		var k: String = ops[r]["carta"]
		if not await _usa_a(k):
			continue
		match k:
			"messaggio":
				extra += 2
			"sciopero":
				var gops := []
				for gr in Dati.d()["gruppi"]:
					gops.append({"t": gr["nome"], "gruppo": gr["id"]})
				var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "sciopero", "testo": "Sciopero sindacale: quale gruppo non potrà essere interrogato?", "opzioni": gops})
				sciopero = gops[s]["gruppo"]
				m.scrivi("Sciopero: i civili del gruppo %s non parlano fino alla fine della prossima fase del Detective." % gops[s]["t"])
			"manomettere":
				var dops := []
				for i in disponibili.size():
					if disponibili[i] != "":
						dops.append({"t": "Scarta %s" % CARTE_DETECTIVE[disponibili[i]]["nome"], "i": i})
				if not dops.is_empty():
					var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "manomettere", "testo": "Quale carta Detective disponibile scarti?", "opzioni": dops})
					var i: int = dops[s]["i"]
					m.scrivi("La carta Detective %s viene scartata." % CARTE_DETECTIVE[disponibili[i]]["nome"])
					scarti_d.append(disponibili[i])
					disponibili[i] = ""
					manomesso = true
			"testimoni":
				var qops := []
				for b in 16:
					if not m.nel_quartiere(b).is_empty():
						qops.append({"t": Dati.quartiere(b), "b": b})
				if not qops.is_empty():
					var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "testimoni", "testo": "Testimoni ostinati: in quale quartiere?", "opzioni": qops})
					ostinati = qops[s]["b"]
					m.scrivi("Testimoni ostinati a %s." % Dati.quartiere(ostinati))
			"graffiti":
				var eops := []
				for b in m.edifici:
					for x in Dati.adiacenti(b):
						if not m.edifici.has(x):
							eops.append({"t": "%s da %s a %s" % [Dati.edificio(m.edifici[b])["nome"], Dati.quartiere(b), Dati.quartiere(x)], "da": b, "a": x})
				if not eops.is_empty():
					var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "graffiti", "testo": "Graffiti minatori: quale edificio sposti?", "opzioni": eops})
					var e: Dictionary = eops[s]
					m.edifici[e["a"]] = m.edifici[e["da"]]
					m.edifici.erase(e["da"])
					m.scrivi("Graffiti minatori: %s." % e["t"])
			"rapimento":
				var cops := []
				for c in m.vivi():
					if not m._destinazioni(c, 2).is_empty():
						cops.append({"t": "%s (%s)" % [m.nome(c), Dati.quartiere(m.pos[c])], "civ": c})
				if not cops.is_empty():
					var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "rapimento", "testo": "Rapimento: quale civile sposti di 1 o 2 quartieri?", "opzioni": cops})
					var c: int = cops[s]["civ"]
					var dops := []
					for b in m._destinazioni(c, 2):
						dops.append({"t": Dati.quartiere(b), "b": b})
					var d := await m.chiedi(Motore.ASSASSINO, {"tipo": "destinazione", "testo": "Dove porti %s?" % m.nome(c), "opzioni": dops, "civ": c})
					m.pos[c] = dops[d]["b"]
					m.scrivi("%s viene portato a %s." % [m.nome(c), Dati.quartiere(m.pos[c])])
		m.cambiato.emit()
	return extra


func inizio_fase_assassino() -> int:
	# Il coprifuoco vale per questa fase dell'Assassino
	coprifuoco_attivo = coprifuoco.duplicate()
	coprifuoco = {}
	return await _menu_carte_a(["messaggio", "sciopero", "manomettere", "testimoni", "graffiti"], "Inizio della fase dell'Assassino: vuoi giocare una carta?")


func prima_omicidio() -> void:
	await _menu_carte_a(["rapimento", "sciopero", "manomettere", "testimoni", "graffiti"], "Prima dell'omicidio: vuoi giocare una carta?")


func opzioni_omicidio() -> Array:
	var out := []
	if not ("bomba" in mano_a):
		return out
	var s := m.foto()
	for b in 16:
		if b == m.det or b == m.pos[m.assassino] or b == cordone:
			continue
		var qui := m.nel_quartiere(b)
		var vera := -1
		for c in qui:
			if c != m.assassino and Regole.ammesso(m.movente, s, c, m.poi):
				vera = c
				break
		if vera >= 0 and qui.size() + m.vittime.size() >= 1:
			out.append({"t": "Bomba artigianale a %s (%d civili)" % [Dati.quartiere(b), qui.size()], "bomba": true, "b": b, "civ": vera})
	return out


func bomba(b: int) -> void:
	if not await _usa_a("bomba"):
		# annullata: nessun omicidio in questo round, ma conta come rinuncia? No: l'Assassino resta senza vittima.
		m.scrivi("La bomba non esplode: nessun omicidio in questo round.")
		m.rifiuti += 1
		if m.rifiuti >= 2:
			m._fine("detective", "L'Assassino è rimasto due volte senza omicidio.")
		else:
			m.round_massimi += 1
		return
	var qui := m.nel_quartiere(b)
	var vera := -1
	var s := m.foto()
	for c in qui:
		if c != m.assassino and Regole.ammesso(m.movente, s, c, m.poi):
			vera = c
			break
	var n := m.vittime.size()
	for c in qui:
		if c != vera:
			m.pos[c] = -1
			m.intim[c] = false
			if m.sorveglianza == c:
				m.sorveglianza = -1
	bombe[n] = qui.duplicate()
	m.uccidi(vera, false)
	m.uccisioni[-1]["bomba"] = qui.duplicate()
	m.scrivi("Bomba artigianale a %s: muoiono %s. Una sola è la vittima vera." % [Dati.quartiere(b), ", ".join(qui.map(func(x): return m.nome(x)))])


func dopo_omicidio() -> void:
	var k := m.vittime.size() - 1
	if k < 0 or k >= sotto_scene.size():
		return
	var due: Array = sotto_scene[k]
	if due.is_empty():
		return
	sotto_scene[k] = []
	var ops := []
	for c in due:
		ops.append({"t": "Tieni %s: %s" % [CARTE_ASSASSINO[c]["nome"], CARTE_ASSASSINO[c]["testo"]], "carta": c})
	var r := await m.chiedi(Motore.ASSASSINO, {"tipo": "carta_scena", "testo": "Sotto la Scena del Crimine ci sono due carte: quale tieni? L'altra va in fondo al mazzo.", "opzioni": ops})
	mano_a.append(due[r])
	mazzo_a.insert(0, due[1 - r])
	m.scrivi("L'Assassino prende una carta dalla Scena del Crimine.")
	m.scrivi("Tieni la carta %s." % CARTE_ASSASSINO[due[r]]["nome"], Motore.ASSASSINO)


func prova_per_omicidio() -> void:
	_dai_prova("per l'omicidio")


func _dai_prova(perche: String) -> void:
	if prove_pool.is_empty():
		return
	var t: String = prove_pool.pop_back()
	prove.append(t)
	m.scrivi("Il Detective riceve una prova %s." % perche)
	m.scrivi("La prova ha il simbolo: %s." % Dati.edificio(t)["nome"], Motore.DETECTIVE)


func dopo_risposta_iniziale() -> void:
	# fine degli effetti che valevano fino a questa fase del Detective
	cordone = -1
	coprifuoco_attivo = {}
	if "falsa" in mano_a:
		var r := await m.chiedi(Motore.ASSASSINO, {"tipo": "falsa", "testo": "Vuoi giocare Falsa segnalazione e spostare il Detective di 1 o 2 quartieri?",
			"opzioni": [{"t": "No"}, {"t": "Sì, gioca Falsa segnalazione"}]})
		if r == 1 and await _usa_a("falsa"):
			var ops := []
			for b in 16:
				var d := Dati.distanza(m.det, b)
				if d >= 1 and d <= 2:
					ops.append({"t": Dati.quartiere(b), "b": b})
			var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "falsa_dest", "testo": "Dove mandi il Detective?", "opzioni": ops})
			m.det = ops[s]["b"]
			m.scrivi("Falsa segnalazione: il Detective corre a %s." % Dati.quartiere(m.det))
			m.cambiato.emit()


func detective_entra(_b: int) -> void:
	pass


## Ricatto: si può giocare durante un interrogatorio di un quartiere con 2 o 3 civili.
func ricatto_possibile() -> bool:
	return _multiplo and ("ricatto" in mano_a)


func opzioni_risposta(_c: int) -> Array:
	if ricatto_possibile():
		return [{"t": "Gioca Ricatto: il civile non risponde", "ricatto": true}]
	return []


func gioca_ricatto() -> void:
	await _usa_a("ricatto")


func reazione_sorveglianza() -> bool:
	if not ("nascondersi" in mano_a):
		return false
	var c := m.sorveglianza
	var vicini := []
	for x in m.civili:
		if x != c and m.pos[x] >= 0 and Dati.distanza(m.pos[x], m.pos[c]) <= 1:
			vicini.append(x)
	if vicini.is_empty():
		return false
	var r := await m.chiedi(Motore.ASSASSINO, {"tipo": "nascondersi", "testo": "Il Detective usa la Sorveglianza su %s. Giochi Nascondersi tra la folla?" % m.nome(c),
		"opzioni": [{"t": "No"}, {"t": "Sì, sposta la Sorveglianza"}]})
	if r == 0 or not await _usa_a("nascondersi"):
		return false
	var ops := []
	for x in vicini:
		ops.append({"t": "%s (%s)" % [m.nome(x), Dati.quartiere(m.pos[x])], "civ": x})
	var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "nascondersi_dest", "testo": "Su quale civile sposti la Sorveglianza?", "opzioni": ops})
	m.sorveglianza = ops[s]["civ"]
	m.scrivi("La Sorveglianza passa su %s." % m.nome(m.sorveglianza))
	var d := await m.chiedi(Motore.DETECTIVE, {"tipo": "rifiuta_sorv", "testo": "La Sorveglianza è passata su %s: vuoi usarla adesso o tenerla per dopo?" % m.nome(m.sorveglianza),
		"opzioni": [{"t": "Usala adesso"}, {"t": "Tienila per più tardi"}]})
	return d == 1


# ---------------------------------------------------------------------- Detective

func azioni_detective(usate: Dictionary) -> Array:
	var out := []
	if m.det in m.scene and not usate.has("scena") and not prove_pool.is_empty():
		out.append({"t": "Ispeziona la Scena del Crimine (2 prove, ne tieni una)", "azione": "scena"})
	return out


func azioni_gratuite() -> Array:
	var out := []
	var e: String = m.edifici.get(m.det, "")
	if e != "" and e in prove:
		out.append({"t": "Verifica la presenza di prove (scarta una prova %s e prendi una carta Detective)" % Dati.edificio(e)["nome"], "gratuita": "verifica"})
	if conservata != "" and conservata != "sesto":
		out.append({"t": "Gioca la carta conservata: %s" % CARTE_DETECTIVE[conservata]["nome"], "gratuita": "gioca"})
	return out


func azione(a: String) -> void:
	if a == "scena":
		var due := []
		for i in 2:
			if not prove_pool.is_empty():
				due.append(prove_pool.pop_back())
		if due.is_empty():
			return
		var ops := []
		for t in due:
			ops.append({"t": "Tieni la prova %s" % Dati.edificio(t)["nome"], "p": t})
		var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "prova_scena", "testo": "Ispezione della Scena del Crimine: quale prova tieni?", "opzioni": ops, "auto": true})
		prove.append(due[r])
		m.scrivi("Il Detective ispeziona la Scena del Crimine e tiene una prova.")


func gratuita(o: Dictionary) -> void:
	match o["gratuita"]:
		"verifica":
			var e: String = m.edifici.get(m.det, "")
			prove.erase(e)
			m.scrivi("Il Detective scarta una prova %s e prende una carta Detective." % Dati.edificio(e)["nome"])
			var ops := []
			for i in disponibili.size():
				if disponibili[i] != "":
					ops.append({"t": "%s: %s" % [CARTE_DETECTIVE[disponibili[i]]["nome"], CARTE_DETECTIVE[disponibili[i]]["testo"]], "i": i})
			ops.append({"t": "La prima carta del mazzo (coperta)", "i": -1})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "prendi_carta", "testo": "Quale carta Detective prendi?", "opzioni": ops})
			var k := ""
			var i: int = ops[r]["i"]
			if i < 0:
				k = _pesca_d()
			else:
				k = disponibili[i]
				disponibili.remove_at(i)
				disponibili.insert(0, "" if manomesso else _pesca_d())
			if k != "":
				await _ricevi(k)
		"gioca":
			var k := conservata
			conservata = ""
			await gioca_d(k)


func _ricevi(k: String) -> void:
	m.scrivi("Il Detective prende la carta %s." % CARTE_DETECTIVE[k]["nome"])
	var ops := []
	if k != "sesto":
		ops.append({"t": "Gioca subito %s" % CARTE_DETECTIVE[k]["nome"], "a": "gioca"})
	if conservata == "":
		ops.append({"t": "Tienila per dopo", "a": "tieni"})
	else:
		if conservata != "sesto":
			ops.append({"t": "Gioca %s (la carta conservata) e tieni %s" % [CARTE_DETECTIVE[conservata]["nome"], CARTE_DETECTIVE[k]["nome"]], "a": "gioca_vecchia"})
		ops.append({"t": "Scarta %s" % CARTE_DETECTIVE[k]["nome"], "a": "scarta"})
		ops.append({"t": "Scarta %s e tieni %s" % [CARTE_DETECTIVE[conservata]["nome"], CARTE_DETECTIVE[k]["nome"]], "a": "scarta_vecchia"})
	var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "ricevi_carta", "testo": "Hai ricevuto %s: %s" % [CARTE_DETECTIVE[k]["nome"], CARTE_DETECTIVE[k]["testo"]], "opzioni": ops})
	match ops[r]["a"]:
		"gioca":
			await gioca_d(k)
		"tieni":
			conservata = k
		"gioca_vecchia":
			var v := conservata
			conservata = k
			await gioca_d(v)
		"scarta":
			scarti_d.append(k)
		"scarta_vecchia":
			scarti_d.append(conservata)
			conservata = k


## Gioca una carta Detective (l'Assassino può annullarla con Corrompere la polizia).
func gioca_d(k: String) -> void:
	m.scrivi("Il Detective gioca %s." % CARTE_DETECTIVE[k]["nome"])
	m.evento.emit({"k": "carta", "posto": 1, "carta": k})
	scarti_d.append(k)
	if "corrompere" in mano_a:
		var r := await m.chiedi(Motore.ASSASSINO, {"tipo": "corrompere", "testo": "Il Detective gioca %s. Giochi Corrompere la polizia per annullarla?" % CARTE_DETECTIVE[k]["nome"],
			"opzioni": [{"t": "No"}, {"t": "Sì, gioca Corrompere la polizia"}]})
		if r == 1 and await _usa_a("corrompere"):
			m.scrivi("Corrompere la polizia: %s non ha effetto." % CARTE_DETECTIVE[k]["nome"])
			return
	_dopo_carta_d(k)
	match k:
		"cordone":
			var ops := []
			for b in 16:
				ops.append({"t": Dati.quartiere(b), "b": b})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "cordone", "testo": "Cordone: in quale quartiere?", "opzioni": ops})
			cordone = ops[r]["b"]
			m.scrivi("Cordone a %s: nessuno entra, esce o viene ucciso lì fino alla prossima fase del Detective." % Dati.quartiere(cordone))
		"raddoppiare":
			var ops := []
			for c in m.vivi():
				if m.intim[c]:
					ops.append({"t": "%s (%s)" % [m.nome(c), Dati.quartiere(m.pos[c])], "civ": c})
			if not ops.is_empty():
				var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "raddoppiare", "testo": "Quale civile intimidito conforti?", "opzioni": ops})
				m.conforta(ops[r]["civ"])
		"aiuto":
			var ops := []
			for t in ["polizia", "ristorante", "ospedale", "pompieri"]:
				ops.append({"t": Dati.edificio(t)["nome"], "e": t})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "aiuto", "testo": "Aiuto alle indagini: quale azione di edificio usi (come se fossi in quel quartiere)?", "opzioni": ops})
			var e: String = ops[r]["e"]
			# l'azione vale dal quartiere di un edificio di quel tipo: lo sceglie il Detective
			var qops := []
			for b in m.edifici:
				if m.edifici[b] == e:
					qops.append({"t": "%s a %s" % [Dati.edificio(e)["nome"], Dati.quartiere(b)], "b": b})
			var qb: int = m.det
			if not qops.is_empty():
				var s := await m.chiedi(Motore.DETECTIVE, {"tipo": "aiuto_dove", "testo": "Quale edificio?", "opzioni": qops})
				qb = qops[s]["b"]
			match e:
				"polizia":
					await m._polizia(m._vicini(qb))
				"ristorante":
					await m._ristorante(m._vicini(qb))
				"ospedale":
					await m._ospedale(m._vicini(qb))
				"pompieri":
					await m.muovi_gruppo(Motore.DETECTIVE, true)
		"sequestro":
			var ops := []
			for b in Dati.adiacenti(m.det):
				ops.append({"t": Dati.quartiere(b), "b": b})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "sequestro", "testo": "Sequestro del veicolo: dove ti sposti?", "opzioni": ops})
			m.det = ops[r]["b"]
			m.scrivi("Il Detective si sposta a %s." % Dati.quartiere(m.det))
		"testimonianza":
			var cand := []
			for c in m.vivi():
				if not m.intim[c] and interrogabile(c):
					cand.append(c)
			if cand.size() >= 2:
				var ops := []
				for c in cand:
					ops.append({"t": "%s (%s)" % [m.nome(c), Dati.quartiere(m.pos[c])], "civ": c})
				var a := await m.chiedi(Motore.DETECTIVE, {"tipo": "testimonianza1", "testo": "Testimonianza: scegli il primo civile.", "opzioni": ops})
				var c1: int = ops[a]["civ"]
				ops.remove_at(a)
				var b := await m.chiedi(Motore.DETECTIVE, {"tipo": "testimonianza2", "testo": "Testimonianza: scegli il secondo civile.", "opzioni": ops})
				var c2: int = ops[b]["civ"]
				var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "testimonianza_scelta", "testo": "Testimonianza: quale dei due civili verrà interrogato?",
					"opzioni": [{"t": m.nome(c1), "civ": c1}, {"t": m.nome(c2), "civ": c2}]})
				await m.interroga([c1, c2][s])
		"copertura":
			var ops := []
			for c in m.vivi():
				ops.append({"t": "%s (%s)" % [m.nome(c), Dati.quartiere(m.pos[c])], "civ": c})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "copertura", "testo": "Su quale civile metti la Sorveglianza?", "opzioni": ops})
			await m.metti_sorveglianza(ops[r]["civ"])
		"profilazione":
			var ops := []
			for a in m.moventi:
				for b in m.moventi:
					if a < b:
						ops.append({"t": "%s o %s" % [Dati.movente(a)["nome"], Dati.movente(b)["nome"]], "m1": a, "m2": b})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "profilazione", "testo": "Profilazione criminale: quali due moventi nomini?", "opzioni": ops})
			var a: String = ops[r]["m1"]
			var b: String = ops[r]["m2"]
			var non := ""
			if m.movente == a:
				non = b
			elif m.movente == b:
				non = a
			else:
				var s := await m.chiedi(Motore.ASSASSINO, {"tipo": "profilazione_risposta", "testo": "Nessuno dei due è il tuo movente: quale indichi come «non è il mio movente»?",
					"opzioni": [{"t": Dati.movente(a)["nome"], "m": a}, {"t": Dati.movente(b)["nome"], "m": b}]})
				non = [a, b][s]
			profilazioni.append({"a": a, "b": b, "non": non})
			m.scrivi("Profilazione criminale: il movente non è %s." % Dati.movente(non)["nome"])
		"blitz":
			var ops := []
			for gr in Dati.d()["gruppi"]:
				if not m._del_gruppo(gr["id"]).is_empty():
					ops.append({"t": gr["nome"], "gruppo": gr["id"]})
			if not ops.is_empty():
				var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "blitz", "testo": "Blitz della polizia: quale gruppo sposti?", "opzioni": ops})
				await m.muovi_civili(Motore.DETECTIVE, m._del_gruppo(ops[r]["gruppo"]), "Blitz: gruppo %s" % ops[r]["t"])
		"coprifuoco":
			var ops := [{"t": "20 anni", "eta": 20}, {"t": "40 anni", "eta": 40}, {"t": "60 anni", "eta": 60}]
			for gr in Dati.d()["gruppi"]:
				ops.append({"t": gr["nome"], "gruppo": gr["id"]})
			var r := await m.chiedi(Motore.DETECTIVE, {"tipo": "coprifuoco", "testo": "Coprifuoco: quale età o gruppo proteggi nella prossima fase dell'Assassino?", "opzioni": ops})
			coprifuoco = {"eta": ops[r]["eta"]} if ops[r].has("eta") else {"gruppo": ops[r]["gruppo"]}
			m.scrivi("Coprifuoco: %s al sicuro nella prossima fase dell'Assassino." % ops[r]["t"])
		"confessione":
			if m.poi >= 0:
				confessione = Dati.civile(m.poi)["gruppo"]
				m.scrivi("Confessione completa: la Persona Segnalata appartiene al gruppo %s." % Dati.nome_gruppo(confessione))
			else:
				m.scrivi("Confessione completa: in questa partita non c'è una Persona Segnalata.")
	m.cambiato.emit()


func _dopo_carta_d(k: String) -> void:
	if CARTE_DETECTIVE[k].get("carta", false):
		var c := _pesca_a()
		if c != "":
			mano_a.append(c)
			m.scrivi("L'Assassino pesca una carta Assassino.")
			m.scrivi("Peschi %s." % CARTE_ASSASSINO[c]["nome"], Motore.ASSASSINO)


func dopo_sorveglianza_posata() -> void:
	pass


func inizio_fase_citta() -> void:
	sciopero = ""
	ostinati = -1


func fine_fase_citta() -> void:
	# rinnovo delle carte Detective: si scarta quella più a destra, si fanno scorrere le altre e se ne aggiunge una a sinistra
	manomesso = false
	if not disponibili.is_empty():
		var ult: String = disponibili.pop_back()
		if ult != "":
			scarti_d.append(ult)
	disponibili.insert(0, _pesca_d())
	for i in disponibili.size():
		if disponibili[i] == "":
			disponibili[i] = _pesca_d()
	m.scrivi("Nuove carte Detective disponibili: %s." % _elenco(disponibili))
