-- Regression for native PTO + terrain registration in the SAME FS25 mod.
-- The production main keeps TerrainDeformation OFF. This harness is scoped
-- only to the explicitly marked experimental integration branch.
dofile("scripts/Config.lua")
assert(RealismExtensionsConfig.releaseChannel == "experimental-terrain-pto")
local mods = RealismExtensionsConfig.modules
assert(mods.PTOControl and mods.TerrainDeformation
    and mods.TerrainRecovery and mods.TerrainPlasticYield)
g_currentModName = "FS25_RealismExtensions"
g_currentModDirectory = "/test/mods/FS25_RealismExtensions/"
g_modIsLoaded = {}
local registered = {}
g_specializationManager = {
    getSpecializationByName = function(_, name) return registered[name] end,
    addSpecialization = function(_, name, className, fileName, modName)
        assert(modName == g_currentModName)
        registered[name] = { className=className, fileName=fileName }
    end
}
local infos = {}
RealismExtensionsDiagnostics = {
    info = function(_, s) infos[#infos+1] = tostring(s or "") end,
    verbose = function() end
}
local ptoModes = {}
RealismExtensionsPTO = {
    setRuntimeStatus = function(a,b) ptoModes[#ptoModes+1]=a end
}
local ptoPhysicsInstalls = 0
RealismExtensionsPTOPhysics = {
    install = function()
        ptoPhysicsInstalls = ptoPhysicsInstalls + 1
        return true, nil
    end
}
local validationCalls = 0
TypeManager = {
    validateTypes = function() validationCalls = validationCalls + 1 end
}
Utils = {
    appendedFunction = function(base, appended)
        return function(...)
            if base then base(...) end
            return appended(...)
        end
    end
}
dofile("scripts/pto/PTOBootstrap.lua")
dofile("scripts/terrain/TerrainDeformationRegistration.lua")
dofile("scripts/terrain/TerrainRecoveryRegistration.lua")
assert(registered.realismExtensionsPTO ~= nil)
assert(registered.realismExtensionsTerrainDeformation ~= nil)
assert(registered.realismExtensionsTerrainRecovery ~= nil)

local types = {
    tractor = {specializationsByName={
        motorized=true, drivable=true, attacherJoints=true, wheels=true
    }},
    tillage = {specializationsByName={wheels=true, cultivator=true}},
    planter = {specializationsByName={wheels=true, sowingMachine=true}},
    combine = {specializationsByName={
        motorized=true, drivable=true, attacherJoints=true, wheels=true, combine=true
    }},
    locomotive = {specializationsByName={wheels=true}}
}
local manager = {
    typeName = "vehicle",
    getTypes = function() return types end,
    addSpecialization = function(_, typeName, fullName)
        assert(types[typeName] ~= nil)
        types[typeName].specializationsByName[fullName] = true
    end
}
-- Exact same late GIANTS lifecycle: RE's mod globals are gone.
g_currentModName=nil
g_currentModDirectory=nil
TypeManager.validateTypes(manager)
assert(validationCalls==1)
local prefix="FS25_RealismExtensions."
local function has(typeName, spec)
    return types[typeName].specializationsByName[prefix..spec] == true
end
assert(has("tractor","realismExtensionsPTO"))
assert(has("tractor","realismExtensionsTerrainDeformation"))
assert(not has("tractor","realismExtensionsTerrainRecovery"))
assert(not has("tillage","realismExtensionsPTO"))
assert(has("tillage","realismExtensionsTerrainDeformation"))
assert(has("tillage","realismExtensionsTerrainRecovery"))
assert(has("planter","realismExtensionsTerrainDeformation"))
assert(not has("planter","realismExtensionsTerrainRecovery"))
assert(not has("combine","realismExtensionsPTO"))
assert(has("combine","realismExtensionsTerrainDeformation"))
assert(not has("locomotive","realismExtensionsTerrainDeformation"))
assert(ptoPhysicsInstalls==1)

-- Native PTO owner must stand aside when external DynamicPTO is active.
types.secondTractor = {specializationsByName={
    motorized=true,drivable=true,attacherJoints=true,wheels=true
}}
g_modIsLoaded.FS25_DynamicPTO_FFM=true
TypeManager.validateTypes(manager)
assert(validationCalls==2)
assert(not has("secondTractor","realismExtensionsPTO"))
assert(has("secondTractor","realismExtensionsTerrainDeformation"))
assert(ptoPhysicsInstalls==1)
print("terrain_pto_coexistence_harness: OK")
