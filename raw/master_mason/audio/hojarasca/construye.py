"""Sonidos de hojarasca para la escena de la caida (scripts/game/caida_hojarasca.gd),
sacados del audio de un video IA del peregrino andando por un camino de otono
(_fuente/Pilgrim_walking_on_autumn_path_20261007015648.mp4; el video no se usa,
solo su sonido). Son 10 s con 13 pisadas en hojas secas, una cada ~0,75 s, sin
musica ni voz: el crujido va de 800 Hz a 9 kHz y entre pisada y pisada queda el
roce de la tunica.

Salida en assets/audio/ (48 kHz, mono):
  hojarasca_paso_1..N.wav   pisadas sueltas (el juego elige una al azar y le
                            cambia algo el tono: AudioStreamRandomizer).
  hojarasca_arrastre.wav    bucle del roce continuo al vadear: la grabacion
                            entera con las pisadas aplanadas (compresor lento) y
                            la costura cruzada. El juego le sube el volumen con
                            la velocidad.
  hojarasca_golpe.wav       el cuerpo entrando en el monton: cuatro pisadas a la
                            vez, algo mas graves (peso), y la cola de hojas que
                            vuelven a caer.
  hojarasca_levantarse.wav  incorporarse en las hojas (3,3 s, lo que dura la
                            animacion): apoyos suaves en los tiempos del
                            levantarse y el sacudon del final, con roce debajo.

Ademas, en _salida/: grafica de las pisadas detectadas y los cortes.

    python raw/master_mason/audio/hojarasca/construye.py
"""
import os
import subprocess

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, find_peaks, resample_poly, sosfilt

AQUI = os.path.dirname(os.path.realpath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", "..", "..", ".."))
FFMPEG = os.path.join(RAIZ, "tools", "ffmpeg", "bin", "ffmpeg.exe")
VIDEO = os.path.join(AQUI, "_fuente", "Pilgrim_walking_on_autumn_path_20261007015648.mp4")
WAV = os.path.join(AQUI, "_fuente", "original.wav")
AUDIO = os.path.join(RAIZ, "assets", "audio")
SALIDA = os.path.join(AQUI, "_salida")
SR = 48000


def leer():
    if not os.path.exists(WAV):
        subprocess.run([FFMPEG, "-loglevel", "error", "-y", "-i", VIDEO, "-vn", "-ac", "2",
                        "-ar", str(SR), WAV], check=True)
    sr, x = wavfile.read(WAV)
    assert sr == SR
    x = x.astype(np.float32) / 32768.0
    m = x.mean(axis=1)
    # Fuera graves de manejo (<60 Hz): no son hojas y suman pico.
    return sosfilt(butter(2, 60, "highpass", fs=SR, output="sos"), m).astype(np.float32)


def envolvente(x, ventana=0.02):
    hp = sosfilt(butter(4, [1500, 12000], "bandpass", fs=SR, output="sos"), x)
    n = int(ventana * SR)
    return np.sqrt(np.convolve(hp ** 2, np.ones(n) / n, "same"))


def pisadas(x):
    """Inicio de cada pisada: el pico de la envolvente de crujido y, hacia atras,
    donde la subida cruza el 20 % del pico (el ataque, no el maximo)."""
    env = envolvente(x)
    paso = int(0.01 * SR)
    e = env[::paso]
    picos, _ = find_peaks(e, height=e.max() * 0.45, distance=50)
    inicios = []
    for p in picos:
        i = p
        while i > 0 and e[i] > e[p] * 0.2 and p - i < 30:
            i -= 1
        inicios.append(i * paso)
    return np.array(inicios), env


def fundido(s, entra=0.004, sale=0.08):
    s = s.copy()
    a, b = int(entra * SR), int(sale * SR)
    s[:a] *= np.linspace(0, 1, a)
    s[-b:] *= np.linspace(1, 0, b) ** 2
    return s


def normalizar(s, pico_db):
    return s / (np.abs(s).max() + 1e-9) * 10 ** (pico_db / 20)


def guardar(nombre, s):
    s = np.clip(s, -1, 1)
    wavfile.write(os.path.join(AUDIO, nombre), SR, (s * 32767).astype(np.int16))
    print(f"{nombre:28s} {len(s) / SR:5.2f} s  pico {20 * np.log10(np.abs(s).max() + 1e-9):5.1f} dB")


def recortar_pasos(x, inicios):
    """Cada pisada desde 20 ms antes del ataque hasta 0,55 s (o hasta la
    siguiente), con fundido de salida. Todas al mismo nivel de crujido (RMS),
    no de pico: si no, las de pico alto sonaban flojas."""
    pasos = []
    for k, i in enumerate(inicios):
        a = max(0, i - int(0.02 * SR))
        fin = inicios[k + 1] - int(0.04 * SR) if k + 1 < len(inicios) else len(x)
        b = min(a + int(0.55 * SR), fin, len(x))
        if b - a < int(0.3 * SR):
            continue
        pasos.append(fundido(x[a:b]))
    rms = [np.sqrt((p[: int(0.2 * SR)] ** 2).mean()) for p in pasos]
    obj = np.median(rms)
    return [p * (obj / r) for p, r in zip(pasos, rms)]


def arrastre(x):
    """El roce continuo: compresor lento que aplasta las pisadas hasta el nivel
    tipico del roce y deja la textura. Bucle: los ultimos 0,6 s se cruzan con
    los primeros."""
    env = envolvente(x, 0.12) + 1e-5
    nivel = np.percentile(env[int(0.5 * SR):], 35)
    g = np.minimum(1.0, nivel / env) ** 0.85
    y = (x * g)[int(0.45 * SR):]          # el principio del video sube de cero
    c = int(0.6 * SR)
    t = np.linspace(0, 1, c)
    y = np.concatenate([y[c:-c], y[-c:] * np.cos(t * np.pi / 2) + y[:c] * np.sin(t * np.pi / 2)])
    return y


def tono(s, factor):
    """Cambia el tono (y la duracion) por remuestreo: factor < 1 mas grave."""
    p, q = int(round(100 / factor)), 100
    return resample_poly(s, p, q).astype(np.float32)


def mezclar(largo, piezas):
    out = np.zeros(int(largo * SR), np.float32)
    for t, s, g in piezas:
        i = int(t * SR)
        n = min(len(s), len(out) - i)
        if n > 0:
            out[i:i + n] += s[:n] * g
    return out


def main():
    os.makedirs(SALIDA, exist_ok=True)
    rng = np.random.default_rng(1851)
    x = leer()
    inicios, env = pisadas(x)
    print("pisadas en:", ", ".join(f"{i / SR:.2f}" for i in inicios))
    pasos = recortar_pasos(x, inicios)

    # Pisadas sueltas: todas menos la primera (empieza con el video y aun no
    # suena a fondo). Al mismo pico para el juego.
    for k, p in enumerate(pasos[1:], 1):
        guardar(f"hojarasca_paso_{k}.wav", normalizar(p, -3.0))

    # Por nivel medio, no por pico: algun chasquido suelto fijaba el pico y el
    # roce quedaba casi mudo. RMS a -22 dBFS y los chasquidos, recortados suave.
    roce = arrastre(x)
    roce = roce * (10 ** (-22 / 20) / np.sqrt((roce ** 2).mean()))
    guardar("hojarasca_arrastre.wav", np.tanh(roce * 2.0) / 2.0)

    # El golpe: cuatro pisadas a la vez algo mas graves (peso del cuerpo) y la
    # cola de hojas que vuelven a caer, cada vez mas flojas y separadas.
    fuertes = sorted(pasos[1:], key=lambda p: -np.abs(p).max())[:4]
    piezas = [(rng.uniform(0, 0.04), tono(p, rng.uniform(0.78, 0.9)), 0.8) for p in fuertes]
    t = 0.35
    while t < 1.5:
        p = pasos[rng.integers(1, len(pasos))]
        piezas.append((t, tono(p, rng.uniform(1.0, 1.25))[: int(0.25 * SR)], 0.35 * (1.6 - t)))
        t += rng.uniform(0.12, 0.3)
    guardar("hojarasca_golpe.wav", normalizar(fundido(mezclar(1.9, piezas), 0.002, 0.3), -1.0))

    # Levantarse: apoyos en los tiempos del incorporarse (los del sintetizado
    # que ya cuadraban) y el sacudon al final, con el roce debajo.
    roce = arrastre(x)
    apoyos = [(0.25, 0.45), (0.9, 0.6), (1.7, 0.5), (2.45, 0.4), (2.92, 0.9)]
    piezas = [(0.0, roce[: int(3.3 * SR)] * np.hanning(int(3.3 * SR)).astype(np.float32), 0.6)]
    for t, g in apoyos:
        p = pasos[rng.integers(1, len(pasos))]
        piezas.append((t, tono(p, rng.uniform(0.95, 1.1)), g))
    guardar("hojarasca_levantarse.wav", normalizar(fundido(mezclar(3.3, piezas), 0.01, 0.25), -3.0))

    # Grafica de control: envolvente y cortes.
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        t = np.arange(len(env)) / SR
        plt.figure(figsize=(14, 3))
        plt.plot(t, env, lw=0.6)
        for i in inicios:
            plt.axvline(i / SR, color="r", lw=0.8)
        plt.title("Crujido (1,5-12 kHz) y pisadas detectadas")
        plt.tight_layout()
        plt.savefig(os.path.join(SALIDA, "pisadas.png"), dpi=90)
    except ImportError:
        pass


if __name__ == "__main__":
    main()
