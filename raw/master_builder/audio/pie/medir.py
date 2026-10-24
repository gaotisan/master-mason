"""Mide cada recorte para elegir los del pie sin oirlos: limpio (snr), seco (cola),
un solo golpe (doble), y timbre parecido al resto de su grupo (dist, en bandas
de tercio de octava). -> medidas.json
    python medir.py
"""
import json, os
import numpy as np
from scipy.io import wavfile

AQUI = os.path.dirname(os.path.abspath(__file__))
SR = 48000
fichas = json.load(open(os.path.join(AQUI, "recortes.json")))
# bandas de tercio de octava de 63 Hz a 12,5 kHz
CENTROS = 1000 * 2 ** (np.arange(-12, 12) / 3)


def bandas(x):
    seg = x[:int(0.12 * SR)]
    seg = np.pad(seg, (0, max(0, int(0.12 * SR) - len(seg))))
    S = np.abs(np.fft.rfft(seg * np.hanning(len(seg)))) ** 2
    f = np.fft.rfftfreq(len(seg), 1 / SR)
    out = []
    for c in CENTROS:
        m = (f >= c / 2 ** (1 / 6)) & (f < c * 2 ** (1 / 6))
        out.append(10 * np.log10(S[m].sum() + 1e-12))
    out = np.array(out)
    return out - out.max()


for d in fichas:
    sr, x = wavfile.read(os.path.join(AQUI, "recortes", d["id"] + ".wav"))
    x = x.astype(np.float64) / 32768
    d["bandas"] = bandas(x).round(2).tolist()
    # doble: el mayor pico de la envolvente (5 ms) a mas de 60 ms del primero, relativo
    w = int(0.005 * SR)
    n = len(x) // w
    e = np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1))
    k0 = int(np.argmax(e[:max(1, int(0.04 / 0.005))]))
    resto = e[k0 + 12:]
    d["doble_db"] = round(float(20 * np.log10((resto.max() if len(resto) else 1e-9) / (e[k0] + 1e-12))), 1)
    d["ataque_ms"] = round(k0 * 5.0, 1)
    # centroide
    S = np.abs(np.fft.rfft(x[:int(0.1 * SR)]))
    f = np.fft.rfftfreq(min(len(x), int(0.1 * SR)), 1 / SR)
    d["centroide"] = int((S * f).sum() / S.sum())

for grupo in ("andar", "correr", "giro", "baculo"):
    g = [d for d in fichas if d["tipo"] == grupo]
    med = np.median([d["bandas"] for d in g], axis=0)
    for d in g:
        d["dist"] = round(float(np.sqrt(np.mean((np.array(d["bandas"]) - med) ** 2))), 2)

json.dump([{k: v for k, v in d.items() if k not in ("forma", "bandas")} | {"bandas": d["bandas"]} for d in fichas],
          open(os.path.join(AQUI, "medidas.json"), "w"), indent=0)
print("%-20s %5s %5s %6s %6s %5s %6s %s" % ("id", "snr", "cola", "doble", "dist", "cent", "nivel", "flojo"))
for d in fichas:
    if d["tipo"] in ("andar", "correr"):
        print("%-20s %5.1f %5s %6.1f %6.2f %5d %6.1f %s" % (d["id"], d["snr_db"], d["cola_s"], d["doble_db"], d["dist"], d["centroide"], d["nivel_db"], "f" if d["flojo"] else ""))
