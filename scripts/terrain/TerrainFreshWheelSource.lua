-- Experimental server-only observation of NEW plastic damage after an
-- authenticated physical MAIN recovery. It NEVER writes terrain.
-- No 0.125m wheel displacement, collision or save/reload inference is made.
RealismExtensionsTerrainFreshWheelSource =
    RealismExtensionsTerrainFreshWheelSource or {}
local Source=RealismExtensionsTerrainFreshWheelSource
Source.VERSION=1

local function finite(x)
    return type(x)=="number" and x==x
        and x~=math.huge and x~=-math.huge
end
local function wheelObject(o)
    return type(o)=="table" or type(o)=="userdata"
end
local function supportedBudget(b)
    return type(b)=="table" and type(b.entries)=="table"
        and type(b.observeFreshDamage)=="function"
end

function Source.new(options)
    options=options or {}
    if type(options.journal)~="table"
        or not finite(options.journal.unitM)
        or options.journal.unitM<=0
        or type(options.getBudget)~="function" then
        return nil,"NO_TRUSTED_SOURCE_DEPENDENCIES"
    end
    return setmetatable({
        journal=options.journal,getBudget=options.getBudget,
        model=options.model or RealismExtensionsTerrainResponseModel,
        gate=options.gate or RealismExtensionsTerrainMainFootprintGate,
        maxSources=math.max(1,math.floor(tonumber(options.maxSources) or 512)),
        sources={},sourceCount=0,
        wheelIds=setmetatable({}, {__mode="k"}),
        wheelSeq=setmetatable({}, {__mode="k"}),
        nextWheelId=0,
        stats={observations=0,noRecovery=0,clientRejected=0,
            geometryRejected=0,modelRejected=0,
            sourceCapRejected=0,modelStates=0,baseline=0,
            admitted=0,otherRefusals=0}
    },{__index=Source})
end

function Source:clear()
    self.sources={}
    self.sourceCount=0
    self.wheelIds=setmetatable({}, {__mode="k"})
    self.wheelSeq=setmetatable({}, {__mode="k"})
    self.nextWheelId=0
end

-- This is a measured, real ENGINE callback, not an invented logical pass.
-- The caller is Engine.processSample after actual server wheel context,
-- surface, footprint, actor, yield and movement checks.
-- No source can start without a journal-issued physical recovery proof
-- already consumed into the quantized budget.
function Source:observeServerWheel(vehicle,wheel,context,footprint,
    x,z,dtMs,modelOptions,dirX,dirZ,pathEvidence)
    self.stats.observations=self.stats.observations+1
    if g_server==nil or type(vehicle)~="table"
        or vehicle.isServer~=true or not wheelObject(wheel) then
        self.stats.clientRejected=self.stats.clientRejected+1
        return nil,"SERVER_WHEEL_REQUIRED"
    end
    local ok,budget=pcall(self.getBudget)
    if not ok or not supportedBudget(budget) or budget.quarantined then
        self.stats.noRecovery=self.stats.noRecovery+1
        return nil,"NO_ACTIVE_RECOVERY_BUDGET"
    end
    local j=self.journal
    local unit=j.unitM
    if not finite(x) or not finite(z)
        or type(context)~="table" or context.grounded~=true
        or type(footprint)~="table" or footprint.available~=true
        or not finite(dtMs) or dtMs<=0 or dtMs>750
        or type(modelOptions)~="table" then
        return nil,"INVALID_SERVER_WHEEL_CONTEXT"
    end
    local ix=math.floor(x/unit+0.5)
    local iz=math.floor(z/unit+0.5)
    local key=tostring(ix)..":"..tostring(iz)
    local paid=budget.entries[key]
    if paid==nil and type(budget.seedPersistedRecovery)=="function"
        and type(j.getRecoveryFence)=="function"
        and j:getRecoveryFence(key)~=nil then
        -- A fresh process has no in-memory epoch. Rehydrate ONLY the
        -- trusted journal's physical recovery fence; never turn the first
        -- loaded wheel event into a historical excavation request.
        local seeded,why=budget:seedPersistedRecovery(j,key)
        if not seeded then return nil,why end
        return nil,"PERSISTED_RECOVERY_FENCE_BOOTSTRAPPED"
    end
    paid=budget.entries[key]
    local anchor=paid~=nil and paid.recoveryAnchor or nil
    if paid==nil or anchor==nil
        or (paid.recoveryEpochPending~=true and paid.epochTicket==nil) then
        self.stats.noRecovery=self.stats.noRecovery+1
        return nil,"NO_VERIFIED_RECOVERY_AT_VERTEX"
    end
    -- MAIN geometry admission deliberately screens out normal narrow
    -- tyres, teleports, stationary wheelspin and sparse interpolation.
    -- The gate NEVER supplies actual native-write permission.
    local gate=self.gate
    if type(gate)~="table" or type(gate.evaluate)~="function" then
        return nil,"MAIN_FOOTPRINT_GATE_MISSING"
    end
    local measured=gate.evaluate({
        unitM=unit,vertexX=ix*unit,vertexZ=iz*unit,
        contactX=x,contactZ=z,
        footprintAvailable=true,
        isCrawler=context.isCrawler==true
            or footprint.kind=="CRAWLER",
        supportWidthM=footprint.supportWidthM,
        footprintLengthM=footprint.footprintLengthM,
        dirX=dirX,dirZ=dirZ,
        pathContinuity=pathEvidence~=nil
            and pathEvidence.state=="CONTINUOUS"
            and pathEvidence.completeCoverage==true
    })
    if measured.state~="MAIN_RESEARCH_CANDIDATE" then
        self.stats.geometryRejected=self.stats.geometryRejected+1
        return nil,measured.reason or "MAIN_GEOMETRY_UNREPRESENTABLE"
    end
    local id=self.wheelIds[wheel]
    if id==nil then
        self.nextWheelId=self.nextWheelId+1
        id=tostring(self.nextWheelId)
        self.wheelIds[wheel]=id
    end
    local sourceKey=id.."@"..key
    local source=self.sources[sourceKey]
    -- Changing the journal-issued, non-serialized recovery anchor starts
    -- a wholly independent model history, never the old SHADOW state.
    if source~=nil and source.anchor~=anchor then
        self.sources[sourceKey]=nil
        self.sourceCount=self.sourceCount-1
        source=nil
    end
    if source==nil then
        if self.sourceCount>=self.maxSources then
            self.stats.sourceCapRejected=self.stats.sourceCapRejected+1
            return nil,"FRESH_SOURCE_CAPACITY"
        end
        source={anchor=anchor,history=nil,lastRutM=0}
        self.sources[sourceKey]=source
        self.sourceCount=self.sourceCount+1
    end
    if type(self.model)~="table"
        or type(self.model.compute)~="function" then
        return nil,"FRESH_RESPONSE_MODEL_UNAVAILABLE"
    end
    -- Real wheel conditions, but *independent* exposure since the physical
    -- recovery. Passing old SpatialHistory or an older absoluteShadow
    -- modelHistory here would silently replay pre-repair damage.
    local response=self.model.compute(
        context,footprint,source.history,dtMs,modelOptions)
    if type(response)~="table" or response.available~=true
        or type(response.nextHistory)~="table"
        or not finite(response.rutDepthM)
        or response.rutDepthM<0
        or not finite(response.nextHistory.rutDepthM)
        or response.nextHistory.rutDepthM<source.lastRutM-0.00000001
        or not finite(response.plasticYield01)
        or response.plasticYield01<=0 then
        self.stats.modelRejected=self.stats.modelRejected+1
        return nil,"FRESH_PLASTIC_DAMAGE_NOT_PROVEN"
    end
    -- The maximum paid quantized debt is independent from any theoretical
    -- model rut larger than 10cm; do NOT clamp an excessive value to fake
    -- eligibility for a height write. No history is saved before validation.
    if response.rutDepthM>budget.maxDebtM then
        return nil,"FRESH_MODEL_EXCEEDS_NATIVE_DEBT_CAP"
    end
    source.history=response.nextHistory
    source.lastRutM=response.rutDepthM
    self.stats.modelStates=self.stats.modelStates+1
    self.wheelSeq[wheel]=(self.wheelSeq[wheel] or 0)+1
    local ticket,why=budget:observeFreshDamage(key,j,{
        wheelKey="server-wheel-"..id,
        sequence=self.wheelSeq[wheel],
        contactX=x,contactZ=z,
        freshCumulativeDamageM=response.rutDepthM,
        grounded=true,
        pathContinuity=true,
        mainGeometryState=measured.state
    })
    if ticket~=nil then
        self.stats.admitted=self.stats.admitted+1
        return {ticket=ticket,targetM=budget.entries[key].authorizedTargetM,
            vertexKey=key,doesNotWrite=true},nil
    end
    if why=="POST_RECOVERY_SOURCE_BASELINE" then
        self.stats.baseline=self.stats.baseline+1
    else
        self.stats.otherRefusals=self.stats.otherRefusals+1
    end
    return nil,why
end

return Source
