RealismExtensionsPTOBootstrap = RealismExtensionsPTOBootstrap or {}
local Bootstrap = RealismExtensionsPTOBootstrap

Bootstrap.registered = false
Bootstrap.disabledByExternalOwner = false

local EXTERNAL_PTO_OWNERS = {
    "FS25_DynamicPTO_FFM"
}

local function moduleEnabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.PTOControl == true
end

local function externalOwnerPresent()
    if type(g_modIsLoaded) ~= "table" then return false, nil end
    for _, modName in ipairs(EXTERNAL_PTO_OWNERS) do
        if g_modIsLoaded[modName] == true then
            return true, modName
        end
    end
    return false, nil
end

local function typeHas(typeDef, specialization)
    return typeDef ~= nil
        and typeDef.specializations ~= nil
        and specialization ~= nil
        and SpecializationUtil.hasSpecialization(
            specialization,
            typeDef.specializations
        )
end

local function isCombine(typeDef)
    return Combine ~= nil and typeHas(typeDef, Combine)
end

function Bootstrap.registerSpecialization(typeManager)
    if Bootstrap.registered or not moduleEnabled() then return end
    if g_vehicleTypeManager == nil or g_specializationManager == nil then return end

    if typeManager ~= nil
        and typeManager.typeName ~= nil
        and typeManager.typeName ~= "vehicle"
        and typeManager ~= g_vehicleTypeManager then
        return
    end

    local blocked, owner = externalOwnerPresent()
    if blocked then
        Bootstrap.disabledByExternalOwner = true
        if RealismExtensionsPTO ~= nil then
            RealismExtensionsPTO.setRuntimeStatus(
                false,
                "external PTO owner active"
            )
        end
        if RealismExtensionsDiagnostics ~= nil then
            RealismExtensionsDiagnostics.info(
                "PTOControl disabled; external PTO owner active"
            )
        end
        Bootstrap.registered = true
        return
    end

    local specName = RealismExtensionsPTOControl.SPEC_NAME
    local fullSpecName = tostring(g_currentModName) .. "." .. specName
    local filename = Utils.getFilename(
        "scripts/pto/PTOControl.lua",
        g_currentModDirectory
    )

    if g_specializationManager:getSpecializationByName(specName) == nil
        and g_specializationManager:getSpecializationByName(fullSpecName) == nil then
        g_specializationManager:addSpecialization(
            specName,
            "RealismExtensionsPTOControl",
            filename,
            nil
        )
    end

    local registeredName = fullSpecName
    if g_specializationManager:getSpecializationByName(registeredName) == nil then
        registeredName = specName
    end
    if g_specializationManager:getSpecializationByName(registeredName) == nil then
        if RealismExtensionsPTO ~= nil then
            RealismExtensionsPTO.setRuntimeStatus(
                false,
                "PTO specialization registration failed"
            )
        end
        return
    end

    local added = 0
    for typeName, typeDef in pairs(g_vehicleTypeManager.types or {}) do
        local byName = typeDef ~= nil and typeDef.specializationsByName or nil
        local already = byName ~= nil
            and (
                byName[registeredName] ~= nil
                or byName[specName] ~= nil
                or byName[fullSpecName] ~= nil
            )

        if not already
            and typeHas(typeDef, Motorized)
            and typeHas(typeDef, Drivable)
            and typeHas(typeDef, AttacherJoints)
            and not isCombine(typeDef) then
            g_vehicleTypeManager:addSpecialization(typeName, registeredName)
            added = added + 1
        end
    end

    Bootstrap.registered = true
    if RealismExtensionsPTO ~= nil then
        RealismExtensionsPTO.setRuntimeStatus(
            true,
            "native PTO control active"
        )
    end
    if RealismExtensionsDiagnostics ~= nil then
        RealismExtensionsDiagnostics.info(
            "PTOControl active; vehicleTypes=" .. tostring(added)
        )
    end
end

if TypeManager ~= nil
    and Utils ~= nil
    and type(Utils.prependedFunction) == "function" then
    TypeManager.finalizeTypes = Utils.prependedFunction(
        TypeManager.finalizeTypes,
        Bootstrap.registerSpecialization
    )
end

return Bootstrap
