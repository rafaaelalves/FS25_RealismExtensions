-- Registration lifecycle harness.
-- Proves that the bootstrap captures the mod environment at source-load time
-- and can install the specialization later even when GIANTS clears the globals.

local registered = {}
local addedToTypes = {}

g_currentModName = "FS25_RealismExtensions"
g_currentModDirectory = "/mods/FS25_RealismExtensions/"

g_specializationManager = {
    getSpecializationByName = function(self, name)
        return registered[name]
    end,
    addSpecialization = function(self, name, className, filename, modName)
        assert(name == "realismExtensionsTerrainDeformation")
        assert(className == "RealismExtensionsTerrainDeformationEngine")
        assert(filename == "/mods/FS25_RealismExtensions/scripts/terrain/TerrainDeformationEngine.lua")
        assert(modName == "FS25_RealismExtensions")
        registered[name] = true
    end
}

TypeManager = {
    validateTypes = function() end
}

Utils = {
    appendedFunction = function(base, appended)
        return function(...)
            if base ~= nil then base(...) end
            return appended(...)
        end
    end
}

dofile("scripts/terrain/TerrainDeformationRegistration.lua")
assert(registered.realismExtensionsTerrainDeformation == true)

-- Simulate the later validateTypes phase where current-mod globals are no
-- longer guaranteed to belong to RE.
g_currentModName = nil
g_currentModDirectory = nil

local manager = {
    typeName = "vehicle",
    getTypes = function()
        return {
            tractor = {
                specializationsByName = {
                    wheels = {}
                }
            },
            locomotive = {
                specializationsByName = {
                    wheels = {}
                }
            },
            placeable = {
                specializationsByName = {}
            }
        }
    end,
    addSpecialization = function(self, typeName, fullName)
        addedToTypes[#addedToTypes + 1] = typeName .. ":" .. fullName
    end
}

TypeManager.validateTypes(manager)

assert(#addedToTypes == 1)
assert(addedToTypes[1] == "tractor:FS25_RealismExtensions.realismExtensionsTerrainDeformation")

print("terrain_deformation_registration_harness: OK")
