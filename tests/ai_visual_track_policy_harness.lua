RealismExtensionsConfig = {
    modules = {
        AIVisualTireTracks = true
    }
}

AIImplement = {}
AIJobVehicle = {}

local originalAIImplement = function(self, superFunc)
    return superFunc(self) and not self:getIsAIActive()
end
local originalAIJobVehicle = function(self, superFunc)
    return superFunc(self) and not self:getIsAIActive()
end

AIImplement.getAllowTireTracks = originalAIImplement
AIJobVehicle.getAllowTireTracks = originalAIJobVehicle

dofile("scripts/tracks/AIVisualTrackPolicy.lua")
local P = RealismExtensionsAIVisualTrackPolicy

assert(AIImplement.getAllowTireTracks == P.getAllowTireTracks)
assert(AIJobVehicle.getAllowTireTracks == P.getAllowTireTracks)

local ai = {
    getIsAIActive = function() return true end
}
local player = {
    getIsAIActive = function() return false end
}

local function nativeAllowTrue() return true end
local function nativeAllowFalse() return false end

-- AI suppression is removed.
assert(P.getAllowTireTracks(ai, nativeAllowTrue) == true)

-- Native / lower-chain restrictions remain authoritative.
assert(P.getAllowTireTracks(ai, nativeAllowFalse) == false)

-- Player behavior is unchanged.
assert(P.getAllowTireTracks(player, nativeAllowTrue) == true)
assert(P.getAllowTireTracks(player, nativeAllowFalse) == false)

local d=P.getDiagnostics()
assert(d.enabled == true)
assert(d.classesPatched == 2)
assert(d.aiImplementPatched == true)
assert(d.aiJobVehiclePatched == true)
assert(d.calls == 4)
assert(d.aiActiveCalls == 2)
assert(d.baseAllowed == 2)
assert(d.baseDenied == 2)

print("ai_visual_track_policy_harness: OK")
