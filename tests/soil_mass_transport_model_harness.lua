dofile("scripts/terrain/SoilMassTransportModel.lua")
local M = RealismExtensionsSoilMassTransportModel

-- Moderate field wetness with low slip should be dominated by compaction and
-- may not produce a representable surface berm at all.
local moderate = M.compute({
    x=10,z=20,
    rutRadiusM=0.30,
    displacedVolumeM3=0.10,
    travelDirX=0,
    travelDirZ=1,
    wetness01=0.50,
    deformability01=1.0,
    longitudinalSlip=0.05,
    lateralSlip=0,
    innerBermSide=1
})
assert(moderate.transportFraction <= 0.02)
assert(moderate.retainedCompactionVolumeM3 > 0.095)

-- Truly wet/plastic soil under severe slip must transport more mass laterally.
local severe = M.compute({
    x=10,z=20,
    rutRadiusM=0.30,
    displacedVolumeM3=1.0,
    travelDirX=0,
    travelDirZ=1,
    wetness01=0.95,
    deformability01=1.0,
    longitudinalSlip=0.95,
    lateralSlip=0,
    innerBermSide=1
})
assert(severe.available == true)
assert(severe.transportFraction > moderate.transportFraction)
assert(severe.transportFraction <= 0.18 + 0.000001)
assert(severe.transportedVolumeM3 > 0)
assert(severe.transportedVolumeM3 < severe.displacedVolumeM3)
assert(math.abs(
    severe.transportedVolumeM3 + severe.retainedCompactionVolumeM3
    - severe.displacedVolumeM3
) < 0.000001)
assert(severe.left.role == "INNER")
assert(severe.right.role == "OUTER")
assert(severe.left.targetVolumeM3 < severe.right.targetVolumeM3)
assert(severe.left.targetVolumeM3 / severe.requestedTransportedVolumeM3 <= 0.18 + 0.000001)
assert(severe.left.raiseHeightM <= 0.003 + 0.000001)
assert(severe.right.raiseHeightM <= 0.003 + 0.000001)

-- The same physical state with no known vehicle-center side falls back to a
-- near-symmetric distribution rather than guessing an inner berm.
local symmetric = M.compute({
    x=0,z=0,rutRadiusM=0.30,displacedVolumeM3=1.0,
    travelDirX=1,travelDirZ=0,
    wetness01=0.95,deformability01=1,longitudinalSlip=0.95,lateralSlip=0
})
assert(symmetric.available == true)
assert(math.abs(
    symmetric.left.targetVolumeM3 - symmetric.right.targetVolumeM3
) < 0.000001)

-- Lateral slip can bias the split, but only gently.
local biased = M.compute({
    x=0,z=0,rutRadiusM=0.30,displacedVolumeM3=1.0,
    travelDirX=1,travelDirZ=0,
    wetness01=0.95,deformability01=1,longitudinalSlip=0.95,lateralSlip=0.8
})
assert(biased.available == true)
assert(biased.left.targetVolumeM3 > biased.right.targetVolumeM3)

local noDir = M.compute({
    rutRadiusM=0.30,displacedVolumeM3=0.10,
    wetness01=0.7,deformability01=1
})
assert(noDir.available == false)
assert(noDir.reason == "NO_TRAVEL_DIRECTION")

local hard = M.compute({
    rutRadiusM=0.30,displacedVolumeM3=0.10,
    travelDirX=1,travelDirZ=0,
    wetness01=0.7,deformability01=0
})
assert(hard.available == false)
assert(hard.reason == "NO_TRANSPORTABLE_VOLUME")

print("soil_mass_transport_model_harness: OK")
