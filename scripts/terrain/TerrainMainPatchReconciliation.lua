-- Read-only bridge between a frozen virtual MAIN patch and observed native
-- geometry. Existing owned depth is NOT automatically a session-local model
-- target. Only a fresh private research anchor may preview new steps.
-- No setter, token, budget reservation, recovery permission or persistence.
RealismExtensionsTerrainMainPatchReconciliation =
    RealismExtensionsTerrainMainPatchReconciliation or {}
local R=RealismExtensionsTerrainMainPatchReconciliation
R.VERSION=1
local EPS=0.00001
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)~=math.huge
end
local function key(x,z) return tostring(x)..":"..tostring(z) end

-- Capture one bounded square including the full one-vertex halo. Direct
-- reads only: getRecoveryFence/getLoweringBudget can downgrade ownership
-- and are deliberately NOT used in this diagnostic.
function R.capture(planner,journal,ix,iz,radius,q,gradient,budget)
    if type(planner)~="table" or type(planner.planMainPatch)~="function"
        or type(journal)~="table" or type(journal.getHeight)~="function"
        or planner.unitM~=journal.unitM or journal.quarantined
        or journal.pendingCount~=0 or journal.reservedObservationSlots~=0
        or type(journal.observations)~="table"
        or type(journal.recoveryFences)~="table" then
        return nil,"PATCH_JOURNAL_NOT_IDLE"
    end
    if budget~=nil and (type(budget.entries)~="table"
        or budget.quarantined or not finite(budget.quantumM)
        or math.abs(budget.quantumM-q)>1e-9) then
        return nil,"PATCH_BUDGET_NOT_COMPATIBLE"
    end
    local plan,why=planner:planMainPatch(ix,iz,radius,q,gradient)
    if not plan then return nil,why end
    local u=journal.unitM
    local anchor={journal=journal,budget=budget,terrain=journal.terrain,
        unitM=u,q=q,gradient=gradient,points={},grid={},radius=radius,
        ix=ix,iz=iz,ownedCount=0,existingDepthSumM=0,
        blockers={},doesNotWrite=true,authorizesMainWrite=false}
    local function block(k,reason)
        anchor.blockers[#anchor.blockers+1]={key=k,reason=reason}
    end
    local targets={}
    for _,p in ipairs(plan.points) do targets[p.key]=p end
    for x=ix-radius-1,ix+radius+1 do
        for z=iz-radius-1,iz+radius+1 do
            local k=key(x,z)
            local y=journal:getHeight(x*u,z*u)
            if not finite(y) then return nil,"PATCH_HEIGHT_UNAVAILABLE:"..k end
            local o=journal.observations[k]
            local b=budget and budget.entries[k]
            local target=targets[k]
            local p={key=k,ix=x,iz=z,x=x*u,z=z*u,anchorY=y,
                targetM=target and target.targetDepthM or 0,
                targetSteps=target and target.steps or 0,halo=target==nil}
            anchor.points[#anchor.points+1]=p
            anchor.grid[k]=p
            if journal.recoveryFences[k]~=nil then
                block(k,"RECOVERY_EPOCH_REQUIRES_SEPARATE_PROOF")
            end
            if journal.pendingByVertex[k]~=nil then block(k,"VERTEX_PENDING") end
            if o~=nil then
                if o.owned~=true or not finite(o.preREHeightM)
                    or not finite(o.observedHeightM) or o.x~=p.x or o.z~=p.z
                    or math.abs(y-o.observedHeightM)>EPS
                    or o.preREHeightM<y or o.preREHeightM-y>0.10 then
                    block(k,"UNTRUSTED_NATIVE_REFERENCE")
                else
                    p.existingDepthM=o.preREHeightM-y
                    anchor.existingDepthSumM=anchor.existingDepthSumM+p.existingDepthM
                    anchor.ownedCount=anchor.ownedCount+1
                    -- Virtual demand is not bound to this historical epoch.
                    -- Report a comparison only; do not add OR subtract it.
                    block(k,"OWNED_DEPTH_MODEL_EPOCH_UNBOUND")
                end
            end
            if b~=nil then
                if o==nil or p.existingDepthM==nil or b.mode~="TARGET"
                    or b.pending~=nil or not finite(b.committedM)
                    or math.abs(b.committedM-p.existingDepthM)>EPS then
                    block(k,"PAID_LEDGER_REFERENCE_MISMATCH")
                else
                    block(k,"EXISTING_PAID_LEDGER_NOT_FRESH")
                end
            end
        end
    end
    anchor.state=#anchor.blockers==0 and "FRESH_RESEARCH_ANCHOR"
        or "REFERENCE_BLOCKED"
    return anchor,nil
end

-- A later preview uses the SAME frozen target and SAME journal/budget
-- objects. It may recognize already paid changes in this private epoch;
-- it cannot adopt an arbitrary saved rut or a new model projection.
function R.previewNext(anchor,journal,budget)
    if type(anchor)~="table" or anchor.state~="FRESH_RESEARCH_ANCHOR"
        or anchor.journal~=journal or anchor.budget~=budget
        or journal.quarantined or journal.terrain~=anchor.terrain
        or journal.unitM~=anchor.unitM or journal.pendingCount~=0
        or journal.reservedObservationSlots~=0
        or (budget~=nil and (budget.quarantined
            or budget.quantumM~=anchor.q)) then
        return nil,"PATCH_ANCHOR_OR_LEDGER_CHANGED"
    end
    local q,u=anchor.q,anchor.unitM
    local now={}
    local done,remaining=0,0
    for _,p in ipairs(anchor.points) do
        local y=journal:getHeight(p.x,p.z)
        local o=journal.observations[p.key]
        local b=budget and budget.entries[p.key]
        if not finite(y) or journal.recoveryFences[p.key]~=nil
            or journal.pendingByVertex[p.key]~=nil then
            return nil,"PATCH_REFERENCE_CHANGED:"..p.key
        end
        local depth=p.anchorY-y
        local n=math.floor(depth/q+0.5)
        if depth<0 or depth>p.targetM+EPS or n<0 or n>p.targetSteps
            or math.abs(depth-n*q)>EPS then
            return nil,"PATCH_HEIGHT_OUTSIDE_ANCHOR:"..p.key
        end
        if n==0 then
            if math.abs(depth)>0.000001 or o~=nil or b~=nil then
                return nil,"PATCH_UNPAID_OR_FOREIGN_EDIT:"..p.key
            end
        elseif o==nil or o.owned~=true or o.x~=p.x or o.z~=p.z
            or not finite(o.preREHeightM) or not finite(o.observedHeightM)
            or math.abs(o.preREHeightM-p.anchorY)>0.000001
            or math.abs(o.observedHeightM-y)>0.000001
            or b==nil or b.mode~="TARGET" or b.pending~=nil
            or b.recoveryEpochPending or b.epochTicket~=nil
            or not finite(b.committedM) or not finite(b.demandTargetM)
            or math.abs(b.committedM-depth)>EPS
            or math.abs(b.demandTargetM-p.targetM)>EPS then
            return nil,"PATCH_PAID_REFERENCE_MISMATCH:"..p.key
        end
        now[p.key]={y=y,depth=depth,steps=n}
        done=done+n
        remaining=remaining+p.targetSteps-n
    end
    -- Check entire observed current depth envelope first. Never propose a
    -- new operation to compensate for an already invalid physical state.
    for _,p in ipairs(anchor.points) do
        for dx=-1,1 do for dz=-1,1 do
            if dx~=0 or dz~=0 then
                local v=now[key(p.ix+dx,p.iz+dz)]
                if v and math.abs(now[p.key].depth-v.depth)
                    >anchor.gradient*u*math.sqrt(dx*dx+dz*dz) then
                    return nil,"PATCH_CURRENT_GRADIENT_EXCEEDED:"..p.key
                end
            end
        end end
    end
    local best
    for _,p in ipairs(anchor.points) do
        local v=now[p.key]
        -- No upward rounding or credit for a smaller measured quantum.
        -- The final step may be withheld if actual rounding used more debt.
        if not p.halo and v.steps<p.targetSteps and v.depth+q<=p.targetM then
            local valid=true
            local largest=0
            local missing=0
            for dx=-1,1 do for dz=-1,1 do
                local k=key(p.ix+dx,p.iz+dz)
                local other=now[k]
                if not other then valid=false else
                    largest=math.max(largest,other.depth)
                    if journal.observations[k]==nil then missing=missing+1 end
                    if dx~=0 or dz~=0 then
                        if math.abs(v.depth+q-other.depth)
                            >anchor.gradient*u*math.sqrt(dx*dx+dz*dz) then valid=false end
                    end
                end
            end end
            if largest+q>0.10 or journal.observationCount+missing>journal.maxObservations then
                valid=false
            end
            local a=now[key(p.ix-1,p.iz)].y
            local b=now[key(p.ix+1,p.iz)].y
            local c=now[key(p.ix,p.iz-1)].y
            local d=now[key(p.ix,p.iz+1)].y
            -- Include the proposed step, not just the old concavity.
            if math.max((a+b)*0.5-v.y+q,(c+d)*0.5-v.y+q)>0.12 then valid=false end
            if valid and (not best or v.steps<best.paidSteps) then
                best={key=p.key,x=p.x,z=p.z,beforeY=v.y,
                    paidSteps=v.steps,paidDepthM=v.depth,
                    cumulativeTargetM=p.targetM,nominalStepM=q}
            end
        end
    end
    return {state=best and "NEXT_STEP_PREVIEW_ONLY"
        or remaining==0 and "TARGET_OBSERVED" or "NO_ADMISSIBLE_NEXT_STEP",
        nextStep=best,paidSteps=done,remainingSteps=remaining,
        doesNotWrite=true,authorizesMainWrite=false},nil
end
return R
