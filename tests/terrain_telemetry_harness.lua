dofile("scripts/terrain/TerrainTelemetry.lua")

local previous = {
    physicalWorkAreaCalls=10,
    changedWorkAreaCalls=6,
    repeatWorkAreaCalls=4,
    processedAreaUnits=100,
    repeatAreaUnits=40,
    brushesEnqueued=20,
    callbacks=18,
    roughnessImproved=12,
    roughnessWorsened=2,
    activeCultivatorRutSkips=30,
    cultivationProtectionSkips=10,
    brushesAccepted=8,
    rutWriter_ImplA=5,
    rutWriter_ImplB=2,
    rutWriterRoot_Tractor=7
}

local recovery = {
    physicalWorkAreaCalls=14,
    changedWorkAreaCalls=7,
    repeatWorkAreaCalls=7,
    processedAreaUnits=145,
    repeatAreaUnits=75,
    brushesEnqueued=28,
    callbacks=26,
    roughnessImproved=18,
    roughnessWorsened=3
}

local runtime = {
    activeCultivatorRutSkips=42,
    cultivationProtectionSkips=15,
    brushesAccepted=11,
    rutWriter_ImplA=5,
    rutWriter_ImplB=6,
    rutWriterRoot_Tractor=11
}

local window,snapshot = RealismExtensionsTerrainTelemetry.buildWindow(
    previous,recovery,runtime
)

assert(window.work==4)
assert(window.changed==1)
assert(window.repeatWork==3)
assert(window.processedArea==45)
assert(window.repeatArea==35)
assert(window.smooth==8)
assert(window.callbacks==8)
assert(window.improved==6)
assert(window.worsened==1)
assert(window.rutBlocked==12)
assert(window.protected==5)
assert(window.rutAccepted==3)

-- Writer ordering is window-causality first, not misleading cumulative totals.
assert(window.writers[1].name=="ImplB")
assert(window.writers[1].window==4)
assert(window.writers[2].name=="ImplA")
assert(window.writers[2].window==0)
assert(window.rootWriters[1].name=="Tractor")
assert(window.rootWriters[1].window==4)

assert(snapshot.rutWriter_ImplB==6)
assert(snapshot.physicalWorkAreaCalls==14)
assert(
    RealismExtensionsTerrainTelemetry.formatWriters(window.writers,2)
    =="ImplB=6(+4) ImplA=5(+0)"
)

print("terrain_telemetry_harness: OK")
