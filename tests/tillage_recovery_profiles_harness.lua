dofile("scripts/terrain/TillageRecoveryProfiles.lua")

local P=RealismExtensionsTillageRecoveryProfiles
local ok,bad=P.validate()
assert(ok==true,bad)

local base={spec_cultivator={isSubsoiler=false,useDeepMode=true,isPowerHarrow=false}}
assert(P.resolveCultivator(base).id=="CULTIVATOR")

local disc={spec_cultivator={isSubsoiler=false,useDeepMode=false,isPowerHarrow=false}}
assert(P.resolveCultivator(disc).id=="SHALLOW_DISC")

local power={spec_cultivator={isSubsoiler=false,useDeepMode=true,isPowerHarrow=true}}
assert(P.resolveCultivator(power).id=="POWER_HARROW")

local sub={spec_cultivator={isSubsoiler=true,useDeepMode=true,isPowerHarrow=true}}
assert(P.resolveCultivator(sub).id=="SUBSOILER")

local plow={spec_plow={}}
assert(P.resolve(plow,"PLOW").id=="PLOW")

local packer={spec_cultivator={},spec_plow={},spec_plowPacker={}}
assert(P.resolveCultivator(packer).id=="PLOW_PACKER")
assert(P.resolvePlow(packer).id=="PLOW_PACKER")

-- Preserve the R6 cultivator physics exactly while the new classes diverge.
local c=P.get("CULTIVATOR")
assert(math.abs(c.targetRadiusM-0.40)<0.000001)
assert(math.abs(c.targetProbeRadiusM-1.25)<0.000001)
assert(math.abs(c.targetAmount-0.75)<0.000001)
assert(math.abs(c.targetAmountMax-1.00)<0.000001)
assert(math.abs(c.targetStrength-0.35)<0.000001)
assert(math.abs(c.targetHardness-0.20)<0.000001)
assert(c.maxStructuralPulses==6)
assert(math.abs(c.targetSpacingFactor-2.10)<0.000001)
assert(c.maxBrushesPerWorkArea==12)

-- Capability dimensions deliberately do not collapse working depth into
-- surface grading power: the subsoiler is deepest but weakest at levelling.
assert(P.get("SUBSOILER").nominalWorkingDepthM>P.get("PLOW").nominalWorkingDepthM)
assert(P.get("SUBSOILER").deepCompactionRelief01>P.get("PLOW").deepCompactionRelief01)
assert(P.get("SUBSOILER").surfaceRegrade01<P.get("PLOW").surfaceRegrade01)
assert(P.get("POWER_HARROW").surfaceFinish01>P.get("PLOW").surfaceFinish01)

print("tillage_recovery_profiles_harness: OK")
