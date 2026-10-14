"""Generate technical textured GLBs and a catalog-bound batch in ignored build/.

Not character art. Blender background only; never uploads or changes catalog.
"""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/figures'))
import bpy
import build
from external import write_json

OUT = ROOT / 'build/figures/external-fixtures'
OUT.mkdir(parents=True, exist_ok=True)
build.reset()
image = bpy.data.images.new('FixtureChecker', 64, 64, alpha=True)
pixels = []
for y in range(64):
    for x in range(64):
        color = (.12, .35, .6, 1) if (x // 8 + y // 8) % 2 else (.8, .35, .15, 1)
        pixels.extend(color)
image.pixels[:] = pixels
image.pack()
mat = bpy.data.materials.new('OriginalTexturedPBR')
mat.use_nodes = True
shader = mat.node_tree.nodes.get('Principled BSDF')
texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = image
mat.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
shader.inputs['Roughness'].default_value = .45
shader.inputs['Metallic'].default_value = .2
normal_image = bpy.data.images.new('FixtureNormal', 32, 32, alpha=False)
normal_image.pixels[:] = [.5, .5, 1, 1] * (32 * 32)
normal_image.colorspace_settings.name = 'Non-Color'
normal_image.pack()
normal_texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
normal_texture.image = normal_image
normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
mat.node_tree.links.new(normal_texture.outputs['Color'], normal.inputs['Color'])
mat.node_tree.links.new(normal.outputs['Normal'], shader.inputs['Normal'])
bpy.ops.mesh.primitive_uv_sphere_add(segments=128, ring_count=96, location=(0, 0, 1))
body = bpy.context.object
body.name = 'TripoFixtureBody'
body.data.materials.append(mat)
bpy.ops.object.shade_smooth()
mod = body.modifiers.new('Triangles', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=mod.name)
# Separate detailed component and second material exercise logical/material partitioning.
bpy.ops.mesh.primitive_torus_add(major_segments=96, minor_segments=32, location=(0, 0, 1.8), major_radius=.75, minor_radius=.14)
detail = bpy.context.object
detail.name = 'HairAccessory'
detail_mat = mat.copy()
detail_mat.name = 'AccessoryOriginalPBR'
detail_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .75
detail.data.materials.append(detail_mat)
bpy.ops.object.shade_smooth()
mod = detail.modifiers.new('Triangles', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=mod.name)
root = bpy.data.objects.new('TripoSource', None)
bpy.context.scene.collection.objects.link(root)
for obj in (body, detail):
    obj.parent = root
(OUT / 'incoming').mkdir(exist_ok=True)
build.export_glb(root, [body, detail], str(OUT / 'incoming/download.glb'))
entries = [{
    'source': 'download.glb', 'collection_id': 'tide', 'figure_id': 'tide.bubble', 'rarity': 'Common',
    'technical_fixture': True,
    'collection_slug': 'tidepool-tales', 'figure_slug': 'bubble-bean', 'root': 'BubbleBean',
    'alias': 'bubble_bean', 'asset_key': 'Models.TidepoolTales.BubbleBean', 'height_studs': 3,
    'eyes': {'object': 'TripoFixtureBody', 'region': [[.25, 0, .55], [.75, .16, .82]]},
    'protected_objects': ['HairAccessory']}]
# A smaller source exercises an actual multi-file batch with different detail budgets.
bpy.data.objects.remove(body, do_unlink=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=24, location=(0, 0, 1))
body = bpy.context.object
body.name = 'TripoFixtureBody'
body.data.materials.append(mat)
body.parent = root
bpy.ops.object.shade_smooth()
mod = body.modifiers.new('Triangles', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=mod.name)
build.export_glb(root, [body, detail], str(OUT / 'incoming/download-small.glb'))
entries.append(dict(entries[0], source='download-small.glb', figure_id='tide.coral',
                    figure_slug='coral-cuddle', root='CoralCuddle', alias='coral_cuddle',
                    asset_key='Models.TidepoolTales.CoralCuddle'))
write_json(OUT / 'batch.json', {'schema_version': 1, 'batch_id': 'technical-tripo', 'figures': entries})
print('Technical source fixture and batch:', OUT)
