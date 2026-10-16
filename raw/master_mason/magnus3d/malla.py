"""Paso 2: de los cascos de voxeles a mallas low-poly (bpy), una por pieza,
juntas en un objeto con UV. Guarda malla.npz y magnus_malla.blend."""
import numpy as np, json
from scipy import ndimage
from skimage import measure
import bpy, bmesh
cfg = json.load(open('casco.json'))
S, y0, R = cfg['S'], cfg['y0'], cfg['R']
PIEZAS = [('cuerpo', 7000, 0.8), ('piernas', 700, 0.6), ('manos', 500, 0.5)]
bpy.ops.wm.read_factory_settings(use_empty=True)
objs = []
for i, (nombre, caras, sigma) in enumerate(PIEZAS):
    vol = np.pad(np.load('casco_%s.npy' % nombre).astype(float), 2)
    vol = ndimage.gaussian_filter(vol, sigma)
    v, f, _, _ = measure.marching_cubes(vol, 0.5)
    v -= 2
    X = -R + v[:, 1] * S; Y = y0 + v[:, 0] * S; Z = -R + v[:, 2] * S
    bv = np.stack([X, -Z, -Y], 1)
    me = bpy.data.meshes.new(nombre); me.from_pydata(bv.tolist(), [], f[:, ::-1].tolist()); me.update()
    ob = bpy.data.objects.new(nombre, me); bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new('dec', 'DECIMATE'); mod.ratio = min(1.0, caras / len(f))
    bpy.ops.object.modifier_apply(modifier='dec')
    bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.triangulate(bm, faces=bm.faces); bm.to_mesh(ob.data); bm.free()
    a = ob.data.attributes.new('pieza', 'INT', 'FACE')
    a.data.foreach_set('value', [i] * len(ob.data.polygons))
    print(nombre, len(ob.data.polygons))
    objs.append(ob)
bpy.ops.object.select_all(action='DESELECT')
for o in objs: o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()
ob = bpy.context.active_object; ob.name = 'magnus'
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, area_weight=0.0, scale_to_bounds=True)
bpy.ops.object.mode_set(mode='OBJECT')
d = ob.data
V = np.array([v.co[:] for v in d.vertices]); T = np.array([p.vertices[:] for p in d.polygons])
pieza = np.zeros(len(T), int); d.attributes['pieza'].data.foreach_get('value', pieza)
uvl = d.uv_layers.active.data; UV = np.zeros((len(T), 3, 2))
for i, p in enumerate(d.polygons):
    for j, li in enumerate(p.loop_indices): UV[i, j] = uvl[li].uv[:]
np.savez('malla.npz', V=V, T=T, UV=UV, pieza=pieza)
bpy.ops.wm.save_as_mainfile(filepath='magnus_malla.blend')
print('ok', len(T))
