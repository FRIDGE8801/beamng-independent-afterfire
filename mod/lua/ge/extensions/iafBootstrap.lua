-- Attach the prototype to the player vehicle without editing vehicle parts.
local M = {}
local seen = {}
local timer = 0

local function attach(id)
  local vehicle = id and be and be:getObjectByID(id)
  if not vehicle then return end
  vehicle:queueLuaCommand("if not rawget(extensions, 'iafPrototype') then extensions.load('iafPrototype') end")
  seen[id] = true
end

local function onUpdate(dtReal)
  timer = timer + (dtReal or 0)
  if timer < 0.5 then return end
  timer = 0
  local player = be and be:getPlayerVehicle(0)
  if player and not seen[player:getID()] then attach(player:getID()) end
end

local function onVehicleSpawned(id)
  seen[id] = nil
end

local function onVehicleDestroyed(id)
  seen[id] = nil
end

local function onExtensionUnloaded()
  for id in pairs(seen) do
    local vehicle = be and be:getObjectByID(id)
    if vehicle then vehicle:queueLuaCommand("if rawget(extensions, 'iafPrototype') then extensions.unload('iafPrototype') end") end
  end
  seen = {}
end

M.onUpdate = onUpdate
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleDestroyed = onVehicleDestroyed
M.onExtensionUnloaded = onExtensionUnloaded
return M
