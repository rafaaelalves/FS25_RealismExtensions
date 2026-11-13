-- RESEARCH ONLY: one verified UPWARD MAIN height quantum at a time.
-- This is the inverse of TerrainAbsoluteVertexCandidate, but it does
-- NOT "restore" native 0.125m wheel sink geometry or replay TireTracks.
-- Intentionally DISCONNECTED from gameplay / automatic recovery.
RealismExtensionsTerrainAbsoluteRecoveryCandidate =
    RealismExtensionsTerrainAbsoluteRecoveryCandidate or {}
local Candidate=RealismExtensionsTerrainAbsoluteRecoveryCandidate
Candidate.VERSION=1

local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end
function Candidate.new(options)
    options=options or {}
    local q=options.quantumM
    local journal=options.journal
    -- beginRecovery currently requires >=3mm residual and the tested
    -- map quantum is 3.89105mm. Do not claim a universal cross-map
    -- calibration for smaller quantums before that API is generalized.
    if not finite(q) or q<0.003 or q>0.05 then
        return nil,"RECOVERY_QUANTUM_UNVERIFIED"
    end
    if type(journal)~="table"
        or not finite(journal.unitM) or journal.unitM<=0
        or type(journal.getRecoverablePoint)~="function"
        or type(journal.beginRecovery)~="function"
        or type(journal.finishRecovery)~="function"
        or type(journal.validateBeforeSubmit)~="function"
        or type(journal.getHeight)~="function" then
        return nil,"RECOVERY_JOURNAL_UNAVAILABLE"
    end
    if options.explicitResearchPermission~=true
        or options.disposableSaveConfirmed~=true then
        return nil,"EXPLICIT_DISPOSABLE_RESEARCH_REQUIRED"
    end
    return setmetatable({
        journal=journal,quantumM=q,
        toleranceM=math.min(q*0.02,0.00005,
            (finite(options.toleranceM) and
                options.toleranceM>0) and options.toleranceM
            or 0.00005),
        writeHeight=options.writeHeight,
        verifyExclusive=options.verifyExclusive,
        consumed=false,quarantined=false,
        stats={attempts=0,verified=0,refused=0,
            unsafe=0,nativeCalls=0}
    },{__index=Candidate})
end

local function isExclusive(candidate)
    if type(candidate.verifyExclusive)~="function" then return false end
    local ok,value=pcall(candidate.verifyExclusive)
    return ok and value==true
end

local function untrust(journal,token,point)
    -- A failed native setter might have physically changed the center
    -- despite reporting failure. Do not grant future recovery ownership.
    for _,p in ipairs(token.points or {}) do
        local e=journal.observations[p.key]
        if e~=nil then
            e.owned=false
            local y=journal:getHeight(p.x,p.z)
            if finite(y) then e.observedHeightM=y end
        end
    end
    -- A fully restored entry may have been retired by finishRecovery()
    -- before the caller noticed a quantum mismatch. Preserve the
    -- ORIGINAL baseline as diagnostic-only data, never as RE ownership.
    if journal.observations[point.key]==nil then
        journal.observations[point.key]={
            x=point.x,z=point.z,
            preREHeightM=point.originalY,
            observedHeightM=journal:getHeight(point.x,point.z),
            owned=false
        }
    end
end

-- One physical raising operation, at exactly one MAIN grid vertex.
-- A caller must independently prove that q is the vertical quantum of
-- THIS map and supply both an exclusive disposable-copy context and an
-- injected native setter. This function cannot be run by simply loading
-- the source module in a normal career.
function Candidate:applyOnce(x,z)
    self.stats.attempts=self.stats.attempts+1
    if self.consumed or self.quarantined then
        self.stats.refused=self.stats.refused+1
        return nil,"RECOVERY_RESEARCH_ALREADY_CONSUMED"
    end
    if type(self.writeHeight)~="function" or not isExclusive(self) then
        self.stats.refused=self.stats.refused+1
        return nil,"RECOVERY_EXCLUSIVITY_UNVERIFIED"
    end
    local journal,q=self.journal,self.quantumM
    local unit=journal.unitM
    if not finite(x) or not finite(z)
        or math.abs(x/unit-math.floor(x/unit+0.5))>0.00001
        or math.abs(z/unit-math.floor(z/unit+0.5))>0.00001 then
        self.stats.refused=self.stats.refused+1
        return nil,"RECOVERY_VERTEX_NOT_MAIN_ALIGNED"
    end
    local ix,iz=math.floor(x/unit+0.5),math.floor(z/unit+0.5)
    local point=journal:getRecoverablePoint(ix,iz,0.003)
    if point==nil or point.deficitM<q-self.toleranceM then
        self.stats.refused=self.stats.refused+1
        return nil,"RECOVERY_FULL_QUANTUM_NOT_AVAILABLE"
    end
    local token,why=journal:beginRecovery(point,unit*0.70)
    if token==nil then
        self.stats.refused=self.stats.refused+1
        return nil,why
    end
    local function abort(reason)
        journal:finishRecovery(token,false)
        self.stats.refused=self.stats.refused+1
        return nil,reason
    end
    -- No release candidate may pass if the 3x3 footprint is truncated
    -- by a map boundary, concurrent lock or an invalid native unit.
    if #token.points~=9 then
        return abort("RECOVERY_3X3_NOT_VERIFIED")
    end
    local valid,preWhy=journal:validateBeforeSubmit(token,0.00001)
    if not valid then
        if preWhy=="QUEUED_GEOMETRY_DRIFT" then
            self.quarantined=true
        end
        return abort(preWhy)
    end
    if not isExclusive(self) then
        return abort("RECOVERY_EXCLUSIVITY_CHANGED")
    end
    local before=journal:getHeight(x,z)
    if not finite(before)
        or math.abs(before-point.beforeY)>0.00001 then
        return abort("RECOVERY_PRE_HEIGHT_CHANGED")
    end

    -- Under FLOOR quantization a +0.75q proposal can do NOTHING;
    -- +1.25q lies INSIDE the next higher cell for FLOOR and NEAREST
    -- when native before is on a trusted q-lattice. The strict readback
    -- must still confirm precisely ONE q and no neighboring movement.
    local target=before+q*1.25
    self.consumed=true -- never repeat a possibly destructive setter
    self.stats.nativeCalls=self.stats.nativeCalls+1
    local ok,writeResult=pcall(self.writeHeight,x,z,target)
    if ok and writeResult==false then ok=false end
    -- Always read the actual post-state even after an adapter exception;
    -- a native call might have changed geometry before returning false.
    local result,finishWhy=journal:finishRecovery(token,true)
    local after=journal:getHeight(x,z)
    local raised=finite(after) and after-before or nil
    local tinyRoundoff=0.000000001
    local safe=ok and result~=nil and result.success==true
        and result.safe==true and result.collateral==0
        and raised~=nil
        and raised>0
        and math.abs(raised-q)<=self.toleranceM
        and raised<=q+tinyRoundoff
        and after<=point.originalY+tinyRoundoff
        and math.abs(result.afterY-after)<=tinyRoundoff
    if not safe then
        self.quarantined=true
        self.stats.unsafe=self.stats.unsafe+1
        untrust(journal,token,point)
        return {verified=false,beforeY=before,afterY=after,
            actualRaiseM=raised,footprint=result},
            (not ok and "RECOVERY_NATIVE_SETTER_FAILED")
            or finishWhy or "UNTRUSTED_RECOVERY_QUANTUM_OR_COLLATERAL"
    end
    self.stats.verified=self.stats.verified+1
    return {verified=true,beforeY=before,afterY=after,
        actualRaiseM=raised,footprint=result,
        completed=result.completed==true},nil
end
return Candidate
