"""Controlla che ogni carattere scritto negli script e nei dati esista nei font del gioco.

Uso: python3 tools/controlla_glifi.py   (esce con errore se trova caratteri che apparirebbero come quadratini)
"""
import glob, json, re, sys
from fontTools.ttLib import TTFont

TESTO = ["assets/font/Oswald.ttf", "assets/font/SpecialElite-Regular.ttf"]
TITOLI = ["assets/font/BebasNeue-Regular.ttf"]
cm_testo = [set(TTFont(f).getBestCmap().keys()) for f in TESTO]
cm_titoli = [set(TTFont(f).getBestCmap().keys()) for f in TITOLI]
bad = {}


def controlla(testo, dove, cmaps):
    for ch in testo:
        if ch in "\n\t":
            continue
        for cm in cmaps:
            if ord(ch) not in cm:
                bad.setdefault(ch, []).append(dove)
                break


for f in glob.glob("scripts/**/*.gd", recursive=True):
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        code = line.split("#", 1)[0] if not line.lstrip().startswith("##") else ""
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
            # i titoli usano Bebas Neue: controlla anche quello
            controlla(s, "%s:%d" % (f, n), cm_testo + cm_titoli)
# testi lunghi su più righe (regole)
for f in glob.glob("scripts/**/*.gd", recursive=True):
    src = open(f, encoding="utf-8").read()
    for s in re.findall(r'"""(.*?)"""', src, re.S):
        controlla(re.sub(r"\[[^\]]*\]", "", s), f + " (testo lungo)", cm_testo)

def tutte(x, dove):
    if isinstance(x, str):
        controlla(x, dove, cm_testo + cm_titoli)
    elif isinstance(x, dict):
        for k, v in x.items():
            tutte(v, dove + "/" + str(k))
    elif isinstance(x, list):
        for i, v in enumerate(x):
            tutte(v, dove + "/" + str(i))
for f in glob.glob("data/*.json"):
    tutte(json.load(open(f, encoding="utf-8")), f)
for ch, where in bad.items():
    print("MANCA %r U+%04X: %s" % (ch, ord(ch), ", ".join(sorted(set(where))[:5])))
print("glifi ok" if not bad else "%d caratteri non disponibili" % len(bad))
sys.exit(1 if bad else 0)
