-- Load the mod's game-side bootstrap when BeamNG mounts the archive.
loadJsonMaterialsFile('/art/independent_afterfire/volume.materials.json')
setExtensionUnloadMode('iafRenderer', 'manual')
extensions.load('iafRenderer')
setExtensionUnloadMode('iafBootstrap', 'manual')
extensions.load('iafBootstrap')
