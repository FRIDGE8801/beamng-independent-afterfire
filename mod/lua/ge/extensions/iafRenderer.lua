-- Prototype renderer: an original layered 3D shape follows each exhaust outlet.
-- This is geometric volume, not a ray-marched fluid simulation.
local M = {}
local active = {}
local sequence = 0
local LIMIT = 16

local function clearOne(i)
  local item = table.remove(active, i)
  if item and item.node then item.node:delete() end
end

local function pose(vehicle, startNode, endNode)
  local origin = vehicle:getPosition()
  local tail = origin + vehicle:getNodePosition(endNode)
  local root = origin + vehicle:getNodePosition(startNode)
  local direction = tail - root
  if direction:length() < 0.001 then return nil end
  direction:normalize()
  local q = quatFromDir(direction, vec3(0, 0, 1))
  return tail, q
end

local function fire(vehicleId, endNode, startNode, intensity)
  local vehicle = be and be:getObjectByID(vehicleId)
  if not vehicle then return false end
  local pos, rotation = pose(vehicle, startNode, endNode)
  if not pos then return false end
  while #active >= LIMIT do clearOne(1) end
  sequence = sequence + 1
  local node = createObject('TSStatic')
  if not node then return false end
  node.canSave = false
  local shape = '/art/independent_afterfire/flame_volume_v2_' .. tostring(1 + sequence % 2) .. '.dae'
  node:setField('shapeName', 0, shape)
  node:setPosition(pos)
  node:registerObject('iafFlame_' .. tostring(sequence))
  node:setPosRot(pos.x, pos.y, pos.z, rotation.x, rotation.y, rotation.z, rotation.w)
  local strength = 0.55 + math.max(0, math.min(1, intensity or 0)) * 0.45
  node:setScale(vec3(strength, strength, strength))
  if scenetree.MissionGroup then scenetree.MissionGroup:addObject(node) end
  active[#active + 1] = {node = node, vehicle = vehicleId, start = startNode, finish = endNode,
    age = 0, duration = 0.10 + math.max(0, math.min(1, intensity or 0)) * 0.06, strength = strength}
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
      local pos, q = pose(vehicle, item.start, item.finish)
      if pos then
        item.node:setPosRot(pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w)
        local life = math.max(0, math.min(1, item.age / item.duration))
        local growth = math.min(1, life * 5) * math.min(1, (1-life) * 3)
        local scale = item.strength * (0.35 + 0.65 * growth)
        item.node:setScale(vec3(scale, scale, scale))
      else clearOne(i) end
    end
  end
end

local function onExtensionUnloaded()
  for i = #active, 1, -1 do clearOne(i) end
end

local function getActiveCount() return #active end
M.fire = fire
M.onUpdate = onUpdate
M.onExtensionUnloaded = onExtensionUnloaded
M.getActiveCount = getActiveCount
return M
