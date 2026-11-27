-- Isolated research executor. Deliberately NOT wired to runtime, console,
-- wheel callbacks, save callbacks, or a native setter. A future adapter must
-- enforce disposable clone, mission policy, session consumption, external
-- observer/contact exclusion and live-runtime quarantine. No automatic retry
-- or rollback. A failed physical attempt means discard the test save.
RealismExtensionsTerrainMainPatchExecutor =
    RealismExtensionsTerrainMainPatchExecutor or {}
local E=RealismExtensionsTerrainMainPatchExecutor
E.VERSION=2
E.MAX_CALLS=8
local EPS=0.000001
local function finite(v)
    return type(v)=="number" and v==v and math.abs(v)~=math.huge
end
local function exclusive(fn)
    local ok,value=pcall(fn)
    return ok and value==true
end

function E.new(options)
    options=options or {}
    local live=options.liveJournal
    local planner=options.planner
    local q=options.quantumM
    local limit=options.maxCalls
    local radius=options.radius
    local roundTrip=options.roundTrip==true
    if options.explicitResearchPermission~=true
        or options.disposableSaveConfirmed~=true
        or type(options.verifyExclusive)~="function"
        or type(options.writeHeight)~="function" then
        return nil,"PATCH_EXPLICIT_RESEARCH_ADAPTER_REQUIRED"
    end
    if not finite(q) or q<0.003 or q>0.012
        or not finite(limit) or limit~=math.floor(limit)
        or limit<1 or limit>E.MAX_CALLS
        or (roundTrip and limit<2)
        or not finite(radius) or radius~=math.floor(radius)
        or radius<1 or radius>2 then
        return nil,"PATCH_EXECUTOR_LIMIT_INVALID"
    end
    if type(live)~="table" or type(planner)~="table"
        or type(live.getHeight)~="function"
        or live.unitM~=planner.unitM or not finite(live.unitM)
        or live.unitM<=0 then return nil,"PATCH_LIVE_REFERENCE_REQUIRED" end
    local J=RealismExtensionsTerrainGeometryJournal
    local B=RealismExtensionsTerrainQuantizedHeightBudget
    local R=RealismExtensionsTerrainMainPatchReconciliation
    local D=RealismExtensionsTerrainAbsoluteVertexCandidate
    local U=RealismExtensionsTerrainAbsoluteRecoveryCandidate
    if not J or not B or not R or not D or (roundTrip and not U) then
        return nil,"PATCH_EXECUTOR_DEPENDENCIES_UNAVAILABLE"
    end
    return setmetatable({live=live,planner=planner,q=q,limit=limit,
        radius=radius,ix=options.ix,iz=options.iz,gradient=options.gradient,
        roundTrip=roundTrip,
        verifyExclusive=options.verifyExclusive,writeHeight=options.writeHeight,
        consumed=false},{__index=E})
end

function E:run()
    if self.consumed then return nil,"PATCH_EXECUTOR_ALREADY_CONSUMED" end
    -- Consume even a refused run; the adapter must also consume its
    -- mission-wide research permission. A new instance is NOT an approval.
    self.consumed=true
    local live=self.live
    local R=RealismExtensionsTerrainMainPatchReconciliation
    local J=RealismExtensionsTerrainGeometryJournal
    local B=RealismExtensionsTerrainQuantizedHeightBudget
    local D=RealismExtensionsTerrainAbsoluteVertexCandidate
    local U=RealismExtensionsTerrainAbsoluteRecoveryCandidate
    local calls,verified,recovered=0,0,0
    local receipts,recoveryReceipts={},{}
    local downLimit=self.roundTrip and math.floor(self.limit/2) or self.limit
    local journal,budget
    local result={calls=0,verified=0,recovered=0,receipts=receipts,
        recoveryReceipts=recoveryReceipts,roundTrip=self.roundTrip,
        discardCopy=true,authorizesProductionWrite=false}
    local function stop(state,reason)
        result.state=state
        result.reason=reason
        result.calls=calls
        result.verified=verified
        result.recovered=recovered
        if state=="FAILED" and calls>0 then
            -- Only private research ledgers are touched. The future live
            -- adapter MUST quarantine its runtime separately before return.
            if budget then budget.quarantined=true end
            if journal then journal:quarantine("PATCH_RESEARCH_FAILED") end
        end
        return result
    end
    local function run()
        if not exclusive(self.verifyExclusive) then
            return stop("REFUSED","PATCH_EXCLUSIVITY_UNVERIFIED")
        end
        local liveAnchor,why=R.capture(self.planner,live,self.ix,self.iz,
            self.radius,self.q,self.gradient,nil)
        if not liveAnchor or liveAnchor.state~="FRESH_RESEARCH_ANCHOR" then
            return stop("REFUSED",why or "PATCH_LIVE_REFERENCE_BLOCKED")
        end
        local expected={}
        for _,p in ipairs(liveAnchor.points) do expected[p.key]=p.anchorY end
        local unit,terrain=live.unitM,live.terrain
        local function matchesLive()
            if live.quarantined or live.pendingCount~=0
                or live.reservedObservationSlots~=0
                or live.terrain~=terrain or live.unitM~=unit then return false end
            for _,p in ipairs(liveAnchor.points) do
                if live.observations[p.key]~=nil
                    or live.recoveryFences[p.key]~=nil
                    or live.pendingByVertex[p.key]~=nil then return false end
                local y=live:getHeight(p.x,p.z)
                if not finite(y) or math.abs(y-expected[p.key])>EPS then
                    return false
                end
            end
            return true
        end
        journal=J.new(terrain,{unitM=unit,
            maxObservations=#liveAnchor.points,maxRecoveryFences=#liveAnchor.points,
            sample=function(x,z) return live:getHeight(x,z) end})
        budget=assert(B.new({quantumM=self.q,toleranceM=0.00005}))
        -- Reuse the FROZEN target, not a second observation of model demand.
        -- The reconciler's own checks still validate the private journal.
        local frozen={unitM=unit}
        function frozen:planMainPatch()
            local points={}
            for _,p in ipairs(liveAnchor.points) do
                if not p.halo then
                    points[#points+1]={key=p.key,targetDepthM=p.targetM,
                        steps=p.targetSteps}
                end
            end
            return {points=points}
        end
        local anchor,anchorWhy=R.capture(frozen,journal,self.ix,self.iz,
            self.radius,self.q,self.gradient,budget)
        if not anchor or anchor.state~="FRESH_RESEARCH_ANCHOR"
            or not matchesLive() then
            return stop("REFUSED",anchorWhy or "PATCH_ANCHOR_CHANGED")
        end
        for _,p in ipairs(anchor.points) do
            if math.abs(p.anchorY-expected[p.key])>EPS then
                return stop("REFUSED","PATCH_PRIVATE_ANCHOR_DRIFT")
            end
        end
        local selected
        local function guard()
            return exclusive(self.verifyExclusive) and matchesLive()
        end
        local candidate=assert(D.new({journal=journal,budget=budget,
            explicitWrite=true,verifyExclusive=guard,
            writeHeight=function(x,z,target)
                -- Final guard executes inside the single-vertex adapter,
                -- after its reservation and strict 3x3 preflight. The live
                -- journal remains idle while the private token is active.
                if selected==nil or x~=selected.x or z~=selected.z
                    or calls>=self.limit or not guard()
                    or math.abs(target-(selected.beforeY-0.75*self.q))>EPS then
                    return false
                end
                calls=calls+1 -- consume BEFORE native code, including throws
                return self.writeHeight(x,z,target)
            end}))
        -- A reverse walk through verified DOWN receipts visits the same
        -- intermediate profiles in reverse order. Do NOT compute a new
        -- smoothing target or treat a work-area event as recovery authority.
        -- Only run after a clean bounded prefix, never after a failed step.
        local function restore(downState)
            result.downState=downState
            result.phase="UP"
            for i=#receipts,1,-1 do
                local receipt=receipts[i]
                local p=anchor.grid[receipt.key]
                local before=expected[p.key]
                local entry=budget.entries[p.key]
                if not guard() or calls>=self.limit
                    or math.abs(before-receipt.afterY)>EPS
                    or not entry or not finite(entry.committedM)
                    or math.abs(entry.committedM-(p.anchorY-before))>0.00001
                    or receipt.beforeY>p.anchorY+EPS then
                    return stop("FAILED","PATCH_UP_REFERENCE_OR_LIMIT_CHANGED")
                end
                local beforeCalls=calls
                local up=assert(U.new({journal=journal,budget=budget,
                    quantumM=self.q,explicitResearchPermission=true,
                    disposableSaveConfirmed=true,verifyExclusive=guard,
                    writeHeight=function(x,z,target)
                        if x~=p.x or z~=p.z or calls>=self.limit
                            or not guard()
                            or math.abs(target-(before+1.25*self.q))>EPS then
                            return false
                        end
                        calls=calls+1
                        return self.writeHeight(x,z,target)
                    end}))
                local step,why=up:applyOnce(p.x,p.z)
                if not step or not step.verified or calls~=beforeCalls+1
                    or not finite(step.beforeY) or not finite(step.afterY)
                    or math.abs(step.beforeY-before)>EPS
                    or math.abs(step.afterY-receipt.beforeY)>EPS
                    or step.afterY>p.anchorY+0.000000001 then
                    return stop("FAILED",why or "PATCH_UP_RECEIPT_MISMATCH")
                end
                expected[p.key]=step.afterY
                if not guard() or journal.pendingCount~=0
                    or journal.reservedObservationSlots~=0 then
                    return stop("FAILED","PATCH_UP_COLLATERAL_OR_EXCLUSIVITY_CHANGED")
                end
                local fence=journal.recoveryFences[p.key]
                local depth=p.anchorY-step.afterY
                if not fence or fence.trusted~=true or fence.accounted~=true
                    or fence.pendingProof or journal.recoveryProofs[p.key]~=nil
                    or entry.recoveryEpochPending~=true
                    or math.abs(entry.committedM-depth)>0.00001 then
                    return stop("FAILED","PATCH_UP_ACCOUNTING_NOT_CLOSED")
                end
                -- Check observed full envelope independently even if a
                -- native readback differed from receipt by less than EPS.
                for _,v in ipairs(anchor.points) do
                    local y=expected[v.key]
                    local dep=v.anchorY-y
                    for dx=-1,1 do for dz=-1,1 do
                        if dx~=0 or dz~=0 then
                            local neighbor=anchor.grid[tostring(v.ix+dx)..":"..tostring(v.iz+dz)]
                            if neighbor and math.abs(dep-(neighbor.anchorY-expected[neighbor.key]))
                                >self.gradient*unit*math.sqrt(dx*dx+dz*dz) then
                                return stop("FAILED","PATCH_UP_GRADIENT_EXCEEDED")
                            end
                        end
                    end end
                end
                recovered=recovered+1
                recoveryReceipts[#recoveryReceipts+1]={key=p.key,
                    beforeY=step.beforeY,afterY=step.afterY,
                    actualRaiseM=step.actualRaiseM}
            end
            for _,p in ipairs(anchor.points) do
                if math.abs(expected[p.key]-p.anchorY)>EPS then
                    return stop("FAILED","PATCH_ORIGINAL_HALO_NOT_RESTORED")
                end
                local b=budget.entries[p.key]
                local fence=journal.recoveryFences[p.key]
                if b and (math.abs(b.committedM)>EPS
                    or b.recoveryEpochPending~=true
                    or not fence or fence.completed~=true
                    or fence.trusted~=true or fence.accounted~=true) then
                    return stop("FAILED","PATCH_FINAL_RECOVERY_FENCE_NOT_CLOSED")
                end
            end
            if journal.observationCount~=0 or journal.pendingCount~=0
                or recovered~=verified or calls~=verified+recovered or not guard() then
                return stop("FAILED","PATCH_ROUNDTRIP_NOT_CLOSED")
            end
            return stop("RESTORED","PATCH_MAIN_ROUNDTRIP_IMMEDIATE_ONLY")
        end
        local function finishDown(state,reason)
            if self.roundTrip and verified>0 then return restore(state) end
            return stop(state,reason)
        end
        result.phase="DOWN"
        local initial=R.previewNext(anchor,journal,budget)
        if not initial or initial.remainingSteps==0 then
            return stop("REFUSED","PATCH_NO_SUPPORTED_WHOLE_STEP")
        end
        result.requestedSteps=initial.remainingSteps
        while true do
            if not guard() then
                return stop(calls>0 and "FAILED" or "REFUSED",
                    "PATCH_EXCLUSIVITY_OR_FULL_HALO_CHANGED")
            end
            local preview,previewWhy=R.previewNext(anchor,journal,budget)
            if not preview then return stop("FAILED",previewWhy) end
            result.remainingSteps=preview.remainingSteps
            if preview.paidSteps~=verified then
                return stop("FAILED","PATCH_PAID_STEP_COUNT_CHANGED")
            end
            if preview.state=="TARGET_OBSERVED" then
                return finishDown("COMPLETE","PATCH_MAIN_IMMEDIATE_ONLY")
            end
            if calls>=downLimit then
                return finishDown("LIMIT_REACHED","PATCH_BOUNDED_PREFIX_ONLY")
            end
            selected=preview.nextStep
            if selected==nil then
                return finishDown(verified>0 and "PARTIAL" or "REFUSED",
                    "PATCH_NO_ADMISSIBLE_NEXT_STEP")
            end
            local beforeCalls=calls
            local step,stepWhy=candidate:applyOne(selected.x,selected.z,
                selected.cumulativeTargetM,"CUMULATIVE")
            if not step or not step.verified or calls~=beforeCalls+1
                or not finite(step.beforeY) or not finite(step.afterY)
                or math.abs(step.beforeY-expected[selected.key])>EPS then
                return stop("FAILED",stepWhy or "PATCH_SINGLE_STEP_NOT_VERIFIED")
            end
            expected[selected.key]=step.afterY
            if not guard() then
                return stop("FAILED","PATCH_COLLATERAL_OR_EXCLUSIVITY_CHANGED")
            end
            local settled,settleWhy=R.previewNext(anchor,journal,budget)
            if not settled or settled.paidSteps~=verified+1
                or settled.remainingSteps~=preview.remainingSteps-1 then
                return stop("FAILED",settleWhy or "PATCH_SETTLEMENT_NOT_CLOSED")
            end
            verified=verified+1
            receipts[#receipts+1]={key=selected.key,beforeY=step.beforeY,
                afterY=step.afterY,actualLowerM=step.beforeY-step.afterY,
                paidSteps=verified}
            result.remainingSteps=settled.remainingSteps
            selected=nil
        end
    end
    local ok,out=pcall(run)
    if not ok then return stop("FAILED",tostring(out)) end
    return out,nil
end
return E
