"""Paso 4: a metros (1,80 m de alto, pies en el suelo), material con la
textura horneada, y .glb para Godot."""
import bpy, sys, os
salida = sys.argv[1]
bpy.ops.wm.open_mainfile(filepath='peregrino_malla.blend')
ob = bpy.data.objects['peregrino']
ESC = 1.8 / 1470.0
ob.location = (0, 0, 1619 * ESC)
ob.scale = (ESC, ESC, ESC)
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.shade_smooth()
mat = bpy.data.materials.new('peregrino')
mat.use_nodes = True
bsdf = mat.node_tree.nodes['Principled BSDF']
img = bpy.data.images.load(os.path.abspath('peregrino_textura.png'))
tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = img
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
bsdf.inputs['Roughness'].default_value = 1.0
bsdf.inputs['Metallic'].default_value = 0.0
ob.data.materials.clear(); ob.data.materials.append(mat)
os.makedirs(os.path.dirname(salida), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=salida, export_format='GLB', use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath='peregrino_metros.blend')
print('exportado', salida)
