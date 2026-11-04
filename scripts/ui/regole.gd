extends Control
## Le regole del gioco in breve (modalità Logica e Intuizione).

var main
var sovrapposto := false

const TESTO := """[font_size=30][color=#bf1f1c]SCOPO DEL GIOCO[/color][/font_size]
Un giocatore è l'[b]Assassino[/b], l'altro il [b]Detective[/b]. L'Assassino si nasconde fra i 20 civili della città e deve uccidere cinque volte rispettando il suo [b]movente[/b] senza farsi scoprire. Il Detective vince se alla fine indica sia il civile che è l'Assassino sia il suo movente: basta un solo errore e vince l'Assassino.

[font_size=30][color=#bf1f1c]PREPARAZIONE[/color][/font_size]
Si scelgono 20 civili a caso fra i 54. L'Assassino pesca in segreto il civile che impersona, la [b]Persona Segnalata[/b] e il movente fra quelli in gioco (6 in Logica, 8 in Intuizione). Poi pesca 3 tessere dei gruppi sociali e ne tiene una: sono i suoi [b]Sostenitori[/b]. Le altre 6 tessere formano la pila dei gruppi sociali. Il Detective colloca il suo segnalino in un quartiere a scelta.

[font_size=30][color=#bf1f1c]CHI PUÒ MENTIRE[/color][/font_size]
Quando il Detective interroga un civile, l'Assassino risponde al suo posto con un «sì» o un «no». Deve dire la verità, tranne quando il civile è l'Assassino stesso, la Persona Segnalata o uno dei Sostenitori: in quei casi può mentire (ma non è obbligato).

[font_size=30][color=#bf1f1c]IL ROUND[/color][/font_size]
[b]1. Fase dell'Assassino.[/b] Intimidisce 2 civili (non nel quartiere del Detective): girati in bianco e nero, non possono essere interrogati. Poi uccide una vittima che rispetti il movente, che non si trovi nel quartiere del Detective e che non sia lui stesso. La carta Scena del Crimine finisce nel quartiere della vittima, che va nell'area delle Vittime. Una volta per partita si può rinunciare a uccidere: la partita dura un round in più. Alla seconda rinuncia l'Assassino perde.
[b]2. Fase del Detective.[/b] Risposta iniziale: il Detective corre sulla nuova Scena del Crimine e sposta nei quartieri adiacenti i civili che vi si trovano (nessun quartiere può avere più di 3 civili e nessuno entra in una Scena del Crimine). Poi indaga: [b]2 azioni diverse[/b] e [b]2 punti movimento[/b], da spendere prima, fra o dopo le azioni.
- Interrogare i civili: una domanda a ciascun civile non intimidito del proprio quartiere.
- Comando di Polizia: colloca il segnalino Sorveglianza su un civile di questo quartiere o di uno adiacente.
- Ristorante: interroga un civile non intimidito di questo quartiere o di uno adiacente.
- Ospedale: conforta un civile intimidito di questo quartiere o di uno adiacente.
- Caserma dei Pompieri: pesca una tessera dalla pila e muovi i civili di quel gruppo.
La [b]Sorveglianza[/b] è gratuita: si toglie il segnalino e si chiede «Puoi uccidere questo civile adesso?». L'Assassino risponde sempre onestamente secondo il movente (e risponde «no» se il civile è lui stesso o è nel quartiere del Detective).
[b]3. Fase della Città.[/b] I civili intimiditi nel quartiere del Detective vengono confortati. L'Assassino e poi il Detective pescano una tessera dalla pila e possono muovere di un quartiere ogni civile di quel gruppo. Le tessere pescate mostrano gruppi che [b]non[/b] sono i Sostenitori.

[font_size=30][color=#bf1f1c]FINE DELLA PARTITA[/color][/font_size]
Si finisce il round del quinto omicidio; poi il Detective nomina l'Assassino e il movente. Dal terzo round il Detective può anche accusare in anticipo.

[font_size=30][color=#bf1f1c]I MOVENTI[/color][/font_size]
[b]Maniaco[/b]: tutte le vittime dello stesso sesso. [b]Psicopatico[/b]: vittime al massimo di due età diverse. [b]Sadico[/b]: non uccide civili intimiditi. [b]Tagliagole[/b]: non uccide nei 4 quartieri centrali. [b]Vigilante[/b]: non uccide negli 8 quartieri intorno al Detective. [b]Killer[/b]: uccide solo civili soli nel quartiere. [b]Terrorista[/b]: vittime tutte di gruppi diversi. [b]Spia[/b]: uccide solo in quartieri con edifici. [b]Rapinatore[/b]: non uccide accanto all'ultima Scena del Crimine. [b]Cannibale[/b]: tra le vittime devono esserci tutte e tre le corporature. [b]Estremista[/b]: almeno 3 vittime dello stesso gruppo. [b]Cultista[/b]: ogni vittima di un gruppo diverso dalla precedente (la prima diverso da quello della Persona Segnalata) e deve uccidere la Persona Segnalata (non nel primo round; se ci sono già 4 vittime, deve essere lei).

[font_size=30][color=#bf1f1c]MODALITÀ INTUIZIONE[/color][/font_size]
Sotto ogni Scena del Crimine ci sono 2 carte Assassino: dopo l'omicidio l'Assassino ne tiene una. Il Detective riceve una prova a ogni omicidio e può ispezionare la Scena del Crimine (azione: pesca 2 prove e ne tiene una). Una prova con il simbolo di un edificio presente nel proprio quartiere si scambia (azione gratuita) con una delle 3 carte Detective disponibili o con la prima del mazzo. Il Detective può tenere da parte una sola carta. Le carte con il simbolo del revolver danno all'avversario una prova (carte Assassino) o una carta Assassino (carte Detective). Nella fase della Città si rinnovano le carte Detective disponibili.

[font_size=30][color=#bf1f1c]COMANDI[/color][/font_size]
Le scelte si fanno con i pulsanti del pannello a destra oppure cliccando sul tabellone: i quartieri e i civili selezionabili si illuminano. Passando sopra una carta la si vede ingrandita con le sue caratteristiche e le risposte che ha dato. F11: schermo intero.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sovrapposto:
		var velo := ColorRect.new()
		velo.color = Color(0, 0, 0, 0.75)
		velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(velo)
	var vp := get_viewport_rect().size
	var p := UI.foglio()
	p.position = Vector2(vp.x * 0.14, 40)
	p.size = Vector2(vp.x * 0.72, vp.y - 80)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := UI.titolo("REGOLE DI INTENT TO KILL", 44, UI.INCHIOSTRO)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var b := UI.bottone("Chiudi" if sovrapposto else "Torna al menu", 20)
	b.pressed.connect(func():
		if sovrapposto:
			queue_free()
		else:
			main.show_menu())
	h.add_child(b)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("default_color", UI.INCHIOSTRO)
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 19)
	r.add_theme_font_override("bold_font", UI.f_titoli)
	r.text = TESTO
	v.add_child(r)
