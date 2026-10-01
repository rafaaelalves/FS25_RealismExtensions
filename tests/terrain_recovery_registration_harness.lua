-- TerrainRecovery registration harness.
g_currentModName = "FS25_RealismExtensions"
g_currentModDirectory = "/mods/FS25_RealismExtensions/"
local addedSpecializations = {}
local registered = {}

g_specializationManager = {
    getSpecializationByName = function(self, name) return registered[name] end,
    addSpecialization = function(self, name, className, path, modName)
        registered[name] = { className=className, path=path, modName=modName }
    end
}

local types = {
    cultivatorOnly = {
        specializationsByName = { cultivator = {} }
    },
    directSeederHybrid = {
        specializationsByName = { cultivator = {}, sowingMachine = {} }
    },
    sowingOnly = {
        specializationsByName = { sowingMachine = {} }
    },
    plowOnly = {
        specializationsByName = { plow = {} }
    }
}

TypeManager = {
    validateTypes = function() end
}
Utils = {
    appendedFunction = function(original, appended)
        return function(self, ...)
            if original ~= nil then original(self, ...) end
            return appended(self, ...)
        end
    end
}

local manager = {
    typeName = "vehicle",
    getTypes = function(self) return types end,
    addSpecialization = function(self, typeName, fullName)
        addedSpecializations[typeName] = fullName
        types[typeName].specializationsByName[fullName] = {}
    end
}

dofile("scripts/terrain/TerrainRecoveryRegistration.lua")
assert(registered.realismExtensionsTerrainRecovery ~= nil)
TypeManager.validateTypes(manager)

assert(addedSpecializations.cultivatorOnly ~= nil)
assert(addedSpecializations.directSeederHybrid ~= nil)
assert(addedSpecializations.sowingOnly == nil)
assert(addedSpecializations.plowOnly == nil)

print("terrain_recovery_registration_harness: OK")
