"""La capa del PIE de las pisadas: cada golpe suelto del audio de los videos del
peregrino (perfil, frente, diagonal), recortado para escucharlo y elegir.

Los videos de Veo/Flow traen audio sincronizado con la imagen; en los de andar y
correr, un golpe limpio por pisada con el fondo casi en silencio, y todos con el
mismo timbre (paso blando sobre suelo duro, sin hojas). Juntos dan una biblioteca
de pasos del mismo peregrino; el suelo (hojas, tierra, madera) va en otra capa.

    python recortar.py

Escribe:
  recortes/<id>.wav    el golpe a su nivel original (48 kHz, mono, 16 bit), desde
                       5 ms antes del ataque hasta que se apaga o llega el siguiente
  escucha/<id>.mp3     el mismo, normalizado a -3 dBFS de pico (para comparar)
  recortes.json        id, video, tipo, fotograma del video (24 fps, desde 1, el
                       del ataque), tiempo, duracion, pico y nivel originales,
                       snr_db (el golpe sobre el ruido de fondo del video: los hay
                       con un siseo continuo a -55 dB) y cola_s (lo que tarda en
                       bajar 20 dB: las secuencias de frente traen eco de sala)
  golpes.png           cada video con su envolvente y los golpes detectados
"""
import json
import os
import subprocess

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfiltfilt

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", "..", "..", ".."))
FFMPEG = os.path.join(RAIZ, "tools", "ffmpeg", "bin", "ffmpeg.exe")
FUENTES = os.path.join(RAIZ, "raw", "master_builder", "anim", "_fuentes")
# lo que no esta en _fuentes (tomas descartadas del diagonal), en las descargas
DESCARGAS = os.path.join(os.path.expanduser("~"), "Downloads", "peregrino_diagonal")
RECORTES = os.path.join(AQUI, "recortes")
ESCUCHA = os.path.join(AQUI, "escucha")
SR = 48000

# clave -> (video, tipo, de donde, que es)
VIDEOS = {
    "perfil_andar": ("peregrino_andando_con_parada a pose side.mp4", "andar", "perfil", "andar de perfil con parada"),
    "perfil_correr": ("peregrino_corriendo.mp4", "correr", "perfil", "correr de perfil"),
    "frente_seq_cb": ("Pilgrim_walking_turning_full_20261008161217.mp4", "andar", "frente", "secuencia con baculo: andar de frente, vuelta, de espaldas"),
    "frente_seq_sb": ("Pilgrim_walking_animation_sequence_20261008164615.mp4", "andar", "frente", "secuencia sin baculo"),
    "espalda_andar_sb": ("Old_pilgrim_walking_away_20261012112519.mp4", "andar", "frente", "andar de espaldas sin baculo (v3)"),
    "vuelta_sb": ("Pilgrim_turns_around_on_green_20261012094345.mp4", "giro", "frente", "vuelta sin baculo (v2)"),
    "correr_frente": ("Old_pilgrim_running_toward_camera_20261012094716.mp4", "correr", "frente", "correr hacia la camara"),
    "correr_espalda": ("Old_man_running_on_green_20261012112604.mp4", "correr", "frente", "correr de espaldas (v2)"),
    "sacar_frente": ("Pilgrim_draws_wooden_staff_20261009165324.mp4", "baculo", "frente", "sacar el baculo de frente"),
    "guardar_frente": ("Pilgrim_stowing_wooden_staff_20261009165938.mp4", "baculo", "frente", "guardar el baculo de frente"),
    "sacar_espalda": ("Pilgrim_drawing_staff_on_green_20261011153220.mp4", "baculo", "frente", "sacar el baculo de espaldas (v2)"),
    "guardar_espalda": ("Character_slinging_staff_animation_20261011153608.mp4", "baculo", "frente", "guardar el baculo de espaldas (a)"),
    "diag_ida_a": ("Pilgrim_walking_on_green_background_20261019101254.mp4", "andar", "diagonal", "diagonal 01, andar de ida (toma a)"),
    "diag_ida_b": ("Pilgrim_walking_away_from_camera_20261019102353.mp4", "andar", "diagonal", "diagonal 01, andar de ida (toma b)"),
    "diag_vuelta": ("Old_pilgrim_walking_toward_camera_20261019111933.mp4", "andar", "diagonal", "diagonal 02, andar de vuelta"),
    "diag_correr": ("Pilgrim_running_on_green_screen_20261019130829.mp4", "correr", "diagonal", "diagonal 03, correr alejandose"),
}

HOP = 0.005          # s, paso de la envolvente
MIN_ENTRE = 0.14     # s, dos golpes a menos son el mismo
LARGO_MAX = 0.55     # s
SUBIDA_DB = 9.0      # cuanto sube sobre el minimo de los 40 ms anteriores
SOBRE_SUELO_DB = 16.0
FLOJO_DB = 12.0      # a mas de esto bajo los golpes fuertes del video: "flojo" (roce, talon)
FUERA_DB = 24.0      # a mas de esto, ni se recorta


def ruta(video):
    p = os.path.join(FUENTES, video)
    if os.path.exists(p):
        return p
    for d, _, fs in os.walk(DESCARGAS):
        if video in fs:
            return os.path.join(d, video)
    raise FileNotFoundError(video)


def extrae(video):
    r = subprocess.run([FFMPEG, "-v", "error", "-i", ruta(video), "-vn", "-ac", "1",
                        "-ar", str(SR), "-f", "s16le", "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, np.int16).astype(np.float64) / 32768


def envolvente_db(x, hop):
    w = int(hop * SR)
    n = len(x) // w
    return 20 * np.log10(np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1)) + 1e-9)


def golpes(x):
    """Ataques (s): la envolvente (paso alto a 120 Hz, 5 ms) sube SUBIDA_DB sobre lo
    de antes y queda SOBRE_SUELO_DB por encima del suelo del video."""
    xh = sosfiltfilt(butter(2, 120, btype="high", fs=SR, output="sos"), x)
    e = envolvente_db(xh, HOP)
    suelo = np.percentile(e, 20)
    atras = int(0.04 / HOP)
    out = []
    for k in range(atras, len(e)):
        if e[k] < suelo + SOBRE_SUELO_DB or e[k] - e[k - atras:k].min() < SUBIDA_DB:
            continue
        if out and k * HOP - out[-1][0] < MIN_ENTRE:
            continue
        # el ataque fino: primer instante (envolvente de 1 ms) a mas del 20 % del pico local
        a, b = int((k * HOP - 0.02) * SR), int((k * HOP + 0.03) * SR)
        seg = np.abs(xh[max(a, 0):b])
        w = int(0.001 * SR)
        en = np.convolve(seg, np.ones(w) / w, "same")
        t = (max(a, 0) + int(np.argmax(en > 0.2 * en.max()))) / SR
        out.append((t, float(e[k:k + int(0.04 / HOP)].max())))
    if not out:
        return [], [], e, suelo, []
    fuerte = np.percentile([p for _, p in out], 90)
    out = [(t, p) for t, p in out if p > fuerte - FUERA_DB]
    activo = e[e > -95.0]
    fondo = float(np.median(activo)) if len(activo) else suelo
    return [t for t, _ in out], [p < fuerte - FLOJO_DB for _, p in out], e, suelo, [p - fondo for _, p in out]


def main():
    os.makedirs(RECORTES, exist_ok=True)
    os.makedirs(ESCUCHA, exist_ok=True)
    fichas = []
    graficas = []
    for clave, (video, tipo, vista, que) in VIDEOS.items():
        x = extrae(video)
        ts, flojos, e, suelo, snrs = golpes(x)
        graficas.append((clave, e, suelo, ts))
        for i, t in enumerate(ts):
            ini = max(int((t - 0.005) * SR), 0)
            fin_max = int((ts[i + 1] - 0.01) * SR) if i + 1 < len(ts) else len(x)
            fin = min(int((t + LARGO_MAX) * SR), fin_max)
            seg = x[ini:fin].copy()
            # cola: hasta que la envolvente de 10 ms cae a 3 dB del suelo
            ee = envolvente_db(seg, 0.01)
            sobre = np.nonzero(ee > suelo + 3.0)[0]
            if len(sobre):
                seg = seg[:max(min(len(seg), int((sobre.max() + 2) * 0.01 * SR)), int(0.08 * SR))]
            nf = min(int(0.03 * SR), len(seg) // 3)
            seg[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
            seg[-nf:] *= np.linspace(1, 0, nf) ** 2
            pico = float(np.abs(seg).max())
            nivel = float(20 * np.log10(np.sqrt((seg[:int(0.15 * SR)] ** 2).mean()) + 1e-9))
            ident = "%s_%02d" % (clave, i + 1)
            # cola: desde el pico (envolvente de 10 ms) hasta 20 dB por debajo
            ec = envolvente_db(seg, 0.01)
            kp = int(np.argmax(ec))
            bajo = np.nonzero(ec[kp:] < ec[kp] - 20.0)[0]
            cola = round(float(bajo[0]) * 0.01, 2) if len(bajo) else None
            wavfile.write(os.path.join(RECORTES, ident + ".wav"), SR, (seg * 32767).astype(np.int16))
            norm = seg * (10 ** (-3 / 20) / max(pico, 1e-6))
            tmp = os.path.join(ESCUCHA, ident + ".tmp.wav")
            wavfile.write(tmp, SR, (norm * 32767).astype(np.int16))
            subprocess.run([FFMPEG, "-v", "error", "-y", "-i", tmp, "-c:a", "libmp3lame", "-b:a", "96k",
                            os.path.join(ESCUCHA, ident + ".mp3")], check=True)
            os.remove(tmp)
            # forma de onda para la pagina: 48 picos
            n = 48
            bloques = np.array_split(np.abs(norm), n)
            forma = [round(float(b.max()) if len(b) else 0.0, 3) for b in bloques]
            fichas.append(dict(id=ident, video=clave, archivo=video, tipo=tipo, vista=vista, que=que,
                               fotograma=int(t * 24) + 1, flojo=bool(flojos[i]),
                               snr_db=round(snrs[i], 1), cola_s=cola, t=round(t, 3), dur=round(len(seg) / SR, 3),
                               pico_db=round(20 * np.log10(pico + 1e-9), 1), nivel_db=round(nivel, 1),
                               forma=forma))
        print("%-18s %2d golpes  %s" % (clave, len(ts), ["%d%s" % (int(t * 24) + 1, "f" if f else "") for t, f in zip(ts, flojos)]))
    json.dump(fichas, open(os.path.join(AQUI, "recortes.json"), "w"), indent=1)
    print(len(fichas), "recortes")

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axs = plt.subplots(len(graficas), 1, figsize=(16, 1.6 * len(graficas)), sharex=True)
    for ax, (clave, e, suelo, ts) in zip(axs, graficas):
        ax.plot(np.arange(len(e)) * HOP, e, lw=0.6)
        ax.axhline(suelo + SOBRE_SUELO_DB, color="r", lw=0.5)
        for t in ts:
            ax.axvline(t, color="g", lw=0.8)
        ax.set_ylabel(clave, rotation=0, ha="right", fontsize=8)
    axs[-1].set_xlabel("s")
    fig.tight_layout()
    fig.savefig(os.path.join(AQUI, "golpes.png"), dpi=70)


if __name__ == "__main__":
    main()
