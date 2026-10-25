-- Research-only ALTERNATIVE to additive TerrainDeformation brush.
-- NO production wiring and NO automatic write path. The GIANTS engine
-- documents setTerrainHeightAtWorldPos() as an absolute main-height setter,
-- but persistence, collision, fine 0.125m displacement and MP semantics are
-- UNPROVEN for this use. Requires explicitWrite=true and caller-provided
-- writeHeight to make any mutation. Never import for production automatically.
RealismExtensionsTerrainAbsoluteVertexCandidate =
    RealismExtensionsTerrainAbsoluteVertexCandidate or {}
local Candidate=RealismExtensionsTerrainAbsoluteVertexCandidate
Candidate.VERSION=1

local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end

function Candidate.new(options)
    options=options or {}
    local budget=options.budget
    local journal=options.journal
    if type(budget)~="table" or type(budget.request)~="function"
        or type(journal)~="table"
        or type(journal.begin)~="function"
        or not finite(journal.unitM) or journal.unitM<=0 then
        return nil,"CANDIDATE_DEPENDENCIES_UNAVAILABLE"
    end
    return setmetatable({
        budget=budget,
        journal=journal,
        explicitWrite=options.explicitWrite==true,
        writeHeight=options.writeHeight,
        stats={attempts=0,writes=0,verified=0,refused=0,
            noEffect=0,unsafe=0,writeErrors=0}
    },{__index=Candidate})
end

local function untrustTouched(journal,token)
    if type(token)~="table" then return end
    for _,v in ipairs(token.points or {}) do
        local e=journal.observations[v.key]
        if e~=nil then e.owned=false end
    end
end

-- A single grid-aligned native 1m vertex, not an arbitrarily centered
-- 0.2m wheel history cell. No neighborhood blending or fine-geometry claims.
-- The RE journal owns the just-in-time provenance and nearby side-effect scan.
function Candidate:applyOne(x,z,damageM)
    self.stats.attempts=self.stats.attempts+1
    if self.explicitWrite~=true or type(self.writeHeight)~="function" then
        self.stats.refused=self.stats.refused+1
        return nil,"RESEARCH_WRITER_DISABLED"
    end
    local journal,budget=self.journal,self.budget
    local unit=journal.unitM
    if not finite(x) or not finite(z)
        or math.abs(x/unit-math.floor(x/unit+0.5))>0.00001
        or math.abs(z/unit-math.floor(z/unit+0.5))>0.00001 then
        self.stats.refused=self.stats.refused+1
        return nil,"VERTEX_GRID_ALIGNMENT_UNVERIFIED"
    end
    local ix,iz=math.floor(x/unit+0.5),math.floor(z/unit+0.5)
    local key=tostring(ix)..":"..tostring(iz)
    -- Include adjacent 1m vertices in the side-effect check; a too-small
    -- envelope would "prove" locality while missing a changed neighbor.
    local radius=unit*0.30
    local remaining,reason=journal:getLoweringBudget(
        x,z,radius,0.10,0.12)
    if not finite(remaining) then
        self.stats.refused=self.stats.refused+1
        return nil,reason or "UNVERIFIED_NATIVE_HEIGHT_BUDGET"
    end
    local plan,why=budget:request(key,damageM,remaining)
    if plan==nil then
        self.stats.refused=self.stats.refused+1
        return nil,why
    end
    local token,lockReason=journal:begin("ABS:"..key,x,z,radius)
    if token==nil then
        budget:cancel(plan)
        self.stats.refused=self.stats.refused+1
        return nil,lockReason
    end
    local function abort(reason)
        budget:cancel(plan)
        journal:complete(token,false)
        self.stats.refused=self.stats.refused+1
        return nil,reason
    end
    local preflight,preReason=journal:validateBeforeSubmit(token)
    if not preflight then return abort(preReason) end
    local before=journal:getHeight(x,z)
    if not finite(before) then return abort("PRE_HEIGHT_UNAVAILABLE") end
    -- Absolute height request is bounded to ONE verified quantum. Unlike
    -- ADDITIVE SOFT CIRCLE, this proposes no change to other height vertices.
    local target=before-plan.stepM
    local ok,err=pcall(self.writeHeight,x,z,target)
    if not ok then
        budget.quarantined=true
        self.stats.writeErrors=self.stats.writeErrors+1
    else
        self.stats.writes=self.stats.writes+1
    end
    -- Readback occurs immediately; no GIANTS queue-job callback interval.
    -- Even then, this is NOT verified to synchronize/affect fine physical ruts.
    local after=journal:getHeight(x,z)
    local measured,measurementReason=budget:settle(plan,before,after)
    local footprint,footprintReason=journal:complete(token,true)
    local tolerance=budget.toleranceM
    local safe=ok and measured~=nil and measured.verified==true
        and footprint~=nil and footprint.movedVertices==1
        and footprint.loweredVertices==1
        and footprint.raisedVertices==0
        and math.abs(footprint.maxLowerM-plan.stepM)<=tolerance
    if not safe then
        budget.quarantined=true
        untrustTouched(journal,token)
        self.stats.unsafe=self.stats.unsafe+1
        if measured~=nil and measurementReason=="NO_MEASURABLE_EFFECT" then
            self.stats.noEffect=self.stats.noEffect+1
        end
        return {
            verified=false,plannedStepM=plan.stepM,beforeY=before,
            afterY=after,footprint=footprint
        },(not ok and tostring(err))
            or measurementReason or footprintReason or "UNTRUSTED_NATIVE_SIDE_EFFECT"
    end
    self.stats.verified=self.stats.verified+1
    return {
        verified=true,plannedStepM=plan.stepM,beforeY=before,
        afterY=after,footprint=footprint
    },nil
end

return Candidate
