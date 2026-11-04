-- Isolated read-only signal comparison; uses the game's controller lifecycle.
local M = {type = 'auxiliary', defaultOrder = 1000000}
local elapsed, prev, gfxPrev, lastEdge, stats, resultPath
local function init(data)
  elapsed, prev, gfxPrev, lastEdge = 0, false, false, nil
  stats = {steps=0, frames=0, cuts=0, gfxCuts=0, intervals={}, samples={}}
  resultPath=data and data.resultPath or '/iaf-physics-probe.json'
end
local function update(dt)
  local e = powertrain.getDevice('mainEngine')
  if not e then return end
  if stats.done then return end
  elapsed = elapsed + dt
  stats.steps = stats.steps + 1
  local cut = e.revLimiterActive == true
  if cut and not prev then
    stats.cuts = stats.cuts + 1
    if lastEdge then stats.intervals[#stats.intervals+1] = elapsed-lastEdge end
    lastEdge = elapsed
    if #stats.samples<12 then stats.samples[#stats.samples+1] = {t=elapsed, rpm=e.outputAV1*9.5492966, throttle=e.requestedThrottle, fuel=e.instantAfterFireFuel} end
  end
  prev = cut
end
local function updateGFX(dt)
  local e = powertrain.getDevice('mainEngine')
  if not e then return end
  if stats.done then return end
  stats.frames = stats.frames+1
  local cut = e.revLimiterActive == true
  if cut and not gfxPrev then stats.gfxCuts=stats.gfxCuts+1 end
  gfxPrev=cut
  if elapsed>8 and not stats.done then
    stats.done=true
    stats.elapsed=elapsed
    stats.engine={limiter=e.revLimiterType, instant=e.instantAfterFireCoef, sustained=e.sustainedAfterFireCoef, outlets=e.thermals and e.thermals.exhaustEndNodes}
    local prototype=rawget(extensions,'iafPrototype')
    stats.runtime=prototype and prototype.getStats() or nil
    input.event('throttle',0,1)
    obj:queueGameEngineLua("jsonWriteFile("..string.format('%q',resultPath)..","..serialize(stats)..",true)")
  end
end
M.init=init
M.reset=init
M.update=update
M.updateGFX=updateGFX
return M
