"""Adapt installed Forever/Camelot artwork using the client's exact DB2 atlas crops.

Read-only source extraction lives outside the addon. This generator chooses c60
set1 variants explicitly; shared gamepad-slot art is used only where the current
Blizzard_GamepadActionBars module references it. No legacy Classic endcaps.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image, ImageChops, ImageEnhance, ImageOps

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'design'/'reforged'
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=ROOT.parent/'forever-wow')
args=parser.parse_args()
SOURCE=args.source.resolve()
provenance=json.loads((SOURCE/'provenance.json').read_text(encoding='utf-8-sig'))
atlas_map=json.loads((SOURCE/'atlas-map.json').read_text(encoding='utf-8'))['atlases']
atlas_map={k.lower():(k,v) for k,v in atlas_map.items()}
records={a['fileDataId']:a for a in provenance['assets']}
used={}; crops={}; assets=[]
OUT.mkdir(parents=True,exist_ok=True)


def blank(size):return Image.new('RGBA',size)
def resize(image,size):return image.resize(size,Image.Resampling.LANCZOS)


def source(file_id):
    record=records[file_id]
    path=Path(record['pngFile'])
    name=path.stem
    destination=OUT/'native'/path.name
    destination.parent.mkdir(exist_ok=True)
    if name not in used:
        shutil.copyfile(path,destination)
        used[name]=dict(fileDataId=file_id,virtualPath=record['virtualPath'],sourceSha256=record['sourceSha256'],
                        png='native/'+path.name,pngSha256=hashlib.sha256(destination.read_bytes()).hexdigest())
    return Image.open(destination).convert('RGBA'),name


def atlas(name,shared=False):
    canonical,entry=atlas_map[name.lower()]
    variant=entry.get('preferredC60')
    if variant is None and shared:
        variant=next(v for v in entry['variants'] if v['validCrop'] and v['fileDataID'] in records)
    if variant is None:raise ValueError('No c60 atlas variant: '+name)
    image,key=source(variant['fileDataID'])
    assert list(image.size)==variant['sheetSize'],(name,image.size,variant['sheetSize'])
    crops[canonical]=dict(fileDataId=variant['fileDataID'],source=key,memberID=variant['memberID'],
                          setID=variant['setID'],memberName=variant['committedName'],crop=variant['crop'],
                          sharedCurrentGamepad=shared)
    return image.crop(variant['crop']),key


def slice9(image,size,src,dst):
    w,h=size; sw,sh=image.size
    sx,sy=(0,src,sw-src,sw),(0,src,sh-src,sh)
    dx,dy=(0,dst,w-dst,w),(0,dst,h-dst,h)
    out=blank(size)
    for row in range(3):
        for col in range(3):
            part=image.crop((sx[col],sy[row],sx[col+1],sy[row+1]))
            out.alpha_composite(resize(part,(dx[col+1]-dx[col],dy[row+1]-dy[row])),(dx[col],dy[row]))
    return out


def alpha(image,amount):
    image=image.copy(); image.putalpha(image.getchannel('A').point(lambda n:round(n*amount)));return image


def fit(image,size,top=False):
    image=ImageOps.contain(image,size,Image.Resampling.LANCZOS)
    out=blank(size);out.alpha_composite(image,((size[0]-image.width)//2,0 if top else (size[1]-image.height)//2));return out


def frame(size,corner):
    w,h=size; out=blank(size);sources=[]
    pieces=[('UI-Frame-DiamondMetal-CornerTopLeft',(0,0,corner,corner)),
            ('UI-Frame-DiamondMetal-CornerTopRight',(w-corner,0,w,corner)),
            ('UI-Frame-DiamondMetal-CornerBottomLeft',(0,h-corner,corner,h)),
            ('UI-Frame-DiamondMetal-CornerBottomRight',(w-corner,h-corner,w,h)),
            ('_UI-Frame-DiamondMetal-EdgeTop',(corner,0,w-corner,corner)),
            ('_UI-Frame-DiamondMetal-EdgeBottom',(corner,h-corner,w-corner,h)),
            ('!UI-Frame-DiamondMetal-EdgeLeft',(0,corner,corner,h-corner)),
            ('!UI-Frame-DiamondMetal-EdgeRight',(w-corner,corner,w,h-corner))]
    for name,(x,y,r,b) in pieces:
        image,key=atlas(name);sources.append(key)
        out.alpha_composite(resize(image,(r-x,b-y)),(x,y))
    return out,list(dict.fromkeys(sources))


def add(name,size,corner,state,family,layers,sources,note):
    paths=[]; composite=blank(size)
    for label,image in layers:
        assert image.size==size and image.getchannel('A').getbbox(),(name,label)
        relative=f'layers/{name}/{label}.png';path=OUT/relative
        path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
        paths.append(relative);composite.alpha_composite(image)
    proof=OUT/'prepared'/f'{name}.png';proof.parent.mkdir(exist_ok=True);composite.save(proof)
    assets.append(dict(name=name,width=size[0],height=size[1],nineSliceCorner=corner,state=state,family=family,
                       sourceLayers=paths,nativeSources=list(dict.fromkeys(sources)),adaptation=note))


def red_button(pressed=False):
    suffix='-Pressed' if pressed else ''
    left,lk=atlas('128-RedButton-Left'+suffix)
    right,rk=atlas('128-RedButton-Right'+suffix)
    middle,mk=atlas('_128-RedButton-Center'+suffix)
    # Preserve both actual end caps; the native right region also includes a
    # long plain center, which is unnecessary in this symmetric nine-slice.
    right=right.crop((right.width-left.width,0,right.width,right.height))
    out=blank((512,128));cap=left.width
    out.alpha_composite(left,(0,0));out.alpha_composite(right,(512-cap,0))
    out.alpha_composite(resize(middle,(512-2*cap,128)),(cap,0))
    return out,[lk,rk,mk]


up,button_sources=red_button();down,_=red_button(True)
glow,glow_key=atlas('RedButton-Highlight')
for state in ('normal','hover','active','pressed'):
    size=(128,32)
    layers=[('01_native_activation' if state=='pressed' else '01_native_static',slice9(down if state=='pressed' else up,size,24,6))]
    sources=button_sources[:]
    if state in ('hover','active'):
        layers.append(('02_native_mouseover',alpha(resize(glow,size),.30 if state=='hover' else .45)));sources.append(glow_key)
    if state=='active':
        rim,keys=frame(size,6);layers.append(('03_controller_focus',ImageEnhance.Brightness(rim).enhance(1.5)));sources+=keys
    add('ck_btn_'+state,size,6,state,'button',layers,sources,
        'Forever c60 ThreeSliceButton artwork repacked into symmetric nine-slice; native Down artwork; c60 highlight adapted to hover.')

keyboard_states={'normal':'normal','hover':'hover','active':'selected','pressed':'pressed','target_l':'hover','target_r':'hover'}
for state,native_state in keyboard_states.items():
    base,key=atlas('common-button-tertiary-'+native_state)
    size=(128,64);layers=[('01_native_'+native_state,slice9(base,size,16,12))];sources=[key]
    if state in ('target_l','target_r'):
        selected,skey=atlas('common-button-tertiary-selected');marker=slice9(selected,size,16,12)
        mask=Image.new('L',size,0)
        # A soft side emphasis preserves the native bevel instead of cutting
        # the selected artwork down the middle of the key.
        ramp=[round(255*max(0,min(1,(96-x)/64))) for x in range(size[0])]
        if state=='target_r':ramp.reverse()
        mask.putdata(ramp*size[1])
        marker.putalpha(ImageChops.multiply(marker.getchannel('A'),mask))
        if state=='target_r':
            r,g,b,a=marker.split();marker=Image.merge('RGBA',(r.point(lambda v:round(v*.65)),g,b.point(lambda v:min(255,round(v*1.55))),a))
        layers.append(('02_'+state,marker));sources.append(skey)
    add('ck_sk_key_'+state,size,12,state,'keyboard',layers,sources,
        'Native Forever tertiary-button normal, hover, selected and pressed states. Left/right stick targets use side-localized selected art; right keeps the existing cyan cue.')

rim,rim_sources=frame((128,32),10)
add('ck_select',(128,32),10,'selected','selection',[('01_native_hover',alpha(resize(glow,(128,32)),.2)),('02_native_focus',rim)],
    [glow_key]+rim_sources,'c60 native highlight and diamond frame, kept separate.')
background,bg_key=source(8198947)
background=ImageEnhance.Brightness(resize(background,(128,128))).enhance(.36)
add('ck_panel_bg',(128,128),0,'static','panel',[('01_forever_background',background)],[bg_key],
    'Forever UICommonBackgrounds stone/leather texture at36% brightness for readable cream text.')
rim,keys=frame((128,128),16)
add('ck_reforged_frame',(128,128),16,'static','frame',[('01_native_diamond_frame',rim)],keys,
    'Eight exact c60 DiamondMetal DB2 atlas pieces repacked into transparent-center nine-slice; original edge orientation preserved.')
paper,paper_key=atlas('spellbook-Page-Left-C60-2x')
paper=paper.crop((56,160,paper.width-20,paper.height-36))
add('ck_reforged_parchment',(256,256),16,'static','detail',[('01_forever_spellbook_paper',slice9(paper,(256,256),48,16))],
    [paper_key],'Native Forever spellbook paper, inner crop56,160,1600,1328 removes the dark book binding behind live text; then nine-slice48 to16. No legacy QuestBackground texture.')

# Compatibility exports retain the existing symmetric 12px runtime contract.
# Live role/navigation textures use SetAtlas, which applies the client's asymmetric
# shader slice data automatically; these baked files are not a native-size proof.
for state in ('normal','hover','active','pressed'):
    size=(512,128);base,key=atlas('common-button-list-large'+('-hover' if state=='hover' else ''))
    if state=='pressed':base=ImageEnhance.Brightness(base).enhance(.70)
    layers=[('01_derived_activation' if state=='pressed' else '01_native_card',slice9(base,size,14,12))];sources=[key]
    if state=='active':
        selected,skey=atlas('common-button-list-large-selected')
        layers.append(('02_native_selection',alpha(slice9(selected,size,14,12),.14)))
        rim,keys=frame(size,12);layers.append(('03_native_focus_frame',rim));sources += [skey]+keys
    add('ck_reforged_role_'+state,size,12,state,'role_card',layers,sources,
        'Compatibility fallback:512x128 bake with symmetric12px runtime slicing, not the native asymmetric list-card layout. Live role cards use native SetAtlas shader slices. Activation is an explicitly derived70%-brightness depression; list family has no native pressed atlas.')

left,lk=atlas('UI-Frame-DiamondMetal-Header-CornerLeft');right,rk=atlas('UI-Frame-DiamondMetal-Header-CornerRight')
middle,mk=atlas('_UI-Frame-DiamondMetal-Header-Tile')
size=(512,128);header=blank(size);cap=64
header.alpha_composite(resize(left,(cap,128)),(0,0));header.alpha_composite(resize(right,(cap,128)),(512-cap,0))
header.alpha_composite(resize(middle,(512-2*cap,128)),(cap,0))
add('ck_reforged_title',size,0,'static','title',[('01_native_c60_header',header)],[lk,rk,mk],
    'Separate c60 DiamondMetal header caps and original tile assembled to the title contract.')
for side in ('left','right'):
    gryphon,key=atlas('UI-HUD-ActionBar-Gryphon-'+side)
    add('ck_reforged_gryphon_'+side,(256,256),0,'static','ornament',[('01_actual_forever_gryphon',fit(gryphon,(256,256),top=True))],
        [key],'Actual480x280 c60 gryphon from set1, fit proportionally with transparent bottom padding; distinct original left/right artwork, no mirroring or redrawing.')
for state in ('normal','hover','pressed'):
    rim,key=atlas('gamepad-actionbar-circleslot-border-'+state,shared=True)
    add('ck_reforged_slot_'+state,(128,128),0,state,'hud_slot',[('01_native_gamepad_'+state,resize(rim,(128,128)))],
        [key],'Exact native Forever GamepadActionBar circular state used by the installed gamepad module; no minimap art or added decoration.')

result=dict(generator='Blender native-art preparation; tools/prepare_native_reforged.py',supersampling=2,blend='ClassicReforged.blend',
            assets=assets,nativeClient={k:provenance[k] for k in ('source','product','version','buildKey','mode')},
            nativeArtwork=list(used.values()),atlasCrops=crops,
            atlasMetadataSha256=hashlib.sha256((SOURCE/'atlas-map.json').read_bytes()).hexdigest(),
            note='Explicit Forever/Camelot c60 variants from installed DB2 metadata. Current gamepad-slot atlases are shared set0. Editable layers and native source images are packed by Blender.')
(OUT/'manifest.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(f'Prepared {len(assets)} Forever assets from {len(used)} sources and {len(crops)} exact atlas crops.')
