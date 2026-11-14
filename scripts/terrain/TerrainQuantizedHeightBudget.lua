-- Experimental main-heightmap actuator planning only: NEVER writes terrain.
-- FS25 main grid sampled from getTerrainHeightAtWorldPos is NOT the native
-- 0.125m wheel-displacement surface. Its vertical step is map-dependent.
-- No estimate based on one input delta may silently authorize a write.
-- An authorizing step MUST be fully paid for by actual, verified budget.
-- In particular, +1e-6 comparisons can spend a full 3.891mm step on
-- slightly less than 3.891mm of requested damage, so do not round UP
-- request/depth budget when deciding whether native geometry can move.
RealismExtensionsTerrainQuantizedHeightBudget =
    RealismExtensionsTerrainQuantizedHeightBudget or {}
local Model = RealismExtensionsTerrainQuantizedHeightBudget
Model.VERSION = 5

local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end

local function currentGameTimeMs()
    return g_currentMission~=nil
        and tonumber(g_currentMission.time) or nil
end

function Model.new(options)
    options=options or {}
    local quantum=tonumber(options.quantumM)
    -- The ~3.891mm observed step is NOT automatically assumed for other maps.
    if not finite(quantum) or quantum<0.00025 or quantum>0.05 then
        return nil,"QUANTUM_UNVERIFIED"
    end
    -- The previous default tolerated 0.5mm per single ~3.9mm step,
    -- enough to hide systematic amplification over many successful
    -- operations. Keep readback jitter conservative AND scale with q.
    local requestedTolerance=tonumber(options.toleranceM) or 0.00005
    if not finite(requestedTolerance) or requestedTolerance<=0 then
        return nil,"INVALID_READBACK_TOLERANCE"
    end
    local tolerance=math.min(requestedTolerance,0.00005,quantum*0.02)
    return setmetatable({
        quantumM=quantum,
        toleranceM=tolerance,
        maxDebtM=math.max(quantum,tonumber(options.maxDebtM) or 0.10),
        entries={},
        -- A monotonic server-side clock is mandatory for NEW source epochs.
        -- Tests inject a fake clock; ordinary standalone research calls
        -- without a loaded mission fail closed rather than guess recency.
        clock=type(options.clock)=="function"
            and options.clock or currentGameTimeMs,
        nextId=0,
        nextDamageEpochId=0,
        quarantined=false,
        stats={requestedM=0,accepted=0,pending=0,belowQuantum=0,
            noBudget=0,verified=0,zeroEffect=0,anomalies=0,
            maxErrorM=0,unavailable=0,
            ownedTargetSeeds=0,ownedTargetSeededM=0,
            ownerLedgerDrift=0,
            recoveryProofsApplied=0,
            recoveredDepthM=0,
            freshEpochBaselines=0,freshEpochOpened=0,
            freshEpochRejected=0,freshEpochDrift=0}
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
    local item=self.entries[key] or {debtM=0,pending=nil,mode="INCREMENTAL"}
    if item.mode~=nil and item.mode~="INCREMENTAL" then
        return nil,"MIXED_DEBT_CONTRACT"
    end
    item.mode="INCREMENTAL"
    if item.pending~=nil then return nil,"VERTEX_PENDING" end
    item.debtM=math.min(self.maxDebtM,item.debtM+damageM)
    self.entries[key]=item
    self.stats.requestedM=self.stats.requestedM+damageM
    if item.debtM<self.quantumM then
        self.stats.belowQuantum=self.stats.belowQuantum+1
        return nil,"SUB_QUANTUM_DEBT"
    end
    if remainingGeometryBudgetM<self.quantumM then
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

-- This is the contract for the SHADOW planner's cumulative vertex
-- target. Repeated observation of the SAME logical target MUST NOT turn into
-- repeated native digging. The target is a requested cumulative depth for a
-- single verified geometry epoch; only measured successful writes advance
-- committedM. This is STILL a pure planner and never writes GIANTS terrain.
function Model:requestTarget(key,cumulativeDepthM,remainingGeometryBudgetM,epochTicket)
    if self.quarantined then return nil,"QUARANTINED" end
    if type(key)~="string" or key==""
        or not finite(cumulativeDepthM) or cumulativeDepthM<0
        or cumulativeDepthM>self.maxDebtM
        or not finite(remainingGeometryBudgetM)
        or remainingGeometryBudgetM<0 then
        return nil,"INVALID_CUMULATIVE_TARGET"
    end
    local item=self.entries[key]
    if item==nil then
        item={debtM=0,pending=nil,mode="TARGET",
            demandTargetM=0,committedM=0}
        self.entries[key]=item
    end
    if item.mode~="TARGET" then return nil,"MIXED_DEBT_CONTRACT" end
    if item.pending~=nil then return nil,"VERTEX_PENDING" end
    if item.recoveryEpochPending then
        -- Old wheel/model demand remains invalid, even if it asks for
        -- precisely the same height as a legitimately fresh source.
        return nil,"NEW_DAMAGE_EPOCH_REQUIRED_AFTER_RECOVERY"
    end
    if item.epochTicket~=nil then
        -- A ticket is an in-process capability generated ONLY after a
        -- distinct post-recovery wheel observation. No old three-arg
        -- caller may replay the previous cumulative target.
        if epochTicket~=item.epochTicket then
            return nil,"NEW_DAMAGE_EPOCH_TICKET_REQUIRED"
        end
        if math.abs(cumulativeDepthM-(item.authorizedTargetM or -1))
            >0.000000001 then
            return nil,"NEW_DAMAGE_TARGET_NOT_PROVEN"
        end
    end
    if cumulativeDepthM+0.000001<(item.demandTargetM or 0) then
        -- A decrease needs a separately VERIFIED recovery/epoch transition.
        -- Do not silently rebase onto transient virtual wheel input.
        return nil,"TARGET_DECREASE_REQUIRES_RECOVERY_EPOCH"
    end
    local old=item.demandTargetM or 0
    item.demandTargetM=math.max(old,cumulativeDepthM)
    item.debtM=math.max(0,item.demandTargetM-(item.committedM or 0))
    self.stats.requestedM=self.stats.requestedM
        +math.max(0,item.demandTargetM-old)
    if item.debtM<self.quantumM then
        self.stats.belowQuantum=self.stats.belowQuantum+1
        return nil,"SUB_QUANTUM_DEBT"
    end
    if remainingGeometryBudgetM<self.quantumM then
        self.stats.noBudget=self.stats.noBudget+1
        return nil,"NO_SAFE_GEOMETRY_STEP"
    end
    self.nextId=self.nextId+1
    local plan={id=self.nextId,key=key,stepM=self.quantumM,
        active=true,mode="TARGET"}
    item.pending=plan
    self.stats.pending=self.stats.pending+1
    self.stats.accepted=self.stats.accepted+1
    return plan,nil
end

-- RESTART/RELOAD ownership bootstrap. The geometry journal carries
-- independently measured RE-owned MAIN height debt across a savegame;
-- this short-lived quantizer ledger normally starts EMPTY each session.
-- Without seeding, an already-persisted q-sized rut could be excavated
-- AGAIN when its old cumulative target is first observed after load.
--
-- Only the guarded caller may supply a PHYSICALLY VERIFIED, RE-OWNED
-- baseline measured from the journal's immutable pre-RE height to the
-- CURRENT native MAIN height. A model wheel target/visual tire mark must
-- NEVER be used as the source of committed material here.
--
-- This operation causes ZERO terrain writes. The cumulative contract is
-- always relative to the ORIGINAL pre-RE height, not the session start.
function Model:seedOwnedTarget(key,committedDepthM)
    if self.quarantined then return false,"QUARANTINED" end
    if type(key)~="string" or key==""
        or not finite(committedDepthM) or committedDepthM<0
        or committedDepthM>self.maxDebtM then
        return false,"INVALID_OWNED_GEOMETRY_DEPTH"
    end
    local item=self.entries[key]
    if item~=nil then
        if item.mode~="TARGET" then
            return false,"MIXED_DEBT_CONTRACT"
        end
        if item.pending~=nil then
            return false,"TARGET_LEDGER_NOT_IDLE"
        end
        -- Every subsequent call checks physical ownership continuity,
        -- rather than blindly trusting this process' older in-memory
        -- committed total. If a foreign writer changed MAIN height,
        -- stop all further writes; no automatic recovery or rebase.
        local drift=math.abs((item.committedM or 0)-committedDepthM)
        if drift>0.00001 then
            self.quarantined=true
            self.stats.ownerLedgerDrift=
                (self.stats.ownerLedgerDrift or 0)+1
            return false,"OWNED_GEOMETRY_LEDGER_DRIFT"
        end
        return true,"ALREADY_TRACKED"
    end
    self.entries[key]={
        debtM=0,pending=nil,mode="TARGET",
        demandTargetM=committedDepthM,
        committedM=committedDepthM
    }
    self.stats.ownedTargetSeeds=(self.stats.ownedTargetSeeds or 0)+1
    self.stats.ownedTargetSeededM=
        (self.stats.ownedTargetSeededM or 0)+committedDepthM
    return true,"OWNED_GEOMETRY_SEEDED"
end

-- Apply only a ONE-SHOT receipt issued by the geometry journal from
-- an independently verified native recovery callback with no collateral.
-- An ordinary 'worked area' event or Lua boolean is not physical proof.
function Model:syncVerifiedRecovery(journal,proof)
    if self.quarantined then return false,"QUARANTINED" end
    if type(journal)~="table"
        or type(journal.consumeRecoveryProof)~="function"
        or type(proof)~="table"
        or type(proof.key)~="string" then
        return false,"RECOVERY_PROOF_REQUIRED"
    end
    local item=self.entries[proof.key]
    if item==nil or item.mode~="TARGET" then
        return false,"NO_CUMULATIVE_TARGET"
    end
    if item.pending~=nil then return false,"VERTEX_PENDING" end
    local measured,why=journal:consumeRecoveryProof(proof)
    if measured==nil then
        self.quarantined=true
        return false,why
    end
    if math.abs((item.committedM or 0)-measured.beforeDepthM)>0.00001
        or measured.afterDepthM>=measured.beforeDepthM-0.00001 then
        self.quarantined=true
        return false,"RECOVERY_LEDGER_OR_DEPTH_MISMATCH"
    end
    -- Reset paid depth to actual remaining physical depression, never
    -- to an unverified target. Crucially, freeze replay of the older
    -- source epoch so 'still wants 2q' cannot re-excavate the recovered
    -- 1q in the very next frame.
    item.committedM=measured.afterDepthM
    item.demandTargetM=measured.afterDepthM
    item.debtM=0
    item.recoveryEpochPending=true
    item.epochTicket=nil
    item.authorizedTargetM=nil
    -- Only this journal produced the consumed recovery proof. The native
    -- height is an anchor, not an inference from SpatialHistory or graphics.
    -- After a new process starts this RAM-only epoch authority is LOST;
    -- a production actuator needs an independently persisted epoch fence.
    local markedMs=self.clock()
    item.recoveryAnchor={
        journal=journal,key=measured.key,
        x=measured.x,z=measured.z,
        originalY=measured.originalY,afterY=measured.afterY,
        recoveredDepthM=measured.afterDepthM,
        completed=measured.completed,
        markedMs=finite(markedMs) and markedMs or nil,
        baseline=nil
    }
    self.stats.recoveryProofsApplied=
        self.stats.recoveryProofsApplied+1
    self.stats.recoveredDepthM=self.stats.recoveredDepthM
        +(measured.beforeDepthM-measured.afterDepthM)
    return true,measured.completed
end

-- A second, independent post-repair wheel-source generation is needed
-- before fresh damage can be paid for. Caller-provided model data NEVER
-- counts as native terrain evidence, and this method performs NO write.
-- The first NEW sample after recovery establishes a NEW wheel exposure
-- baseline; it cannot itself authorize a q-step. A later continuous
-- traveled contact from the same wheel may demonstrate additional plastic
-- demand, still subject to all MAIN footprint and geometry writer gates.
--
-- The future wheel adapter MUST supply a dedicated post-repair cumulative
-- plastic-damage counter. Replaying SpatialHistory.rutDepthM or an older
-- SHADOW target is not this contract. This function is intentionally NOT
-- wired to a gameplay setter or an arbitrary console command.
function Model:observeFreshDamage(key,journal,sample)
    if self.quarantined then return nil,"QUARANTINED" end
    local item=self.entries[key]
    local anchor=item~=nil and item.recoveryAnchor or nil
    if item==nil or item.mode~="TARGET" or anchor==nil
        or (not item.recoveryEpochPending and item.epochTicket==nil) then
        return nil,"NO_VERIFIED_RECOVERY_EPOCH"
    end
    if item.pending~=nil then return nil,"VERTEX_PENDING" end
    if journal~=anchor.journal or type(journal.getHeight)~="function"
        or not finite(anchor.x) or not finite(anchor.z)
        or not finite(anchor.afterY) then
        return nil,"RECOVERY_JOURNAL_MISMATCH"
    end
    local nativeY=journal:getHeight(anchor.x,anchor.z)
    if not finite(nativeY) or math.abs(nativeY-anchor.afterY)>0.00001 then
        self.quarantined=true
        self.stats.freshEpochDrift=self.stats.freshEpochDrift+1
        local owned=journal.observations~=nil
            and journal.observations[key] or nil
        if owned~=nil then owned.owned=false end
        return nil,"RECOVERY_EPOCH_HEIGHT_DRIFT"
    end
    local owned=journal.observations~=nil
        and journal.observations[key] or nil
    if (anchor.completed and owned~=nil)
        or (not anchor.completed and
            (owned==nil or owned.owned~=true
                or math.abs((owned.preREHeightM or 0)-anchor.originalY)>0.00001
                or math.abs((owned.observedHeightM or 0)-anchor.afterY)>0.00001)) then
        self.quarantined=true
        return nil,"RECOVERY_EPOCH_OWNERSHIP_CHANGED"
    end
    local timestamp=self.clock()
    if type(sample)~="table" or not finite(timestamp)
        or not finite(anchor.markedMs) or timestamp<=anchor.markedMs
        or type(sample.wheelKey)~="string" or sample.wheelKey==""
        or not finite(sample.sequence) or sample.sequence<1
        or sample.sequence~=math.floor(sample.sequence)
        or not finite(sample.contactX) or not finite(sample.contactZ)
        or not finite(sample.freshCumulativeDamageM)
        or sample.freshCumulativeDamageM<0
        or sample.freshCumulativeDamageM>self.maxDebtM
        or sample.grounded~=true or sample.pathContinuity~=true
        or sample.mainGeometryState~="MAIN_RESEARCH_CANDIDATE" then
        self.stats.freshEpochRejected=self.stats.freshEpochRejected+1
        return nil,"FRESH_DAMAGE_SOURCE_NOT_VERIFIED"
    end
    -- One MAIN vertex is NOT every narrow wheel contact. Even an observed
    -- continuous travel segment must remain locally within its cell.
    local unit=tonumber(journal.unitM) or 0
    local dx=sample.contactX-anchor.x
    local dz=sample.contactZ-anchor.z
    if unit<=0 or dx*dx+dz*dz>(0.70*unit)^2 then
        return nil,"FRESH_DAMAGE_OUTSIDE_MAIN_VERTEX"
    end
    local first=anchor.baseline
    if first==nil then
        anchor.baseline={
            wheelKey=sample.wheelKey,sequence=sample.sequence,
            timeMs=timestamp,x=sample.contactX,z=sample.contactZ,
            damageM=sample.freshCumulativeDamageM
        }
        self.stats.freshEpochBaselines=self.stats.freshEpochBaselines+1
        return nil,"POST_RECOVERY_SOURCE_BASELINE"
    end
    if sample.wheelKey~=first.wheelKey
        or sample.sequence<=first.sequence or timestamp<=first.timeMs then
        return nil,"STALE_OR_DIFFERENT_WHEEL_SOURCE"
    end
    local movement=math.sqrt((sample.contactX-first.x)^2
        +(sample.contactZ-first.z)^2)
    if movement<math.max(0.20,unit*0.20) then
        return nil,"POST_RECOVERY_TRAVEL_NOT_PROVEN"
    end
    local fresh=sample.freshCumulativeDamageM-first.damageM
    if fresh<=0.00000001 or not finite(fresh) then
        return nil,"NO_POST_RECOVERY_DAMAGE_GROWTH"
    end
    -- This authorization is bounded to the physical remaining depth plus
    -- ONLY modeled incremental NEW damage; it is not an old model target.
    local target=anchor.recoveredDepthM+fresh
    if target>self.maxDebtM or target<item.committedM then
        return nil,"FRESH_DAMAGE_OVER_BUDGET"
    end
    if item.epochTicket==nil then
        self.nextDamageEpochId=self.nextDamageEpochId+1
        item.epochTicket={key=key,id=self.nextDamageEpochId}
        item.recoveryEpochPending=false
        self.stats.freshEpochOpened=self.stats.freshEpochOpened+1
    end
    item.authorizedTargetM=target
    return item.epochTicket,nil
end

-- The name is retained for old callers, but a boolean 'true' can NO
-- LONGER erase a paid physical depth or reopen a stale wheel target.
-- This records the verified completed recovery while retaining a
-- blocked new-demand-epoch tombstone for this process.
function Model:retireTarget(key,journal,proof)
    if type(proof)~="table" or proof.key~=key
        or proof.completed~=true then
        return false,"RECOVERY_PROOF_REQUIRED"
    end
    return self:syncVerifiedRecovery(journal,proof)
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
    -- Native ownership is a measured height, not the nominal request.
    -- Debit the ACTUAL measured lowering so rounding/readback error cannot
    -- silently accumulate through a series of apparently successful steps.
    -- A writer can still change terrain without our attribution: this
    -- remains a bounded observation, not proof of native causality.
    -- A readback tolerance answers "did one q-sized step happen?", NOT
    -- "may we excavate a little more than the player requested?" These
    -- are separate contracts. The former 50-micrometer allowance here
    -- permitted q+0.02mm of measured lowering against a demand of q.
    -- Allow only a tiny floating-point comparison allowance (<=1nm
    -- for normal map quantums), never the 50um quantizer readback band.
    -- Any observed excess quarantines the research writer. This does not
    -- undo an already executed native edit; actual engine proof is still
    -- required before enabling automatic terrain writes.
    local accountingRoundoffM=math.max(0.000000001,
        math.abs(item.debtM)*0.0000001)
    if lowered>item.debtM+accountingRoundoffM then
        self.stats.anomalies=self.stats.anomalies+1
        self.quarantined=true
        return {verified=false,loweringM=lowered,
            debtM=item.debtM},"OBSERVED_LOWERING_EXCEEDS_DEBT"
    end
    item.debtM=math.max(0,item.debtM-lowered)
    if item.mode=="TARGET" then
        item.committedM=(item.committedM or 0)+lowered
        item.debtM=math.max(0,(item.demandTargetM or 0)-item.committedM)
        if item.recoveryAnchor~=nil and item.epochTicket~=nil then
            -- Each verified single-quantum write advances the physical
            -- anchor. A foreign subsequent move still trips the drift guard.
            item.recoveryAnchor.afterY=afterY
        end
    end
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
