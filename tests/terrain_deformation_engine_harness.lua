SpecializationUtil = {
    hasSpecialization = function() return true end,
    registerEventListener = function() end
}
Wheels = {}
g_currentModDirectory = ""
g_currentModName = "FS25_RealismExtensions"

g_specializationManager = {
    getSpecializationByName = function() return {} end,
    addSpecialization = function() error("should not add in harness") end
}
TypeManager = { validateTypes = function() end }
Utils = {
    appendedFunction = function(base, appended)
        return function(...)
            if base ~= nil then base(...) end
            return appended(...)
        end
    end
}

RealismExtensionsConfig = {
    modules = { TerrainDeformation = true }
}

local contexts = 0
RealismExtensionsState = {
    getWheelContext = function(vehicle, wheel)
        contexts = contexts + 1
        return {
            contextVersion=1,
            grounded=true,
            soilContact=true,
            worldX=wheel.testX,
            worldZ=0,
            structuralRadiusM=0.8,
            supportWidthM=0.6,
            wheelLoadN=20000,
            wheelLoadMeasured=true,
            tirePressureBar=1.0,
            physicalGroundWetness=0.8,
            groundMudPotential=0.7,
            hardFrozen=false,
            speedKph=5,
            wheelSurfaceSpeedMps=2,
            longitudinalSlip=0.3,
            lateralSlip=0.05,
            sinkDepthM=0.02,
            sinkSeverity=0.025
        }
    end
}

RealismExtensionsFootprintModel = {
    compute = function(context)
        return {
            available=true,
            supportWidthM=0.6,
            footprintLengthM=0.4,
            structuralRadiusM=0.8,
            groundPressurePa=100000
        }
    end
}

RealismExtensionsTerrainResponseModel = {
    compute = function(context, footprint, history, dt)
        local previous = history and history.rutDepthM or 0
        return {
            available=true,
            rutDepthM=previous + 0.005,
            rutWidthM=0.6,
            nextHistory={
                rutDepthM=previous + 0.005,
                longitudinalShearDistanceM=(history and history.longitudinalShearDistanceM or 0)+0.01,
                lateralShearDistanceM=0,
                passCount=(history and history.passCount or 0)+1
            }
        }
    end
}

dofile("scripts/terrain/SpatialHistory.lua")
dofile("scripts/terrain/TerrainWriter.lua")

local enqueued = 0
RealismExtensionsTerrainRuntime = {
    history = RealismExtensionsSpatialHistory.new({cellSizeM=0.2,maxCells=100}),
    writer = {
        options = { minDepthM = 0.0004 },
        enqueue = function(self, brush)
            enqueued = enqueued + 1
            return true
        end
    }
}

dofile("scripts/terrain/TerrainDeformationEngine.lua")

local wheelA = { physics = {}, testX = 0 }
local wheelB = { physics = {}, testX = 0.5 }
local vehicle = {
    isServer = true,
    spec_wheels = { wheels = { wheelA, wheelB } },
    getWheels = function(self) return self.spec_wheels.wheels end,
    getLastSpeed = function(self) return 5 end
}

RealismExtensionsTerrainDeformationEngine.onLoad(vehicle)
RealismExtensionsTerrainDeformationEngine.onUpdate(vehicle, 100)

assert(contexts == 2)
assert(enqueued == 2)
assert(RealismExtensionsTerrainRuntime.history.count == 2)

-- Move each wheel forward: only this vehicle's two wheels are processed.
wheelA.testX = 0.4
wheelB.testX = 0.9
RealismExtensionsTerrainDeformationEngine.onUpdate(vehicle, 100)
assert(contexts == 4)
assert(enqueued > 2)

-- Disabled module means zero further provider calls.
RealismExtensionsConfig.modules.TerrainDeformation = false
RealismExtensionsTerrainDeformationEngine.onUpdate(vehicle, 100)
assert(contexts == 4)

-- Client vehicles never write terrain.
RealismExtensionsConfig.modules.TerrainDeformation = true
vehicle.isServer = false
RealismExtensionsTerrainDeformationEngine.onUpdate(vehicle, 100)
assert(contexts == 4)

print("terrain_deformation_engine_harness: OK")
