dofile("scripts/terrain/SoilMassTransportModel.lua")
local M = RealismExtensionsSoilMassTransportModel

local r = M.compute({
    x=10,z=20,
    rutRadiusM=0.30,
    displacedVolumeM3=0.10,
    travelDirX=0,
    travelDirZ=1,
    wetness01=0.70,
    deformability01=1.0,
    longitudinalSlip=0.20,
    lateralSlip=0
})
assert(r.available == true)
assert(r.transportFraction > 0 and r.transportFraction < 1)
assert(r.transportedVolumeM3 > 0)
assert(r.transportedVolumeM3 < r.displacedVolumeM3)
assert(math.abs(
    r.transportedVolumeM3 + r.retainedCompactionVolumeM3
    - r.displacedVolumeM3
) < 0.000001)
assert(r.left.x < 10 and r.right.x > 10)
assert(math.abs(r.left.z - 20) < 0.000001)
assert(math.abs(r.right.z - 20) < 0.000001)
assert(r.left.raiseHeightM > 0 and r.right.raiseHeightM > 0)

local wet = M.compute({
    x=0,z=0,rutRadiusM=0.30,displacedVolumeM3=0.10,
    travelDirX=1,travelDirZ=0,
    wetness01=0.9,deformability01=1,longitudinalSlip=0.4,lateralSlip=0
})
local dry = M.compute({
    x=0,z=0,rutRadiusM=0.30,displacedVolumeM3=0.10,
    travelDirX=1,travelDirZ=0,
    wetness01=0.1,deformability01=1,longitudinalSlip=0,lateralSlip=0
})
assert(wet.transportFraction > dry.transportFraction)

local biased = M.compute({
    x=0,z=0,rutRadiusM=0.30,displacedVolumeM3=0.10,
    travelDirX=1,travelDirZ=0,
    wetness01=0.7,deformability01=1,longitudinalSlip=0.1,lateralSlip=0.8
})
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
