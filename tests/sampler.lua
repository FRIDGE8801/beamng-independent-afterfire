-- Run in vehicle Lua. Deterministic sub-frame cuts with isolated engine mocks.
local engine = {outputAV1=800, revLimiterAV=1000, instantAfterFireCoef=.8,
  sustainedAfterFireCoef=0, requestedThrottle=.9, revLimiterActive=false}
local values = {throttle_input=.9, gearIndex=3}
local env = setmetatable({powertrain={getDevice=function() return engine end}, electrics={values=values}}, {__index=_G})
local chunk = assert(loadfile('/lua/vehicle/controller/iafSignalSampler.lua'))
setfenv(chunk, env)
local sampler = chunk()
sampler.init()
local function step(cut, dt)
  engine.revLimiterActive=cut
  sampler.update(dt or .0005)
end
step(false)
-- Entire on/off pulse occurs between two graphics updates.
step(true); step(false)
local event = assert(sampler.takeEvent())
assert(event.kind=='limiter' and event.age>.0 and sampler.takeEvent()==nil)
assert(sampler.getStats().cuts==1 and sampler.getStats().limiter==1)
step(true); step(false); step(true); step(false)
assert(sampler.takeEvent().kind=='limiter')
assert(sampler.getStats().coalesced==1, 'slow frames retain only the latest event')
step(true); step(false)
for i=1,5 do step(false,.05) end
assert(sampler.takeEvent()==nil and sampler.getStats().stale==1, 'old flames must expire')
sampler.reset()
step(false); step(true)
engine = {outputAV1=800,revLimiterAV=1000,instantAfterFireCoef=.8,revLimiterActive=false}
values.throttle_input=.1
step(false)
assert(sampler.takeEvent()==nil, 'engine replacement must clear pending events and baselines')
values.throttle_input=.9
step(false); step(true)
sampler.reset()
assert(sampler.takeEvent()==nil and sampler.getStats().events==0)
engine.instantAfterFireCoef=0
step(false); step(true)
assert(sampler.takeEvent()==nil and sampler.getStats().cuts==1, 'an incapable engine must not emit')
assert(engine.revLimiterActive==true and engine.outputAV1==800, 'sampler must not alter engine state')
return 'physics sampler tests passed'
