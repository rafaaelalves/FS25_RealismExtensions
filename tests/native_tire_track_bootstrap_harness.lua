RealismExtensionsConfig = {
    modules = {
        NativeTireTrackProbe = true,
        VisualTrackCapture = true
    }
}

local originalCalls = 0
TireTracks = {
    onPreLoad = function(self, savegame)
        originalCalls = originalCalls + 1
        self.originalSawInstalled =
            RealismExtensionsNativeTireTrackAdapter ~= nil
            and RealismExtensionsNativeTireTrackAdapter.installed == true
        self.originalSawCapture =
            RealismExtensionsVisualTrackRuntime ~= nil
            and RealismExtensionsVisualTrackRuntime.active == true
    end
}

Utils = {
    prependedFunction = function(original, prepended)
        return function(...)
            prepended(...)
            return original(...)
        end
    end
}

local systemMt = {}
systemMt.__index = systemMt
function systemMt:createTrack(width, atlas) return 77 end
function systemMt:addTrackPoint(...) return true end
function systemMt:cutTrack(id) return true end

g_currentMission = {
    tireTrackSystem = setmetatable({}, systemMt)
}

RealismExtensionsDiagnostics = {
    info = function() end
}

local captureInitCalls = 0
RealismExtensionsVisualTrackRuntime = {
    active = false,
    initialize = function(adapter)
        captureInitCalls = captureInitCalls + 1
        assert(adapter == RealismExtensionsNativeTireTrackAdapter)
        assert(adapter.installed == true)
        RealismExtensionsVisualTrackRuntime.active = true
        return true, nil
    end
}

dofile("scripts/tracks/NativeTireTrackAdapter.lua")
local A = RealismExtensionsNativeTireTrackAdapter
A.uninstall()
A.resetProbe()
A.observers = {}

dofile("scripts/tracks/NativeTireTrackBootstrap.lua")
local B = RealismExtensionsNativeTireTrackBootstrap

assert(B.installed == true)
assert(A.installed == false)

local vehicle = {}
TireTracks.onPreLoad(vehicle, nil)

assert(originalCalls == 1)
assert(vehicle.originalSawInstalled == true)
assert(vehicle.originalSawCapture == true)
assert(A.installed == true)
assert(A.probeEnabled == true)

local id = g_currentMission.tireTrackSystem:createTrack(0.62, 4)
assert(id == 77)

local d = A.getDiagnostics()
assert(d.createTrackCalls == 1)
assert(d.maxCreateArgs == 2)
assert(d.signatures.createTrack["number,number"] == 1)

local b = B.getDiagnostics()
assert(b.preLoadCalls == 1)
assert(b.adapterInstallAttempts == 1)
assert(b.adapterInstalls == 1)
assert(b.captureInitializations == 1)
assert(b.captureInitFailures == 0)
assert(captureInitCalls == 1)

-- Many later vehicles must not stack the mission-instance adapter.
TireTracks.onPreLoad({}, nil)
assert(B.getDiagnostics().adapterAlreadyActive >= 1)
assert(B.getDiagnostics().captureAlreadyActive >= 1)
assert(A.stats.installs == 1)
assert(captureInitCalls == 1)

-- New mission after teardown: the process-global bootstrap remains, but it
-- installs onto the new mission's TireTrackSystem instance.
A.uninstall()
A.resetProbe()
RealismExtensionsVisualTrackRuntime.active = false
g_currentMission.tireTrackSystem = setmetatable({}, systemMt)
local vehicle2 = {}
TireTracks.onPreLoad(vehicle2, nil)
assert(A.installed == true)
assert(vehicle2.originalSawCapture == true)
assert(A.stats.installs == 2)
assert(captureInitCalls == 2)
assert(B.getDiagnostics().captureInitializations == 2)

A.uninstall()
print("native_tire_track_bootstrap_harness: OK")
