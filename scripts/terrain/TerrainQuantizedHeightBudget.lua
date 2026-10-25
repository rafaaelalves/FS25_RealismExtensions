-- Experimental main-heightmap actuator planning only: NEVER writes terrain.
-- FS25 main grid sampled from getTerrainHeightAtWorldPos is NOT the native
-- 0.125m wheel-displacement surface. Its vertical step is map-dependent.
-- No estimate based on one input delta may silently authorize a write.
RealismExtensionsTerrainQuantizedHeightBudget =
    RealismExtensionsTerrainQuantizedHeightBudget or {}
local Model = RealismExtensionsTerrainQuantizedHeightBudget
Model.VERSION = 1

local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end

function Model.new(options)
    options=options or {}
    local quantum=tonumber(options.quantumM)
    -- The ~3.891mm observed step is NOT automatically assumed for other maps.
    if not finite(quantum) or quantum<0.00025 or quantum>0.05 then
        return nil,"QUANTUM_UNVERIFIED"
    end
    return setmetatable({
        quantumM=quantum,
        toleranceM=math.max(0.00005,tonumber(options.toleranceM) or 0.0005),
        maxDebtM=math.max(quantum,tonumber(options.maxDebtM) or 0.10),
        entries={},
        nextId=0,
        quarantined=false,
        stats={requestedM=0,accepted=0,pending=0,belowQuantum=0,
            noBudget=0,verified=0,zeroEffect=0,anomalies=0,
            maxErrorM=0,unavailable=0}
    },{__index=Model})
end

-- Logical damage is an independent ledger and MUST NOT be misinterpreted
-- as a measured rut, used as a recovery reference or saved as native geometry.
-- An already-in-flight vertex must not accept more requests until settled;
-- the caller must retry later, not lose or double-commit requested deformation.
function Model:request(key,damageM,remainingGeometryBudgetM)
    if self.quarantined then return nil,"QUARANTINED" end
    if key==nil or not finite(damageM) or damageM<0
        or not finite(remainingGeometryBudgetM)
        or remainingGeometryBudgetM<0 then
        return nil,"INVALID_REQUEST"
    end
    local item=self.entries[key] or {debtM=0,pending=nil}
    if item.pending~=nil then return nil,"VERTEX_PENDING" end
    item.debtM=math.min(self.maxDebtM,item.debtM+damageM)
    self.entries[key]=item
    self.stats.requestedM=self.stats.requestedM+damageM
    if item.debtM+0.000001<self.quantumM then
        self.stats.belowQuantum=self.stats.belowQuantum+1
        return nil,"SUB_QUANTUM_DEBT"
    end
    if remainingGeometryBudgetM+0.000001<self.quantumM then
        self.stats.noBudget=self.stats.noBudget+1
        return nil,"NO_SAFE_GEOMETRY_STEP"
    end
    -- Never submit more than one measured quantum at a time, irrespective
    -- of accumulated physical demand. The next write must wait for readback.
    self.nextId=self.nextId+1
    local plan={id=self.nextId,key=key,stepM=self.quantumM,active=true}
    item.pending=plan
    self.stats.accepted=self.stats.accepted+1
    self.stats.pending=self.stats.pending+1
    return plan,nil
end

-- No-op plans retain their stored demand, so quantization never invents
-- material removal. A >one-step response quarantines future proposals.
function Model:settle(plan,beforeY,afterY)
    local item=type(plan)=="table" and self.entries[plan.key] or nil
    if item==nil or item.pending~=plan or plan.active~=true then
        return nil,"STALE_PLAN"
    end
    plan.active=false
    item.pending=nil
    self.stats.pending=math.max(0,self.stats.pending-1)
    if not finite(beforeY) or not finite(afterY) then
        self.stats.unavailable=self.stats.unavailable+1
        self.quarantined=true
        return nil,"HEIGHT_UNAVAILABLE"
    end
    local lowered=beforeY-afterY
    local errorM=math.abs(lowered-plan.stepM)
    self.stats.maxErrorM=math.max(self.stats.maxErrorM,errorM)
    if math.abs(lowered)<=self.toleranceM then
        self.stats.zeroEffect=self.stats.zeroEffect+1
        return {verified=false,loweringM=lowered,
            debtM=item.debtM}, "NO_MEASURABLE_EFFECT"
    end
    if errorM>self.toleranceM then
        -- A different native writer between request and readback may have
        -- contributed; this is an anomaly, NOT proof the actuator caused it.
        self.stats.anomalies=self.stats.anomalies+1
        self.quarantined=true
        return {verified=false,loweringM=lowered,
            debtM=item.debtM},"UNBOUNDED_OBSERVED_DELTA"
    end
    item.debtM=math.max(0,item.debtM-plan.stepM)
    self.stats.verified=self.stats.verified+1
    return {verified=true,loweringM=lowered,debtM=item.debtM},nil
end

function Model:cancel(plan)
    local item=type(plan)=="table" and self.entries[plan.key] or nil
    if item==nil or item.pending~=plan or plan.active~=true then
        return false,"STALE_PLAN"
    end
    plan.active=false
    item.pending=nil
    self.stats.pending=math.max(0,self.stats.pending-1)
    return true,nil
end

function Model:getDebt(key)
    local item=self.entries[key]
    return item~=nil and item.debtM or 0
end

return Model
