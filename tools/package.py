"""Build a development mod ZIP containing only the runtime mod directory."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

project = Path(__file__).resolve().parents[1]
source = project / 'mod'
output = project / 'dist/independent_afterfire_dev.zip'
output.parent.mkdir(parents=True, exist_ok=True)
with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(source.rglob('*')):
        if not path.is_file() or '__pycache__' in path.parts:
            continue
        name = path.relative_to(source).as_posix()
        entry = ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, path.read_bytes())
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert 'info.json' in archive.namelist()
    assert 'scripts/independent_afterfire/modScript.lua' in archive.namelist()
    assert 'lua/vehicle/controller/iafSignalSampler.lua' in archive.namelist()
print(output)
