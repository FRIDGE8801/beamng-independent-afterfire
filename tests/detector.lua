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
s = detector.new(); step(s, sample(0.9))
assert(step(s, sample(0.9, {limiterCut = true})).kind == 'limiter')
assert(step(s, sample(0.9, {limiterCut = true})) == nil)
step(s, sample(0.9)); assert(step(s, sample(0.9, {limiterCut = true})).kind == 'limiter')
s = detector.new(); step(s, sample(0.8, {capability = 0}))
assert(step(s, sample(0.1, {capability = 0})) == nil)
s = detector.new(); step(s, sample(0.8, {rpmFraction = 0.3}))
assert(step(s, sample(0.1, {rpmFraction = 0.3})) == nil)
s = detector.new(); step(s, sample(0.8)); assert(step(s, sample(0.1, {running = false})) == nil)
return 'detector tests passed'
