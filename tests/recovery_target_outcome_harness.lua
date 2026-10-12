-- Pure, GIANTS-free regression tests. Never mutates heightmap or history.
dofile("scripts/terrain/RecoveryTargetOutcome.lua")
local O = RealismExtensionsRecoveryTargetOutcome
local function classify(beforeY, afterY, extra, options)
    local sample = { beforeY=beforeY, afterY=afterY, targetY=10.0 }
    for k,v in pairs(extra or {}) do sample[k]=v end
    return O.classify(sample, options)
end
local unchanged = classify(9.8,9.8, {
    queuedCenterY=9.8, beforeReferenceY=10, afterReferenceY=10.4,
    residualBeforeM=-0.2, residualAfterM=-0.6,
})
assert(unchanged.kind=="CENTER_UNCHANGED")
assert(unchanged.fixedTargetGainM==0)
assert(math.abs(unchanged.referenceDriftM-0.4)<0.0000001)
local toward=classify(9.8,9.91)
assert(toward.kind=="TOWARD_TARGET")
assert(toward.fixedTargetGainM>0.1)
local reached=classify(9.8,9.999)
assert(reached.kind=="TARGET_REACHED")
local away=classify(9.8,9.7)
assert(away.kind=="AWAY_FROM_TARGET")
assert(away.fixedTargetGainM<0)
local nongain=classify(9.8,9.8001,nil,{motionThresholdM=0.00005, improvementThresholdM=0.001})
assert(nongain.kind=="MOVED_WITHOUT_GAIN")
local queued=classify(9.8,9.85,{queuedCenterY=9.6})
assert(math.abs(queued.queueDriftM-0.2)<0.00001)
local noSample=O.classify({beforeY=9.8,targetY=10},{})
assert(noSample.kind=="UNMEASURED" and noSample.valid==false)
local invalid=O.classify({beforeY=0/0,afterY=9.9,targetY=10},{})
assert(invalid.kind=="UNMEASURED")
print("recovery_target_outcome_harness: OK")
