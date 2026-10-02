-- Core diagnostics smoke/regression harness.
-- Exercises the five-second causal telemetry with minimal FS25 stubs so scope
-- and nil-regression errors are caught by CI.

Logging = {
    lines = {},
    info = function(fmt, ...)
        Logging.lines[#Logging.lines + 1] = string.format(fmt, ...)
    end,
    warning = function(fmt, ...)
        Logging.lines[#Logging.lines + 1] = string.format(fmt, ...)
    end
}

function addModEventListener(_) end

Utils = {
    appendedFunction = function(original, appended)
        return original or appended
    end
}

FSCareerMissionInfo = {
    saveToXMLFile = function() end
}

g_server = {}
g_currentMission = {
    time = 10000,
    missionInfo = {}
}

RealismExtensionsBuildInfo = {
    branch = "test",
    commit = "abcdef",
    runId = "1",
    builtAtUtc = "test"
}

dofile("scripts/Config.lua")
dofile("scripts/Diagnostics.lua")
dofile("scripts/terrain/TerrainTelemetry.lua")

RealismExtensionsState = {
    getProviderStatus = function() return true end,
    clearProvider = function() end
}

local runtimeDiag = {
    vehiclesLoaded = 1,
    wheelsAttached = 4,
    vehicleUpdateCalls = 1,
    wheelTicks = 4,
    sampleTicks = 4,
    samplesProcessed = 4,
    activeCultivatorRutSkips = 8,
    cultivationProtectionSkips = 2,
    brushesAccepted = 3,
    rutWriter_TestImplement = 3,
    rutWriterRoot_TestTractor = 3
}

RealismExtensionsTerrainRuntime = {
    writer = {
        queue = {},
        stats = {}
    },
    history = {
        count = 0
    },
    flush = function() return 0, 0 end,
    getDiagnostics = function() return runtimeDiag end,
    clear = function() end
}

local recoveryDiag = {
    workAreaCalls = 10,
    workedAreaCalls = 8,
    physicalWorkAreaCalls = 8,
    changedWorkAreaCalls = 4,
    repeatWorkAreaCalls = 4,
    areaPositiveCalls = 8,
    preSuperActiveMarks = 8,
    processedAreaUnits = 80,
    changedAreaUnits = 40,
    repeatAreaUnits = 40,
    brushesEnqueued = 12,
    callbacks = 12,
    roughnessImproved = 10,
    roughnessWorsened = 2
}

RealismExtensionsTerrainRecovery = {
    getDiagnostics = function() return recoveryDiag end
}

dofile("scripts/Core.lua")

local ok, err = pcall(function()
    RealismExtensionsCore:update(5000)
end)
assert(ok, tostring(err))
assert(RealismExtensionsCore.terrainDiagPrevious ~= nil)
assert(RealismExtensionsCore.terrainDiagPrevious.brushesAccepted == 3)
assert(RealismExtensionsCore.terrainDiagPrevious.rutWriter_TestImplement == 3)

-- Advance cumulative counters and ensure a second diagnostic window can read
-- the previous baseline and format writer deltas without relying on globals.
runtimeDiag.activeCultivatorRutSkips = 13
runtimeDiag.brushesAccepted = 5
runtimeDiag.rutWriter_TestImplement = 5
runtimeDiag.rutWriterRoot_TestTractor = 5
recoveryDiag.physicalWorkAreaCalls = 12
recoveryDiag.repeatWorkAreaCalls = 8
recoveryDiag.processedAreaUnits = 120
recoveryDiag.repeatAreaUnits = 80
recoveryDiag.brushesEnqueued = 18
recoveryDiag.callbacks = 18
recoveryDiag.roughnessImproved = 15
recoveryDiag.roughnessWorsened = 3

ok, err = pcall(function()
    RealismExtensionsCore:update(5000)
end)
assert(ok, tostring(err))
assert(RealismExtensionsCore.terrainDiagPrevious.brushesAccepted == 5)
assert(RealismExtensionsCore.terrainDiagPrevious.rutWriter_TestImplement == 5)

local joined = table.concat(Logging.lines, "\n")
assert(joined:find("TerrainWindow 5s", 1, true) ~= nil)
assert(joined:find("RutWriters runtime", 1, true) ~= nil)
assert(joined:find("TestImplement=5(+2)", 1, true) ~= nil)
assert(joined:find("TestTractor=5(+2)", 1, true) ~= nil)

print("core_diagnostics_harness: OK")
