"""Check the generated 3D flame's packaging and geometry using the stdlib."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
assets = root / 'mod/art/independent_afterfire'
ns = {'c': 'http://www.collada.org/2005/11/COLLADASchema'}
materials = json.loads((assets / 'volume.materials.json').read_text(encoding='utf-8'))
assert set(materials) == {'iaf_core', 'iaf_outer'}
for material in materials.values():
    stage = material['Stages'][0]
    for key in ('baseColorMap', 'emissiveMap'):
        asset = root / 'mod' / stage[key].lstrip('/')
        assert asset.is_file(), asset
    assert material['translucent'] and stage['emissive']

for version in (1, 2, 3, 4):
    tree = ET.parse(assets / f'flame_volume_v3_{version}.dae')
    geometries = tree.findall('.//c:geometry', ns)
    assert len(geometries) == 2
    for geometry in geometries:
        arrays = geometry.findall('.//c:float_array', ns)
        assert len(arrays) == 3
        for array in arrays:
            assert int(array.get('count')) == len(array.text.split())
        for tri in geometry.findall('.//c:triangles', ns):
            indices = [int(value) for value in tri.find('c:p', ns).text.split()]
            assert len(indices) == int(tri.get('count')) * 9
            assert min(indices) >= 0
            for offset, array in enumerate(arrays):
                stride = 2 if offset == 2 else 3
                assert max(indices[offset::3]) < int(array.get('count')) // stride
print('3D flame assets validated')
