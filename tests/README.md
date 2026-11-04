# Prototype checks

`detector.lua` is a small deterministic test for the event detector. It is
designed to run in a BeamNG vehicle Lua VM with the prototype mounted and a
copy of the test file in the isolated profile's root:

```lua
dofile('/iaf-detector-test.lua')
```

The assertions cover a lift, direct and manual-neutral gear changes, repeated
physics-step limiter edges, and stopped, low-RPM, and incapable engines. They
also reject false shifts after a long neutral coast or reverse, suppress a
spurious cut when attaching during an existing cut, and verify that a limiter
event does not suppress the driver's next throttle lift.

Copy `sampler.lua` and `prototype.lua` to the isolated profile as
`/iaf-sampler-test.lua` and `/iaf-prototype-test.lua`, then run them with `dofile`
in vehicle Lua. These use local mocks: sub-frame pulses, one-time consumption,
coalescing, stale expiry, engine replacement, resets, controller ownership,
unload, outlet attenuation and water filtering. They do not modify the live
engine or its fuel queues.

An isolated 0.40.4 test manually triggered each event and confirmed that both
outlets received the selected profile. Movement captures at approximately
180 km/h exposed static-render-object trailing. Dynamic instance rendering and
reused outlet pools removed the visible detached plume in subsequent captures.
This does not prove alignment at every frame rate, speed, or camera angle.

`renderer.lua` exercises reuse, hidden-object tracking, collision exclusion,
visibility after a burst, and cleanup using local scene mocks inside GE Lua.
It also checks weak-intensity scaling, dark limiter gaps, expired-event rejection,
first-frame timing and cancellation on vehicle reset.
Copy it to the test profile as `/iaf-renderer-test.lua`, then run
`dofile('/iaf-renderer-test.lua')` in the game-engine console.

Run `python tests/test_assets.py` from the project root to check the packaged
geometry, materials, textures, and references without launching the game.

## Real engine comparison

In an isolated test profile only, copy `limiterProbe.lua` to
`lua/vehicle/controller/iafCutProbe.lua`. With the mod attached and the car
stationary in neutral, run in vehicle Lua:

```lua
extensions.iafPrototype.onReset()
controller.loadControllerExternal('iafCutProbe', 'iafCutProbe', {})
updateCorePhysicsStepEnabled()
input.event('throttle', 1, 1)
```

The probe records eight seconds of real engine cuts at both physics and graphics
rates, releases the throttle and writes `/iaf-physics-probe.json`. Unload it with
`controller.unloadControllerExternal('iafCutProbe')`. Use an undamaged car on a
flat test area. Set the gearbox behavior and frame limit first, allow settings
to settle, and then select neutral: applying settings can reapply the default
gearbox behavior. The snapshot is taken in controller `updateGFX`, before the
extension drains the current frame's mailbox, so its delivery counters can lag
the captured-edge counter by one event.

See [the validation notes](../docs/validation-2026-11-04.md). A physics edge count
does not guarantee that every cut is separately visible at every frame rate.
