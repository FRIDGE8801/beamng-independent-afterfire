# Prototype checks

`detector.lua` is a small deterministic test for the event detector. It is
designed to run in a BeamNG vehicle Lua VM with the prototype mounted and a
copy of the test file in the isolated profile's root:

```lua
dofile('/iaf-detector-test.lua')
```

The assertions cover a lift, a gear change, repeated sampled limiter edges,
and cases where the engine is stopped, at low RPM, or has no configured
afterfire capability.

The graphics-update loop can miss short physics events between frames. The
current tests intentionally do not claim frame-perfect limiter synchronization
or verify the visual result during normal driving.

An isolated 0.40.4 test manually triggered each event and confirmed that both
outlets received the selected profile. Movement captures at approximately
180 km/h exposed static-render-object trailing. Dynamic instance rendering and
reused outlet pools removed the visible detached plume in subsequent captures.
This does not prove alignment at every frame rate, speed, or camera angle.

`renderer.lua` exercises reuse, hidden-object tracking, collision exclusion,
visibility after a burst, and cleanup using local scene mocks inside GE Lua.
Copy it to the test profile as `/iaf-renderer-test.lua`, then run
`dofile('/iaf-renderer-test.lua')` in the game-engine console.

Run `python tests/test_assets.py` from the project root to check the packaged
geometry, materials, textures, and references without launching the game.
