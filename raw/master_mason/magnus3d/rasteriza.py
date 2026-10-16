"""Rasterizador por software (numpy): triangulos en 2D con profundidad y
atributos por vertice. Lo usan el horneado de textura y los renders."""
import numpy as np

def rasterizar(p2, z, attrs, tris, w, h, mayor_cerca=True):
    """p2 (N,2) coords pixel (x,y); z (N,) profundidad; attrs (N,k).
    Devuelve zbuf (h,w), abuf (h,w,k), idbuf (h,w) con -1 vacio."""
    k = attrs.shape[1]
    zb = np.full((h, w), -np.inf if mayor_cerca else np.inf)
    ab = np.zeros((h, w, k))
    ib = np.full((h, w), -1, int)
    for t, (a, b, c) in enumerate(tris):
        P = p2[[a, b, c]]
        x0, y0 = np.floor(P.min(0)).astype(int)
        x1, y1 = np.ceil(P.max(0)).astype(int)
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, w - 1); y1 = min(y1, h - 1)
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        v0 = P[1] - P[0]; v1 = P[2] - P[0]
        den = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(den) < 1e-12:
            continue
        dx = xs - P[0, 0]; dy = ys - P[0, 1]
        l1 = (dx * v1[1] - v1[0] * dy) / den
        l2 = (v0[0] * dy - dx * v0[1]) / den
        l0 = 1 - l1 - l2
        dentro = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not dentro.any():
            continue
        zz = l0 * z[a] + l1 * z[b] + l2 * z[c]
        sub = zb[y0:y1 + 1, x0:x1 + 1]
        mejor = dentro & ((zz > sub) if mayor_cerca else (zz < sub))
        if not mejor.any():
            continue
        sub[mejor] = zz[mejor]
        A = (l0[..., None] * attrs[a] + l1[..., None] * attrs[b] + l2[..., None] * attrs[c])
        ab[y0:y1 + 1, x0:x1 + 1][mejor] = A[mejor]
        ib[y0:y1 + 1, x0:x1 + 1][mejor] = t
    return zb, ab, ib
