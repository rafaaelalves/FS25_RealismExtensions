-- PTO specialization bootstrap.
--
-- The implementation is deliberately NOT an extraSourceFile. GIANTS owns its
-- lifecycle through SpecializationManager, matching the established terrain
-- registration pattern and avoiding duplicate implementation loads.

local MOD_NAME = g_currentModName
local MOD_DIRECTORY = g_currentModDirectory
local SPEC_NAME = "realismExtensionsPTO"

if type(MOD_NAME) ~= "string" or MOD_NAME == "" then
    error("RealismExtensions PTO bootstrap: g_currentModName unavailable")
end
if type(MOD_DIRECTORY) ~= "string" or MOD_DIRECTORY == "" then
    error("RealismExtensions PTO bootstrap: g_currentModDirectory unavailable")
end

local FULL_NAME = MOD_NAME .. "." .. SPEC_NAME
local IMPLEMENTATION = MOD_DIRECTORY .. "scripts/pto/PTOControl.lua"
local statusReported = false

local function moduleEnabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.PTOControl == true
end

local function externalOwnerPresent()
    return type(g_modIsLoaded) == "table"
        and g_modIsLoaded["FS25_DynamicPTO_FFM"] == true
end

if g_specializationManager ~= nil
    and g_specializationManager:getSpecializationByName(SPEC_NAME) == nil then
    g_specializationManager:addSpecialization(
        SPEC_NAME,
        "RealismExtensionsPTOControl",
        IMPLEMENTATION,
        MOD_NAME
    )
end

local function report(enabled, reason, added)
    if RealismExtensionsPTO ~= nil then
        RealismExtensionsPTO.setRuntimeStatus(enabled, reason)
    end

    if statusReported or RealismExtensionsDiagnostics == nil then return end
    statusReported = true

    if enabled then
        RealismExtensionsDiagnostics.info(
            "PTOControl active; vehicleTypes=" .. tostring(added or 0)
        )
    else
        RealismExtensionsDiagnostics.info(
            "PTOControl inactive; reason=" .. tostring(reason)
        )
    end
end

local function installSpecialization(typeManager)
    if typeManager == nil or typeManager.typeName ~= "vehicle" then return end

    if not moduleEnabled() then
        report(false, "disabled by config", 0)
        return
    end

    -- Migration guard only. The old external owner may remain installed until
    -- the native RE implementation is validated, but both must never own the
    -- same PTO state simultaneously.
    if externalOwnerPresent() then
        report(false, "external PTO owner active", 0)
        return
    end

    local types = typeManager:getTypes()
    if type(types) ~= "table" then
        report(false, "vehicle type table unavailable", 0)
        return
    end

    local added = 0
    for typeName, typeDef in pairs(types) do
        local byName = typeDef ~= nil and typeDef.specializationsByName or nil
        local eligible = type(byName) == "table"
            and typeName ~= "locomotive"
            and byName["motorized"] ~= nil
            and byName["drivable"] ~= nil
            and byName["attacherJoints"] ~= nil
            and byName["combine"] == nil

        if eligible and byName[FULL_NAME] == nil then
            typeManager:addSpecialization(typeName, FULL_NAME)
            added = added + 1
        end
    end

    report(true, "native PTO control active", added)

    if RealismExtensionsPTOPhysics ~= nil
        and type(RealismExtensionsPTOPhysics.install) == "function" then
        local ok, reason = RealismExtensionsPTOPhysics.install()
        if RealismExtensionsDiagnostics ~= nil then
            RealismExtensionsDiagnostics.verbose(
                "PTO standalone physics="
                .. tostring(ok and "active" or "inactive")
                .. " reason=" .. tostring(reason)
            )
        end
    end
end

TypeManager.validateTypes = Utils.appendedFunction(
    TypeManager.validateTypes,
    installSpecialization
)
