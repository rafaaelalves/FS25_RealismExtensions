-- Experimental recovery of ONLY confirmed RE-owned native main-heightmap
-- vertices under GIANTS physically worked tillage parallelograms.
-- Does not touch legacy unknown dents, TerraFarm works, or other mod owners.
RealismExtensionsTerrainCausalRecovery =
    RealismExtensionsTerrainCausalRecovery or {}
local C=RealismExtensionsTerrainCausalRecovery
C.DEFAULTS={
    minDeficitM=0.004,
    maxAreaVertices=120,
    maxPending=512,
    retryMs=250,
    maxPendingAgeMs=15000,
    inFlightTimeoutMs=4500,
    radiusUnitFraction=0.56,
    amount=0.75,
    hardness=0.25,
    strength=0.65,
    maxAttemptsPerVertex=2
}
C.queue={}
C.queueHead=1
C.queueTail=0
C.byKey={}
C.inFlight=nil
C.nextTryMs=0
C.stats={considered=0,accepted=0,completed=0,improved=0,
    unchanged=0,failed=0,collateral=0,expired=0,blocked=0,
    gainSumM=0,maxGainM=0,maxBeforeDeficitM=0,
    physicallyClosed=0,unsafe=0,
    noBaselineVisits=0,untrustedVisits=0,
    toolPLOW=0,toolSUBSOILER=0,toolCULTIVATOR=0,toolOTHER=0}

local function now()
    return g_currentMission~=nil and tonumber(g_currentMission.time) or 0
end
local function journal()
    local r=RealismExtensionsTerrainRuntime
    return r~=nil and r.geometryJournal or nil
end
function C.enabled()
    local cfg=RealismExtensionsConfig
    return g_server~=nil and cfg~=nil and cfg.modules~=nil
        and cfg.modules.TerrainDeformation==true
        and cfg.modules.TerrainRecovery==true
        and cfg.modules.TerrainGeometryJournal==true
        and cfg.modules.TerrainCausalRecovery==true
        and journal()~=nil and journal().unitM~=nil
end
local function inside(x,z,g)
    local det=g.ux*g.vz-g.uz*g.vx
    if math.abs(det)<0.000001 then return false end
    local dx,dz=x-g.xs,z-g.zs
    local a=(dx*g.vz-dz*g.vx)/det
    local b=(g.ux*dz-g.uz*dx)/det
    -- Do not grant recovery across field boundaries or unworked strips.
    return a>=0 and a<=1 and b>=0 and b<=1
end
local function segmentDistanceSquared(px,pz,x0,z0,x1,z1)
    local dx,dz=x1-x0,z1-z0
    local len2=dx*dx+dz*dz
    if len2<=0.00000001 then
        return (px-x0)^2+(pz-z0)^2
    end
    local t=math.max(0,math.min(1,((px-x0)*dx+(pz-z0)*dz)/len2))
    local x,z=x0+t*dx,z0+t*dz
    return (px-x)^2+(pz-z)^2
end

local function nativeVertexTouchesWorkedArea(x,z,g,unit)
    if inside(x,z,g) then return true end
    -- The 1m main-heightmap vertex owns a surrounding surface footprint.
    -- A narrow subsoiler stripe may intersect that footprint without
    -- containing the exact vertex centre. Cap the extension to 45cm.
    local margin=math.min(0.45,0.45*unit)
    if margin<=0 then return false end
    local ax,az=g.xs,g.zs
    local bx,bz=ax+g.ux,az+g.uz
    local cx,cz=bx+g.vx,bz+g.vz
    local dx,dz=ax+g.vx,az+g.vz
    local d2=math.min(
        segmentDistanceSquared(x,z,ax,az,bx,bz),
        segmentDistanceSquared(x,z,bx,bz,cx,cz),
        segmentDistanceSquared(x,z,cx,cz,dx,dz),
        segmentDistanceSquared(x,z,dx,dz,ax,az)
    )
    return d2<=margin*margin
end

local function effort(p)
    local f=math.max(0,math.min(1,
        tonumber(p~=nil and p.surfaceRegrade01) or 0.65))
    local profile=p~=nil and tostring(p.id) or "CULTIVATOR"
    -- Deep compaction relief is not automatically a perfectly flat surface.
    return f,profile
end
function C.reset()
    local j=journal()
    if C.inFlight~=nil and j~=nil then
        j:finishRecovery(C.inFlight.token,false)
    end
    C.queue={};C.queueHead=1;C.queueTail=0
    C.byKey={};C.inFlight=nil;C.nextTryMs=0
    C.stats={considered=0,accepted=0,completed=0,improved=0,
        unchanged=0,failed=0,collateral=0,expired=0,blocked=0,
    gainSumM=0,maxGainM=0,maxBeforeDeficitM=0,
    physicallyClosed=0,unsafe=0,
    noBaselineVisits=0,untrustedVisits=0,
    toolPLOW=0,toolSUBSOILER=0,toolCULTIVATOR=0,toolOTHER=0}
end

-- No global history scan. Direct lookup of native-grid vertices inside a
-- real, processed GIANTS work-area footprint.
function C.observeWorkedArea(geometry,profile)
    if not C.enabled() or type(geometry)~="table" then return 0 end
    local j=journal()
    local unit=j.unitM
    local x0,x1=geometry.xs,geometry.xs+geometry.ux
    local x2,x3=geometry.xs+geometry.vx,geometry.xs+geometry.ux+geometry.vx
    local z0,z1=geometry.zs,geometry.zs+geometry.uz
    local z2,z3=geometry.zs+geometry.vz,geometry.zs+geometry.uz+geometry.vz
    local margin=math.min(0.45,0.45*unit)
    local minIx,maxIx=math.ceil((math.min(x0,x1,x2,x3)-margin)/unit),
        math.floor((math.max(x0,x1,x2,x3)+margin)/unit)
    local minIz,maxIz=math.ceil((math.min(z0,z1,z2,z3)-margin)/unit),
        math.floor((math.max(z0,z1,z2,z3)+margin)/unit)
    local total=(maxIx-minIx+1)*(maxIz-minIz+1)
    if total<=0 or total>C.DEFAULTS.maxAreaVertices then
        -- Never iterate a giant malformed machine work-area every frame.
        return 0
    end
    local factor,profileId=effort(profile)
    if factor<0.10 then return 0 end
    local timestamp=now()
    local count=0
    for ix=minIx,maxIx do
        for iz=minIz,maxIz do
            local x,z=ix*unit,iz*unit
            if nativeVertexTouchesWorkedArea(x,z,geometry,unit) then
                local p=j:getRecoverablePoint(ix,iz,C.DEFAULTS.minDeficitM)
                if p==nil then
                    local e=j.observations~=nil
                        and j.observations[tostring(ix)..":"..tostring(iz)] or nil
                    if e==nil then
                        C.stats.noBaselineVisits=C.stats.noBaselineVisits+1
                    elseif e.owned~=true then
                        C.stats.untrustedVisits=C.stats.untrustedVisits+1
                    end
                end
                if p~=nil and C.byKey[p.key]==nil
                    and (C.queueTail-C.queueHead+1)<C.DEFAULTS.maxPending then
                    C.queueTail=C.queueTail+1
                    C.queue[C.queueTail]={
                        key=p.key,ix=ix,iz=iz,factor=factor,
                        profileId=profileId,atMs=timestamp,attempts=0
                    }
                    C.byKey[p.key]=true
                    C.stats.considered=C.stats.considered+1
                    local toolKey="tool"..profileId
                    if C.stats[toolKey]==nil then toolKey="toolOTHER" end
                    C.stats[toolKey]=C.stats[toolKey]+1
                    C.stats.maxBeforeDeficitM=math.max(
                        C.stats.maxBeforeDeficitM,p.deficitM
                    )
                    count=count+1
                elseif p~=nil and C.byKey[p.key]~=nil then
                    -- Multiple fragments of one legitimate work pass may
                    -- improve operation strength without enqueuing duplicates.
                    -- Queued element remains bounded by the original TTL.
                end
            end
        end
    end
    return count
end

-- Trusted periodic world-maintenance admission. The authority and eligibility
-- policy lives in TerrainCausalMaintenance; no arbitrary (x,z) without a
-- confirmed RE-owned native-vertex baseline may enter this queue.
function C.enqueueAuthorizedVertex(ix,iz,factor,cause,ttlMs)
    if not C.enabled() then return false,"NOT_READY" end
    if type(ix)~="number" or type(iz)~="number"
        or ix~=math.floor(ix) or iz~=math.floor(iz) then
        return false,"INVALID_GRID"
    end
    if cause~="NEIGHBOR" and cause~="MUNICIPAL" then
        return false,"UNAUTHORIZED_CAUSE"
    end
    local j=journal()
    local p=j:getRecoverablePoint(ix,iz,C.DEFAULTS.minDeficitM)
    if p==nil then return false,"NO_TRUSTED_DEBT" end
    if C.byKey[p.key]~=nil then return false,"ALREADY_PENDING" end
    if C.queueTail-C.queueHead+1>=C.DEFAULTS.maxPending then
        return false,"QUEUE_FULL"
    end
    local f=math.max(0.10,math.min(1,tonumber(factor) or 0.25))
    local limit=math.max(C.DEFAULTS.maxPendingAgeMs,
        tonumber(ttlMs) or C.DEFAULTS.maxPendingAgeMs)
    C.queueTail=C.queueTail+1
    C.queue[C.queueTail]={
        key=p.key,ix=ix,iz=iz,factor=f,profileId=cause,
        cause=cause,ttlMs=limit,atMs=now(),attempts=0
    }
    C.byKey[p.key]=true
    C.stats.considered=C.stats.considered+1
    C.stats.maxBeforeDeficitM=math.max(
        C.stats.maxBeforeDeficitM,p.deficitM
    )
    return true,nil
end

local function authorizedAtExecution(item,point)
    if item.cause==nil then return true end
    local policy=RealismExtensionsTerrainMaintenancePolicy
    if policy==nil or type(policy.classifyAt)~="function"
        or type(policy.circleHasMaintainer)~="function" then return false end
    local mission=g_currentMission
    local farmId=nil
    if mission~=nil and type(mission.getFarmId)=="function" then
        local ok,id=pcall(mission.getFarmId,mission)
        if ok then farmId=id end
    end
    local cls=policy.classifyAt(point.x,point.z,farmId)
    if cls==nil or cls.maintainer~=item.cause then return false end
    local r=math.max(0.12,journal().unitM*0.35)
    if policy.circleHasMaintainer(
        point.x,point.z,r,item.cause,farmId
    )~=true then return false end
    if item.cause=="MUNICIPAL" then
        local surface=RealismExtensionsTerrainSurfaceResponse
        if surface==nil
            or type(surface.isMunicipalMaintenanceSurface)~="function" then
            return false
        end
        local off=r*0.75
        for _,v in ipairs({{0,0},{off,0},{-off,0},{0,off},{0,-off}}) do
            if surface.isMunicipalMaintenanceSurface(
                point.x+v[1],point.z+v[2]
            )~=true then return false end
        end
    end
    return true
end

local function pop()
    local p=C.queue[C.queueHead]
    C.queue[C.queueHead]=nil
    C.queueHead=C.queueHead+1
    if C.queueHead>C.queueTail then
        C.queue={};C.queueHead=1;C.queueTail=0
    elseif C.queueHead>256 and C.queueHead>C.queueTail*0.5 then
        -- A blocked wheel can keep a candidate in the queue for seconds.
        -- Without bounded compaction the Lua array index grows forever while
        -- tasks are repeatedly retried, despite a fixed active queue size.
        local compact={}
        for i=C.queueHead,C.queueTail do
            compact[#compact+1]=C.queue[i]
        end
        C.queue=compact
        C.queueHead=1
        C.queueTail=#compact
    end
    return p
end
local function push(p)
    C.queueTail=C.queueTail+1
    C.queue[C.queueTail]=p
end

function C.update()
    if not C.enabled() then return end
    local j=journal()
    local clock=now()
    if C.inFlight~=nil then
        local i=C.inFlight
        if clock>i.startMs+C.DEFAULTS.inFlightTimeoutMs then
            j:finishRecovery(i.token,false)
            C.inFlight=nil
            C.byKey[i.key]=nil
            C.stats.failed=C.stats.failed+1
        end
        return
    end
    if clock<C.nextTryMs then return end
    C.nextTryMs=clock+C.DEFAULTS.retryMs
    local runtime=RealismExtensionsTerrainRuntime
    local w=runtime~=nil and runtime.writer or nil
    if w==nil then return end
    for _=1,math.min(5,C.queueTail-C.queueHead+1) do
        local item=pop()
        if item==nil then return end
        if clock>item.atMs+(item.ttlMs or C.DEFAULTS.maxPendingAgeMs)
            or item.attempts>=C.DEFAULTS.maxAttemptsPerVertex then
            C.byKey[item.key]=nil
            C.stats.expired=C.stats.expired+1
        else
            local point=j:getRecoverablePoint(item.ix,item.iz,C.DEFAULTS.minDeficitM)
            if point==nil then
                C.byKey[item.key]=nil
            elseif not authorizedAtExecution(item,point) then
                -- Land owner, boundary or public-surface paint may have
                -- changed since the month began. Never grade on stale auth.
                C.byKey[item.key]=nil
                C.stats.unauthorized=
                    (C.stats.unauthorized or 0)+1
            else
                local radius=j.unitM*C.DEFAULTS.radiusUnitFraction
                local contact=RealismExtensionsLoadedContactRegistry
                local blocked=contact~=nil
                    and contact.overlapsCircle(point.x,point.z,radius,clock)
                if blocked then
                    C.stats.blocked=C.stats.blocked+1
                    push(item)
                else
                    -- The geometry journal locks native vertices, not the
                    -- whole farm. Other independent RE writes in distant
                    -- fields must not globally starve tillage recovery.
                    local token=j:beginRecovery(point,radius)
                    if token==nil then
                        push(item)
                    else
                        item.attempts=item.attempts+1
                        local originalTarget=point.beforeY
                            + math.max(0,math.min(1,item.factor))*point.deficitM
                        local targetY=math.min(point.originalY,originalTarget)
                        local accepted=w:enqueue({
                            mode="TARGET",source="RECOVERY",
                            x=point.x,z=point.z,
                            radiusM=radius,hardness=C.DEFAULTS.hardness,
                            strength=C.DEFAULTS.strength,
                            targetY=targetY,targetPlaneAx=0,targetPlaneAz=0,
                            targetAmount=C.DEFAULTS.amount,
                            skipRecoveryGeometryProbe=true,
                            onApplied=function(state)
                                local current=C.inFlight
                                if current==nil or current.token~=token then
                                    return -- stale callback cannot revive state
                                end
                                C.inFlight=nil
                                C.byKey[item.key]=nil
                                local ok=state~=false and
                                    (TerrainDeformation==nil
                                        or TerrainDeformation.STATE_SUCCESS==nil
                                        or state==TerrainDeformation.STATE_SUCCESS)
                                local result=j:finishRecovery(token,ok)
                                if result==nil or not result.success then
                                    C.stats.failed=C.stats.failed+1
                                else
                                    C.stats.completed=C.stats.completed+1
                                    C.stats.collateral=C.stats.collateral
                                        +(result.collateral or 0)
                                    if result.safe and result.gainM>0.0001 then
                                        C.stats.improved=C.stats.improved+1
                                        C.stats.gainSumM=C.stats.gainSumM+result.gainM
                                        C.stats.maxGainM=math.max(
                                            C.stats.maxGainM,result.gainM
                                        )
                                        if result.completed then
                                            C.stats.physicallyClosed=
                                                C.stats.physicallyClosed+1
                                        end
                                        -- A completed native vertex only clears
                                        -- an exact associated mechanical cell.
                                        -- Do not clear all 0.2m neighbors merely
                                        -- because one 1.0m vertex moved.
                                        if result.completed and runtime.history~=nil
                                            and type(runtime.history.applyRecoveryAt)=="function" then
                                            local h=runtime.history:get(point.x,point.z)
                                            local debt=h~=nil and tonumber(h.rutDepthM) or 0
                                            if debt>0 then
                                                runtime.history:applyRecoveryAt(
                                                    point.x,point.z,debt,{minRutM=0,nowMs=clock}
                                                )
                                            end
                                        end
                                    else
                                        C.stats.unchanged=C.stats.unchanged+1
                                        if result.safe==false then
                                            C.stats.unsafe=C.stats.unsafe+1
                                        end
                                    end
                                end
                            end
                        })
                        if accepted then
                            C.inFlight={key=item.key,token=token,startMs=clock}
                            C.stats.accepted=C.stats.accepted+1
                            return
                        end
                        j:finishRecovery(token,false)
                        C.stats.failed=C.stats.failed+1
                        if item.attempts<C.DEFAULTS.maxAttemptsPerVertex then
                            push(item)
                        else
                            C.byKey[item.key]=nil
                        end
                    end
                end
            end
        end
    end
end

function C.getDiagnostics()
    local out={}
    for k,v in pairs(C.stats) do out[k]=v end
    out.pending=math.max(0,C.queueTail-C.queueHead+1)
    out.inFlight=C.inFlight~=nil
    return out
end

return C
