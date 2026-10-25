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

print("terrain_quantized_height_budget_harness: OK")
