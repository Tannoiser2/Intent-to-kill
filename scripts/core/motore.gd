class_name Motore
extends Node
## Motore di Intent to Kill (modalità Logica e Intuizione).
## Tutta la partita è una sequenza di decisioni numerate: ogni volta che serve una scelta il motore chiede al
## controllore del posto (0 = Assassino, 1 = Detective) l'indice di un'opzione. Con lo stesso seme e le stesse
## decisioni la partita è identica: su questo si basano il gioco online (lockstep), i salvataggi e i test.

signal messaggio(testo: String, per: int)   # per: -1 tutti, 0 solo l'Assassino, 1 solo il Detective
signal cambiato
signal evento(e: Dictionary)

const ASSASSINO := 0
const DETECTIVE := 1
const MAX_NEL_QUARTIERE := 3

var config := {}
var rng := RandomNumberGenerator.new()
var giocatori := [{"nome": "Assassino", "ia": false}, {"nome": "Detective", "ia": true}]
var controllori := []
var storia: Array = []          # decisioni prese, in ordine (salvataggi e ripresa)
var ripresa: Array = []         # decisioni da riapplicare (ripresa di un salvataggio)
var in_simulazione := false
var _scelte_fatte := 0

# --- stato della città (pubblico) ---
var civili: Array = []          # i 20 civili in gioco (indici in Dati)
var pos: Array = []             # quartiere di ogni civile (54): -2 fuori dal gioco, -1 ucciso
var intim: Array = []           # civile intimidito
var det := -1                   # quartiere del segnalino Detective
var edifici := {}               # quartiere -> tipo di edificio
var scene: Array = []           # quartieri delle Scene del Crimine, in ordine
var vittime: Array = []         # civili uccisi, in ordine
var sorveglianza := -1          # civile con il segnalino Sorveglianza, -1 se è in mano al Detective
var moventi: Array = []         # i moventi in gioco (6, o 8 in Intuizione)
var pila: Array = []            # tessere dei gruppi sociali nella pila
var gruppi_rivelati := {}       # gruppi pescati dalla pila: sicuramente non sono i Sostenitori
var round := 0
var round_massimi := 5
var rifiuti := 0
var fase := ""
var esito := ""                 # "" in corso, "detective" o "assassino"
var motivo_esito := ""
var accusa := {}

# --- segreti dell'Assassino ---
var assassino := -1
var poi := -1                   # Persona Segnalata (-1 se non si usa)
var sostenitori := ""
var movente := ""

# --- registri (pubblici) per il taccuino e l'IA del Detective ---
var testimonianze: Array = []   # {civ, q, r (bool), round, b}
var sorveglianze: Array = []    # {civ, r (bool), foto, round}
var uccisioni: Array = []       # {civ, foto (prima dell'omicidio), round, b}
var registro: Array = []        # testo della partita (per i test)

var intuizione: Intuizione      # carte e prove della modalità Intuizione (null in Logica)


func prepara(cfg: Dictionary) -> void:
	config = cfg
	rng.seed = int(cfg.get("seme", 1))
	if cfg.has("giocatori"):
		giocatori = cfg["giocatori"]
	var d := Dati.d()
	pos = []
	intim = []
	for i in d["civili"].size():
		pos.append(-2)
		intim.append(false)
	# 20 civili a caso fra i 54
	var mazzo := range(d["civili"].size())
	_mescola(mazzo)
	civili = mazzo.slice(0, 20)
	# edifici
	edifici = {}
	var disp: Dictionary = d["disposizioni"].get(cfg.get("citta", "base"), d["disposizioni"]["base"])
	if cfg.get("citta", "base") == "casuale":
		var tipi := ["polizia", "polizia", "ristorante", "ristorante", "ospedale", "ospedale", "pompieri", "pompieri"]
		var q := range(16)
		_mescola(q)
		for k in 8:
			edifici[q[k]] = tipi[k]
	else:
		for k in disp["edifici"]:
			edifici[int(k)] = disp["edifici"][k]
	# moventi in gioco
	var n_mov := 8 if cfg.get("modo", "logica") == "intuizione" else 6
	var scelta: Variant = cfg.get("moventi", "principianti")
	if scelta is Array:
		moventi = scelta.duplicate()
	elif scelta == "casuali":
		var tutti := []
		for m in d["moventi"]:
			if m["id"] != "cultista" or cfg.get("persona_segnalata", true):
				tutti.append(m["id"])
		_mescola(tutti)
		moventi = tutti.slice(0, n_mov)
	else:
		moventi = d["moventi_principianti"].duplicate() if n_mov == 6 else ["psicopatico", "maniaco", "sadico", "tagliagole", "killer", "terrorista", "estremista", "rapinatore"]
	if not cfg.get("persona_segnalata", true):
		moventi.erase("cultista")
	# segreti: l'Assassino pesca a caso fra i 20, poi la Persona Segnalata, poi il movente
	var venti := civili.duplicate()
	_mescola(venti)
	assassino = venti[0]
	poi = venti[1] if cfg.get("persona_segnalata", true) else -1
	movente = moventi[rng.randi_range(0, moventi.size() - 1)]
	# civili in città: 2 negli angoli, 1 negli altri quartieri
	var k := 0
	for b in 16:
		var n := 2 if b in [0, 3, 12, 15] else 1
		for j in n:
			pos[civili[k]] = b
			k += 1
	if cfg.get("modo", "logica") == "intuizione":
		intuizione = Intuizione.new()
		intuizione.m = self
		intuizione.prepara()


func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


## Una decisione: chiede al controllore del posto e restituisce l'indice dell'opzione scelta.
func chiedi(posto: int, req: Dictionary) -> int:
	var n: int = req["opzioni"].size()
	if n == 0:
		return -1
	req["posto"] = posto
	req["n"] = storia.size()
	var v: int
	if not ripresa.is_empty():
		v = int(ripresa.pop_front())
	elif n == 1 and req.get("auto", false):
		v = 0
	else:
		v = int(await controllori[posto].decide(self, posto, req))
	if v < 0 or v >= n:
		v = 0
	storia.append(v)
	_scelte_fatte += 1
	return v


func scrivi(t: String, per := -1) -> void:
	registro.append(("[%s] " % ["A", "D"][per] if per >= 0 else "") + t)
	messaggio.emit(t, per)


func nome(c: int) -> String:
	return str(Dati.civile(c)["nome"])


## Fotografia pubblica della città (per le regole dei moventi).
func foto() -> Dictionary:
	var s := {"pos": pos.duplicate(), "intim": intim.duplicate(), "det": det, "edifici": edifici.duplicate(),
		"scene": scene.duplicate(), "vittime": vittime.duplicate(), "round": round}
	if intuizione != null:
		intuizione.aggiungi_a_foto(s)
	return s


func nel_quartiere(b: int) -> Array:
	var out := []
	for c in civili:
		if pos[c] == b:
			out.append(c)
	return out


func vivi() -> Array:
	var out := []
	for c in civili:
		if pos[c] >= 0:
			out.append(c)
	return out


func bugiardo(c: int) -> bool:
	return c == assassino or c == poi or Dati.civile(c)["gruppo"] == sostenitori


func puo_entrare(b: int) -> bool:
	return not (b in scene) and nel_quartiere(b).size() < MAX_NEL_QUARTIERE and (intuizione == null or intuizione.puo_entrare(b))


func vittime_possibili() -> Array:
	return Regole.vittime_possibili(movente, foto(), assassino, poi)


# ======================================================================
# Partita
# ======================================================================

func gioca() -> void:
	fase = "preparazione"
	await _preparazione()
	while esito == "":
		round += 1
		scrivi("Round %d" % round)
		await _fase_assassino()
		if esito != "":
			break
		await _fase_detective()
		if esito != "":
			break
		await _fase_citta()
		if esito != "":
			break
		if vittime.size() >= Regole.VITTIME_TOTALI or round >= round_massimi:
			await _accusa()
		elif round >= 3:
			var r := await chiedi(DETECTIVE, {"tipo": "anticipo", "testo": "Fine del round %d. Vuoi formulare subito le tue conclusioni?" % round,
				"opzioni": [{"t": "Continua l'indagine"}, {"t": "Accusa adesso"}]})
			if r == 1:
				await _accusa()
	fase = "fine"
	cambiato.emit()


func _preparazione() -> void:
	# Sostenitori: l'Assassino pesca 3 tessere e ne tiene una
	var tessere := []
	for g in Dati.d()["gruppi"]:
		tessere.append(g["id"])
	_mescola(tessere)
	var tre := tessere.slice(0, 3)
	var ops := []
	for g in tre:
		ops.append({"t": Dati.nome_gruppo(g), "gruppo": g})
	cambiato.emit()
	var s := await chiedi(ASSASSINO, {"tipo": "sostenitori", "testo": "Scegli i tuoi Sostenitori: i civili di questo gruppo potranno mentire per te.", "opzioni": ops})
	sostenitori = tre[s]
	pila = tessere.slice(3)
	_mescola(pila)
	scrivi("I tuoi Sostenitori: %s." % Dati.nome_gruppo(sostenitori), ASSASSINO)
	scrivi("L'Assassino ha scelto i suoi Sostenitori. Le altre 6 tessere formano la pila dei gruppi sociali.")
	# il Detective sceglie dove cominciare
	ops = []
	for b in 16:
		ops.append({"t": Dati.quartiere(b), "b": b})
	cambiato.emit()
	var q := await chiedi(DETECTIVE, {"tipo": "inizio", "testo": "Scegli il quartiere in cui collocare il segnalino Detective.", "opzioni": ops})
	det = q
	scrivi("Il Detective comincia a %s." % Dati.quartiere(det))
	if intuizione != null:
		await intuizione.preparazione()
	cambiato.emit()


# ---------------------------------------------------------------------- fase dell'Assassino

func _fase_assassino() -> void:
	fase = "assassino"
	var ucciso := -1
	var n_intim := 2
	if intuizione != null:
		n_intim += await intuizione.inizio_fase_assassino()
	for k in n_intim:
		var ops := []
		for c in vivi():
			if pos[c] != det and not intim[c]:
				ops.append({"t": "Intimidisci: %s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
		if ops.is_empty():
			break
		cambiato.emit()
		var r := await chiedi(ASSASSINO, {"tipo": "intimidisci", "testo": "Intimidisci un civile (%d di %d): il Detective non potrà interrogarlo." % [k + 1, n_intim], "opzioni": ops})
		var c: int = ops[r]["civ"]
		intim[c] = true
		scrivi("L'Assassino intimidisce %s." % nome(c))
		evento.emit({"k": "intimidito", "civ": c})
	cambiato.emit()
	if intuizione != null:
		await intuizione.prima_omicidio()
		if esito != "":
			return
	# omicidio
	var possibili := vittime_possibili()
	var ops := []
	for c in possibili:
		ops.append({"t": "Uccidi: %s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
	if intuizione != null:
		ops.append_array(intuizione.opzioni_omicidio())
	ops.append({"t": "Rinuncia a uccidere in questo round", "rinuncia": true})
	var testo := "Scegli la vittima: deve rispettare il tuo movente (%s), non può essere nel quartiere del Detective e non puoi essere tu." % Dati.movente(movente)["nome"]
	if possibili.is_empty():
		testo = "Nessun civile rispetta il tuo movente: devi rinunciare all'omicidio."
		if intuizione == null or intuizione.opzioni_omicidio().is_empty():
			ops = [ops[-1]]
	cambiato.emit()
	var r := await chiedi(ASSASSINO, {"tipo": "omicidio", "testo": testo, "opzioni": ops, "auto": true})
	var o: Dictionary = ops[r]
	if o.get("rinuncia", false):
		rifiuti += 1
		if rifiuti >= 2:
			scrivi("L'Assassino rinuncia per la seconda volta a uccidere: è la sua fine.")
			_fine("detective", "L'Assassino ha rinunciato due volte all'omicidio.")
			return
		round_massimi += 1
		scrivi("L'Assassino rinuncia a uccidere: la partita durerà un round in più.")
	elif o.has("bomba"):
		await intuizione.bomba(o["b"])
	else:
		uccidi(o["civ"])
	if intuizione != null and vittime.size() > 0 and uccisioni.size() > 0 and uccisioni[-1]["round"] == round:
		await intuizione.dopo_omicidio()
	cambiato.emit()


func uccidi(c: int, conta_prova := true) -> void:
	var b: int = pos[c]
	uccisioni.append({"civ": c, "foto": foto(), "round": round, "b": b})
	scene.append(b)
	vittime.append(c)
	pos[c] = -1
	intim[c] = false
	if sorveglianza == c:
		sorveglianza = -1
		scrivi("Il segnalino Sorveglianza torna al Detective.")
	scrivi("Omicidio n. %d: %s, a %s." % [vittime.size(), nome(c), Dati.quartiere(b)])
	evento.emit({"k": "omicidio", "civ": c, "b": b})
	if intuizione != null and conta_prova:
		intuizione.prova_per_omicidio()


# ---------------------------------------------------------------------- fase del Detective

func _fase_detective() -> void:
	fase = "detective"
	# Risposta iniziale
	if not uccisioni.is_empty() and uccisioni[-1]["round"] == round:
		var b: int = scene[-1]
		det = b
		scrivi("Risposta iniziale: il Detective accorre a %s." % Dati.quartiere(b))
		evento.emit({"k": "detective", "b": b})
		cambiato.emit()
		await _sgombera(b)
	if intuizione != null:
		await intuizione.dopo_risposta_iniziale()
	# Indagine
	var mp := 2
	var usate := {}
	var azioni := 0
	while esito == "":
		var ops := []
		if mp > 0:
			for b in Dati.adiacenti(det):
				ops.append({"t": "Muoviti a %s" % Dati.quartiere(b), "muovi": b, "b": b})
		if azioni < 2:
			if not usate.has("interroga") and _interrogabili(det).size() > 0 and (intuizione == null or intuizione.si_puo_interrogare_quartiere(det)):
				ops.append({"t": "Interroga i civili di %s" % Dati.quartiere(det), "azione": "interroga"})
			var e: String = edifici.get(det, "")
			if e != "" and not usate.has(e) and _edificio_utile(e):
				ops.append({"t": "%s: %s" % [Dati.edificio(e)["nome"], _breve_edificio(e)], "azione": e})
			if intuizione != null:
				ops.append_array(intuizione.azioni_detective(usate))
		if sorveglianza >= 0:
			ops.append({"t": "Sorveglianza: «Puoi uccidere %s adesso?»" % nome(sorveglianza), "sorveglia": true, "civ": sorveglianza})
		if intuizione != null:
			ops.append_array(intuizione.azioni_gratuite())
		ops.append({"t": "Termina la fase del Detective", "fine": true})
		cambiato.emit()
		var testo := "Indagine: %d azioni diverse rimaste, %d punti movimento." % [2 - azioni, mp]
		var r := await chiedi(DETECTIVE, {"tipo": "indagine", "testo": testo, "opzioni": ops, "mp": mp, "azioni": 2 - azioni, "usate": usate.keys()})
		var o: Dictionary = ops[r]
		if o.get("fine", false):
			break
		if o.has("muovi"):
			det = o["muovi"]
			mp -= 1
			scrivi("Il Detective si sposta a %s." % Dati.quartiere(det))
			evento.emit({"k": "detective", "b": det})
			if intuizione != null:
				intuizione.detective_entra(det)
		elif o.get("sorveglia", false):
			await usa_sorveglianza()
		elif o.has("gratuita"):
			await intuizione.gratuita(o)
		elif o.has("azione"):
			var a: String = o["azione"]
			usate[a] = true
			azioni += 1
			match a:
				"interroga":
					await _interroga_quartiere()
				"polizia":
					await _polizia(_vicini(det))
				"ristorante":
					await _ristorante(_vicini(det))
				"ospedale":
					await _ospedale(_vicini(det))
				"pompieri":
					await muovi_gruppo(DETECTIVE, true)
				_:
					await intuizione.azione(a)
	cambiato.emit()


func _vicini(b: int) -> Array:
	return [b] + Dati.adiacenti(b)


func _breve_edificio(e: String) -> String:
	return {"polizia": "colloca la Sorveglianza", "ristorante": "interroga un civile vicino", "ospedale": "conforta un civile vicino",
		"pompieri": "muovi un gruppo sociale"}[e]


func _edificio_utile(e: String) -> bool:
	var quartieri := _vicini(det)
	match e:
		"polizia":
			return _civili_in(quartieri).size() > 0
		"ristorante":
			for c in _civili_in(quartieri):
				if not intim[c] and (intuizione == null or intuizione.interrogabile(c)):
					return true
			return false
		"ospedale":
			for c in _civili_in(quartieri):
				if intim[c]:
					return true
			return false
	return true


func _civili_in(quartieri: Array) -> Array:
	var out := []
	for c in civili:
		if pos[c] in quartieri:
			out.append(c)
	return out


func _interrogabili(b: int) -> Array:
	var out := []
	for c in nel_quartiere(b):
		if not intim[c] and (intuizione == null or intuizione.interrogabile(c)):
			out.append(c)
	return out


## Civili sulla Scena del Crimine: il Detective li sposta nei quartieri adiacenti.
func _sgombera(b: int) -> void:
	for c in nel_quartiere(b):
		var ops := []
		for x in Dati.adiacenti(b):
			if puo_entrare(x):
				ops.append({"t": "%s a %s" % [nome(c), Dati.quartiere(x)], "b": x})
		if ops.is_empty():
			for x in 16:
				if x != b and puo_entrare(x):
					ops.append({"t": "%s a %s" % [nome(c), Dati.quartiere(x)], "b": x})
		if ops.is_empty():
			continue
		cambiato.emit()
		var r := await chiedi(DETECTIVE, {"tipo": "sgombera", "testo": "%s si trova sulla Scena del Crimine: dove lo sposti?" % nome(c), "opzioni": ops, "civ": c, "auto": true})
		pos[c] = ops[r]["b"]
		scrivi("%s si sposta a %s." % [nome(c), Dati.quartiere(pos[c])])


func _interroga_quartiere() -> void:
	var fatti := {}
	if intuizione != null:
		intuizione._multiplo = _interrogabili(det).size() >= 2
	while true:
		var ops := []
		for c in _interrogabili(det):
			if not fatti.has(c):
				ops.append({"t": "Interroga %s" % nome(c), "civ": c})
		if ops.is_empty():
			break
		ops.append({"t": "Basta interrogare", "fine": true})
		cambiato.emit()
		var r := await chiedi(DETECTIVE, {"tipo": "testimone", "testo": "Chi vuoi interrogare a %s?" % Dati.quartiere(det), "opzioni": ops})
		if ops[r].get("fine", false):
			break
		var c: int = ops[r]["civ"]
		fatti[c] = true
		await interroga(c)
	if intuizione != null:
		intuizione._multiplo = false


## Una domanda a un civile: il Detective sceglie la domanda, l'Assassino risponde per il civile.
func interroga(c: int) -> void:
	var ops := []
	for i in Dati.d()["domande"].size():
		ops.append({"t": Dati.domanda(i)["testo"], "q": i})
	cambiato.emit()
	var q := await chiedi(DETECTIVE, {"tipo": "domanda", "testo": "Che cosa chiedi a %s?" % nome(c), "opzioni": ops, "civ": c})
	await rispondi(c, q)


func rispondi(c: int, q: int) -> void:
	var verita := Dati.vero(q, assassino)
	var risposta := verita
	var muto := false
	if bugiardo(c):
		var ops := [{"t": "Sì", "v": true}, {"t": "No", "v": false}]
		var chi := "sei tu" if c == assassino else ("è la Persona Segnalata" if c == poi else "è dei tuoi Sostenitori")
		var testo := "Il Detective chiede a %s: «%s» Il civile può mentire (%s). La verità è «%s»." % [nome(c), Dati.domanda(q)["testo"], chi, "Sì" if verita else "No"]
		if intuizione != null:
			ops.append_array(intuizione.opzioni_risposta(c))
		cambiato.emit()
		var r := await chiedi(ASSASSINO, {"tipo": "risposta", "testo": testo, "opzioni": ops, "civ": c, "q": q})
		if ops[r].has("ricatto"):
			muto = true
			await intuizione.gioca_ricatto()
		else:
			risposta = ops[r]["v"]
	elif intuizione != null and intuizione.ricatto_possibile():
		var ops := [{"t": "Rispondi «%s»" % ("Sì" if verita else "No"), "v": verita}]
		ops.append_array(intuizione.opzioni_risposta(c))
		if ops.size() > 1:
			var r := await chiedi(ASSASSINO, {"tipo": "risposta", "testo": "Il Detective chiede a %s: «%s» Il civile deve dire la verità, ma puoi giocare Ricatto." % [nome(c), Dati.domanda(q)["testo"]], "opzioni": ops, "civ": c, "q": q})
			if ops[r].has("ricatto"):
				muto = true
				await intuizione.gioca_ricatto()
	if muto:
		scrivi("%s non risponde alla domanda «%s» (Ricatto)." % [nome(c), Dati.domanda(q)["breve"]])
		return
	testimonianze.append({"civ": c, "q": q, "r": risposta, "round": round, "b": pos[c]})
	scrivi("%s: «%s» %s." % [nome(c), Dati.domanda(q)["testo"], "Sì" if risposta else "No"])
	evento.emit({"k": "risposta", "civ": c, "q": q, "r": risposta})


func _polizia(quartieri: Array) -> void:
	var ops := []
	for c in _civili_in(quartieri):
		ops.append({"t": "Sorveglia %s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
	if ops.is_empty():
		return
	cambiato.emit()
	var r := await chiedi(DETECTIVE, {"tipo": "polizia", "testo": "Comando di Polizia: su quale civile metti il segnalino Sorveglianza?", "opzioni": ops})
	await metti_sorveglianza(ops[r]["civ"])


func metti_sorveglianza(c: int) -> void:
	sorveglianza = c
	scrivi("Il segnalino Sorveglianza va su %s." % nome(c))
	if intuizione != null:
		await intuizione.dopo_sorveglianza_posata()


func _ristorante(quartieri: Array) -> void:
	var ops := []
	for c in _civili_in(quartieri):
		if not intim[c] and (intuizione == null or intuizione.interrogabile(c)):
			ops.append({"t": "Interroga %s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
	if ops.is_empty():
		return
	cambiato.emit()
	var r := await chiedi(DETECTIVE, {"tipo": "ristorante", "testo": "Ristorante: chi interroghi?", "opzioni": ops})
	await interroga(ops[r]["civ"])


func _ospedale(quartieri: Array) -> void:
	var ops := []
	for c in _civili_in(quartieri):
		if intim[c]:
			ops.append({"t": "Conforta %s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
	if ops.is_empty():
		return
	cambiato.emit()
	var r := await chiedi(DETECTIVE, {"tipo": "ospedale", "testo": "Ospedale: chi conforti?", "opzioni": ops})
	conforta(ops[r]["civ"])


func conforta(c: int) -> void:
	intim[c] = false
	scrivi("%s viene confortato e torna disponibile." % nome(c))


## La Sorveglianza: «Puoi uccidere questo civile adesso?». L'Assassino risponde sempre in modo onesto.
func usa_sorveglianza() -> void:
	var c := sorveglianza
	if c < 0:
		return
	if intuizione != null and await intuizione.reazione_sorveglianza():
		return
	c = sorveglianza
	if c < 0:
		return
	var s := foto()
	var r: bool = c != assassino and pos[c] != det and Regole.ammesso(movente, s, c, poi)
	sorveglianze.append({"civ": c, "r": r, "foto": s, "round": round})
	sorveglianza = -1
	scrivi("Sorveglianza su %s: «Puoi ucciderlo adesso?» %s." % [nome(c), "Sì" if r else "No"])
	evento.emit({"k": "sorveglianza", "civ": c, "r": r})


# ---------------------------------------------------------------------- fase della Città

func _fase_citta() -> void:
	fase = "citta"
	if intuizione != null:
		intuizione.inizio_fase_citta()
	for c in nel_quartiere(det):
		if intim[c]:
			conforta(c)
	cambiato.emit()
	await muovi_gruppo(ASSASSINO, false)
	if esito != "":
		return
	await muovi_gruppo(DETECTIVE, false)
	pila.append_array(_da_rimettere)
	_da_rimettere.clear()
	_mescola(pila)
	if intuizione != null:
		await intuizione.fine_fase_citta()
	cambiato.emit()


## Pesca una tessera dalla pila e muove i civili di quel gruppo (fase della Città e Caserma dei Pompieri).
func muovi_gruppo(posto: int, da_pompieri: bool) -> void:
	if pila.is_empty():
		return
	var i := rng.randi_range(0, pila.size() - 1)
	var g: String = pila[i]
	pila.remove_at(i)
	gruppi_rivelati[g] = true
	var chi := "L'Assassino" if posto == ASSASSINO else "Il Detective"
	scrivi("%s pesca la tessera %s." % [chi, Dati.nome_gruppo(g)])
	evento.emit({"k": "tessera", "gruppo": g, "posto": posto})
	var presenti := _del_gruppo(g)
	var tolta := false
	if presenti.is_empty():
		var ops := []
		for gg in Dati.d()["gruppi"]:
			if not _del_gruppo(gg["id"]).is_empty():
				ops.append({"t": gg["nome"], "gruppo": gg["id"]})
		if ops.is_empty():
			pila.append(g)
			return
		cambiato.emit()
		var r := await chiedi(posto, {"tipo": "gruppo_libero", "testo": "Nessun civile del gruppo %s è in città: scegli un altro gruppo da muovere. La tessera esce dal gioco." % Dati.nome_gruppo(g), "opzioni": ops})
		tolta = true
		scrivi("Nessun %s in città: la tessera esce dal gioco e si muove il gruppo %s." % [Dati.nome_gruppo(g), ops[r]["t"]])
		g = ops[r]["gruppo"]
		presenti = _del_gruppo(g)
	await muovi_civili(posto, presenti, "Gruppo %s" % Dati.nome_gruppo(g))
	if not tolta:
		if da_pompieri:
			pila.insert(rng.randi_range(0, pila.size()), g)
		else:
			_da_rimettere.append(g)

var _da_rimettere: Array = []


func _del_gruppo(g: String) -> Array:
	var out := []
	for c in vivi():
		if Dati.civile(c)["gruppo"] == g:
			out.append(c)
	return out


## Muove una volta, a scelta, ciascuno dei civili indicati verso un quartiere adiacente.
func muovi_civili(posto: int, quali: Array, titolo: String, passi := 1) -> void:
	var mossi := {}
	while true:
		var ops := []
		for c in quali:
			if pos[c] >= 0 and not mossi.has(c) and not _destinazioni(c, passi).is_empty():
				ops.append({"t": "Muovi %s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
		if ops.is_empty():
			break
		ops.append({"t": "Non muovere altri civili", "fine": true})
		cambiato.emit()
		var r := await chiedi(posto, {"tipo": "scegli_mossa", "testo": "%s: quale civile vuoi muovere?" % titolo, "opzioni": ops})
		if ops[r].get("fine", false):
			break
		var c: int = ops[r]["civ"]
		mossi[c] = true
		var dest := _destinazioni(c, passi)
		var dops := []
		for b in dest:
			dops.append({"t": Dati.quartiere(b), "b": b})
		cambiato.emit()
		var d := await chiedi(posto, {"tipo": "destinazione", "testo": "Dove muovi %s?" % nome(c), "opzioni": dops, "civ": c})
		pos[c] = dops[d]["b"]
		scrivi("%s si sposta a %s." % [nome(c), Dati.quartiere(pos[c])])
		evento.emit({"k": "mossa", "civ": c, "b": pos[c]})


## Quartieri raggiungibili da un civile con 1 (o fino a 2) passi.
func _destinazioni(c: int, passi := 1) -> Array:
	var da: int = pos[c]
	var out := []
	if intuizione != null and not intuizione.puo_uscire(da):
		return out
	for b in 16:
		var dist := Dati.distanza(da, b)
		if dist >= 1 and dist <= passi and puo_entrare(b):
			out.append(b)
	return out


# ---------------------------------------------------------------------- fine

func _accusa() -> void:
	fase = "accusa"
	var ops := []
	for c in vivi():
		ops.append({"t": "%s (%s)" % [nome(c), Dati.quartiere(pos[c])], "civ": c})
	cambiato.emit()
	var r := await chiedi(DETECTIVE, {"tipo": "accusa_civile", "testo": "Conclusioni: chi è l'Assassino?", "opzioni": ops})
	var c: int = ops[r]["civ"]
	var mops := []
	for mv in moventi:
		mops.append({"t": Dati.movente(mv)["nome"], "mov": mv})
	var rm := await chiedi(DETECTIVE, {"tipo": "accusa_movente", "testo": "E qual è il suo movente?", "opzioni": mops})
	var mv: String = mops[rm]["mov"]
	accusa = {"civ": c, "mov": mv}
	scrivi("Il Detective accusa %s, con il movente %s." % [nome(c), Dati.movente(mv)["nome"]])
	if c == assassino and mv == movente:
		_fine("detective", "Il Detective ha smascherato l'Assassino e il suo movente.")
	elif c == assassino:
		_fine("assassino", "Il Detective ha trovato l'Assassino ma ha sbagliato il movente.")
	elif mv == movente:
		_fine("assassino", "Il movente era giusto, ma l'Assassino era un altro.")
	else:
		_fine("assassino", "Il Detective ha sbagliato sia l'Assassino sia il movente.")


func _fine(chi: String, perche: String) -> void:
	esito = chi
	motivo_esito = perche
	scrivi("L'Assassino era %s, movente %s%s. %s" % [nome(assassino), Dati.movente(movente)["nome"],
		(", Persona Segnalata %s" % nome(poi)) if poi >= 0 else "", perche])
	evento.emit({"k": "fine", "esito": chi})
	cambiato.emit()


## Impronta della partita (per controllare che due dispositivi abbiano la stessa partita).
func impronta() -> String:
	return "%d|%s|%s|%s|%s" % [round, str(vittime), str(pos.hash()), esito, str(storia.size())]
