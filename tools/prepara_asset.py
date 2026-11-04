#!/usr/bin/env python3
"""Ricava le immagini del gioco dalle scansioni italiane (Carte.pdf) e dal modulo Tabletop Simulator.

Uso: python3 tools/prepara_asset.py <cartella con hr-000.jpg ... (pdfimages di Carte.pdf)> <cartella Mods del modulo TTS> <json del modulo>
Le immagini finiscono in assets/. Serve solo quando cambiano le scansioni.
"""
import json, os, re, sys, glob
from PIL import Image, ImageOps

SCAN, MODS, JS = sys.argv[1], sys.argv[2], sys.argv[3]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets")


def salva(im, rel, w=None, q=88):
    p = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if w and im.width != w:
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    if p.endswith(".png"):
        im.save(p, optimize=True)
    else:
        im.convert("RGB").save(p, quality=q, method=6)


def rifila(im, soglia=228, margine=2):
    g = ImageOps.invert(im.convert("L")).point(lambda v: 255 if v > 255 - soglia else 0)
    box = g.getbbox()
    if not box:
        return im
    x0, y0, x1, y1 = box
    return im.crop((max(0, x0 + margine), max(0, y0 + margine), min(im.width, x1 - margine), min(im.height, y1 - margine)))


# --- civili: pagine 1-4, 2 colonne x 7 righe, carte ruotate ---
n = 0
for p, righe in [(0, 7), (1, 7), (2, 7), (3, 6)]:
    im = Image.open(os.path.join(SCAN, "hr-%03d.jpg" % p))
    H, W = 3340 / 7.0, 2476 / 2.0
    for c in range(2):
        for r in range(righe):
            cr = im.crop((int(c * W) + 4, int(r * H) + 4, int((c + 1) * W) - 4, int((r + 1) * H) - 4)).rotate(-90, expand=True)
            salva(cr, "civili/c%02d.webp" % n, 300)
            n += 1

# --- carte 3x3 nelle pagine 5-9 ---
GRIGLIA = {
    4: ["mov_rapinatore", "mov_estremista", "mov_sadico", "mov_cannibale", "mov_psicopatico", "mov_cultista", "mov_vigilante", "mov_tagliagole", "mov_maniaco"],
    5: ["mov_terrorista", "mov_killer", "mov_spia", "ass_rapimento", "ass_sciopero", "ass_manomettere", "ass_nascondersi", "ass_messaggio", None],
    6: [None, "ass_ricatto", "ass_testimoni", "ass_graffiti", "ass_bomba", "ass_corrompere", None, "ass_falsa", "det_cordone"],
    7: ["det_raddoppiare", "det_aiuto", "det_sequestro", None, "det_testimonianza", "det_copertura", "det_sesto", "det_profilazione", None],
    8: ["det_blitz", None, "det_coprifuoco", "det_confessione", "memo_logica", "memo_intuizione", "retro_detective", "retro_assassino", "retro_movente"],
}
for p, nomi in GRIGLIA.items():
    im = Image.open(os.path.join(SCAN, "hr-%03d.jpg" % p))
    W, H = 2080 / 3, 3170 / 3
    for i, nome in enumerate(nomi):
        if not nome:
            continue
        r, c = divmod(i, 3)
        cr = rifila(im.crop((int(c * W), int(r * H), int((c + 1) * W), int((r + 1) * H))))
        cartella = {"mov": "moventi", "ass": "assassino", "det": "detective", "memo": "varie", "retro": "varie"}[nome.split("_")[0]]
        salva(cr, "%s/%s.webp" % (cartella, nome.split("_", 1)[1]), 420)

# --- immagini del modulo TTS ---
d = json.load(open(JS))
files = {os.path.splitext(os.path.basename(f))[0]: f for f in glob.glob(os.path.join(MODS, "*", "*"))}


def tts(url):
    return Image.open(files[re.sub(r"[^A-Za-z0-9]", "", url)])


oggetti = {}
for o in d["ObjectStates"]:
    oggetti.setdefault(o.get("Nickname") or o["Name"], []).append(o)
tab = [o for o in oggetti["Custom_Tile"] if o["Transform"]["scaleX"] > 19][0]
salva(tts(tab["CustomImage"]["ImageURL"]), "tabellone.webp", 2048, 90)
for nick, nome in [("Police Station", "polizia"), ("Hospital", "ospedale"), ("Fire Station", "pompieri"), ("Diner", "ristorante")]:
    salva(tts(oggetti[nick][0]["CustomImage"]["ImageURL"]).convert("RGBA"), "edifici/%s.png" % nome, 220)
salva(tts(oggetti["Surveillance Token"][0]["CustomImage"]["ImageURL"]).convert("RGBA"), "segnalini/sorveglianza.png", 160)
salva(tts(oggetti["Detective Marker"][0]["CustomImage"]["ImageURL"]).convert("RGBA"), "segnalini/detective.png", 300)
scene = sorted([o for o in oggetti["CardCustom"]], key=lambda o: -o["Transform"]["posZ"])
for i, o in enumerate(scene):
    cd = list(o["CustomDeck"].values())[0]
    salva(tts(cd["FaceURL"]), "scene/scena%d.webp" % (i + 1), 200)
# prove (modalità Intuizione)
for o in oggetti["Evidence Tokens"][0]["ContainedObjects"]:
    nome = {"Hospital": "ospedale", "Police Station": "polizia", "Fire Station": "pompieri", "Diner": "ristorante"}[o["Nickname"]]
    salva(tts(o["CustomImage"]["ImageURL"]).convert("RGBA"), "prove/%s.png" % nome, 160)
    salva(tts(o["CustomImage"]["ImageSecondaryURL"]).convert("RGBA"), "prove/retro.png", 160)
# simboli dei gruppi sociali (parte alta delle tessere, senza la scritta inglese)
GRUPPI = {"LABOR": "lavoratori", "JET SET": "jetset", "IMMIGRANTS": "immigrati", "GOVERNMENT": "governo", "CRIMINALS": "criminali",
          "AUTHORITY": "autorita", "OUTCASTS": "emarginati", "MEDICINE": "medicina", "PRESS": "stampa"}
print("fatto: %d civili" % n)
ORDINE_SACCHETTO = ["stampa", "lavoratori", "jetset", "immigrati", "governo", "criminali", "autorita", "emarginati", "medicina"]
for o, nome in zip(oggetti["Social Group Tokens"][0]["ContainedObjects"], ORDINE_SACCHETTO):
    im = tts(o["CustomImage"]["ImageURL"]).convert("RGBA")
    w, h = im.size
    salva(im.crop((int(w * 0.05), int(h * 0.04), int(w * 0.95), int(h * 0.62))), "gruppi/%s.png" % nome, 200)
salva(tts(oggetti["Social Group Tokens"][0]["ContainedObjects"][0]["CustomImage"]["ImageSecondaryURL"]).convert("RGBA").resize((585, 289)), "gruppi/retro.png", 200)
print("gruppi fatti")
