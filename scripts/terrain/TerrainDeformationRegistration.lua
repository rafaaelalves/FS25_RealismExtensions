-- TerrainDeformation specialization bootstrap.
--
-- Keep registration separate from TerrainDeformationEngine.lua. The engine is
-- loaded by GIANTS as the specialization implementation; loading that same file
-- first as an extraSourceFile can recursively re-enter registration and loses
-- reliable access to g_currentModName during later TypeManager callbacks.

local MOD_NAME = g_currentModName
local MOD_DIRECTORY = g_currentModDirectory
local SPEC_NAME = "realismExtensionsTerrainDeformation"

if type(MOD_NAME) ~= "string" or MOD_NAME == "" then
    error("RealismExtensions TerrainDeformation bootstrap: g_currentModName unavailable")
end
if type(MOD_DIRECTORY) ~= "string" or MOD_DIRECTORY == "" then
    error("RealismExtensions TerrainDeformation bootstrap: g_currentModDirectory unavailable")
end

local FULL_NAME = MOD_NAME .. "." .. SPEC_NAME
local IMPLEMENTATION = MOD_DIRECTORY .. "scripts/terrain/TerrainDeformationEngine.lua"

if g_specializationManager ~= nil
    and g_specializationManager:getSpecializationByName(SPEC_NAME) == nil then
    g_specializationManager:addSpecialization(
        SPEC_NAME,
        "RealismExtensionsTerrainDeformationEngine",
        IMPLEMENTATION,
        MOD_NAME
    )
end

local function installSpecialization(typeManager)
    if typeManager == nil or typeManager.typeName ~= "vehicle" then return end

    local types = typeManager:getTypes()
    if type(types) ~= "table" then return end

    for typeName, typeDef in pairs(types) do
        local byName = typeDef ~= nil and typeDef.specializationsByName or nil
        if type(byName) == "table"
            and typeName ~= "locomotive"
            and byName["wheels"] ~= nil
            and byName[FULL_NAME] == nil then
            typeManager:addSpecialization(typeName, FULL_NAME)
        end
    end
end

TypeManager.validateTypes = Utils.appendedFunction(
    TypeManager.validateTypes,
    installSpecialization
)
