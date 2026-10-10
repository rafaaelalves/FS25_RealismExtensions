RealismExtensionsTillageRecoveryProfiles =
    RealismExtensionsTillageRecoveryProfiles or {}
local Profiles = RealismExtensionsTillageRecoveryProfiles

Profiles.VERSION = 1

-- These are capability profiles, not literal implement working depths.
-- nominalWorkingDepthM documents the agronomic scale used to classify the tool;
-- the TARGET parameters describe only RE's surface-rut reconstruction behavior.
--
-- Real-world basis:
-- * moldboard plow: roughly 0.20-0.30 m, aggressive inversion, rough finish;
-- * field cultivator: roughly 0.075-0.10 m secondary tillage;
-- * tandem/shallow disk: roughly 0.05-0.10 m, strong seedbed finishing;
-- * power harrow: commonly roughly 0.05-0.15 m, intensive crumbling/levelling;
-- * in-line subsoiler/ripper: roughly 0.38-0.50 m but deliberately low surface
--   disturbance. Deep compaction relief is therefore separated from surface
--   regrading instead of treating depth as one generic "recovery power".
--
-- CULTIVATOR intentionally reproduces the R6 constants so introducing the
-- profile layer does not change the proven baseline.
Profiles.PROFILES = {
    CULTIVATOR = {
        id = "CULTIVATOR",
        family = "SECONDARY_TILLAGE",
        nominalWorkingDepthM = 0.10,
        surfaceRegrade01 = 0.70,
        surfaceFinish01 = 0.75,
        deepCompactionRelief01 = 0.25,

        targetRadiusM = 0.40,
        targetProbeRadiusM = 1.25,
        targetAmount = 0.75,
        targetAmountMax = 1.00,
        targetStrength = 0.35,
        targetHardness = 0.20,
        maxStructuralPulses = 6,
        targetSpacingFactor = 2.10,
        maxBrushesPerWorkArea = 12
    },

    SHALLOW_DISC = {
        id = "SHALLOW_DISC",
        family = "SECONDARY_TILLAGE",
        nominalWorkingDepthM = 0.08,
        surfaceRegrade01 = 0.65,
        surfaceFinish01 = 0.90,
        deepCompactionRelief01 = 0.12,

        targetRadiusM = 0.45,
        targetProbeRadiusM = 1.20,
        targetAmount = 0.65,
        targetAmountMax = 0.85,
        targetStrength = 0.30,
        targetHardness = 0.18,
        maxStructuralPulses = 4,
        targetSpacingFactor = 1.80,
        maxBrushesPerWorkArea = 14
    },

    POWER_HARROW = {
        id = "POWER_HARROW",
        family = "SEEDBED_FINISHING",
        nominalWorkingDepthM = 0.10,
        surfaceRegrade01 = 0.55,
        surfaceFinish01 = 1.00,
        deepCompactionRelief01 = 0.08,

        targetRadiusM = 0.45,
        targetProbeRadiusM = 1.15,
        targetAmount = 0.60,
        targetAmountMax = 0.80,
        targetStrength = 0.28,
        targetHardness = 0.15,
        maxStructuralPulses = 3,
        targetSpacingFactor = 1.60,
        maxBrushesPerWorkArea = 16
    },

    SUBSOILER = {
        id = "SUBSOILER",
        family = "DEEP_ZONE_TILLAGE",
        nominalWorkingDepthM = 0.45,
        surfaceRegrade01 = 0.35,
        surfaceFinish01 = 0.20,
        deepCompactionRelief01 = 1.00,

        targetRadiusM = 0.30,
        targetProbeRadiusM = 1.25,
        targetAmount = 0.60,
        targetAmountMax = 0.85,
        targetStrength = 0.30,
        targetHardness = 0.30,
        maxStructuralPulses = 3,
        targetSpacingFactor = 2.20,
        maxBrushesPerWorkArea = 8
    },

    PLOW = {
        id = "PLOW",
        family = "PRIMARY_INVERSION_TILLAGE",
        nominalWorkingDepthM = 0.25,
        surfaceRegrade01 = 0.90,
        surfaceFinish01 = 0.35,
        deepCompactionRelief01 = 0.45,

        targetRadiusM = 0.45,
        targetProbeRadiusM = 1.30,
        targetAmount = 0.85,
        targetAmountMax = 1.00,
        targetStrength = 0.42,
        targetHardness = 0.28,
        maxStructuralPulses = 6,
        targetSpacingFactor = 1.85,
        maxBrushesPerWorkArea = 12
    },

    PLOW_PACKER = {
        id = "PLOW_PACKER",
        family = "PRIMARY_TILLAGE_WITH_PACKING",
        nominalWorkingDepthM = 0.25,
        surfaceRegrade01 = 0.90,
        surfaceFinish01 = 0.70,
        deepCompactionRelief01 = 0.45,

        targetRadiusM = 0.48,
        targetProbeRadiusM = 1.30,
        targetAmount = 0.85,
        targetAmountMax = 1.00,
        targetStrength = 0.40,
        targetHardness = 0.22,
        maxStructuralPulses = 6,
        targetSpacingFactor = 1.75,
        maxBrushesPerWorkArea = 12
    }
}

local function profile(id)
    return Profiles.PROFILES[id] or Profiles.PROFILES.CULTIVATOR
end

function Profiles.get(id)
    return profile(id)
end

function Profiles.resolveCultivator(vehicle)
    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil

    -- GIANTS PlowPacker owns a cultivator work-area path even though the tool
    -- is fundamentally primary tillage followed by packing.
    if vehicle ~= nil and vehicle.spec_plowPacker ~= nil then
        return profile("PLOW_PACKER")
    end

    if spec ~= nil and spec.isSubsoiler == true then
        return profile("SUBSOILER")
    end

    if spec ~= nil and spec.isPowerHarrow == true then
        return profile("POWER_HARROW")
    end

    -- GIANTS: useDeepMode=false is the disc-harrow/seedbed-combination path.
    if spec ~= nil and spec.useDeepMode == false then
        return profile("SHALLOW_DISC")
    end

    return profile("CULTIVATOR")
end

function Profiles.resolvePlow(vehicle)
    if vehicle ~= nil and vehicle.spec_plowPacker ~= nil then
        return profile("PLOW_PACKER")
    end
    return profile("PLOW")
end

function Profiles.resolve(vehicle, operationKind)
    if operationKind == "PLOW" then
        return Profiles.resolvePlow(vehicle)
    end
    return Profiles.resolveCultivator(vehicle)
end

function Profiles.validate()
    for id, p in pairs(Profiles.PROFILES) do
        if p.id ~= id
            or type(p.targetRadiusM) ~= "number"
            or p.targetRadiusM <= 0
            or type(p.targetAmount) ~= "number"
            or type(p.targetAmountMax) ~= "number"
            or p.targetAmount <= 0
            or p.targetAmountMax < p.targetAmount
            or type(p.maxStructuralPulses) ~= "number"
            or p.maxStructuralPulses < 1
            or type(p.targetSpacingFactor) ~= "number"
            or p.targetSpacingFactor <= 0 then
            return false, id
        end
    end
    return true, nil
end

return Profiles
