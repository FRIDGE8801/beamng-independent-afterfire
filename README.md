# Independent Afterfire for BeamNG.drive

An experimental, independently written exhaust-flame mod. This repository is an
early prototype, not a finished or repository-ready release.

The first milestone is a small event detector that responds to throttle lift,
gear changes and detected rev-limiter cuts. It uses BeamNG.drive's built-in
particle effects temporarily while a new visual effect is developed. The
prototype does not include assets or source from other mods. BeamNG.drive is
required and its built-in effects remain the property of their respective owners.

The current implementation samples vehicle state once per graphics update.
Short limiter cuts between updates can be missed; synchronization is unfinished.
The extension is not automatically installed or enabled in a normal game.

## Development status

- Independent event detector and temporary in-game particle preview: work in progress.
- Original flame rendering, configuration interface and sound: not implemented.
- Exhaust heat: not implemented in this project.

The project is being tested in a separate game profile. Do not use the
experimental prototype alongside another afterfire mod: both may emit effects.
