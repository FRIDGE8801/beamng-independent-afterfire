-- Run in BeamNG GE Lua with the mod mounted. Mock scene objects only inside
-- this module's environment; the live scene and engine globals are unchanged.
local allocated = {}
local vehicle = {origin = vec3(0,0,0)}
function vehicle:getPosition() return self.origin end
function vehicle:getNodePosition(id) return id == 1 and vec3(0,0,0) or vec3(0,1,0) end
local function object()
  local o = {fields = {}, hidden = false, deleted = false}
  function o:setField(key, _, value) self.fields[key] = value end
  function o:setPosition(p) self.position = vec3(p) end
  function o:registerObject(name) self.name = name end
  function o:setPosRot(x,y,z) self.position = vec3(x,y,z) end
  function o:setHidden(value) self.hidden = value end
  function o:setScale(value) self.scale = value end
  function o:delete() self.deleted = true end
  allocated[#allocated + 1] = o
  return o
end
local env = setmetatable({
  createObject = object,
  be = {getObjectByID = function(_,id) return id == 123 and vehicle or nil end},
  scenetree = {MissionGroup = {addObject = function() end}},
}, {__index = _G})
local chunk = assert(loadfile('/lua/ge/extensions/iafRenderer.lua'))
setfenv(chunk, env)
local renderer = chunk()
assert(renderer.fire(999,2,1,1,'shift') == false)
assert(#allocated == 0)
assert(renderer.fire(123,2,1,0,'limiter') == false)
assert(#allocated == 0, 'zero intensity must not create a flame pool')
assert(renderer.fire(123,2,1,.8,'limiter'))
assert(#allocated == 4)
for _,o in ipairs(allocated) do
  assert(o.dynamic == true and o.useInstanceRenderData == true)
  assert(o.fields.collisionType == 'None')
end
renderer.onPreRender(.02,.02)
local function visible()
  local count = 0
  for _,o in ipairs(allocated) do if not o.deleted and not o.hidden then count = count + 1 end end
  return count
end
assert(visible() == 1)
local strongScale
for _,o in ipairs(allocated) do if not o.hidden then strongScale=o.scale.x end end
assert(renderer.fire(123,2,1,.04,'limiter'))
renderer.onPreRender(.02,.02)
local weakScale
for _,o in ipairs(allocated) do if not o.hidden then weakScale=o.scale.x end end
assert(weakScale<strongScale*.3, 'weak exhaust attenuation must substantially reduce flame size')
assert(renderer.fire(123,2,1,.8,'limiter'))
renderer.onPreRender(.02,.02)
renderer.onPreRender(.02,.02)
assert(visible() == 1)
renderer.onPreRender(.05,.05)
assert(visible() == 0, 'limiter burst must leave a dark gap before the next cut')
assert(renderer.fire(123,2,1,.8,'limiter',.1,.06) == false, 'expired cuts must not be replayed')
assert(renderer.fire(123,2,1,.8,'limiter',.1,.04))
renderer.onPreRender(.03,.03)
assert(visible() == 1, 'first render must not age a captured event by a second frame')
vehicle.origin = vec3(50,-20,0)
renderer.onPreRender(.02,.02)
for _,o in ipairs(allocated) do assert((o.position - vec3(50,-19,0)):length() < 0.0001) end
assert(renderer.fire(123,2,1,.8,'lift'))
assert(#allocated == 4, 'repeat bursts must reuse the outlet pool')
for i=1,10 do renderer.onPreRender(.05,.05) end
assert(visible() == 0 and renderer.getActiveCount() == 0)
assert(renderer.fire(123,2,1,.8,'shift'))
assert(#allocated == 4)
renderer.onVehicleDestroyed(123)
for _,o in ipairs(allocated) do assert(o.deleted) end
renderer.onExtensionUnloaded()
local checkpoint = #allocated
for outlet=2,18 do assert(renderer.fire(123,outlet,1,.8,'shift')) end
local living = 0
for i=checkpoint+1,#allocated do if not allocated[i].deleted then living=living+1 end end
assert(living == 64, 'outlet pools must have a fixed upper bound')
renderer.onVehicleSpawned(123)
for _,o in ipairs(allocated) do assert(o.deleted) end
assert(renderer.fire(123,2,1,.8,'shift'))
renderer.onVehicleResetted(123)
for _,o in ipairs(allocated) do assert(o.deleted, 'reset must cancel flames at the old pose') end
assert(renderer.fire(123,2,1,.8,'shift'))
for i=1,610 do renderer.onPreRender(.1,.1) end
for _,o in ipairs(allocated) do assert(o.deleted, 'idle pools must be released') end
return 'renderer lifecycle tests passed'
