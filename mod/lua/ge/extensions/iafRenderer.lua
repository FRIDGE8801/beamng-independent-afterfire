-- Prototype renderer: an original layered 3D shape follows each exhaust outlet.
-- This is geometric volume, not a ray-marched fluid simulation.
local M = {}
local active = {}
local sequence = 0
local LIMIT = 16
local PROFILES = {
  limiter = {width = 0.85, length = 0.86, duration = 0.11},
  shift = {width = 1.0, length = 0.92, duration = 0.13},
  lift = {width = 1.1, length = 0.74, duration = 0.15},
}

local function clearOne(i)
  local item = table.remove(active, i)
  if item and item.node then item.node:delete() end
end

local function pose(vehicle, startNode, endNode, leadSeconds)
  local origin = vehicle:getPosition()
  -- Scene objects and the soft-body vehicle can reach the visible frame at
  -- slightly different times. Advance by a bounded fraction of the simulated
  -- frame while keeping zero lead when the simulation is paused.
  local lead = vehicle:getVelocity() * (leadSeconds or 0)
  local tail = origin + vehicle:getNodePosition(endNode) + lead
  local root = origin + vehicle:getNodePosition(startNode) + lead
  local direction = tail - root
  if direction:length() < 0.001 then return nil end
  direction:normalize()
  local q = quatFromDir(direction, vec3(0, 0, 1))
  return tail, q
end

local function fire(vehicleId, endNode, startNode, intensity, kind)
  local vehicle = be and be:getObjectByID(vehicleId)
  if not vehicle then return false end
  local pos, rotation = pose(vehicle, startNode, endNode)
  if not pos then return false end
  while #active >= LIMIT do clearOne(1) end
  sequence = sequence + 1
  local node = createObject('TSStatic')
  if not node then return false end
  node.canSave = false
  local shape = '/art/independent_afterfire/flame_volume_v3_' .. tostring(1 + sequence % 4) .. '.dae'
  node:setField('shapeName', 0, shape)
  node:setPosition(pos)
  node:registerObject('iafFlame_' .. tostring(sequence))
  node:setPosRot(pos.x, pos.y, pos.z, rotation.x, rotation.y, rotation.z, rotation.w)
  local strength = 0.55 + math.max(0, math.min(1, intensity or 0)) * 0.45
  local profile = PROFILES[kind] or PROFILES.shift
  local variation = 0.92 + (sequence % 5) * 0.04
  local width, length = strength * profile.width, strength * profile.length * variation
  node:setScale(vec3(width, length, width))
  if scenetree.MissionGroup then scenetree.MissionGroup:addObject(node) end
  active[#active + 1] = {node = node, vehicle = vehicleId, start = startNode, finish = endNode,
    age = 0, duration = profile.duration + math.max(0, math.min(1, intensity or 0)) * 0.025,
    width = width, length = length}
  return true
end

local function onUpdate(dtReal, dtSim)
  local dt = math.max(0, math.min(dtSim or 0, 0.1))
  for i = #active, 1, -1 do
    local item = active[i]
    item.age = item.age + dt
    local vehicle = be and be:getObjectByID(item.vehicle)
    if not vehicle or item.age >= item.duration then
      clearOne(i)
    else
      local pos, q = pose(vehicle, item.start, item.finish, math.min(dt * 0.7, 0.025))
      if pos then
        item.node:setPosRot(pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w)
        local life = math.max(0, math.min(1, item.age / item.duration))
        local growth = math.min(1, life * 5) * math.min(1, (1-life) * 3)
        local scale = 0.35 + 0.65 * growth
        item.node:setScale(vec3(item.width * scale, item.length * scale, item.width * scale))
      else clearOne(i) end
    end
  end
end

local function onExtensionUnloaded()
  for i = #active, 1, -1 do clearOne(i) end
end

local function getActiveCount() return #active end
M.fire = fire
-- Update after vehicle physics, immediately before the frame is drawn.
-- Running during onUpdate can leave the visual one physics frame behind a
-- fast-moving vehicle even though its coordinates are correct at that time.
M.onPreRender = onUpdate
M.onExtensionUnloaded = onExtensionUnloaded
M.getActiveCount = getActiveCount
return M
