-- Trigger the independent prototype renderer at each eligible exhaust outlet.
local M = {}
local sampler
local stats = {events = 0, emitted = 0, lastKind = ''}

local function emit(engine, event)
  local ends = engine.thermals and engine.thermals.exhaustEndNodes or {}
  for _, outlet in pairs(ends) do
    if outlet.finish and outlet.start and (outlet.afterFireVisualCoef or 1) > 0 and not obj:inWater(outlet.finish) then
      obj:queueGameEngineLua(string.format(
        "local r=rawget(extensions,'iafRenderer'); if r then r.fire(%d,%d,%d,%.3f,%q,%.6f,%.6f) end",
        obj:getId(), outlet.finish, outlet.start, event.intensity * math.min(1, outlet.afterFireVisualCoef or 1),
        event.kind, event.interval or 0, event.age or 0))
      stats.emitted = stats.emitted + 1
    end
  end
end

local function updateGFX()
  local engine = powertrain.getDevice('mainEngine')
  if not sampler then return end
  local event = sampler.takeEvent()
  if not engine then return end
  if event then
    stats.events = stats.events + 1
    stats.lastKind = event.kind
    emit(engine, event)
  end
end

local function reset()
  if sampler then sampler.reset() end
  stats = {events = 0, emitted = 0, lastKind = ''}
end

local function onExtensionLoaded()
  local existing = controller.getController('iafSignalSampler')
  if existing then
    log('E', 'iafPrototype', 'Signal sampler name is already in use; attachment skipped')
    return
  end
  sampler = controller.loadControllerExternal('iafSignalSampler', 'iafSignalSampler', {})
  if updateCorePhysicsStepEnabled then updateCorePhysicsStepEnabled() end
end

local function onExtensionUnloaded()
  if sampler and controller.getController('iafSignalSampler') == sampler then
    controller.unloadControllerExternal('iafSignalSampler')
    if updateCorePhysicsStepEnabled then updateCorePhysicsStepEnabled() end
  end
  sampler = nil
end

local function getStats()
  return {events=stats.events, emitted=stats.emitted, lastKind=stats.lastKind,
    sampling=sampler and 'physics' or 'unavailable', signal=sampler and sampler.getStats() or nil}
end

M.updateGFX = updateGFX
M.onReset = reset
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.getStats = getStats
return M
