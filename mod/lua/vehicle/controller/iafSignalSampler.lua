-- Original, read-only auxiliary controller. BeamNG invokes update after powertrain.
local detector = require('extensions/iafEventDetector')
local M = {type = 'auxiliary', defaultOrder = 1000000}
local state, engine, pending, stats

local function reset()
  state, engine, pending = detector.new(), nil, nil
  stats = {steps=0, cuts=0, events=0, limiter=0, shift=0, lift=0, coalesced=0, stale=0}
end

local function update(dt)
  local current = powertrain.getDevice('mainEngine')
  if current ~= engine then
    -- Replacing an engine must not look like a throttle lift or a gear change.
    state, pending, engine = detector.new(), nil, current
  end
  if not engine then return end
  stats.steps = stats.steps + 1
  local values = electrics.values
  local cut = engine.revLimiterActive == true
  if cut and state.prevCut == false then stats.cuts = stats.cuts + 1 end
  local limit = tonumber(engine.revLimiterAV) or tonumber(engine.maxAV) or 1
  local event = detector.advance(state, {
    running = not (engine.isDisabled or engine.isStalled),
    throttle = values.throttle_input or values.throttle or engine.requestedThrottle or 0,
    rpmFraction = math.abs(tonumber(engine.outputAV1) or 0) / math.max(limit, 1),
    capability = math.max(tonumber(engine.instantAfterFireCoef) or 0, tonumber(engine.sustainedAfterFireCoef) or 0),
    limiterCut = cut,
    gear = values.gearIndex,
  }, dt)
  if event then
    stats.events = stats.events + 1
    stats[event.kind] = stats[event.kind] + 1
    if pending then stats.coalesced = stats.coalesced + 1 end
    -- One bounded mailbox: a slow frame never replays a backlog of old flames.
    pending = event
  end
end

local function takeEvent()
  local event = pending
  pending = nil
  if event then
    event.age = state.time - event.time
    if event.age > 0.2 then stats.stale = stats.stale + 1; return nil end
  end
  return event
end

local function getStats() return stats end
M.init = reset
M.reset = reset
M.update = update
M.takeEvent = takeEvent
M.getStats = getStats
return M
