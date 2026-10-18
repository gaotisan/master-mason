"""Comprueba las traducciones de textos/*.csv: que cada frase tenga todos los
idiomas, que no haya claves repetidas y que los %s / %d / %% sean los mismos en
todos los idiomas. Uso: python textos/comprobar.py"""
import csv
import glob
import os
import re
import sys

MARCAS = re.compile(r"%[sd%]")
aqui = os.path.dirname(os.path.abspath(__file__))
fallos = 0
for ruta in sorted(glob.glob(os.path.join(aqui, "*.csv"))):
    with open(ruta, encoding="utf-8", newline="") as f:
        filas = list(csv.reader(f))
    nombre = os.path.basename(ruta)
    cabecera, filas = filas[0], filas[1:]
    if cabecera[0] != "keys":
        print(f"{nombre}: la primera columna tiene que llamarse 'keys'")
        fallos += 1
    idiomas = cabecera[1:]
    vistas = set()
    for n, fila in enumerate(filas, start=2):
        if not fila:
            continue
        clave = fila[0]
        if clave in vistas:
            print(f"{nombre}:{n} clave repetida: {clave}")
            fallos += 1
        vistas.add(clave)
        textos = dict(zip(idiomas, fila[1:]))
        for idioma in idiomas:
            if not textos.get(idioma, "").strip():
                print(f"{nombre}:{n} {clave}: falta '{idioma}'")
                fallos += 1
        marcas = {i: sorted(MARCAS.findall(t)) for i, t in textos.items()}
        if len({tuple(m) for m in marcas.values()}) > 1:
            print(f"{nombre}:{n} {clave}: los %s/%d no coinciden entre idiomas: {marcas}")
            fallos += 1
    print(f"{nombre}: {len(vistas)} frases, idiomas {', '.join(idiomas)}")
print("Todo bien." if fallos == 0 else f"{fallos} problemas.")
sys.exit(1 if fallos else 0)
