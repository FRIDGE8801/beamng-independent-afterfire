-- Independent Afterfire: event detection independent of the renderer.
local M = {}
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

function M.new()
  return {time = 0, lastEvent = -10, prevThrottle = nil, prevGear = nil, prevCut = false}
end

-- Returns at most one event per graphics update. This does not mutate engine state
-- or consume BeamNG's afterfire queues.
function M.advance(state, input, dt)
  dt = clamp(tonumber(dt) or 0, 0, 0.1)
  state.time = state.time + dt
  local throttle = clamp(tonumber(input.throttle) or 0, 0, 1)
  local rpmFraction = clamp(tonumber(input.rpmFraction) or 0, 0, 2)
  local capability = math.max(0, tonumber(input.capability) or 0)
  local cut = input.limiterCut == true
  local gear = tonumber(input.gear)
  local kind

  if input.running ~= false and capability > 0.05 and rpmFraction >= 0.55 then
    if cut and not state.prevCut and throttle > 0.6 then
      kind = 'limiter'
    elseif gear and state.prevGear and gear > 0 and state.prevGear > 0 and gear ~= state.prevGear
        and math.max(throttle, state.prevThrottle or 0) > 0.5 then
      kind = 'shift'
    elseif state.prevThrottle and state.prevThrottle > 0.65 and throttle < 0.3 then
      kind = 'lift'
    end
  end

  state.prevThrottle, state.prevGear, state.prevCut = throttle, gear, cut
  if not kind then return nil end
  -- Limiter events follow observed cuts; lift and shift use a short debounce.
  local gap = kind == 'limiter' and 0.035 or 0.16
  if state.time - state.lastEvent < gap then return nil end
  state.lastEvent = state.time
  return {kind = kind, intensity = clamp(capability * rpmFraction, 0.1, 1)}
end

return M
