-- TerrainRecovery H2 causal-center / convergence harness.
RealismExtensionsConfig = {
    modules = {
        TerrainDeformation = true,
        TerrainRecovery = true,
        SoilMassTransport = false
    }
}

local enqueued = {}
local exactRecoveryCalls = 0
local exactRecoveryDepth = 0
local cells = {}
local callbackMode = "COMPLETE"
local convergenceStep = 0
local structuralStep = 0

local function hkey(x,z)
    return string.format("%.2f:%.2f", x, z)
end

local function clearHistory()
    cells = {}
    exactRecoveryCalls = 0
    exactRecoveryDepth = 0
end

local function seedHistory(list)
    clearHistory()
    for _,v in ipairs(list or {}) do
        cells[hkey(v.x,v.z)] = {
            x=v.x,
            z=v.z,
            rutDepthM=v.rutDepthM,
            deformationExposure=1.0
        }
    end
end

local historyApi = {}

function historyApi:getRecoveryCandidatesParallelogram(xs,zs,xw,zw,xh,zh,options)
    local out = {}
    for key,h in pairs(cells) do
        if (h.rutDepthM or 0) >= (options.minRutM or 0) then
            out[#out+1] = {
                key=key,
                x=h.x,
                z=h.z,
                rutDepthM=h.rutDepthM
            }
        end
    end
    table.sort(out,function(a,b) return a.x < b.x end)
    return out
end

function historyApi:get(x,z)
    return cells[hkey(x,z)]
end

function historyApi:applyRecoveryAt(x,z,amount,options)
    local h = cells[hkey(x,z)]
    if h == nil then return 0 end
    local minRut = options ~= nil and (options.minRutM or 0) or 0
    local rut = math.max(0,h.rutDepthM or 0)
    if rut < minRut then return 0 end
    local applied = math.min(rut,math.max(0,amount or 0))
    h.rutDepthM = rut - applied
    exactRecoveryCalls = exactRecoveryCalls + 1
    exactRecoveryDepth = exactRecoveryDepth + applied
    return applied
end

local function geometryForMode(writerMode)
    if callbackMode == "COMPLETE" then
        return {
            roughnessBeforeM=0.020,
            roughnessAfterM=0.012,
            reliefBeforeM=0.060,
            reliefAfterM=0.035,
            centerDeficitBeforeM=0.020,
            centerDeficitAfterM=0.002
        }
    elseif callbackMode == "ROUGHNESS_ONLY" then
        -- Regression case from v23: the region becomes less rough while the
        -- causal rut center does not improve at all.
        return {
            roughnessBeforeM=0.020,
            roughnessAfterM=0.010,
            reliefBeforeM=0.060,
            reliefAfterM=0.045,
            centerDeficitBeforeM=0.030,
            centerDeficitAfterM=0.030
        }
    elseif callbackMode == "WORSEN_CENTER" then
        return {
            roughnessBeforeM=0.020,
            roughnessAfterM=0.015,
            reliefBeforeM=0.060,
            reliefAfterM=0.055,
            centerDeficitBeforeM=0.030,
            centerDeficitAfterM=0.035
        }
    elseif callbackMode == "CONVERGE" then
        convergenceStep = convergenceStep + 1
        if convergenceStep == 1 then
            return {
                roughnessBeforeM=0.030, roughnessAfterM=0.022,
                reliefBeforeM=0.070, reliefAfterM=0.055,
                centerDeficitBeforeM=0.030,
                centerDeficitAfterM=0.020
            }
        elseif convergenceStep == 2 then
            return {
                roughnessBeforeM=0.022, roughnessAfterM=0.016,
                reliefBeforeM=0.055, reliefAfterM=0.038,
                centerDeficitBeforeM=0.020,
                centerDeficitAfterM=0.010
            }
        else
            return {
                roughnessBeforeM=0.016, roughnessAfterM=0.010,
                reliefBeforeM=0.038, reliefAfterM=0.020,
                centerDeficitBeforeM=0.010,
                centerDeficitAfterM=0.002
            }
        end
    elseif callbackMode == "STRUCTURAL" then
        if writerMode == "TARGET" then
            structuralStep = structuralStep + 1
            if structuralStep == 1 then
                return {
                    roughnessBeforeM=0.050, roughnessAfterM=0.035,
                    reliefBeforeM=0.140, reliefAfterM=0.100,
                    centerDeficitBeforeM=0.110,
                    centerDeficitAfterM=0.070,
                    referenceAfterY=10.0,
                    planeAxAfter=0.02,
                    planeAzAfter=-0.01
                }
            else
                return {
                    roughnessBeforeM=0.035, roughnessAfterM=0.020,
                    reliefBeforeM=0.100, reliefAfterM=0.055,
                    centerDeficitBeforeM=0.070,
                    centerDeficitAfterM=0.030,
                    referenceAfterY=10.0,
                    planeAxAfter=0.02,
                    planeAzAfter=-0.01
                }
            end
        elseif structuralStep >= 2 then
            return {
                roughnessBeforeM=0.020, roughnessAfterM=0.010,
                reliefBeforeM=0.055, reliefAfterM=0.018,
                centerDeficitBeforeM=0.030,
                centerDeficitAfterM=0.002,
                referenceAfterY=10.0,
                planeAxAfter=0.02,
                planeAzAfter=-0.01
            }
        else
            return {
                roughnessBeforeM=0.060, roughnessAfterM=0.052,
                reliefBeforeM=0.150, reliefAfterM=0.140,
                centerDeficitBeforeM=0.120,
                centerDeficitAfterM=0.110,
                referenceAfterY=10.0,
                planeAxAfter=0.02,
                planeAzAfter=-0.01
            }
        end
    end
    error("unexpected callbackMode")
end

RealismExtensionsTerrainRuntime = {
    history = historyApi,
    writer = {
        enqueue=function(self,brush)
            enqueued[#enqueued+1]=brush
            assert(brush.source=="RECOVERY")
            if brush.mode=="SMOOTH" then
                assert(math.abs(brush.smoothAmountM-0.05)<0.000001)
                assert(math.abs(brush.radiusM-2.0)<0.000001)
                assert(math.abs(brush.hardness-0.20)<0.000001)
                assert(math.abs(brush.strength-0.50)<0.000001)
                assert(brush.probeRadiusM>0)
                local g=geometryForMode("SMOOTH")
                brush.onApplied(1,-0.002,1.0,0.998,0,g)
            elseif brush.mode=="TARGET" then
                assert(type(brush.targetY)=="number")
                assert(type(brush.targetPlaneAx)=="number")
                assert(type(brush.targetPlaneAz)=="number")
                assert(brush.maxStepM>0 and brush.maxStepM<=0.040001)
                assert(math.abs(brush.radiusM-0.45)<0.000001)
                assert(math.abs(brush.hardness-0.45)<0.000001)
                assert(math.abs(brush.strength-0.90)<0.000001)
                assert(brush.probeRadiusM>1.0)
                local g=geometryForMode("TARGET")
                brush.onApplied(1,0.040,0.90,0.94,0,g)
            else
                error("unexpected recovery writer mode "..tostring(brush.mode))
            end
            return true
        end
    }
}

local perfBegins,perfFinishes=0,0
RealismExtensionsTerrainPerformance = {
    begin=function() perfBegins=perfBegins+1 return perfBegins end,
    finish=function(name,started)
        assert(name=="recovery" and started~=nil)
        perfFinishes=perfFinishes+1
    end
}

g_currentMission={time=10000}
getWorldTranslation=function(node)
    if node==101 then return 0,0,0 end
    if node==102 then return 2,0,0 end
    if node==103 then return 0,0,1 end
    error("unexpected node")
end
Cultivator={}
SpecializationUtil={
    hasSpecialization=function() return true end,
    registerOverwrittenFunction=function() end
}

dofile("scripts/terrain/TerrainWorkContext.lua")
dofile("scripts/terrain/TerrainRecovery.lua")

local Recovery=RealismExtensionsTerrainRecovery
local rootVehicle={}
local vehicle={
    spec_cultivator={useDeepMode=false,isEnabled=true,isWorking=false},
    getRootVehicle=function(self) return rootVehicle end,
    getLastSpeed=function(self) return 8 end
}
local workArea={start=101,width=102,height=103}
local function workedSuper(self,wa,dt)
    self.spec_cultivator.isWorking=true
    return 12,12
end
local function repeatSuper(self,wa,dt)
    self.spec_cultivator.isWorking=true
    return 0,12
end
local function rejectedSuper(self,wa,dt)
    self.spec_cultivator.isWorking=false
    return 0,0
end

-- 1. Causal history candidates are centered and successful center-deficit
-- reduction reconciles only those exact cells.
seedHistory({
    {x=0.40,z=0.40,rutDepthM=0.05},
    {x=1.20,z=0.40,rutDepthM=0.03}
})
callbackMode="COMPLETE"
Recovery.resetRuntimeState()
local before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
local firstCount=#enqueued-before
assert(firstCount==2)
local d=Recovery.getDiagnostics()
assert(d.intentCandidateCells==2)
assert(d.intentPoints==2)
assert(d.intentMaxRutM>=0.05)
assert(d.centerDeficitVerified==2)
assert(d.centerDeficitImproved==2)
assert(d.convergenceCompleted>=2)
assert(d.historyRecoveredCells>=2)
assert(d.historyRecoveredDepthM>0)
assert(exactRecoveryCalls>=2)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)
assert((historyApi:get(1.20,0.40).rutDepthM or 0)<0.003)
assert(d.protectedCellsMarked>0)
assert(d.activeCombinationMarks>0)
assert(Recovery.isRutGenerationSuppressed(rootVehicle,10000)==true)
assert(Recovery.isRutGenerationSuppressed(rootVehicle,11501)==false)
assert(Recovery.isRecentlyCultivated(1.0,0.5,10000)==true)
assert(Recovery.isRecentlyCultivated(1.0,0.5,19001)==false)

-- 2. Repeated physical pass is still recognized even when vanilla realArea=0.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.04}})
Recovery.resetRuntimeState()
g_currentMission.time=12000
before=#enqueued
Recovery.processCultivatorArea(vehicle,repeatSuper,workArea,16)
assert(#enqueued>before)
d=Recovery.getDiagnostics()
assert(d.repeatWorkAreaCalls>0)
assert(d.areaPositiveCalls>0)
assert(d.physicalWorkAreaCalls>0)
assert(d.processedAreaUnits>=12)
assert(d.changedAreaUnits==0)

-- 3. Core v23 regression guard:
-- roughness/relief may improve while the wheel-channel center does not.
-- In that case logical rut debt MUST remain untouched.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.05}})
Recovery.resetRuntimeState()
callbackMode="ROUGHNESS_ONLY"
g_currentMission.time=14000
local debtBefore=historyApi:get(0.40,0.40).rutDepthM
local recoveryBefore=exactRecoveryDepth
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
d=Recovery.getDiagnostics()
assert(d.roughnessImproved>0)
assert(d.reliefImproved>0)
assert(d.centerDeficitNeutral>0)
assert(d.historyRecoveredDepthM==0)
assert(exactRecoveryDepth==recoveryBefore)
assert(math.abs(historyApi:get(0.40,0.40).rutDepthM-debtBefore)<0.000001)
assert(d.convergenceScheduled>0)

-- Do not let the queued neutral pulse contaminate later cases.
Recovery.resetRuntimeState()

-- 4. Material worsening at the causal center must neither erase history nor
-- launch an unbounded convergence loop.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.05}})
callbackMode="WORSEN_CENTER"
g_currentMission.time=15000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
d=Recovery.getDiagnostics()
assert(#enqueued==before+1)
assert(d.centerDeficitWorsened==1)
assert(d.historyRecoveredDepthM==0)
assert(d.convergenceScheduled==0)
assert(d.convergenceStalled>=1)
assert(math.abs(historyApi:get(0.40,0.40).rutDepthM-0.05)<0.000001)

-- 5. H2 temporal convergence: one agricultural authorization can continue
-- native SOFTEN pulses on the same history-owned rut center after the work-area
-- callback has moved on, until the physical center deficit is <=3mm.
-- Deliberately seed only 5mm of logical debt against a 30mm physical
-- center deficit. The first pulse can exhaust logical debt, but H2 must keep
-- converging until the measured heightfield center is flat.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.005}})
Recovery.resetRuntimeState()
callbackMode="CONVERGE"
convergenceStep=0
g_currentMission.time=20000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before+1)
d=Recovery.getDiagnostics()
assert(d.convergenceScheduled==1)
assert(d.deferredCount==1)
assert(d.historyRecoveredDepthM>0)

g_currentMission.time=20160
Recovery.update(16)
assert(#enqueued==before+2)
d=Recovery.getDiagnostics()
assert(d.convergenceApplied>=1)
assert(d.convergenceScheduled>=2)
assert(d.deferredCount==1)

g_currentMission.time=20320
Recovery.update(16)
assert(#enqueued==before+3)
d=Recovery.getDiagnostics()
assert(d.convergenceApplied>=2)
assert(d.convergenceCompleted>=1)
assert(d.deferredCount==0)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)

-- 6. R1 structural recovery: a deep center starts with native SMOOTH only
-- as a detector/finisher, then two narrow TARGET pulses lift the causal rut
-- toward the CURRENT fitted boundary plane before H2 performs final polish.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.12}})
Recovery.resetRuntimeState()
callbackMode="STRUCTURAL"
structuralStep=0
g_currentMission.time=21000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before+1)
d=Recovery.getDiagnostics()
assert(d.structuralScheduled==1)
assert(d.deferredCount==1)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.12)

g_currentMission.time=21160
Recovery.update(16)
assert(#enqueued==before+2)
d=Recovery.getDiagnostics()
assert(d.structuralApplied==1)
assert(d.structuralScheduled>=2)
assert(d.structuralDeficitReductionM>0.039)
assert(d.structuralCenterRaisedM>0.039)
assert(d.deferredCount==1)

g_currentMission.time=21320
Recovery.update(16)
assert(#enqueued==before+3)
d=Recovery.getDiagnostics()
assert(d.structuralApplied==2)
assert(d.structuralCompleted>=1)
assert(d.deferredCount==1)

g_currentMission.time=21480
Recovery.update(16)
assert(#enqueued==before+4)
d=Recovery.getDiagnostics()
assert(d.convergenceCompleted>=1)
assert(d.deferredCount==0)
assert((historyApi:get(0.40,0.40).rutDepthM or 0)<0.003)
assert(d.structuralOwnershipExhausted==0)

-- 7. No RE-attributable rut debt => physically working cultivation must not
-- smooth arbitrary landscaping/current baseline terrain.
clearHistory()
Recovery.resetRuntimeState()
callbackMode="COMPLETE"
g_currentMission.time=22000
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before)
d=Recovery.getDiagnostics()
assert(d.intentEmptyWorkAreas>0)
assert(d.intentCandidateCells==0)
assert(d.intentPoints==0)

-- 8. A loaded wheel defers the first authorized pulse; overlapping callbacks
-- coalesce. Once the wheel clears, recovery executes without requiring another
-- Cultivator callback.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.05}})
Recovery.resetRuntimeState()
callbackMode="COMPLETE"
g_currentMission.time=24000
local blockRecovery=true
RealismExtensionsLoadedContactRegistry={
    overlapsCircle=function(x,z,radius,nowMs)
        if blockRecovery then return true,{loadN=32000} end
        return false,nil
    end
}
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(#enqueued==before)
d=Recovery.getDiagnostics()
assert(d.loadedContactQueries>0)
assert(d.loadedContactSkips>0)
assert(d.loadedContactMaxLoadN>=32000)
assert(d.deferredCreated==1)
assert(d.deferredCount==1)

local createdBefore=d.deferredCreated
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
d=Recovery.getDiagnostics()
assert(d.deferredCreated==createdBefore)
assert(d.deferredCoalesced>0)

blockRecovery=false
g_currentMission.time=24100
Recovery.update(16)
assert(#enqueued==before)
g_currentMission.time=24250
Recovery.update(16)
assert(#enqueued==before+1)
d=Recovery.getDiagnostics()
assert(d.deferredApplied>0)
assert(d.deferredCount==0)
assert(d.convergenceCompleted>0)

-- 9. If causal debt disappears while a first pulse waits under a loaded wheel,
-- the stale request must be discarded without touching terrain.
seedHistory({{x=0.40,z=0.40,rutDepthM=0.05}})
Recovery.resetRuntimeState()
g_currentMission.time=26000
blockRecovery=true
before=#enqueued
Recovery.processCultivatorArea(vehicle,workedSuper,workArea,16)
assert(Recovery.getDiagnostics().deferredCount==1)
historyApi:get(0.40,0.40).rutDepthM=0
blockRecovery=false
g_currentMission.time=26250
Recovery.update(16)
assert(#enqueued==before)
d=Recovery.getDiagnostics()
assert(d.intentDeferredGone>0)
assert(d.deferredCount==0)

-- 10. Inactive/rejected work area stays inert and perf accounting remains paired.
RealismExtensionsLoadedContactRegistry=nil
clearHistory()
Recovery.resetRuntimeState()
g_currentMission.time=28000
before=#enqueued
Recovery.processCultivatorArea(vehicle,rejectedSuper,workArea,16)
assert(#enqueued==before)
assert(perfBegins==perfFinishes)

print("terrain_recovery_h2_causal_center_harness: OK")
