RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 6
Recovery.DEFAULTS = {
    -- v16 no longer uses TerrainDeformation smoothing as a cultivator repair
    -- primitive. Runtime v15 proved that SMOOTH behaved almost entirely as a
    -- weak erosive operation (centerUp=0). Cultivation now grades short-scale
    -- damage toward a robust local plane using set-height deformation mode.
    shallowLevelAmountM = 0.045,
    deepLevelAmountM = 0.035,
    shallowStrength = 0.55,
    deepStrength = 0.45,
    shallowRadiusM = 0.70,
    deepRadiusM = 0.60,
    brushHardness = 0.30,
    targetSpacingFactor = 1.00,
    maxBrushesPerWorkArea = 24,
    minTargetErrorM = 0.0015,
    maxTargetErrorM = 0.20,
    maxPlaneSlope = 0.35,

    -- Prevent overlapping work-area callbacks from grading the same physical
    -- patch repeatedly during one passage while still allowing deliberate
    -- second/third passes over the same ground.
    stampCellSizeM = 0.40,
    passageCooldownMs = 2500,

    -- Logical history follows verified physical relief reduction.
    minRoughnessImprovementM = 0.00020,
    shallowHistoryFraction = 0.45,
    deepHistoryFraction = 0.30,
    shallowMaxHistoryRecoveryM = 0.025,
    deepMaxHistoryRecoveryM = 0.018,
    minHistoryRutM = 0.003
}

Recovery.processedStamps = Recovery.processedStamps or {}
Recovery.pendingStamps = Recovery.pendingStamps or {}
Recovery._targetCounter = Recovery._targetCounter or 0
Recovery.stats = Recovery.stats or {
    workAreaCalls = 0,
    workedAreaCalls = 0,
    planeFits = 0,
    planeFitFailures = 0,
    coveragePoints = 0,
    targetEligible = 0,
    targetSkips = 0,
    stampSkips = 0,
    brushesEnqueued = 0,
    brushesRejected = 0,
    callbacks = 0,
    roughnessVerified = 0,
    roughnessImproved = 0,
    roughnessWorsened = 0,
    roughnessNeutral = 0,
    roughnessImprovementM = 0,
    roughnessWorseningM = 0,
    centerRaised = 0,
    centerLowered = 0,
    targetAbsErrorM = 0,
    maxTargetErrorM = 0,
    planeRejectSlope = 0,
    planeRejectError = 0,
    historyRecoveredCells = 0,
    historyRecoveredDepthM = 0
}

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function getWorkAreaGeometry(workArea)
    if workArea == nil or workArea.start == nil
        or workArea.width == nil or workArea.height == nil then return nil end

    local okS, xs, _, zs = pcall(getWorldTranslation, workArea.start)
    local okW, xw, _, zw = pcall(getWorldTranslation, workArea.width)
    local okH, xh, _, zh = pcall(getWorldTranslation, workArea.height)
    if not okS or not okW or not okH then return nil end

    local ux, uz = xw - xs, zw - zs
    local vx, vz = xh - xs, zh - zs
    local widthM = math.sqrt(ux * ux + uz * uz)
    local depthM = math.sqrt(vx * vx + vz * vz)
    if widthM < 0.05 or depthM < 0.05 then return nil end

    return {
        xs=xs, zs=zs, ux=ux, uz=uz, vx=vx, vz=vz,
        widthM=widthM, depthM=depthM
    }
end

local function terrainNode()
    return g_currentMission ~= nil
        and g_currentMission.terrainRootNode or g_terrainNode
end

local function sampleTerrainHeight(x, z)
    local terrain = terrainNode()
    if getTerrainHeightAtWorldPos == nil or terrain == nil or terrain == 0 then
        return nil
    end
    local ok, y = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and type(y) == "number" then return y end
    return nil
end

local function median(values)
    if #values == 0 then return nil end
    table.sort(values)
    local n = #values
    if n % 2 == 1 then return values[(n + 1) / 2] end
    return (values[n / 2] + values[n / 2 + 1]) * 0.5
end

local function solvePlane(samples)
    if #samples < 4 then return nil end
    local mx, mz, my = 0, 0, 0
    for _,s in ipairs(samples) do
        mx, mz, my = mx + s.x, mz + s.z, my + s.y
    end
    mx, mz, my = mx/#samples, mz/#samples, my/#samples

    local sxx, sxz, szz, sxy, szy = 0,0,0,0,0
    for _,s in ipairs(samples) do
        local dx, dz, dy = s.x-mx, s.z-mz, s.y-my
        sxx = sxx + dx*dx
        sxz = sxz + dx*dz
        szz = szz + dz*dz
        sxy = sxy + dx*dy
        szy = szy + dz*dy
    end

    local det = sxx*szz - sxz*sxz
    local bx, bz = 0, 0
    if math.abs(det) > 0.0000001 then
        bx = (sxy*szz - szy*sxz) / det
        bz = (szy*sxx - sxy*sxz) / det
    end

    -- Use the median intercept rather than least-squares mean elevation. Deep
    -- wheel ruts are then treated as outliers instead of dragging the target
    -- surface downward on every cultivation pass.
    local intercepts = {}
    for _,s in ipairs(samples) do
        intercepts[#intercepts+1] = s.y - bx*s.x - bz*s.z
    end
    local a = median(intercepts)
    if a == nil then return nil end
    return { a=a, bx=bx, bz=bz }
end

local function fitRobustPlane(g)
    local samples = {}
    local ax = {0, 0.25, 0.50, 0.75, 1.0}
    local bz = {0, 0.50, 1.0}
    for _,b in ipairs(bz) do
        for _,a in ipairs(ax) do
            local x = g.xs + g.ux*a + g.vx*b
            local z = g.zs + g.uz*a + g.vz*b
            local y = sampleTerrainHeight(x,z)
            if y ~= nil then
                samples[#samples+1] = {x=x,z=z,y=y}
            end
        end
    end
    if #samples < 8 then return nil end

    local first = solvePlane(samples)
    if first == nil then return nil end

    -- One trimmed refit rejects the largest local rut/berm residuals while
    -- retaining the macro field slope.
    local ranked = {}
    for _,s in ipairs(samples) do
        local target = first.a + first.bx*s.x + first.bz*s.z
        ranked[#ranked+1] = {sample=s, residual=math.abs(s.y-target)}
    end
    table.sort(ranked, function(a,b) return a.residual < b.residual end)
    local keep = math.max(8, math.floor(#ranked*0.75 + 0.5))
    local trimmed = {}
    for i=1,math.min(keep,#ranked) do trimmed[#trimmed+1]=ranked[i].sample end
    local plane = solvePlane(trimmed) or first

    local normalLen = math.sqrt(plane.bx*plane.bx + 1 + plane.bz*plane.bz)
    plane.nx = -plane.bx / normalLen
    plane.ny = 1 / normalLen
    plane.nz = -plane.bz / normalLen
    plane.d = -plane.a / normalLen

    local function targetY(x,z)
        return plane.a + plane.bx*x + plane.bz*z
    end
    plane.targetY = targetY

    local corners = {
        {g.xs,g.zs},
        {g.xs+g.ux,g.zs+g.uz},
        {g.xs+g.vx,g.zs+g.vz},
        {g.xs+g.ux+g.vx,g.zs+g.uz+g.vz}
    }
    local minY,maxY = math.huge,-math.huge
    for _,p in ipairs(corners) do
        local y=targetY(p[1],p[2])
        minY,maxY=math.min(minY,y),math.max(maxY,y)
    end
    plane.minY=minY
    plane.maxY=maxY
    return plane
end

local function buildCoveragePoints(g, radius)
    local spacing = math.max(0.25, radius * Recovery.DEFAULTS.targetSpacingFactor)
    local maxBrushes = math.max(1, Recovery.DEFAULTS.maxBrushesPerWorkArea)
    local nx = math.max(1, math.ceil(g.widthM / spacing))
    local nz = math.max(1, math.ceil(g.depthM / spacing))
    while nx*nz > maxBrushes do
        spacing=spacing*1.12
        nx=math.max(1,math.ceil(g.widthM/spacing))
        nz=math.max(1,math.ceil(g.depthM/spacing))
    end

    local points={}
    for iz=1,nz do
        local b=(iz-0.5)/nz
        for ix=1,nx do
            local a=(ix-0.5)/nx
            points[#points+1]={
                x=g.xs+g.ux*a+g.vx*b,
                z=g.zs+g.uz*a+g.vz*b
            }
        end
    end
    return points
end

local function samplePlaneErrorAround(point, radius, plane)
    local r = math.max(0.10, radius * 0.70)
    local offsets = {
        {0,0}, {r,0}, {-r,0}, {0,r}, {0,-r},
        {r*0.7071,r*0.7071}, {-r*0.7071,r*0.7071},
        {r*0.7071,-r*0.7071}, {-r*0.7071,-r*0.7071}
    }
    local maxAbsError = 0
    local signedAtMax = 0
    local samples = 0
    for _,o in ipairs(offsets) do
        local x,z = point.x+o[1], point.z+o[2]
        local currentY = sampleTerrainHeight(x,z)
        if currentY ~= nil then
            local targetY = plane.targetY(x,z)
            local err = targetY-currentY
            if math.abs(err) > maxAbsError then
                maxAbsError = math.abs(err)
                signedAtMax = err
            end
            samples = samples + 1
        end
    end
    if samples == 0 then return nil,nil,0 end
    return maxAbsError,signedAtMax,samples
end

local function stampKey(x,z)
    local s=math.max(0.10,Recovery.DEFAULTS.stampCellSizeM)
    return tostring(math.floor(x/s+0.5))..":"..tostring(math.floor(z/s+0.5))
end

local function stampAvailable(key,nowMs)
    if Recovery.pendingStamps[key]==true then return false end
    local last=Recovery.processedStamps[key]
    return last==nil or nowMs<=0 or nowMs-last>=Recovery.DEFAULTS.passageCooldownMs
end

local function cleanupOldStamps(nowMs)
    if nowMs<=0 then return end
    local last=Recovery._lastStampCleanupMs or 0
    if nowMs-last<10000 then return end
    Recovery._lastStampCleanupMs=nowMs
    local maxAge=math.max(15000,Recovery.DEFAULTS.passageCooldownMs*5)
    for key,stampMs in pairs(Recovery.processedStamps) do
        if Recovery.pendingStamps[key]~=true and type(stampMs)=="number"
            and nowMs-stampMs>maxAge then
            Recovery.processedStamps[key]=nil
        end
    end
end

local function recoverWorkedArea(vehicle,workArea,realArea)
    if not enabled() or (tonumber(realArea) or 0)<=0 then return end
    local runtime=RealismExtensionsTerrainRuntime
    if runtime==nil or runtime.history==nil or runtime.writer==nil
        or runtime.history.applyRecoveryCircle==nil then return end

    local g=getWorkAreaGeometry(workArea)
    if g==nil then return end

    local plane=fitRobustPlane(g)
    if plane==nil then
        Recovery.stats.planeFitFailures=Recovery.stats.planeFitFailures+1
        return
    end

    local slope=math.sqrt((plane.bx or 0)^2+(plane.bz or 0)^2)
    if slope>Recovery.DEFAULTS.maxPlaneSlope then
        Recovery.stats.planeRejectSlope=Recovery.stats.planeRejectSlope+1
        return
    end

    Recovery.stats.planeFits=Recovery.stats.planeFits+1

    Recovery._targetCounter=Recovery._targetCounter+1
    local target={
        key="RECOVERY:"..tostring(Recovery._targetCounter),
        minY=plane.minY,
        maxY=plane.maxY,
        nx=plane.nx,ny=plane.ny,nz=plane.nz,d=plane.d
    }

    local spec=vehicle~=nil and vehicle.spec_cultivator or nil
    local deep=spec~=nil and spec.useDeepMode==true
    local radius=deep and Recovery.DEFAULTS.deepRadiusM or Recovery.DEFAULTS.shallowRadiusM
    local levelAmount=deep and Recovery.DEFAULTS.deepLevelAmountM or Recovery.DEFAULTS.shallowLevelAmountM
    local strength=deep and Recovery.DEFAULTS.deepStrength or Recovery.DEFAULTS.shallowStrength
    local historyFraction=deep and Recovery.DEFAULTS.deepHistoryFraction or Recovery.DEFAULTS.shallowHistoryFraction
    local maxHistoryRecovery=deep and Recovery.DEFAULTS.deepMaxHistoryRecoveryM or Recovery.DEFAULTS.shallowMaxHistoryRecoveryM

    local nowMs=g_currentMission~=nil and g_currentMission.time or 0
    cleanupOldStamps(nowMs)
    local points=buildCoveragePoints(g,radius)
    Recovery.stats.coveragePoints=Recovery.stats.coveragePoints+#points

    for _,point in ipairs(points) do
        local targetErrorAbs = samplePlaneErrorAround(point,radius,plane)
        if targetErrorAbs==nil
            or targetErrorAbs<Recovery.DEFAULTS.minTargetErrorM then
            Recovery.stats.targetSkips=Recovery.stats.targetSkips+1
        elseif targetErrorAbs>Recovery.DEFAULTS.maxTargetErrorM then
            Recovery.stats.planeRejectError=Recovery.stats.planeRejectError+1
        else
            Recovery.stats.targetEligible=Recovery.stats.targetEligible+1
            Recovery.stats.targetAbsErrorM=Recovery.stats.targetAbsErrorM+targetErrorAbs
            Recovery.stats.maxTargetErrorM=math.max(Recovery.stats.maxTargetErrorM,targetErrorAbs)

            local key=stampKey(point.x,point.z)
            if not stampAvailable(key,nowMs) then
                Recovery.stats.stampSkips=Recovery.stats.stampSkips+1
            else
                Recovery.pendingStamps[key]=true
                Recovery.processedStamps[key]=nowMs

                local accepted=runtime.writer:enqueue({
                    x=point.x,z=point.z,
                    mode="LEVEL",
                    levelAmountM=levelAmount,
                    levelTarget=target,
                    radiusM=radius,
                    hardness=Recovery.DEFAULTS.brushHardness,
                    strength=strength,
                    source="RECOVERY",
                    probeRadiusM=radius*0.80,
                    onApplied=function(state,deltaY,beforeY,afterY,callbackVolume,geometry)
                        Recovery.pendingStamps[key]=nil
                        Recovery.stats.callbacks=Recovery.stats.callbacks+1
                        if type(deltaY)=="number" then
                            if deltaY>0.00005 then
                                Recovery.stats.centerRaised=Recovery.stats.centerRaised+1
                            elseif deltaY< -0.00005 then
                                Recovery.stats.centerLowered=Recovery.stats.centerLowered+1
                            end
                        end

                        local beforeR=geometry~=nil and tonumber(geometry.roughnessBeforeM) or nil
                        local afterR=geometry~=nil and tonumber(geometry.roughnessAfterM) or nil
                        if beforeR==nil or afterR==nil then
                            Recovery.stats.roughnessNeutral=Recovery.stats.roughnessNeutral+1
                            return
                        end

                        Recovery.stats.roughnessVerified=Recovery.stats.roughnessVerified+1
                        local improvement=beforeR-afterR
                        local epsilon=Recovery.DEFAULTS.minRoughnessImprovementM
                        if improvement>epsilon then
                            Recovery.stats.roughnessImproved=Recovery.stats.roughnessImproved+1
                            Recovery.stats.roughnessImprovementM=Recovery.stats.roughnessImprovementM+improvement
                            local amount=math.min(maxHistoryRecovery,improvement)
                            local cells,depth=runtime.history:applyRecoveryCircle(
                                point.x,point.z,radius,amount,historyFraction,
                                {minRutM=Recovery.DEFAULTS.minHistoryRutM,
                                 nowMs=g_currentMission~=nil and g_currentMission.time or nowMs}
                            )
                            Recovery.stats.historyRecoveredCells=Recovery.stats.historyRecoveredCells+(cells or 0)
                            Recovery.stats.historyRecoveredDepthM=Recovery.stats.historyRecoveredDepthM+(depth or 0)
                        elseif improvement< -epsilon then
                            Recovery.stats.roughnessWorsened=Recovery.stats.roughnessWorsened+1
                            Recovery.stats.roughnessWorseningM=Recovery.stats.roughnessWorseningM-improvement
                        else
                            Recovery.stats.roughnessNeutral=Recovery.stats.roughnessNeutral+1
                        end
                    end
                })

                if accepted then
                    Recovery.stats.brushesEnqueued=Recovery.stats.brushesEnqueued+1
                else
                    Recovery.pendingStamps[key]=nil
                    Recovery.processedStamps[key]=nil
                    Recovery.stats.brushesRejected=Recovery.stats.brushesRejected+1
                end
            end
        end
    end
end

function Recovery.processCultivatorArea(vehicle,superFunc,workArea,dt)
    Recovery.stats.workAreaCalls=Recovery.stats.workAreaCalls+1
    local realArea,area=superFunc(vehicle,workArea,dt)
    if (tonumber(realArea) or 0)>0 then
        Recovery.stats.workedAreaCalls=Recovery.stats.workedAreaCalls+1
        local perfStarted=RealismExtensionsTerrainPerformance~=nil
            and RealismExtensionsTerrainPerformance.begin() or nil
        recoverWorkedArea(vehicle,workArea,realArea)
        if RealismExtensionsTerrainPerformance~=nil then
            RealismExtensionsTerrainPerformance.finish("recovery",perfStarted)
        end
    end
    return realArea,area
end

function Recovery.getDiagnostics()
    local out={}
    for k,v in pairs(Recovery.stats) do out[k]=v end
    return out
end

function Recovery.prerequisitesPresent(specializations)
    return Cultivator~=nil and SpecializationUtil.hasSpecialization(Cultivator,specializations)
end

function Recovery.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType,"processCultivatorArea",Recovery.processCultivatorArea)
end
