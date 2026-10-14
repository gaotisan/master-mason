"""fondo.ps1 en paralelo: el mismo _fondo.py de tools/anim, con los mismos
parametros, repartido en varios procesos (va a ~10 s por fotograma en las
casillas grandes y un job de empujar tiene 170).

Como fondo.ps1: guarda la copia con el croma en <job>/_con_fondo/04_limpios la
primera vez y no la pisa; parte siempre de esa copia y escribe en 04_limpios.

  python fondo_paralelo.py <job> [<job> ...] [--procesos 7] [--tolerancia 35] [--radio 4]
"""
import argparse, os, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

AQUI = os.path.dirname(os.path.abspath(__file__))
PROY = os.path.abspath(os.path.join(AQUI, '..', '..', '..'))
FONDO = os.path.join(PROY, 'tools', 'anim', '_fondo.py')
FFMPEG = os.path.join(PROY, 'tools', 'ffmpeg', 'bin', 'ffmpeg.exe')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('jobs', nargs='+')
    ap.add_argument('--procesos', type=int, default=7)
    ap.add_argument('--tolerancia', type=int, default=35)
    ap.add_argument('--radio', type=int, default=4)
    a = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix='fondo_')
    tareas = []
    for job in a.jobs:
        limpios = os.path.join(AQUI, job, '04_limpios')
        copia = os.path.join(AQUI, job, '_con_fondo', '04_limpios')
        if not os.path.isdir(copia):
            shutil.copytree(limpios, copia)
            print('%s: copia con fondo guardada en _con_fondo\\04_limpios' % job)
        fs = sorted(f for f in os.listdir(copia) if f.endswith('.png'))
        trozo = max(1, (len(fs) + a.procesos - 1) // a.procesos)
        for k in range(0, len(fs), trozo):
            d = os.path.join(tmp, '%s_%03d' % (job, k))
            os.makedirs(d)
            for f in fs[k:k + trozo]:
                shutil.copyfile(os.path.join(copia, f), os.path.join(d, f))
            tareas.append((job, d, limpios))

    def correr(t):
        job, d, limpios = t
        r = subprocess.run([sys.executable, FONDO, '--ffmpeg', FFMPEG, '--entrada', d, '--salida', limpios,
                            '--tolerancia', str(a.tolerancia), '--radio', str(a.radio)],
                           capture_output=True, text=True)
        if r.returncode:
            print(job, d, 'FALLO', r.stderr[-800:])
        return job, r.returncode, r.stdout

    with ThreadPoolExecutor(a.procesos) as ex:
        for job, rc, out in ex.map(correr, tareas):
            lineas = [l for l in out.splitlines() if 'bolsas' in l or 'motas' in l]
            print('%s: trozo %s (%d avisos de bolsas/motas)' % (job, 'ok' if rc == 0 else 'FALLO', len(lineas)))
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
