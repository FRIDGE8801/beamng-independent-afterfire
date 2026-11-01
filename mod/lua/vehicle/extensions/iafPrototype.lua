-- Trigger the independent prototype renderer at each eligible exhaust outlet.
local detector = require('extensions/iafEventDetector')
local M = {}
local state = detector.new()
local stats = {events = 0, emitted = 0, lastKind = ''}

local function emit(engine, event)
  local ends = engine.thermals and engine.thermals.exhaustEndNodes or {}
  for _, outlet in pairs(ends) do
    if outlet.finish and outlet.start and (outlet.afterFireVisualCoef or 1) > 0 and not obj:inWater(outlet.finish) then
      obj:queueGameEngineLua(string.format(
        "if extensions.iafRenderer then extensions.iafRenderer.fire(%d,%d,%d,%.3f) end",
        obj:getId(), outlet.finish, outlet.start, event.intensity))
      stats.emitted = stats.emitted + 1
    end
  end
end

local function updateGFX(dt)
  local engine = powertrain.getDevice('mainEngine')
  if not engine then return end
  local values = electrics.values
  local currentAV = math.abs(tonumber(engine.outputAV1) or 0)
  local limitAV = tonumber(engine.revLimiterAV) or tonumber(engine.maxAV) or 1
  local event = detector.advance(state, {
    running = not (engine.isDisabled or engine.isStalled),
    throttle = values.throttle_input or values.throttle or engine.requestedThrottle or 0,
    rpmFraction = currentAV / math.max(limitAV, 1),
    capability = math.max(tonumber(engine.instantAfterFireCoef) or 0, tonumber(engine.sustainedAfterFireCoef) or 0),
    limiterCut = engine.revLimiterActive == true,
    gear = values.gearIndex,
  }, dt)
  if event then
    stats.events = stats.events + 1
    stats.lastKind = event.kind
    emit(engine, event)
  end
end

local function reset()
  state = detector.new()
  stats = {events = 0, emitted = 0, lastKind = ''}
end

local function getStats() return stats end

M.updateGFX = updateGFX
M.onReset = reset
M.getStats = getStats
return M
