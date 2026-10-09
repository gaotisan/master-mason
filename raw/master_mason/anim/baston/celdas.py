"""Lee resources/characters/magnus_frames.tres y reconstruye cada fotograma en
su casilla completa (la hoja va recortada: region + margin). Devuelve
{animacion: [RGBA numpy (alto, ancho, 4), ...]}."""
import re
from pathlib import Path
import numpy as np
from PIL import Image

PROY = Path(__file__).resolve().parents[4]
TRES = PROY / "resources/characters/magnus_frames.tres"


def _res_path(p):
    return PROY / p.replace("res://", "")


def cargar():
    txt = TRES.read_text(encoding="utf-8")
    tex = dict(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', txt)[::1])
    tex = {i: p for p, i in tex.items()}
    atlas = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*\n'
                         r'atlas = ExtResource\("([^"]+)"\)\s*\nregion = Rect2\(([^)]*)\)'
                         r'(?:\s*\nmargin = Rect2\(([^)]*)\))?', txt):
        sid, tid, reg, mar = m.groups()
        reg = [float(v) for v in reg.split(",")]
        mar = [float(v) for v in mar.split(",")] if mar else [0, 0, 0, 0]
        atlas[sid] = (tex[tid], reg, mar)
    anims = {}
    cuerpo = txt[txt.index("animations = ["):]
    for bloque in re.finditer(r'"frames": \[(.*?)\],\s*"loop": (true|false),\s*"name": &"([^"]+)",\s*"speed": ([0-9.]+)', cuerpo, re.S):
        frames, loop, nombre, speed = bloque.groups()
        ids = re.findall(r'SubResource\("([^"]+)"\)', frames)
        anims[nombre] = {"ids": ids, "loop": loop == "true", "speed": float(speed)}
    hojas = {}
    out = {}
    for nombre, a in anims.items():
        celdas = []
        for sid in a["ids"]:
            p, reg, mar = atlas[sid]
            if p not in hojas:
                hojas[p] = np.array(Image.open(_res_path(p)).convert("RGBA"))
            h = hojas[p]
            x, y, w, hh = map(int, reg)
            W, H = int(w + mar[2]), int(hh + mar[3])
            c = np.zeros((H, W, 4), np.uint8)
            c[int(mar[1]):int(mar[1]) + hh, int(mar[0]):int(mar[0]) + w] = h[y:y + hh, x:x + w]
            celdas.append(c)
        out[nombre] = {"celdas": celdas, **a}
    return out


if __name__ == "__main__":
    for n, a in cargar().items():
        print(n, len(a["celdas"]), a["celdas"][0].shape, a["loop"], a["speed"])
