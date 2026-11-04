-- Run inside BeamNG's vehicle Lua VM: dofile('/iaf-detector-test.lua').
local detector = require('extensions/iafEventDetector')
local function sample(t, overrides)
  local s = {running = true, throttle = t, rpmFraction = 0.8, capability = 0.6, gear = 3, limiterCut = false}
  for k, v in pairs(overrides or {}) do s[k] = v end
  return s
end
local function step(st, s, dt) return detector.advance(st, s, dt or 0.2) end
local s = detector.new()
assert(step(s, sample(0.8)) == nil)
assert(step(s, sample(0.1)).kind == 'lift')
assert(step(s, sample(0.1)) == nil)
s = detector.new(); step(s, sample(0.8))
assert(step(s, sample(0.8, {gear = 4})).kind == 'shift')
s = detector.new(); step(s, sample(.8, {gear=1}))
assert(step(s, sample(.8, {gear=0}), .08)==nil)
assert(step(s, sample(.8, {gear=2}), .08).kind=='shift', 'manual shifts must survive a short neutral phase')
s = detector.new(); step(s, sample(.8, {gear=1}))
for i=1,8 do step(s, sample(.8, {gear=0}), .1) end
assert(step(s, sample(.8, {gear=2}), .01)==nil, 'selecting a gear after coasting in neutral is not a shift burst')
s = detector.new(); step(s, sample(.8, {gear=1}))
step(s, sample(.8, {gear=-1}), .01)
assert(step(s, sample(.8, {gear=2}), .01)==nil, 'reverse must clear forward-gear history')
s = detector.new(); step(s, sample(0.9))
assert(step(s, sample(0.9, {limiterCut = true})).kind == 'limiter')
assert(step(s, sample(0.9, {limiterCut = true})) == nil)
step(s, sample(0.9)); assert(step(s, sample(0.9, {limiterCut = true})).kind == 'limiter')
s = detector.new(); step(s, sample(0.8, {capability = 0}))
assert(step(s, sample(0.1, {capability = 0})) == nil)
s = detector.new(); step(s, sample(0.8, {rpmFraction = 0.3}))
assert(step(s, sample(0.1, {rpmFraction = 0.3})) == nil)
s = detector.new(); step(s, sample(0.8)); assert(step(s, sample(0.1, {running = false})) == nil)
s = detector.new()
assert(step(s, sample(0.9, {limiterCut = true})) == nil, 'attachment during a cut is not a new edge')
s = detector.new(); step(s, sample(0.9))
assert(step(s, sample(0.9, {limiterCut = true}), .0005).kind == 'limiter')
step(s, sample(0.9), .02)
local shortCut = step(s, sample(0.9, {limiterCut = true}), .0005)
assert(shortCut and math.abs(shortCut.interval - .0205) < .000001, 'short real cuts must not be debounced away')
assert(step(s, sample(0.1), .0005).kind == 'lift', 'a limiter cut must not suppress a throttle lift')
s = detector.new(); step(s, sample(.9, {rpmFraction=1.01}))
for i=1,100 do
  assert(step(s, sample(.9, {rpmFraction=1.01}), .0005)==nil, 'high RPM alone is not an observed limiter cut')
end
return 'detector tests passed'
