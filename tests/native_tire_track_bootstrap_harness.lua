RealismExtensionsConfig = {
    modules = {
        NativeTireTrackProbe = true,
        VisualTrackCapture = false
    }
}

local originalCalls = 0
TireTracks = {
    onPreLoad = function(self, savegame)
        originalCalls = originalCalls + 1
        self.originalSawInstalled =
            RealismExtensionsNativeTireTrackAdapter ~= nil
            and RealismExtensionsNativeTireTrackAdapter.installed == true
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

-- Many later vehicles must not stack the mission-instance adapter.
TireTracks.onPreLoad({}, nil)
assert(B.getDiagnostics().adapterAlreadyActive >= 1)
assert(A.stats.installs == 1)

-- New mission after teardown: the process-global bootstrap remains, but it
-- installs onto the new mission's TireTrackSystem instance.
A.uninstall()
A.resetProbe()
g_currentMission.tireTrackSystem = setmetatable({}, systemMt)
TireTracks.onPreLoad({}, nil)
assert(A.installed == true)
assert(A.stats.installs == 2)

A.uninstall()
print("native_tire_track_bootstrap_harness: OK")
