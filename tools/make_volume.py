"""Create two original layered 3D flame meshes and emissive textures.

The surface is generated from equations, not imported assets. Pillow is only
needed for the two RGBA textures. Run this file from any working directory.
"""
from math import cos, sin, pi, floor
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / 'mod/art/independent_afterfire'
OUT.mkdir(parents=True, exist_ok=True)

def value_noise(u, v, frequency, seed):
    """Deterministic, horizontally tileable 2D noise for the cylindrical UV."""
    x, y = u * frequency, v * frequency
    ix, iy = floor(x), floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    def sample(a, b):
        a %= frequency
        n = (a * 374761393 + b * 668265263 + seed * 1442695041) & 0xffffffff
        n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
        return ((n ^ (n >> 16)) & 0xffff) / 65535
    a, b = sample(ix, iy), sample(ix + 1, iy)
    c, d = sample(ix, iy + 1), sample(ix + 1, iy + 1)
    return (a + (b-a)*fx) * (1-fy) + (c + (d-c)*fx) * fy

def texture(name, core):
    img = Image.new('RGBA', (256, 256))
    for y in range(256):
        for x in range(256):
            u, v = x / 255, y / 255
            # Low-frequency swirls and smaller pockets; U wraps at the seam.
            drift = u + .07*sin(v*11) + .035*sin(v*23)
            turbulence = (value_noise(drift, v*1.6, 5, 9) * .58 +
                          value_noise(drift, v*1.6, 11, 15) * .29 +
                          value_noise(drift, v*1.6, 23, 22) * .13)
            falloff = max(0, min(1, min(v * 6, (1-v) * 5)))
            alpha = max(0, min(1, falloff * (.28 + turbulence * (.55 if core else .38))))
            brightness = .58 + .42*turbulence
            if core:
                rgb = (255, int((180 + 60 * (1-v)) * brightness), int((45 + 130 * (1-v)) * brightness))
            else:
                rgb = (255, int((65 + 100 * (1-v)) * brightness), int((12 + 35 * (1-v)) * brightness))
            img.putpixel((x, y), (*rgb, round(255 * alpha)))
    img.save(OUT / name, optimize=True)

def geometry(name, core, phase):
    rings, slices = 32, 48
    pos, normals, uv, indices = [], [], [], []
    for j in range(rings + 1):
        t = j / rings
        # Narrow exhaust root, billowing middle and tapered tip in +Y.
        envelope = sin(pi * (t ** .75)) ** .72
        for i in range(slices + 1):
            angle = 2*pi*i/slices
            rough = 1 + .16*sin(angle*3 + t*18 + phase) + .09*cos(angle*5 - t*24 + phase) + .04*sin(angle*9+t*39-phase)
            width = (.025 + (.055 if core else .095) * envelope) * rough * (1 - .65*t)
            bend = .035*sin(t*7 + phase)*t
            x, y, z = cos(angle)*width + bend, .80*t, sin(angle)*width
            pos += [x, y, z]; normals += [cos(angle), 0, sin(angle)]; uv += [i/slices, t]
    for j in range(rings):
        for i in range(slices):
            a=j*(slices+1)+i; b=a+1; c=a+slices+1; d=c+1
            for k in (a,c,b,b,c,d): indices += [k,k,k]
    def source(suffix, vals, stride, params):
        arr=' '.join(f'{v:.6g}' for v in vals)
        ps=''.join(f'<param name="{p}" type="float"/>' for p in params)
        return f'<source id="{name}-{suffix}"><float_array id="{name}-{suffix}-arr" count="{len(vals)}">{arr}</float_array><technique_common><accessor source="#{name}-{suffix}-arr" count="{len(vals)//stride}" stride="{stride}">{ps}</accessor></technique_common></source>'
    src=source('pos',pos,3,['X','Y','Z'])+source('norm',normals,3,['X','Y','Z'])+source('uv',uv,2,['S','T'])
    faces=' '.join(map(str,indices))
    material='iaf_core' if core else 'iaf_outer'
    return f'''<geometry id="{name}" name="{name}"><mesh>{src}<vertices id="{name}-verts"><input semantic="POSITION" source="#{name}-pos"/></vertices><triangles material="{material}" count="{len(indices)//9}"><input semantic="VERTEX" source="#{name}-verts" offset="0"/><input semantic="NORMAL" source="#{name}-norm" offset="1"/><input semantic="TEXCOORD" source="#{name}-uv" offset="2" set="0"/><p>{faces}</p></triangles></mesh></geometry>'''

def build(variant):
    names=['iaf_shell','iaf_core_mesh']
    geoms=geometry(names[0],False,variant*1.9)+geometry(names[1],True,variant*1.9+.7)
    nodes=''.join(f'<node id="{n}_node" name="{n}"><instance_geometry url="#{n}"><bind_material><technique_common><instance_material symbol="iaf_outer" target="#iaf_outer"/><instance_material symbol="iaf_core" target="#iaf_core"/></technique_common></bind_material></instance_geometry></node>' for n in names)
    text=f'''<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1"><asset><unit name="meter" meter="1"/><up_axis>Z_UP</up_axis></asset><library_effects><effect id="outer-fx"><profile_COMMON><technique sid="common"><lambert><diffuse><color>1 0.3 0.03 0.5</color></diffuse></lambert></technique></profile_COMMON></effect><effect id="core-fx"><profile_COMMON><technique sid="common"><lambert><diffuse><color>1 0.8 0.2 0.8</color></diffuse></lambert></technique></profile_COMMON></effect></library_effects><library_materials><material id="iaf_outer" name="iaf_outer"><instance_effect url="#outer-fx"/></material><material id="iaf_core" name="iaf_core"><instance_effect url="#core-fx"/></material></library_materials><library_geometries>{geoms}</library_geometries><library_visual_scenes><visual_scene id="Scene" name="Scene">{nodes}</visual_scene></library_visual_scenes><scene><instance_visual_scene url="#Scene"/></scene></COLLADA>'''
    (OUT / f'flame_volume_v3_{variant}.dae').write_text(text, encoding='utf-8')

texture('volume_outer.png', False)
texture('volume_core.png', True)
for variant in range(1, 5):
    build(variant)
