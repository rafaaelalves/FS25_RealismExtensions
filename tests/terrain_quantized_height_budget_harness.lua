-- Pure model tests; no GIANTS engine, no native terrain writes.
-- Evidence: observed main-height delta quantization ~255/65535 m in 2026-10-25
-- log; the candidate quantum is supplied, never inferred from a generic map.
dofile("scripts/terrain/TerrainQuantizedHeightBudget.lua")
local B=RealismExtensionsTerrainQuantizedHeightBudget
local q=255/65535
assert(B.new({})==nil)
assert(B.new({quantumM=0})==nil)
assert(B.new({quantumM=0/0})==nil)
local m=assert(B.new({quantumM=q,maxDebtM=0.10,toleranceM=0.00012}))
assert(m.quarantined==false)
assert(math.abs(m.toleranceM-0.00005)<1e-12)
local strict=assert(B.new({quantumM=q,toleranceM=0.0005}))
assert(strict.toleranceM<=0.00005)
assert(B.new({quantumM=q,toleranceM=-0.001})==nil)
assert(B.new({quantumM=q,toleranceM=0/0})==nil)

-- A 0.2mm mismatch previously passed the 0.5mm default tolerance,
-- letting systematic error accumulate over many nominal "successes".
local highMismatch=assert(strict:requestTarget("mismatch",q,0.10))
local mismatch,reasonMismatch=strict:settle(highMismatch,100,100-(q+0.0002))
assert(mismatch~=nil and mismatch.verified==false)
assert(reasonMismatch=="UNBOUNDED_OBSERVED_DELTA")
assert(strict.quarantined==true)
assert(strict.entries.mismatch.committedM==0)

-- A 20-micrometer overshoot *is* close to one native quantum, so it
-- passes the 50um quantization readback check. But it is STILL more
-- actual terrain removed than the FULL authorized debt of q. Do not
-- mistakenly apply that readback tolerance as a material budget.
local excess=assert(B.new({quantumM=q,toleranceM=0.00005}))
local excessPlan=assert(excess:requestTarget("strict-budget",q,0.10))
local excessive,excessReason=excess:settle(
    excessPlan,100,100-(q+0.00002))
assert(excessive~=nil and excessive.verified==false)
assert(excessReason=="OBSERVED_LOWERING_EXCEEDS_DEBT")
assert(excess.quarantined==true)
assert(excess.stats.anomalies==1)
assert(excess.entries["strict-budget"].committedM==0)
assert(math.abs(excess:getDebt("strict-budget")-q)<1e-10)
assert(select(1,excess:requestTarget("strict-budget",2*q,0.10))==nil)

-- The same safety rule applies to true incremental damage contracts;
-- no extra native material removal is accepted as an authorized write.
local incrementalExcess=assert(B.new({quantumM=q}))
local incrementalPlan=assert(incrementalExcess:request("inc",q,0.10))
local incBad,incWhy=incrementalExcess:settle(
    incrementalPlan,100,100-(q+0.00001))
assert(incBad.verified==false
    and incWhy=="OBSERVED_LOWERING_EXCEEDS_DEBT")
assert(incrementalExcess.quarantined)
assert(math.abs(incrementalExcess:getDebt("inc")-q)<1e-10)

-- Noise below the booked quantum remains an accepted measurement but is
-- credited at the actual measured amount, NEVER the nominal q.
local smallShortfall=assert(B.new({quantumM=q}))
local shortPlan=assert(smallShortfall:requestTarget("noise",q,0.10))
local short=assert(smallShortfall:settle(
    shortPlan,100,100-(q-0.00002)))
assert(short.verified==true and not smallShortfall.quarantined)
assert(math.abs(smallShortfall.entries.noise.committedM-(q-0.00002))
    <1e-9)
assert(math.abs(smallShortfall:getDebt("noise")-0.00002)<1e-9)

-- Even a small *accepted* jitter is measured and debited from the
-- cumulative target, NOT rounded to the nominal q in accounting.
local accounted=assert(B.new({quantumM=q,toleranceM=0.00005}))
local first=assert(accounted:requestTarget("measured",2*q,0.10))
local actualFirst=q-0.00002
local res=assert(accounted:settle(first,100,100-actualFirst))
assert(res.verified==true)
assert(math.abs(accounted.entries.measured.committedM-actualFirst)<1e-9)
assert(math.abs(accounted:getDebt("measured")-(2*q-actualFirst))<1e-9)
local second=assert(accounted:requestTarget("measured",2*q,0.10))
assert(assert(accounted:settle(second,100,100-q)).verified)
assert(math.abs(accounted.entries.measured.committedM-(actualFirst+q))<1e-9)
assert(select(1,accounted:requestTarget("measured",2*q,0.10))==nil)
assert(accounted.stats.verified==2)

-- LIVE regression (Estancia Sao Carlos): the 03-Nov absolute setter
-- request of 1.5mm returned 3.891mm, twice. Holding 1.5mm (or 3mm)
-- is mandatory; it is NOT permissible to round a native step upward.
local live=assert(B.new({quantumM=q,toleranceM=0.00005}))
local liveKey="344:387"
local livePlan,liveWhy=live:request(liveKey,0.0015,0.10)
assert(livePlan==nil and liveWhy=="SUB_QUANTUM_DEBT")
livePlan,liveWhy=live:request(liveKey,0.0015,0.10)
assert(livePlan==nil and liveWhy=="SUB_QUANTUM_DEBT")
assert(math.abs(live:getDebt(liveKey)-0.003)<1e-10)
livePlan=assert(live:request(liveKey,0.0015,0.10))
assert(math.abs(livePlan.stepM-q)<1e-10)
assert(assert(live:settle(livePlan,152.501938,152.501938-q)).verified)
assert(math.abs(live:getDebt(liveKey)-(0.0045-q))<1e-10)
-- Strict inequality: a deficit of just 0.5 micrometers is still not
-- enough to authorize a whole 3.891mm native step (old +1e-6 bug).
local early=assert(B.new({quantumM=q}))
local badStep,badWhy=early:request("strict",q-0.0000005,0.10)
assert(badStep==nil and badWhy=="SUB_QUANTUM_DEBT")
local unsafeBudget,unsafeReason=early:request("strict",0,q-0.0000005)
assert(unsafeBudget==nil and unsafeReason=="SUB_QUANTUM_DEBT")
badStep=assert(early:request("strict",0.0000005,0.10))
assert(math.abs(badStep.stepM-q)<1e-10)
assert(early:cancel(badStep))
-- Once demand is sufficient, a budget short by 0.5 micrometers must
-- STILL deny the setter. No 'close enough' height-budget overspend.
local noStep,budgetReason=early:request("strict",0,q-0.0000005)
assert(noStep==nil and budgetReason=="NO_SAFE_GEOMETRY_STEP")
assert(math.abs(early:getDebt("strict")-q)<1e-10)
-- Stable CUMULATIVE input across many frames never counts as repeated debt.
local liveTarget=assert(B.new({quantumM=q}))
for _=1,100 do
    local noPlan,noWhy=liveTarget:requestTarget("rounding",0.0015,0.10)
    assert(noPlan==nil and noWhy=="SUB_QUANTUM_DEBT")
end
assert(math.abs(liveTarget:getDebt("rounding")-0.0015)<1e-10)
assert(liveTarget.stats.requestedM==0.0015)
assert(select(1,liveTarget:requestTarget("rounding",0.003,0.10))==nil)
local exactlyOne=assert(liveTarget:requestTarget("rounding",0.0045,0.10))
assert(exactlyOne.stepM==q)
assert(assert(liveTarget:settle(exactlyOne,100,100-q)).verified)
for _=1,100 do
    assert(select(1,liveTarget:requestTarget("rounding",0.0045,0.10))==nil)
end
assert(math.abs(liveTarget.entries.rounding.committedM-q)<1e-10)
assert(math.abs(liveTarget:getDebt("rounding")-(0.0045-q))<1e-10)

-- One wheel demands 1.7mm: cannot excavate a finer main heightmap step.
local p,why=m:request("250:250",0.0017,0.10)
assert(p==nil and why=="SUB_QUANTUM_DEBT")
assert(math.abs(m:getDebt("250:250")-0.0017)<1e-8)

-- A second pass brings the demand to 3.4mm; still no write.
p,why=m:request("250:250",0.0017,0.10)
assert(p==nil and why=="SUB_QUANTUM_DEBT")

-- Third pass crosses a representable quantum; issue EXACTLY one step,
-- not three additive TerrainDeformation brushes.
p=assert(m:request("250:250",0.0017,0.10))
assert(math.abs(p.stepM-q)<1e-10)
assert(m.stats.accepted==1 and m.stats.pending==1)
local dup,dupReason=m:request("250:250",0.10,0.10)
assert(dup==nil and dupReason=="VERTEX_PENDING")
local valid=assert(m:settle(p,140,140-q))
assert(valid.verified==true and m.quarantined==false)
assert(math.abs(m:getDebt("250:250")-(0.0051-q))<0.000001)
assert(m.stats.verified==1 and m.stats.pending==0)
assert(m:settle(p,140,140-q)==nil) -- double callback cannot double-spend

-- No applied height change is not success; preserve debt for retry.
local noopPlan=assert(m:request("300:300",q,0.10))
local noEffect,noEffectReason=m:settle(noopPlan,100,100)
assert(noEffect.verified==false)
assert(noEffectReason=="NO_MEASURABLE_EFFECT")
assert(math.abs(m:getDebt("300:300")-q)<1e-8)
assert(m.stats.zeroEffect==1)

-- If the verified remaining depth is below one quantum, refuse to write
-- even when the demand is already multiple quanta.
local noBudget,whyBudget=m:request("300:300",0,0.002)
assert(noBudget==nil and whyBudget=="NO_SAFE_GEOMETRY_STEP")
assert(math.abs(m:getDebt("300:300")-q)<1e-8)

-- Confirm a normal second plan can be canceled without consuming debt.
local canceled=assert(m:request("300:300",0,0.10))
assert(m:cancel(canceled)==true)
assert(m:cancel(canceled)==false)
assert(math.abs(m:getDebt("300:300")-q)<1e-8)

-- GIANTS/third-party movement in the callback window: DO NOT credit any
-- of the 15 quanta to the planned one-step RE write; quarantine future work.
local runaway=assert(m:request("400:400",q,0.10))
local unsafe,reason=m:settle(runaway,100,100-q*15)
assert(unsafe.verified==false and reason=="UNBOUNDED_OBSERVED_DELTA")
assert(m.quarantined==true and m.stats.anomalies==1)
assert(m:getDebt("400:400")==q)
local denied,deniedReason=m:request("new-cell",q,0.10)
assert(denied==nil and deniedReason=="QUARANTINED")

-- Do not set a single default q for all maps. A completely different map
-- may use a 1.5mm measured vertical step, and is handled independently.
local other=assert(B.new({quantumM=0.0015}))
assert(math.abs(assert(other:request("2:1",0.003,0.009)).stepM-0.0015)<1e-10)

-- The SHADOW planner provides CUMULATIVE native vertex demands, not
-- additive per-frame debt. Replaying the same 10mm target 500 times cannot
-- manufacture a 20mm, 50mm, or 100mm rut. Only 2 full ~3.891mm steps
-- are representable, leaving the sub-quantum remainder unspent.
local targets=assert(B.new({quantumM=q,toleranceM=0.00012}))
local targetKey="344:388"
local steps=0
for n=1,500 do
    local plan,reason=targets:requestTarget(targetKey,0.010,0.1)
    if plan~=nil then
        steps=steps+1
        local before=100-(steps-1)*q
        local settled=assert(targets:settle(plan,before,before-q))
        assert(settled.verified==true)
    else
        assert(reason=="SUB_QUANTUM_DEBT")
    end
end
assert(steps==2)
assert(math.abs(targets:getDebt(targetKey)-(0.010-2*q))<0.000001)
assert(math.abs(targets.entries[targetKey].committedM-2*q)<0.000001)
assert(math.abs(targets.entries[targetKey].demandTargetM-0.010)<0.000001)
assert(math.abs(targets.stats.requestedM-0.010)<0.000001)
assert(targets:requestTarget(targetKey,0.009,0.1)==nil)
local _,decrease=targets:requestTarget(targetKey,0.009,0.1)
assert(decrease=="TARGET_DECREASE_REQUIRES_RECOVERY_EPOCH")
local _,mixed=targets:request(targetKey,q,0.1)
assert(mixed=="MIXED_DEBT_CONTRACT")
assert(targets:retireTarget(targetKey)==false)
assert(targets:retireTarget(targetKey,true)==true)
assert(targets:getDebt(targetKey)==0)
assert(targets:requestTarget(targetKey,0.004,0.1)~=nil)
local otherMixed=assert(B.new({quantumM=q}))
otherMixed:request("INC",q/2,0.1)
local _,otherReason=otherMixed:requestTarget("INC",q,0.1)
assert(otherReason=="MIXED_DEBT_CONTRACT")

-- Zero/no-effect native readback retains exactly the existing cumulative
-- target; next attempts must never add a second copy of that target.
local noEffect=assert(B.new({quantumM=q}))
local x=assert(noEffect:requestTarget("x",q,0.1))
local no,reasonNo=noEffect:settle(x,100,100)
assert(no.verified==false and reasonNo=="NO_MEASURABLE_EFFECT")
assert(noEffect:getDebt("x")==q)
assert(noEffect:requestTarget("x",q,0.1)~=nil)
print("terrain_quantized_height_budget_harness: OK")
