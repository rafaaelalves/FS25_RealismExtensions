RealismExtensionsTerrainRecovery = RealismExtensionsTerrainRecovery or {}
local Recovery = RealismExtensionsTerrainRecovery

Recovery.VERSION = 4
Recovery.DEFAULTS = {
    -- Recovery now uses the same physical TerrainDeformation heightfield API
    -- as rut creation. TerraFarm's FS25 smoothing path is the precedent:
    -- TerrainDeformation + enableSmoothingMode + soft terrain brushes.
    shallowSmoothAmountM = 0.050,
    deepSmoothAmountM = 0.035,
    shallowStrength = 0.25,
    deepStrength = 0.18,
    shallowRadiusM = 0.50,
    deepRadiusM = 0.40,
    brushHardness = 0.25,

    -- Work only on RE cells that actually remember a material rut. Candidate
    -- selection is sparse/depth-first and spatially suppresses overlapping
    -- brushes so recovery cost scales with damaged ground, not map size.
    minHistoryRutM = 0.003,
    historyCooldownMs = 1500,
    maxCandidatesPerWorkArea = 24,
    maxBrushesPerWorkArea = 8,
    brushSpacingFactor = 0.70,

    -- One pass is intentionally not a magic reset. Logical recovery is capped
    -- to the physical rise observed at the rut center and to a fraction of the
    -- remembered rut, preserving progressive multi-pass field repair.
    shallowHistoryFraction = 0.35,
    deepHistoryFraction = 0.20,
    shallowMaxHistoryRecoveryM = 0.020,
    deepMaxHistoryRecoveryM = 0.012,
    physicalChangeEpsilonM = 0.00005
}

Recovery.pendingCells = Recovery.pendingCells or {}
Recovery.stats = Recovery.stats or {
    workAreaCalls = 0,
    workedAreaCalls = 0,
    candidateCells = 0,
    selectedCells = 0,
    brushesEnqueued = 0,
    brushesRejected = 0,
    callbacks = 0,
    physicalChanged = 0,
    physicalNoChange = 0,
    physicalRaisedSamples = 0,
    physicalLoweredSamples = 0,
    physicalAbsDeltaM = 0,
    physicalMaxDeltaM = 0,
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

    return {
        xs = xs, zs = zs,
        xw = xw, zw = zw,
        xh = xh, zh = zh
    }
end

local function selectCandidates(candidates, radius, maxCount)
    table.sort(candidates, function(a, b)
        if a.rutDepthM == b.rutDepthM then
            return a.key < b.key
        end
        return a.rutDepthM > b.rutDepthM
    end)

    local selected = {}
    local minSpacing = math.max(
        0.10,
        radius * Recovery.DEFAULTS.brushSpacingFactor
    )
    local minSpacingSq = minSpacing * minSpacing

    for _, candidate in ipairs(candidates) do
        if #selected >= maxCount then break end
        if Recovery.pendingCells[candidate.key] ~= true then
            local separated = true
            for _, existing in ipairs(selected) do
                local dx = candidate.x - existing.x
                local dz = candidate.z - existing.z
                if dx * dx + dz * dz < minSpacingSq then
                    separated = false
                    break
                end
            end
            if separated then
                selected[#selected + 1] = candidate
            end
        end
    end
    return selected
end

local function recoverWorkedArea(vehicle, workArea, realArea)
    if not enabled() or (tonumber(realArea) or 0) <= 0 then return end

    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil or runtime.history == nil or runtime.writer == nil
        or runtime.history.getRecoveryCandidatesParallelogram == nil
        or runtime.history.applyRecoveryAt == nil then
        return
    end

    local g = getWorkAreaGeometry(workArea)
    if g == nil then return end

    local spec = vehicle ~= nil and vehicle.spec_cultivator or nil
    local deep = spec ~= nil and spec.useDeepMode == true

    local radius = deep and Recovery.DEFAULTS.deepRadiusM
        or Recovery.DEFAULTS.shallowRadiusM
    local smoothAmount = deep and Recovery.DEFAULTS.deepSmoothAmountM
        or Recovery.DEFAULTS.shallowSmoothAmountM
    local strength = deep and Recovery.DEFAULTS.deepStrength
        or Recovery.DEFAULTS.shallowStrength
    local fraction = deep and Recovery.DEFAULTS.deepHistoryFraction
        or Recovery.DEFAULTS.shallowHistoryFraction
    local maxHistoryRecovery = deep and Recovery.DEFAULTS.deepMaxHistoryRecoveryM
        or Recovery.DEFAULTS.shallowMaxHistoryRecoveryM

    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0
    local candidates = runtime.history:getRecoveryCandidatesParallelogram(
        g.xs, g.zs, g.xw, g.zw, g.xh, g.zh,
        {
            minRutM = Recovery.DEFAULTS.minHistoryRutM,
            cooldownMs = Recovery.DEFAULTS.historyCooldownMs,
            nowMs = nowMs,
            maxCells = Recovery.DEFAULTS.maxCandidatesPerWorkArea
        }
    )

    Recovery.stats.candidateCells =
        Recovery.stats.candidateCells + #candidates

    local selected = selectCandidates(
        candidates,
        radius,
        Recovery.DEFAULTS.maxBrushesPerWorkArea
    )
    Recovery.stats.selectedCells =
        Recovery.stats.selectedCells + #selected

    for _, candidate in ipairs(selected) do
        Recovery.pendingCells[candidate.key] = true

        local key = candidate.key
        local x, z = candidate.x, candidate.z
        local rutAtSubmission = candidate.rutDepthM

        local accepted = runtime.writer:enqueue({
            x = x,
            z = z,
            mode = "SMOOTH",
            smoothAmountM = smoothAmount,
            radiusM = radius,
            hardness = Recovery.DEFAULTS.brushHardness,
            strength = strength,
            source = "RECOVERY",
            onApplied = function(state, deltaY)
                Recovery.pendingCells[key] = nil
                Recovery.stats.callbacks = Recovery.stats.callbacks + 1

                if type(deltaY) ~= "number" then
                    Recovery.stats.physicalNoChange =
                        Recovery.stats.physicalNoChange + 1
                    return
                end

                local absDelta = math.abs(deltaY)
                Recovery.stats.physicalAbsDeltaM =
                    Recovery.stats.physicalAbsDeltaM + absDelta
                Recovery.stats.physicalMaxDeltaM =
                    math.max(Recovery.stats.physicalMaxDeltaM, absDelta)

                if absDelta <= Recovery.DEFAULTS.physicalChangeEpsilonM then
                    Recovery.stats.physicalNoChange =
                        Recovery.stats.physicalNoChange + 1
                    return
                end

                Recovery.stats.physicalChanged =
                    Recovery.stats.physicalChanged + 1

                if deltaY < 0 then
                    -- Smoothing can lower a local ridge as well as raise a rut.
                    -- This is real geometry work, but it must never be counted
                    -- as logical rut healing for a remembered depression.
                    Recovery.stats.physicalLoweredSamples =
                        Recovery.stats.physicalLoweredSamples + 1
                    return
                end

                Recovery.stats.physicalRaisedSamples =
                    Recovery.stats.physicalRaisedSamples + 1

                local logicalCap = math.min(
                    maxHistoryRecovery,
                    rutAtSubmission * fraction
                )
                local applied = runtime.history:applyRecoveryAt(
                    x,
                    z,
                    math.min(deltaY, logicalCap),
                    {
                        minRutM = Recovery.DEFAULTS.minHistoryRutM,
                        nowMs = g_currentMission ~= nil
                            and g_currentMission.time or nowMs
                    }
                )

                if applied > 0 then
                    Recovery.stats.historyRecoveredCells =
                        Recovery.stats.historyRecoveredCells + 1
                    Recovery.stats.historyRecoveredDepthM =
                        Recovery.stats.historyRecoveredDepthM + applied
                end
            end
        })

        if accepted then
            Recovery.stats.brushesEnqueued =
                Recovery.stats.brushesEnqueued + 1
        else
            Recovery.pendingCells[key] = nil
            Recovery.stats.brushesRejected =
                Recovery.stats.brushesRejected + 1
        end
    end
end

function Recovery.processCultivatorArea(vehicle, superFunc, workArea, dt)
    Recovery.stats.workAreaCalls = Recovery.stats.workAreaCalls + 1

    local realArea, area = superFunc(vehicle, workArea, dt)
    if (tonumber(realArea) or 0) > 0 then
        Recovery.stats.workedAreaCalls = Recovery.stats.workedAreaCalls + 1
        local perfStarted = RealismExtensionsTerrainPerformance ~= nil
            and RealismExtensionsTerrainPerformance.begin() or nil

        recoverWorkedArea(vehicle, workArea, realArea)

        if RealismExtensionsTerrainPerformance ~= nil then
            RealismExtensionsTerrainPerformance.finish("recovery", perfStarted)
        end
    end
    return realArea, area
end

function Recovery.getDiagnostics()
    local out = {}
    for k, v in pairs(Recovery.stats) do out[k] = v end
    return out
end

function Recovery.prerequisitesPresent(specializations)
    return Cultivator ~= nil
        and SpecializationUtil.hasSpecialization(Cultivator, specializations)
end

function Recovery.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(
        vehicleType,
        "processCultivatorArea",
        Recovery.processCultivatorArea
    )
end
