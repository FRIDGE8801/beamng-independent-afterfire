-- Original layered geometry, not a ray-marched fluid simulation.
local M = {}
local pools, sequence = {}, 0
local LIMIT = 16
local profiles = {
  limiter = {width = .85, length = .86, duration = .11},
  shift = {width = 1, length = .92, duration = .13},
  lift = {width = 1.1, length = .74, duration = .15},
}
local function pose(vehicle, first, last)
  local origin = vehicle:getPosition()
  local tail = origin + vehicle:getNodePosition(last)
  local direction = tail - (origin + vehicle:getNodePosition(first))
  if direction:length() < .001 then return nil end
  direction:normalize()
  return tail, quatFromDir(direction, vec3(0,0,1))
end
local function destroy(key)
  local p = pools[key]
  if not p then return end
  for _, node in ipairs(p.nodes) do node:delete() end
  pools[key] = nil
end
local function position(node, pos, q)
  node:setPosRot(pos.x,pos.y,pos.z,q.x,q.y,q.z,q.w)
end
local function acquire(id, first, last, pos, q)
  local key = tostring(id)..':'..tostring(first)..':'..tostring(last)
  if pools[key] then return pools[key] end
  local count, oldest, idle = 0, nil, -1
  for k,p in pairs(pools) do
    count=count+1
    if p.idle>idle then oldest,idle=k,p.idle end
  end
  if count>=LIMIT and oldest then destroy(oldest) end
  local p={vehicle=id,first=first,last=last,nodes={},idle=0,age=0}
  for variant=1,4 do
    sequence=sequence+1
    local node=createObject('TSStatic')
    if not node then for _,old in ipairs(p.nodes) do old:delete() end;return nil end
    node.canSave=false
    node.dynamic=true
    node.useInstanceRenderData=true
    node:setField('collisionType',0,'None')
    node:setField('decalType',0,'None')
    node:setField('shapeName',0,'/art/independent_afterfire/flame_volume_v3_'..variant..'.dae')
    node:setPosition(pos)
    node:registerObject('iafFlame_'..sequence)
    position(node,pos,q)
    node:setHidden(true)
    if scenetree.MissionGroup then scenetree.MissionGroup:addObject(node) end
    p.nodes[variant]=node
  end
  pools[key]=p
  return p
end
local function fire(id,last,first,intensity,kind)
  local vehicle=be and be:getObjectByID(id)
  if not vehicle then return false end
  local pos,q=pose(vehicle,first,last)
  if not pos then return false end
  local p=acquire(id,first,last,pos,q)
  if not p then return false end
  p.variant=1+((p.variant or 0)%4)
  local profile=profiles[kind] or profiles.shift
  local power=math.max(0,math.min(1,tonumber(intensity) or 0))
  local strength=.55+power*.45
  p.width=strength*profile.width
  p.length=strength*profile.length*(.92+p.variant*.04)
  p.duration=profile.duration+power*.025
  p.age,p.idle=0,0
  return true
end
local function onPreRender(dtReal,dtSim)
  local dt=math.max(0,math.min(dtSim or 0,.1))
  for key,p in pairs(pools) do
    local vehicle=be and be:getObjectByID(p.vehicle)
    local pos,q
    if vehicle then pos,q=pose(vehicle,p.first,p.last) end
    if not pos then destroy(key)
    else
      p.age,p.idle=p.age+dt,p.idle+dt
      local lit=p.duration and p.age<p.duration
      local life=lit and p.age/p.duration or 1
      local growth=math.min(1,life*5)*math.min(1,(1-life)*3)
      local scale=.35+.65*growth
      for variant,node in ipairs(p.nodes) do
        -- Keep hidden variants moving too; avoid creating new world objects
        -- on every ignition and losing their previous render transform.
        position(node,pos,q)
        node:setHidden(not(lit and variant==p.variant))
        if lit and variant==p.variant then node:setScale(vec3(p.width*scale,p.length*scale,p.width*scale)) end
      end
      if p.idle>60 then destroy(key) end
    end
  end
end
local function clear() for key in pairs(pools) do destroy(key) end end
local function getActiveCount()
  local count=0
  for _,p in pairs(pools) do if p.duration and p.age<p.duration then count=count+1 end end
  return count
end
M.fire=fire
M.onPreRender=onPreRender
M.onExtensionUnloaded=clear
M.onClientEndMission=clear
local function clearVehicle(id)
  for key,p in pairs(pools) do if p.vehicle==id then destroy(key) end end
end
M.onVehicleDestroyed=clearVehicle
M.onVehicleSpawned=clearVehicle
M.getActiveCount=getActiveCount
return M
