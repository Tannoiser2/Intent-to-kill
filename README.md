# Intent to Kill — versione digitale

Versione digitale in Godot 4.7 di **Intent to Kill** (Artur Khodzhikov, Hobby World 2023; in Italia Ghenos Games), il gioco di deduzione noir in cui un Assassino si nasconde fra i civili della città e un Detective deve scoprire chi è e qual è il suo movente prima del quinto omicidio.

Si gioca nel browser: https://tannoiser2.github.io/Intent-to-Kill/

## Cosa c'è

- **Modalità Logica** completa: 20 civili su 54, Assassino, Persona Segnalata e Sostenitori segreti, intimidazioni, omicidi secondo il movente, rinuncia all'omicidio (una sola volta), risposta iniziale, interrogatori con le 11 domande, i quattro edifici (Comando di Polizia, Ristorante, Ospedale, Caserma dei Pompieri), Sorveglianza, fase della Città con la pila dei gruppi sociali, accusa finale o anticipata dal terzo round.
- **Modalità Intuizione**: 14 carte Assassino (2 sotto ogni Scena del Crimine), 14 carte Detective con le 3 disponibili e la carta conservata, 24 prove, ispezione della Scena del Crimine, verifica delle prove, simbolo del revolver, Sesto senso e Corrompere la polizia come reazioni, 8 moventi.
- **I 12 moventi** con tutte le precisazioni del regolamento (Cannibale, Estremista, Cultista con la Persona Segnalata, Rapinatore, ecc.).
- **IA per entrambi i ruoli**: l'Assassino sceglie vittime che lasciano aperti più moventi, intimidisce i testimoni sinceri vicini alla prossima Scena del Crimine e fa mentire i complici in modo coerente; il Detective ragiona solo sulle informazioni pubbliche, pesando tutte le ipotesi compatibili (Assassino, Sostenitori, Persona Segnalata, movente) e scegliendo domande e azioni che le dividono meglio.
- **Materiale dell'edizione italiana**: carte Civile, moventi, carte Assassino e Detective dalle scansioni; tabellone, edifici, prove e segnalini dal modulo Tabletop Simulator. Promemoria delle fasi in italiano sopra il tabellone.
- **Interfaccia noir**: dossier segreto dell'Assassino (identità, Persona Segnalata, Sostenitori, movente, vittime possibili, carte in mano), taccuino del Detective (testimonianze per civile, Sorveglianze, gruppi sicuramente sinceri, vittime), moventi da segnare come esclusi, rapporto di polizia, anteprima ingrandita delle carte, bersagli cliccabili sul tabellone.
- **Firebase**: partite online Assassino contro Detective (stanza con codice di 4 lettere; se l'avversario sparisce gioca l'IA), salvataggi riprendibili da qualsiasi dispositivo; sul dispositivo la partita si salva comunque da sola.

## Struttura

- `data/gioco.json` — i 54 civili (nome italiano, gruppo, sesso, età, corporatura, altezza: ogni combinazione compare una sola volta), gruppi sociali, moventi, quartieri, edifici, domande
- `scripts/core/` — motore (`motore.gd`), condizioni dei moventi (`regole.gd`), modalità Intuizione (`intuizione.gd`), IA (`ia.gd`), dati
- `scripts/ui/` — menu, schermata di gioco, tabellone, regole
- `scripts/net/` — Firebase (radice `intenttokill/rooms` nel progetto condiviso)
- `assets/` — immagini (ricavate con `tools/prepara_asset.py`), font Bebas Neue, Oswald, Special Elite (licenza OFL)
- `tests/` — partite automatiche, ripresa dei salvataggi, prova online con il finto Firebase, fotografie dell'interfaccia
- `ludoteca/` — scheda e copertina per la pagina della ludoteca

## Prove

```
godot --headless --path . -s tests/sim.gd -- 60 logica          # partite IA contro IA
godot --headless --path . -s tests/sim.gd -- 60 intuizione
godot --headless --path . -s tests/ripresa.gd                   # salvataggi: ripresa identica
python3 tools/controlla_glifi.py                                 # nessun carattere mancante nei font
xvfb-run godot --path . --rendering-driver opengl3 -s tests/foto.gd -- /tmp/foto logica 1
```

Prova online in locale: `python3 tests/firebase_mock.py 8765`, poi due istanze di `tests/online_play.gd` con `PL_ROLE=host` e `PL_ROLE=guest` (vedi l'intestazione del file).

## Pubblicazione

Solo su richiesta: Actions » Pubblica » Run workflow, oppure un commit con `[pubblica]` nel messaggio. Il workflow esporta la versione web e la pubblica su GitHub Pages (e sulla ludoteca privata Cloudflare se ci sono i segreti `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`).

## Note

- Nel gioco online i due dispositivi fanno girare lo stesso motore: anche quello del Detective «conosce» i segreti dell'Assassino, ma l'interfaccia non li mostra mai.
- La Bomba artigianale sceglie da sola come vittima vera un civile del quartiere che rispetta il movente.
- Gli scenari del regolamento (T-Men, D.O.A. e gli altri) non sono ancora inclusi; gli edifici si possono disporre come nel regolamento o a caso.
