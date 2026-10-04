"""Render locally extracted WoW artwork as packed, layered Blender sources.

Run prepare_native_reforged.py, then this script in Blender, then export_reforged.py.
Artwork is unlit: the original painted lighting and silhouette remain intact.
"""
import argparse
import json
import shutil
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'design' / 'reforged'
parser = argparse.ArgumentParser()
parser.add_argument('--only', default='')
parser.add_argument('--samples', type=int, default=1)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
if not manifest.get('nativeArtwork'):
    raise RuntimeError('Run prepare_native_reforged.py with client-extracted artwork first.')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=args.samples
scene.cycles.use_denoising=False
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.image_settings.color_depth='8'
scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0
scene.view_settings.gamma=1
scene.render.filter_size=.01
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.context.preferences.filepaths.save_version=0
scene.world=bpy.data.worlds.new('Unlit native artwork')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=0
rig=bpy.data.collections.new('00 / Orthographic export camera')
scene.collection.children.link(rig)
camera_data=bpy.data.cameras.new('Pixel-matched orthographic camera')
camera=bpy.data.objects.new('Export camera',camera_data)
rig.objects.link(camera)
camera.location=(0,0,100)
camera_data.type='ORTHO'
camera_data.sensor_fit='HORIZONTAL'
scene.camera=camera


def load_image(path):
    image=bpy.data.images.load(str(path),check_existing=True)
    image.colorspace_settings.name='sRGB'
    image.pack()
    return image


def plane(name,image,width,height,z,collection):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([(-width/2,-height/2,z),(width/2,-height/2,z),
                     (width/2,height/2,z),(-width/2,height/2,z)],[],[(0,1,2,3)])
    mesh.update()
    uv=mesh.uv_layers.new(name='Native image UV')
    for loop,xy in zip(uv.data,((0,0),(1,0),(1,1),(0,1))):loop.uv=xy
    obj=bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    material=bpy.data.materials.new(name)
    material.use_nodes=True
    nodes=material.node_tree.nodes
    nodes.clear()
    tex=nodes.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Closest'
    tex.label='Native artwork — packed RGBA layer'
    emission=nodes.new('ShaderNodeEmission')
    transparent=nodes.new('ShaderNodeBsdfTransparent')
    mix=nodes.new('ShaderNodeMixShader')
    output=nodes.new('ShaderNodeOutputMaterial')
    links=material.node_tree.links
    links.new(tex.outputs['Color'],emission.inputs['Color'])
    links.new(tex.outputs['Alpha'],mix.inputs[0])
    links.new(transparent.outputs[0],mix.inputs[1])
    links.new(emission.outputs[0],mix.inputs[2])
    links.new(mix.outputs[0],output.inputs['Surface'])
    obj.data.materials.append(material)


for source in manifest['nativeArtwork']:
    image=load_image(OUT/source['png'])
    image['FileDataID']=source['fileDataId']
    image['WoW virtual path']=source['virtualPath']
    image['Source SHA256']=source['sourceSha256']
    image.use_fake_user=True

collections=[]
for asset in manifest['assets']:
    col=bpy.data.collections.new(asset['name']+' / '+asset['state'])
    scene.collection.children.link(col)
    col['Runtime file']='textures/'+asset['name']+'.tga'
    col['Adaptation']=asset['adaptation']
    for i,relative in enumerate(asset['sourceLayers']):
        image=load_image(OUT/relative)
        sub=bpy.data.collections.new(Path(relative).stem)
        col.children.link(sub)
        plane(Path(relative).stem,image,asset['width'],asset['height'],i*.1,sub)
        dest=OUT/'renders'/relative
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(OUT/relative,dest)
    col.hide_render=col.hide_viewport=True
    collections.append((asset,col))

for asset,col in collections:
    if args.only and asset['name'] not in args.only.split(','):continue
    col.hide_render=col.hide_viewport=False
    camera_data.ortho_scale=asset['width']
    scene.render.resolution_x=asset['width']*manifest['supersampling']
    scene.render.resolution_y=asset['height']*manifest['supersampling']
    scene.render.filepath=str(OUT/'renders'/(asset['name']+'.png'))
    print('NATIVE ART RENDER',asset['name'],flush=True)
    bpy.ops.render.render(write_still=True)
    col.hide_render=col.hide_viewport=True

for asset,col in collections:
    if asset['name']=='ck_btn_hover':col.hide_render=col.hide_viewport=False
camera_data.ortho_scale=140
scene.render.resolution_x=1120
scene.render.resolution_y=280
scene['README']='Actual installed WoW artwork; one collection per texture/state, image planes per layer. All sources packed. Static, mouseover, focus, activation remain separate. See manifest.json for provenance and exact crops.'
manifest['generator']='Blender '+bpy.app.version_string+' / tools/blender_reforged.py; locally extracted native artwork'
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ClassicReforged.blend'))
print('NATIVE ART BLEND SAVED',OUT/'ClassicReforged.blend',flush=True)
