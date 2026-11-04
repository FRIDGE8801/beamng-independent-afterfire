-- Isolated extension lifecycle and outlet filtering in vehicle Lua.
local commands, rendered, resets, loads, unloads, enabled = {}, {}, 0, 0, 0, 0
local event
local sampler = {
  reset=function() resets=resets+1 end,
  takeEvent=function() local e=event; event=nil; return e end,
  getStats=function() return {steps=42} end,
}
local current
local engine = {instantAfterFireFuel=123, shiftAfterFireFuel=456, thermals={exhaustEndNodes={
  {start=1,finish=2,afterFireVisualCoef=.2},
  {start=1,finish=3,afterFireVisualCoef=0},
  {start=1,finish=4,afterFireVisualCoef=1},
  {finish=5},
}}}
local env = setmetatable({
  powertrain={getDevice=function() return engine end},
  controller={
    getController=function() return current end,
    loadControllerExternal=function() loads=loads+1; current=sampler; return sampler end,
    unloadControllerExternal=function() unloads=unloads+1; current=nil end,
  },
  obj={getId=function() return 123 end, inWater=function(_,id) return id==4 end,
    queueGameEngineLua=function(_,code) commands[#commands+1]=code end},
  updateCorePhysicsStepEnabled=function() enabled=enabled+1 end,
  log=function() end,
}, {__index=_G})
local function load()
  local chunk=assert(loadfile('/lua/vehicle/extensions/iafPrototype.lua'))
  setfenv(chunk,env)
  return chunk()
end
local prototype=load()
prototype.onExtensionLoaded()
assert(loads==1 and enabled==1 and prototype.getStats().sampling=='physics')
event={kind='limiter',intensity=1,interval=.1,age=.02}
prototype.updateGFX(.03)
assert(#commands==1, 'only an eligible outlet outside water should emit')
local geEnv={extensions={iafRenderer={fire=function(...) rendered={...} end}},rawget=rawget}
local command=assert(loadstring(commands[1])); setfenv(command,geEnv); command()
assert(rendered[1]==123 and rendered[2]==2 and rendered[3]==1)
assert(rendered[4]==.2 and rendered[5]=='limiter' and rendered[6]==.1 and rendered[7]==.02)
prototype.updateGFX(.03)
assert(#commands==1, 'each captured event must be consumed once')
assert(engine.instantAfterFireFuel==123 and engine.shiftAfterFireFuel==456)
prototype.onReset()
assert(resets==1 and prototype.getStats().events==0)
prototype.onExtensionUnloaded()
assert(unloads==1 and enabled==2 and current==nil)
prototype.onExtensionUnloaded()
assert(unloads==1, 'unload must be idempotent')
prototype=load(); prototype.onExtensionLoaded()
current={} -- Another owner replaced the controller: do not remove its object.
prototype.onExtensionUnloaded()
assert(unloads==1 and current~=nil)
prototype=load(); prototype.onExtensionLoaded()
assert(loads==2 and prototype.getStats().sampling=='unavailable', 'do not overwrite another controller')
return 'prototype lifecycle tests passed'
