-- DISABLED-BY-DEFAULT integration seam for the GIANTS absolute-height API.
-- This is a bounded research one-shot, NOT a production wheel rut writer.
-- It never uses an additive TerrainDeformation brush and cannot silently
-- infer a vertical quantum from one observed 7.78mm legacy event.
RealismExtensionsTerrainAbsoluteHeightExperimentalBackend =
    RealismExtensionsTerrainAbsoluteHeightExperimentalBackend or {}
local Backend=RealismExtensionsTerrainAbsoluteHeightExperimentalBackend
Backend.VERSION=1
local function finite(n)
    return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end

function Backend.new(options)
    options=options or {}
    if options.explicitResearchPermission~=true
        or options.disposableSaveConfirmed~=true then
        return nil,"EXPLICIT_DISPOSABLE_RESEARCH_REQUIRED"
    end
    -- The current map's actual vertical height quantum MUST be separately
    -- established. One command-response pair cannot certify it.
    if options.quantumVerified~=true or not finite(options.quantumM) then
        return nil,"MAP_VERTICAL_QUANTUM_UNVERIFIED"
    end
    local j=options.journal
    local w=options.writer
    local rt=options.runtime
    if j==nil or not finite(j.unitM) or j.unitM<=0
        or type(j.getHeight)~="function"
        or type(j.begin)~="function"
        or type(j.complete)~="function"
        or type(j.getLoweringBudget)~="function"
        or w==nil or type(w.getQueueSize)~="function"
        or rt==nil or rt.geometryJournal~=j then
        return nil,"NATIVE_GEOMETRY_RUNTIME_UNAVAILABLE"
    end
    local Budget=RealismExtensionsTerrainQuantizedHeightBudget
    local Candidate=RealismExtensionsTerrainAbsoluteVertexCandidate
    if Budget==nil or Candidate==nil then
        return nil,"ABSOLUTE_ACTUATOR_MODULE_UNAVAILABLE"
    end
    local budget,reason=Budget.new({
        quantumM=options.quantumM,
        toleranceM=options.toleranceM,
        maxDebtM=0.10
    })
    if budget==nil then return nil,reason end
    local self=setmetatable({
        journal=j,writer=w,runtime=rt,budget=budget,
        terrainId=options.terrainId,
        explicitNativeSetter=options.nativeSetter,
        consumed=false,attempted=0,confirmed=0,quarantined=false
    },{__index=Backend})
    return self,nil
end

function Backend:exclusive()
    if self.consumed or self.quarantined or self.budget.quarantined
        or self.runtime.nativeDamageQuarantined==true
        or self.writer.nativeCausalPending==true
        or self.writer:getQueueSize()~=0 then
        return false
    end
    -- API availability and server authority must be rechecked at commit.
    if g_server==nil or g_currentMission==nil then return false end
    local dynamic=g_currentMission.missionDynamicInfo
    local info=g_currentMission.missionInfo
    if dynamic~=nil and dynamic.isMultiplayer==true then return false end
    if info~=nil and info.isMultiplayer==true then return false end
    if self.journal~=self.runtime.geometryJournal then return false end
    return true
end

function Backend:applyOnce(x,z,damageM)
    if not self:exclusive() then
        return nil,"EXPERIMENT_NOT_EXCLUSIVE"
    end
    local setter=self.explicitNativeSetter
    if type(setter)~="function" then
        return nil,"ABSOLUTE_SETTER_NOT_AVAILABLE"
    end
    if not finite(x) or not finite(z) or not finite(damageM)
        or damageM<=0 then return nil,"INVALID_EXPERIMENT_REQUEST" end

    -- The actual Candidate rechecks exclusivity before the setter; its
    -- verifyExclusive callback cannot reuse :exclusive after consumed=true.
    local started=false
    local function recheck()
        if started then return false end
        if self.quarantined or self.budget.quarantined
            or self.runtime.nativeDamageQuarantined==true
            or self.writer.nativeCausalPending==true
            or self.writer:getQueueSize()~=0 then return false end
        return g_server~=nil and g_currentMission~=nil
            and self.runtime.geometryJournal==self.journal
    end
    local candidate,why=RealismExtensionsTerrainAbsoluteVertexCandidate.new({
        budget=self.budget,journal=self.journal,
        explicitWrite=true,
        verifyExclusive=recheck,
        writeHeight=function(vx,vz,target)
            started=true
            return setter(vx,vz,target)
        end
    })
    if candidate==nil then return nil,why end
    -- Once requested, never auto-retry, even after a candidate failure:
    -- the first setter might have been executed before a readback fault.
    self.consumed=true
    self.attempted=self.attempted+1
    local result,err=candidate:applyOne(x,z,damageM)
    if result~=nil and result.verified==true then
        self.confirmed=self.confirmed+1
        -- Research readback success is NOT proof of savegame synchronization
        -- or recovery ownership; mark the touched native footprint UNTRUSTED.
        local unit=self.journal.unitM
        local ix,iz=math.floor(x/unit+0.5),math.floor(z/unit+0.5)
        local key=tostring(ix)..":"..tostring(iz)
        local e=self.journal.observations[key]
        if e~=nil then e.owned=false end
    else
        self.quarantined=true
        self.runtime.nativeDamageQuarantined=true
    end
    return result,err
end

-- Opt-in adapter for the documented engine setter, passed only by a
-- deliberate test harness/session after availability has been verified.
-- GIANTS signature: (terrainNode, x, y, z, absoluteHeight).
function Backend.makeNativeSetter(terrainId)
    if not finite(terrainId) or terrainId<=0
        or type(setTerrainHeightAtWorldPos)~="function" then
        return nil,"GIANTS_ABSOLUTE_SETTER_UNAVAILABLE"
    end
    return function(x,z,target)
        return setTerrainHeightAtWorldPos(terrainId,x,0,z,target)
    end,nil
end
return Backend
