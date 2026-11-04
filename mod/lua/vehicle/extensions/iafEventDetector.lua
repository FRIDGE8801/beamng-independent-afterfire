-- Independent Afterfire: event detection independent of the renderer.
local M = {}
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end

function M.new()
  return {time = 0, lastTransient = -10, prevThrottle = nil, prevCut = nil}
end

-- Called after each physics step by our auxiliary controller. Does not mutate engine state
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
  local edge = cut and state.prevCut == false
  local interval = edge and state.lastCut and (state.time - state.lastCut) or nil
  if edge then state.lastCut = state.time end

  if input.running ~= false and capability > 0.05 and rpmFraction >= 0.55 then
    if edge and throttle > 0.6 then
      kind = 'limiter'
    elseif gear and gear > 0 and state.lastForwardGear and gear ~= state.lastForwardGear
        and state.time - state.lastForwardTime <= 0.5
        and math.max(throttle, state.prevThrottle or 0) > 0.5 then
      kind = 'shift'
    elseif state.prevThrottle and state.prevThrottle > 0.65 and throttle < 0.3 then
      kind = 'lift'
    end
  end

  -- A manual gearbox commonly reports neutral while the clutch is open.
  -- Remember the last engaged forward gear briefly, but never across reverse.
  if gear and gear > 0 then
    state.lastForwardGear, state.lastForwardTime = gear, state.time
  elseif gear and gear < 0 then
    state.lastForwardGear, state.lastForwardTime = nil, nil
  end
  state.prevThrottle, state.prevCut = throttle, cut
  if not kind then return nil end
  -- Real limiter edges need no synthetic beat. A limiter burst must not suppress
  -- the driver's next throttle lift through the transient debounce either.
  if kind ~= 'limiter' then
    if state.time - state.lastTransient < 0.16 then return nil end
    state.lastTransient = state.time
  end
  return {kind = kind, intensity = clamp(capability * rpmFraction, 0.1, 1),
    time = state.time, interval = kind == 'limiter' and interval or nil}
end

return M
