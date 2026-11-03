-- Periodic repair of VERIFIED RE-owned native heightmap dents.
-- Reuses the existing territory rules and SpatialHistory period age. Unlike
-- the old R1 TerrainMaintenance TARGET it never invents a reference plane.
RealismExtensionsTerrainCausalMaintenance =
    RealismExtensionsTerrainCausalMaintenance or {}
local M=RealismExtensionsTerrainCausalMaintenance
M.DEFAULTS={
    minRutM=0.003,
    neighborMinPeriods=1,
    municipalMinPeriods=2,
    maxNeighborVertices=128,
    maxMunicipalVertices=64,
    neighborRecoveryFactor=0.50,
    municipalRecoveryFactor=0.30,
    queueTtlMs=120000
}
M.initialized=false
local function resetStats()
    M.stats={periods=0,scanned=0,eligibleNeighbor=0,
        eligibleMunicipal=0,boundaryRejected=0,
        surfaceRejected=0,notTrusted=0,
        queuedNeighbor=0,queuedMunicipal=0,
        queueRejected=0,skippedDisabled=0}
end
resetStats()

local function enabled()
    local cfg=RealismExtensionsConfig
    local modules=cfg~=nil and cfg.modules or nil
    local causal=RealismExtensionsTerrainCausalRecovery
    return g_server~=nil and modules~=nil
        and modules.TerrainCausalMaintenance==true
        and modules.TerrainMaintenance~=true
        and causal~=nil and type(causal.enabled)=="function"
        and causal.enabled()
end

local function farmId()
    local mission=g_currentMission
    if mission~=nil and type(mission.getFarmId)=="function" then
        local ok,id=pcall(mission.getFarmId,mission)
        if ok then return id end
    end
    return nil
end

local function classificationAt(x,z,localFarm,cache)
    local policy=RealismExtensionsTerrainMaintenancePolicy
    if policy==nil then return nil end
    if type(policy.getFarmlandIdAt)=="function"
        and type(policy.classifyFarmlandId)=="function" then
        local id=policy.getFarmlandIdAt(x,z)
        local key=id~=nil and tostring(id) or "unknown"
        local cls=cache[key]
        if cls==nil then
            cls=policy.classifyFarmlandId(id,localFarm)
            cache[key]=cls
        end
        return cls
    end
    if type(policy.classifyAt)=="function" then
        return policy.classifyAt(x,z,localFarm)
    end
    return nil
end

local function authorizedNativePoint(p,maintainer,localFarm)
    local policy=RealismExtensionsTerrainMaintenancePolicy
    if policy==nil or type(policy.classifyAt)~="function"
        or type(policy.circleHasMaintainer)~="function" then return false end
    local j=RealismExtensionsTerrainRuntime.geometryJournal
    if j==nil then return false end
    local at=policy.classifyAt(p.x,p.z,localFarm)
    if at==nil or at.maintainer~=maintainer then return false end
    local radius=math.max(0.12,j.unitM*0.35)
    if policy.circleHasMaintainer(
        p.x,p.z,radius,maintainer,localFarm
    )~=true then return false end
    return true
end

local function municipalAllowed(x,z,unit)
    local surface=RealismExtensionsTerrainSurfaceResponse
    if surface==nil
        or type(surface.isMunicipalMaintenanceSurface)~="function" then
        return false
    end
    local r=math.min(0.36,unit*0.35)
    for _,p in ipairs({
        {0,0},{r,0},{-r,0},{0,r},{0,-r}
    }) do
        if surface.isMunicipalMaintenanceSurface(x+p[1],z+p[2])~=true then
            return false
        end
    end
    return true
end

function M.onPeriodChanged(self,currentPeriod)
    if not enabled() then
        M.stats.skippedDisabled=M.stats.skippedDisabled+1
        return
    end
    local rt=RealismExtensionsTerrainRuntime
    local history=rt~=nil and rt.history or nil
    local j=rt~=nil and rt.geometryJournal or nil
    local policy=RealismExtensionsTerrainMaintenancePolicy
    local causal=RealismExtensionsTerrainCausalRecovery
    if history==nil or j==nil or policy==nil
        or type(history.advanceMaintenancePeriod)~="function"
        or type(j.getRecoverablePoint)~="function" then return end

    M.stats.periods=M.stats.periods+1
    local localFarm=farmId()
    local clsCache,seen={},{}
    local neighbor,municipal={},{}
    local scanned=history:advanceMaintenancePeriod(
        function(_,x,z,h)
            if (tonumber(h.rutDepthM) or 0)<M.DEFAULTS.minRutM then
                return
            end
            local cls=classificationAt(x,z,localFarm,clsCache)
            if cls==nil then return end
            local kind=cls.maintainer
            local required
            if kind=="NEIGHBOR" then
                required=M.DEFAULTS.neighborMinPeriods
            elseif kind=="MUNICIPAL" then
                required=M.DEFAULTS.municipalMinPeriods
            else
                return
            end
            local age=tonumber(h.maintenanceAgePeriods) or 0
            if age<required then return end
            local ix=math.floor(x/j.unitM+0.5)
            local iz=math.floor(z/j.unitM+0.5)
            local key=tostring(ix)..":"..tostring(iz)
            if seen[key] then return end
            seen[key]=true
            local p=j:getRecoverablePoint(ix,iz,0.004)
            if p==nil then
                M.stats.notTrusted=M.stats.notTrusted+1
                return
            end
            if not authorizedNativePoint(p,kind,localFarm) then
                M.stats.boundaryRejected=M.stats.boundaryRejected+1
                return
            end
            if kind=="MUNICIPAL" and not municipalAllowed(
                p.x,p.z,j.unitM
            ) then
                M.stats.surfaceRejected=M.stats.surfaceRejected+1
                return
            end
            local candidate={
                ix=ix,iz=iz,age=age,deficit=p.deficitM
            }
            if kind=="NEIGHBOR" then
                neighbor[#neighbor+1]=candidate
                M.stats.eligibleNeighbor=M.stats.eligibleNeighbor+1
            else
                municipal[#municipal+1]=candidate
                M.stats.eligibleMunicipal=M.stats.eligibleMunicipal+1
            end
        end
    )
    M.stats.scanned=M.stats.scanned+(scanned or 0)
    local function priority(a,b)
        if a.age~=b.age then return a.age>b.age end
        if a.deficit~=b.deficit then return a.deficit>b.deficit end
        if a.ix~=b.ix then return a.ix<b.ix end
        return a.iz<b.iz
    end
    table.sort(neighbor,priority)
    table.sort(municipal,priority)
    local function schedule(pool,kind,maximum,factor)
        for i=1,math.min(#pool,maximum) do
            local p=pool[i]
            local ok=causal.enqueueAuthorizedVertex(
                p.ix,p.iz,factor,kind,M.DEFAULTS.queueTtlMs
            )
            if ok then
                if kind=="NEIGHBOR" then
                    M.stats.queuedNeighbor=M.stats.queuedNeighbor+1
                else
                    M.stats.queuedMunicipal=M.stats.queuedMunicipal+1
                end
            else
                M.stats.queueRejected=M.stats.queueRejected+1
            end
        end
    end
    -- Alternate the two classes by period to avoid persistent NPC-first
    -- starvation if many fields are dirty. Both pools are separately bounded.
    if M.stats.periods%2==0 then
        schedule(municipal,"MUNICIPAL",
            M.DEFAULTS.maxMunicipalVertices,
            M.DEFAULTS.municipalRecoveryFactor)
        schedule(neighbor,"NEIGHBOR",
            M.DEFAULTS.maxNeighborVertices,
            M.DEFAULTS.neighborRecoveryFactor)
    else
        schedule(neighbor,"NEIGHBOR",
            M.DEFAULTS.maxNeighborVertices,
            M.DEFAULTS.neighborRecoveryFactor)
        schedule(municipal,"MUNICIPAL",
            M.DEFAULTS.maxMunicipalVertices,
            M.DEFAULTS.municipalRecoveryFactor)
    end
end

function M.initialize()
    if M.initialized then return true end
    resetStats()
    if g_messageCenter==nil or MessageType==nil
        or MessageType.PERIOD_CHANGED==nil
        or type(g_messageCenter.subscribe)~="function" then
        return false
    end
    g_messageCenter:subscribe(
        MessageType.PERIOD_CHANGED,M.onPeriodChanged,M
    )
    M.initialized=true
    return true
end

function M.shutdown()
    if M.initialized and g_messageCenter~=nil
        and MessageType~=nil and MessageType.PERIOD_CHANGED~=nil
        and type(g_messageCenter.unsubscribe)=="function" then
        g_messageCenter:unsubscribe(
            MessageType.PERIOD_CHANGED,M
        )
    end
    M.initialized=false
end

function M.getDiagnostics()
    local d={}
    for k,v in pairs(M.stats) do d[k]=v end
    d.enabled=enabled()
    return d
end
