"""La pagina de escucha (escucha.html) con los datos de recortes.json; se publica
como artifact con escucha/*.mp3 al lado. Las marcas (vale / fuera / duda) van a
su base de datos, coleccion "marcas", un documento por recorte.
    python pagina.py
"""
import json
import os

from recortar import VIDEOS

AQUI = os.path.dirname(os.path.abspath(__file__))
datos = json.load(open(os.path.join(AQUI, "recortes.json")))
for d in datos:
    for k in ("archivo", "que", "t", "dur", "pico_db", "nivel_db"):
        if k != "t":
            d.pop(k, None)
videos = {k: dict(vista=v[2], tipo=v[1], que=v[3][0].upper() + v[3][1:]) for k, v in VIDEOS.items()}
t = open(os.path.join(AQUI, "pagina.html.tpl"), encoding="utf-8").read()
t = t.replace("/*DATOS*/", json.dumps(datos, separators=(",", ":")))
t = t.replace("/*VIDEOS*/", json.dumps(videos, separators=(",", ":"), ensure_ascii=False))
open(os.path.join(AQUI, "escucha.html"), "w", encoding="utf-8").write(t)
print(len(datos), "recortes,", len(t) // 1024, "KiB")
