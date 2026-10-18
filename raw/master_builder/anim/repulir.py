"""Repite el pulido de las acciones de perfil con --oscuras y lo que va detras.

El pulido normal (baston/pulir.py) toma por croma lo gris verdoso en grupos
grandes, y la capucha de estos videos es gris verdosa en la sombra: le hacia
agujeros (se veia el fondo a traves de la capucha en trepar, subirse al sillar,
bajar, coger de la mesa...). Con --oscuras solo quita las bolsas de croma en
sombra (todo por debajo de 100), y las encerradas claras las quita
--bolsas-verdes comparando con la copia con el croma, como siempre.

Por job: pulir.py --oscuras (parte de _antes_de_pulir), --bolsas-verdes, la
casilla a multiplos de 8 si hacia falta (las de la primera tanda se rellenaron
despues del pulido: raiz.json ya trae la casilla nueva), montar_accion.py y
hoja.ps1.
  python repulir.py <job> [<job> ...]
"""
import json, os, subprocess, sys
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
HOJA = os.path.abspath(os.path.join(AQUI, '..', '..', '..', 'tools', 'anim', 'hoja.ps1'))


def correr(args, cwd):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if r.returncode:
        raise SystemExit('%s fallo:\n%s' % (' '.join(args[:3]), (r.stdout + r.stderr)[-1500:]))
    return r.stdout


def rellenar(job):
    """Lleva 04_limpios a la casilla de raiz.json (arriba lo que falte de alto,
    a los lados lo que falte de ancho), si el pulido la ha dejado mas pequena."""
    rz = json.load(open(os.path.join(AQUI, job, 'raiz.json')))
    CW, CH = rz['casilla']
    d = os.path.join(AQUI, job, '04_limpios')
    n = 0
    for f in sorted(os.listdir(d)):
        a = np.asarray(Image.open(os.path.join(d, f)).convert('RGBA'))
        h, w = a.shape[:2]
        if (w, h) == (CW, CH):
            continue
        b = np.zeros((CH, CW, 4), np.uint8)
        b[CH - h:, (CW - w) // 2:(CW - w) // 2 + w] = a
        Image.fromarray(b, 'RGBA').save(os.path.join(d, f))
        n += 1
    return n


def main():
    for job in sys.argv[1:]:
        print(job, ':', correr([sys.executable, 'pulir.py', '--oscuras', job], os.path.join(AQUI, 'baston')).strip().splitlines()[-1])
        correr([sys.executable, 'pulir.py', '--bolsas-verdes', job], os.path.join(AQUI, 'baston'))
        n = rellenar(job)
        if n:
            print('  casillas rellenadas: %d' % n)
        salida = correr([sys.executable, '-I', 'montar_accion.py', job], AQUI)
        print('  ' + ' | '.join(l for l in salida.splitlines() if l.startswith('extremos') or l.startswith('raiz por')))
        correr(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', HOJA, '-Job', job,
                '-Desde', '04_acciones', '-Fps', '24', '-Escala', '2', '-Cols', '10'], os.path.dirname(HOJA))
        print('  hoja hecha')


if __name__ == '__main__':
    main()
