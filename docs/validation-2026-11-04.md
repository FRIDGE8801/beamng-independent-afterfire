# Physics-step event validation — 2026-11-04

BeamNG.drive 0.40.4, isolated test profile, Gridmap V2. Other afterfire mods were
disabled. The normal user profile was not changed. Geometry, textures and the
approved warm material colors were preserved.

## Real limiter cuts

Each run used eight simulated seconds of ordinary full-throttle input in neutral.
An independent read-only controller counted `revLimiterActive` rising edges
after powertrain updates and compared them with the same flag read once per
graphics update. Both foreground and background frame limits were set, and
settings were allowed to settle before selecting neutral. The final Bolide
runs used an upright, reset car on a flat area.

| Configuration | Requested FPS | Graphics updates | Physics cut edges | New detector limiter events | Graphics-only cut edges |
|---|---:|---:|---:|---:|---:|
| Bolide GTR, `race.pc` | 30 | 241 | 72 | 72 | 57 |
| Bolide GTR, `race.pc` | 60 | 482 | 72 | 72 | 71 |
| ETK I-Series stock, `2400_M.pc` | 60 | 481 | 30 | 30 | 30 |
| ETK I-Series race, `race.pc` | 30 | 241 | 46 | 46 | 46 |

All four tested configurations used the game's `timeBased` limiter. Counts include
spin-up and do not imply identical cut timing or engine behavior between runs.
Stock ETK's exhaust had `afterFireVisualCoef=0`: the detector observed its cuts
but sent **zero flame requests**. Race ETK had two eligible outlets with a visual
coefficient of 0.3, and sent 92 outlet requests for 46 detected events.

The probe snapshots the extension's delivery counters before its `updateGFX`
mailbox drain. A final captured event can therefore still be pending in that
snapshot. The comparison above uses the sampler's captured limiter count,
not a claim that every edge produced a separately visible frame.

## Ordinary driving

One eight-second ETK race run used standard throttle, clutch assistance, a
requested 1→2 shift, throttle release and braking. Velocity and flame events were
not injected. It reached 25.55 m/s (about 92 km/h). The actual gearbox reported
1→0→2, with a neutral phase of about 0.067 seconds. The detector captured one
shift and one throttle-lift event, sent to both eligible outlets. The earlier
detector lost this shift because it required consecutive positive gears.

## Visual recording and local tests

`media/real-limiter.gif` shows real Bolide limiter-triggered flashes in neutral
on Smallgrid, after a fresh game launch using the packaged ZIP.
The game recorded 60 screenshots over about one second at roughly 60 FPS;
the GIF retains alternate screenshots with elapsed-time-based durations.
The capture code never called the renderer to force a burst. Warm, dense bursts
and intervening dark frames are visible. Older demo GIFs use forced events and
remain labeled accordingly in the README.

Deterministic vehicle-Lua tests cover event edges, short neutral phases,
debouncing, initial attachment during a cut, sub-frame capture, bounded event
delivery, stale expiry, engine replacement, reset, controller ownership and
outlet filtering. GE Lua tests cover renderer reuse, dynamic flags, motion of
hidden variants, limits, cleanup, intensity scaling, burst gaps and first-frame
event age. Python validates the original 3D assets. Packaging is deterministic
and includes only runtime mod files. A fresh launch confirmed that all four
runtime Lua files came from the ZIP, with the development overrides removed.
All four Lua test suites passed in that launch, and actual unload/reload removed
and recreated only our auxiliary controller while preserving every other
controller object.

## Limits

- Throttle and gear values still originate in graphics-updated electrics. The
  physics controller cannot recover input transitions the game did not publish.
- A mailbox retains the latest event in a graphics frame. Excess events are
  coalesced, and expired flashes are discarded rather than replayed late.
- Limiter duration uses the previous measured cut interval, leaving a dark
  portion of a stable cycle. Sudden cadence changes and very low frame rates
  can still reduce visible separation.
- This is an effect linked to engine state, not exhaust-gas transport, a fuel
  combustion model or a fluid simulation. Sound is still the game's sound.
- Only the configurations, frame rates and short driving run listed above were
  checked. Soft and RPM-drop limiters, other mods, many other vehicles and
  long sessions still need testing.
