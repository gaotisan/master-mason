"""Elige los golpes de la capa del PIE y los deja listos para el juego.

El usuario no podia juzgarlos de oido (muy cortos, sin contexto), asi que se
eligen por medidas (medidas.json, de medir.py):

  familia   los videos cuyo timbre es el de la mayoria: cuerpo en los medios
            (600-1600 Hz), como las pisadas de perfil que ya sonaban. Fuera los
            de golpe sordo grave (perfil_correr, frente_seq_cb) y los de golpe
            grave con siseo (correr_frente, vuelta_sb): mezclados, unas pisadas
            sonarian a otro suelo.
  limpio    snr_db: el golpe muy por encima del ruido del video.
  seco      cola_s corta: sin eco de sala (la sala la pone cada escena).
  uno       doble_db bajo: un solo golpe dentro del recorte.
  parecido  dist: bandas de tercio de octava cerca de la mediana de su familia.
  repartido como mucho POR_VIDEO de cada video, para que no suene a una toma.

Proceso: paso alto a 60 Hz, empieza 2 ms antes del ataque, acaba cuando la
envolvente cae 35 dB (o a LARGO_MAX), fundidos de 1 y 40 ms, y el nivel de las
pisadas de antes medido en los 80 ms desde el ataque (andar -26,5 dBFS como
peregrino_paso_a/b; correr -24 como peregrino_paso_correr_a/b), con el pico a
-3 dBFS como mucho. Asi las mezclas ya afinadas (hojarasca) no se mueven.

    python elegir.py
Escribe assets/audio/pie/pie_<andar|correr>_NN.wav, resources/audio/pie_andar.tres
y pie_correr.tres (AudioStreamRandomizer) y seleccion.json aqui.
"""
import json
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfiltfilt

AQUI = os.path.dirname(os.path.abspath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, "..", "..", "..", ".."))
SALIDA = os.path.join(PROY, "assets", "audio", "pie")
RECURSOS = os.path.join(PROY, "resources", "audio")
SR = 48000

GRUPOS = {
    "andar": dict(videos=["perfil_andar", "frente_seq_sb", "espalda_andar_sb", "diag_ida_a", "diag_ida_b", "diag_vuelta"],
                  snr=24.0, cola=0.16, doble=-4.0, dist=3.5, n=12, rms=-26.5, largo=0.35),
    "correr": dict(videos=["correr_espalda", "diag_correr"],
                   snr=20.0, cola=0.17, doble=-6.0, dist=4.0, n=12, rms=-24.0, largo=0.30),
}
POR_VIDEO = 4
PICO_MAX = -3.0


def elegir(medidas, g):
    cand = [d for d in medidas if d["video"] in g["videos"] and not d["flojo"] and d["fotograma"] >= 3]
    med = np.median([d["bandas"] for d in cand], axis=0)
    for d in cand:
        d["dist_f"] = float(np.sqrt(np.mean((np.array(d["bandas"]) - med) ** 2)))
    vale = [d for d in cand if d["snr_db"] >= g["snr"] and d["cola_s"] is not None and d["cola_s"] <= g["cola"]
            and d["doble_db"] <= g["doble"] and d["dist_f"] <= g["dist"]]
    for d in vale:
        d["nota"] = d["snr_db"] - 40.0 * d["cola_s"] - 3.0 * d["dist_f"]
    vale.sort(key=lambda d: -d["nota"])
    por_video = {v: max(POR_VIDEO, -(-g["n"] // len(g["videos"]))) for v in g["videos"]}
    out, cuenta = [], {}
    for d in vale:
        if cuenta.get(d["video"], 0) < por_video[d["video"]]:
            out.append(d)
            cuenta[d["video"]] = cuenta.get(d["video"], 0) + 1
        if len(out) == g["n"]:
            break
    return out, len(cand), len(vale)


def env_db(x, hop):
    w = int(hop * SR)
    n = len(x) // w
    return 20 * np.log10(np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1)) + 1e-9)


def procesar(ident, g):
    _, x = wavfile.read(os.path.join(AQUI, "recortes", ident + ".wav"))
    x = x.astype(np.float64) / 32768
    x = sosfiltfilt(butter(2, 60, btype="high", fs=SR, output="sos"), x)
    # ataque: primer instante (envolvente de 1 ms) a mas del 20 % del pico de los 30 primeros ms
    w = int(0.001 * SR)
    en = np.convolve(np.abs(x[:int(0.03 * SR)]), np.ones(w) / w, "same")
    a = int(np.argmax(en > 0.2 * en.max()))
    x = x[max(a - int(0.002 * SR), 0):]
    e = env_db(x, 0.005)
    kp = int(np.argmax(e))
    bajo = np.nonzero(e[kp:] < e[kp] - 35.0)[0]
    fin = int((kp + (bajo[0] if len(bajo) else len(e) - kp)) * 0.005 * SR)
    fin = min(max(fin, int(0.12 * SR)), int(g["largo"] * SR), len(x))
    x = x[:fin].copy()
    x[:w] *= np.linspace(0, 1, w)
    nf = min(int(0.04 * SR), len(x) // 3)
    x[-nf:] *= np.linspace(1, 0, nf) ** 2
    rms = 20 * np.log10(np.sqrt((x[:int(0.08 * SR)] ** 2).mean()) + 1e-12)
    gan = g["rms"] - rms
    pico = 20 * np.log10(np.abs(x).max()) + gan
    if pico > PICO_MAX:
        gan -= pico - PICO_MAX
    x *= 10 ** (gan / 20)
    return x, round(rms + gan, 1), round(20 * np.log10(np.abs(x).max()), 1), round(len(x) / SR, 3)


def tres(nombre, archivos):
    lineas = ['[gd_resource type="AudioStreamRandomizer" load_steps=%d format=3]' % (len(archivos) + 1), ""]
    for i, f in enumerate(archivos):
        lineas.append('[ext_resource type="AudioStream" path="res://assets/audio/pie/%s" id="%d"]' % (f, i + 1))
    lineas += ["", "[resource]", "random_pitch = 1.05", "random_volume_offset_db = 1.5",
               "streams_count = %d" % len(archivos)]
    for i in range(len(archivos)):
        lineas += ['stream_%d/stream = ExtResource("%d")' % (i, i + 1), "stream_%d/weight = 1.0" % i]
    open(os.path.join(RECURSOS, nombre + ".tres"), "w", encoding="utf-8", newline="\n").write("\n".join(lineas) + "\n")


def main():
    medidas = json.load(open(os.path.join(AQUI, "medidas.json")))
    os.makedirs(SALIDA, exist_ok=True)
    os.makedirs(RECURSOS, exist_ok=True)
    for f in os.listdir(SALIDA):
        if f.endswith(".wav"):
            os.remove(os.path.join(SALIDA, f))
    sel = {}
    for grupo, g in GRUPOS.items():
        elegidos, n_cand, n_vale = elegir(medidas, g)
        print("%s: %d candidatos, %d pasan, %d elegidos" % (grupo, n_cand, n_vale, len(elegidos)))
        archivos = []
        for i, d in enumerate(elegidos, 1):
            x, rms, pico, dur = procesar(d["id"], g)
            nombre = "pie_%s_%02d.wav" % (grupo, i)
            wavfile.write(os.path.join(SALIDA, nombre), SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
            archivos.append(nombre)
            print("  %-16s <- %-20s snr %4.1f cola %.2f dist %.2f  -> rms %5.1f pico %5.1f %.2f s"
                  % (nombre, d["id"], d["snr_db"], d["cola_s"], d["dist_f"], rms, pico, dur))
            sel.setdefault(grupo, []).append(dict(archivo=nombre, recorte=d["id"], video=d["video"],
                                                 fotograma=d["fotograma"], snr_db=d["snr_db"], cola_s=d["cola_s"],
                                                 dist=round(d["dist_f"], 2), rms=rms, pico=pico, dur=dur))
        tres("pie_" + grupo, archivos)
    json.dump(sel, open(os.path.join(AQUI, "seleccion.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
