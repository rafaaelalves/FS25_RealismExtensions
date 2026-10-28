RealismExtensionsTerrainDeformationEngine = RealismExtensionsTerrainDeformationEngine or {}
local Engine = RealismExtensionsTerrainDeformationEngine

Engine.SPEC_NAME = "realismExtensionsTerrainDeformation"
Engine.SPEC_FIELD = "spec_" .. Engine.SPEC_NAME

Engine.DEFAULTS = {
    sampleIntervalMs = 250,
    pathSpacingFactor = 0.45,
    minPathSpacingM = 0.10,
    maxSamplesPerWheelTick = 6,
    loadedContactRefreshIntervalMs = 1000,
    inactiveSpeedKph = 0.10,
    inactiveWheelSpeedMps = 0.05,
    maxBrushDepthM = 0.003,
    -- Temporary physical safety envelope for experimental journal-owned ruts;
    -- depth cap is relative to the VERIFIED original main-heightmap vertex,
    -- not to a speculative 0.20m history cell.
    maxVerifiedNativeRutDepthM = 0.10,
    maxPreExistingHollowM = 0.12,
    brushHardness = 0.35,
    historyCellSizeM = 0.20,
    maxHistoryCells = 50000
}

local function distance2D(x1, z1, x2, z2)
    local dx, dz = x2 - x1, z2 - z1
    return math.sqrt(dx * dx + dz * dz)
end

local function resolveInnerBermSide(vehicle, x, z, travelDirX, travelDirZ)
    if vehicle == nil or vehicle.rootNode == nil
        or getWorldTranslation == nil
        or travelDirX == nil or travelDirZ == nil then
        return nil
    end

    local ok, vx, _, vz = pcall(getWorldTranslation, vehicle.rootNode)
    if not ok or type(vx) ~= "number" or type(vz) ~= "number" then
        return nil
    end

    local toCenterX, toCenterZ = vx - x, vz - z
    local leftX, leftZ = -travelDirZ, travelDirX
    local dot = toCenterX * leftX + toCenterZ * leftZ
    if math.abs(dot) < 0.01 then return nil end

    -- +1 is the berm on the travel-left side, -1 travel-right.
    return dot > 0 and 1 or -1
end

local function copyHistoryForAppliedDepth(response, previousDepth, appliedDepth, previousHistory, preDeformReferenceY)
    local h = {}
    for k, v in pairs(response.nextHistory or {}) do h[k] = v end
    h.rutDepthM = math.max(previousDepth or 0, (previousDepth or 0) + appliedDepth)

    -- Any fresh wheel interaction makes this terrain debt new again for
    -- event-driven neighbor/municipal maintenance. The counter advances only
    -- on PERIOD_CHANGED and is persisted with SpatialHistory.
    h.maintenanceAgePeriods = 0

    -- EXPERIMENTAL / OBSERVATION ONLY. Capture an actual pre-write terrain
    -- height for newly formed RE ruts. This value MUST NOT command geometry
    -- until native brush effects, overlap and persistence have been validated.
    local previousReference = previousHistory ~= nil
        and tonumber(previousHistory.preDeformHeightM) or nil
    if previousReference ~= nil then
        h.preDeformHeightM = previousReference
    elseif (previousDepth or 0) <= 0 and type(preDeformReferenceY) == "number"
        and preDeformReferenceY == preDeformReferenceY
        and math.abs(preDeformReferenceY) < math.huge then
        h.preDeformHeightM = preDeformReferenceY
    end
    return h
end

local function loadedContactGuardEnabled()
    return RealismExtensionsLoadedContactRegistry ~= nil
        and RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainRecovery == true
end

local function diagnosticsEnabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.diagnostics ~= nil
        and RealismExtensionsConfig.diagnostics.verbose == true
end

-- A few critical ownership counters stay cheap and available when the
-- high-volume five-second research mode is OFF.
local HEALTH_COUNTERS={
    brushesAccepted=true,
    geometryJournalDeferred=true,
    geometryJournalConfirmed=true,
    geometryJournalNoLowering=true,
    geometryJournalConfirmedDepthM=true,
    geometryJournalFailClosed=true,
    geometryJournalFailed=true,
    nativeRutGuardBlocked=true,
    nativeRutGuardUnavailable=true,
    nativeRutGuardCap=true,
    nativeRutGuardOldHollow=true,
    nativeRutGuardUntrusted=true,
    nativeMeasuredLowerEvents=true,
    nativeMeasuredLowerMaxSumM=true,
    nativeMeasuredRequestedSumM=true,
    nativeMeasuredExcessEvents=true,
    trialReadOnlyWheelSamples=true,
    freezeContextSamples=true
}
local function diagCount(name, delta)
    if not diagnosticsEnabled() and HEALTH_COUNTERS[name]~=true then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    runtime.stats[name] = (tonumber(runtime.stats[name]) or 0) + (delta or 1)
end

local function diagMax(name, value)
    if not diagnosticsEnabled() or type(value) ~= "number" then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    runtime.stats[name] = math.max(tonumber(runtime.stats[name]) or 0, value)
end

local function diagSet(name, value)
    if not diagnosticsEnabled() or type(value) ~= "number" then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    runtime.stats[name] = value
end

local function diagMin(name, value)
    if not diagnosticsEnabled() or type(value) ~= "number" then return end
    local runtime = RealismExtensionsTerrainRuntime
    if runtime == nil then return end
    runtime.stats = runtime.stats or {}
    local current = tonumber(runtime.stats[name])
    runtime.stats[name] = current == nil and value or math.min(current, value)
end

-- Trial-only, read-only stage evidence. The patch distance and counters
-- live in GeometryProbe; production rut behavior is untouched.
local function trialStage(stage,x,z)
    local trial=RealismExtensionsTerrainControlledWriteTrial
    if trial==nil or not trial.enabled() then return end
    local probe=RealismExtensionsTerrainGeometryProbe
    if probe~=nil and type(probe.observeWheelContact)=="function" then
        probe.observeWheelContact(x,z,stage)
    end
end

function Engine.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Wheels, specializations)
end

function Engine.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", Engine)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", Engine)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", Engine)
end

function Engine:onLoad(savegame)
    local wheels = nil
    if self.getWheels ~= nil then
        wheels = self:getWheels()
    elseif self.spec_wheels ~= nil then
        wheels = self.spec_wheels.wheels
    end

    self[Engine.SPEC_FIELD] = {
        wheels = wheels or {},
        states = setmetatable({}, { __mode = "k" }),
        axleContacts = {},
        diagnosticEpoch = 0
    }

    diagCount("vehiclesLoaded", 1)
    local wheelCount = 0
    for _ in pairs(wheels or {}) do wheelCount = wheelCount + 1 end
    diagCount("wheelsAttached", wheelCount)
end

local function getCheapVehicleSpeedKph(vehicle)
    if vehicle ~= nil and type(vehicle.getLastSpeed) == "function" then
        local ok, value = pcall(vehicle.getLastSpeed, vehicle)
        if ok and type(value) == "number" then return math.abs(value) end
    end
    return 0
end

local function getCheapWheelSpeedMps(wheel, physics)
    if physics ~= nil and type(physics.mrLastWheelSpeed) == "number" then
        return math.abs(physics.mrLastWheelSpeed)
    end

    if getWheelShapeAxleSpeed ~= nil
        and wheel ~= nil
        and wheel.node ~= nil
        and physics ~= nil
        and physics.wheelShape ~= nil then
        local ok, axleSpeed = pcall(getWheelShapeAxleSpeed, wheel.node, physics.wheelShape)
        if ok and type(axleSpeed) == "number" then
            local radius = tonumber(physics.radius) or tonumber(physics.radiusOriginal)
            if radius ~= nil and radius > 0 then
                return math.abs(axleSpeed * radius)
            end
        end
    end

    return 0
end

local function cheapActivityGate(vehicle, wheel, physics, state)
    local bodySpeed = getCheapVehicleSpeedKph(vehicle)
    local wheelSpeed = getCheapWheelSpeedMps(wheel, physics)

    if state.hadContext ~= true then
        return true, bodySpeed, wheelSpeed
    end

    return bodySpeed >= Engine.DEFAULTS.inactiveSpeedKph
        or wheelSpeed >= Engine.DEFAULTS.inactiveWheelSpeedMps,
        bodySpeed,
        wheelSpeed
end

local function shouldSample(state, dt, intervalMs)
    state.elapsedMs = (state.elapsedMs or intervalMs) + math.max(0, tonumber(dt) or 0)
    if state.elapsedMs < intervalMs then return false, 0 end
    local elapsed = state.elapsedMs
    state.elapsedMs = 0
    return true, elapsed
end

local function sampleTerrainHeight(x, z)
    local mission = g_currentMission
    local terrain = mission ~= nil and mission.terrainRootNode or g_terrainNode
    if terrain == nil or terrain == 0 or getTerrainHeightAtWorldPos == nil then
        return nil
    end
    local ok, y = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and type(y) == "number" then return y end
    return nil
end

function Engine.computeCentralTerrainCrest(left, right, heightFn)
    if type(left) ~= "table" or type(right) ~= "table" then return nil end
    if type(left.x) ~= "number" or type(left.z) ~= "number"
        or type(right.x) ~= "number" or type(right.z) ~= "number" then
        return nil
    end

    heightFn = heightFn or sampleTerrainHeight
    local leftY = heightFn(left.x, left.z)
    local rightY = heightFn(right.x, right.z)
    local centerX = (left.x + right.x) * 0.5
    local centerZ = (left.z + right.z) * 0.5
    local centerY = heightFn(centerX, centerZ)
    if type(leftY) ~= "number" or type(rightY) ~= "number"
        or type(centerY) ~= "number" then
        return nil
    end

    local expectedPlaneY = (leftY + rightY) * 0.5
    local dx, dz = right.x - left.x, right.z - left.z
    return {
        crestHeightM = centerY - expectedPlaneY,
        axleSpanM = math.sqrt(dx * dx + dz * dz),
        centerX = centerX,
        centerZ = centerZ,
        centerTerrainY = centerY,
        leftTerrainY = leftY,
        rightTerrainY = rightY
    }
end

function Engine.updateAxleCrestDiagnostics(vehicle, physics, context)
    if not diagnosticsEnabled()
        or RealismExtensionsConfig == nil
        or RealismExtensionsConfig.diagnostics == nil
        or RealismExtensionsConfig.diagnostics.expensiveGeometry ~= true
        or vehicle == nil
        or physics == nil or context == nil then return end

    local localX = tonumber(physics.positionX)
    local localZ = tonumber(physics.positionZ)
    if localX == nil or localZ == nil
        or type(context.worldX) ~= "number"
        or type(context.worldZ) ~= "number" then
        return
    end

    -- Bucket left/right contacts by axle longitudinal position. 0.25 m is
    -- narrow enough to keep distinct axles apart while tolerating modded wheel
    -- placement noise, matching the grouping precedent from SoilCompaction.
    local axleKey = math.floor(localZ * 4 + 0.5)
    local spec = vehicle[Engine.SPEC_FIELD]
    if spec == nil then return end
    spec.axleContacts = spec.axleContacts or {}

    local axle = spec.axleContacts[axleKey]
    if axle == nil or axle.epoch ~= spec.diagnosticEpoch then
        axle = { epoch = spec.diagnosticEpoch }
        spec.axleContacts[axleKey] = axle
    end

    local side = localX < 0 and "left" or (localX > 0 and "right" or nil)
    if side == nil then return end

    axle[side] = {
        x = context.worldX,
        z = context.worldZ,
        supportWidthM = tonumber(context.supportWidthM),
        baseTireWidthM = tonumber(context.baseTireWidthM)
    }

    if axle.left == nil or axle.right == nil or axle.measured == true then return end
    axle.measured = true

    local result = Engine.computeCentralTerrainCrest(axle.left, axle.right)
    if result == nil then return end

    diagCount("axleCrestSamples", 1)
    diagMax("maxAxleSpanM", result.axleSpanM)
    diagMax("maxCentralTerrainCrestM", result.crestHeightM)
    if result.crestHeightM >= 0.05 then
        diagCount("centralCrestOver5cm", 1)
    end
    if result.crestHeightM >= 0.10 then
        diagCount("centralCrestOver10cm", 1)
    end
    if result.crestHeightM >= 0.15 then
        diagCount("centralCrestOver15cm", 1)
    end
end

function Engine.processSample(
    vehicle,
    wheel,
    wheelState,
    context,
    footprint,
    x,
    z,
    dtMs,
    stationaryWheelspin,
    travelDirX,
    travelDirZ,
    actor
)
    diagCount("samplesProcessed", 1)

    local nowMs = g_currentMission ~= nil and g_currentMission.time or 0

    if actor ~= nil then
        diagCount("actorSamples_" .. tostring(actor.kind or "UNKNOWN"), 1)
        local actorPolicy = RealismExtensionsTerrainActorPolicy
        local reason = actorPolicy ~= nil
            and type(actorPolicy.getSuppressionReason) == "function"
            and actorPolicy.getSuppressionReason(actor, stationaryWheelspin)
            or nil
        if reason ~= nil then
            diagCount("actorSuppressed_" .. tostring(reason), 1)
            trialStage("actorBlocked",x,z)
            return false
        end
    end

    -- A working soil-repair implement owns the persistent terrain state for
    -- the complete tractor/implement combination. Keep wheel context,
    -- footprint, tracks and upstream physics alive; suppress only RE's rut
    -- history + TerrainDeformation writes while real cultivation is occurring.
    if RealismExtensionsTerrainRecovery ~= nil
        and type(RealismExtensionsTerrainRecovery.isRutGenerationSuppressed) == "function"
        and RealismExtensionsTerrainRecovery.isRutGenerationSuppressed(vehicle, nowMs) then
        diagCount("activeCultivatorRutSkips", 1)
        trialStage("workBlocked",x,z)
        return false
    end

    if RealismExtensionsTerrainRecovery ~= nil
        and type(RealismExtensionsTerrainRecovery.isRecentlyCultivated) == "function"
        and RealismExtensionsTerrainRecovery.isRecentlyCultivated(x,z,nowMs) then
        diagCount("cultivationProtectionSkips",1)
        trialStage("recentWorkBlocked",x,z)
        return false
    end

    local historyStore = RealismExtensionsTerrainRuntime.history
    local writer = RealismExtensionsTerrainRuntime.writer

    local history = historyStore:get(x, z)
    local previousDepth = history ~= nil and tonumber(history.rutDepthM) or 0

    -- Observability only: estimate how much currently observed instantaneous
    -- sink is already represented by RE's logical persistent-rut history.
    -- This is NOT a Mud radius handoff and must not be used as one until the
    -- actual terrain geometry/provider contract is proven in runtime.
    local observedSinkProxy = math.max(0, tonumber(context.sinkDepthM) or 0)
    local representedSinkProxy = math.min(observedSinkProxy, previousDepth)
    local residualSinkProxy = math.max(0, observedSinkProxy - representedSinkProxy)
    diagSet("lastSinkObservedProxyM", observedSinkProxy)
    diagSet("lastSinkRepresentedByHistoryProxyM", representedSinkProxy)
    diagSet("lastSinkResidualProxyM", residualSinkProxy)
    diagMax("maxSinkRepresentedByHistoryProxyM", representedSinkProxy)
    diagMax("maxSinkResidualProxyM", residualSinkProxy)

    local surface = RealismExtensionsTerrainSurfaceResponse ~= nil
        and RealismExtensionsTerrainSurfaceResponse.resolve(context, x, z) or nil
    if surface == nil or surface.available ~= true then
        diagCount("surfaceRejects", 1)
        diagCount("surfaceSeen_UNKNOWN", 1)
        trialStage("surfaceUnavailable",x,z)
        return false
    end
    diagCount("surfaceSeen_" .. tostring(surface.category or "UNKNOWN"), 1)
    if (tonumber(surface.deformability01) or 0) <= 0 then
        diagCount("surfaceRejects", 1)
        diagCount("surfaceBlocked_" .. tostring(surface.category or "UNKNOWN"), 1)
        trialStage("surfaceBlocked",x,z)
        return false
    end
    diagCount("surfaceAccepted", 1)
    diagCount("surfaceDeformable_" .. tostring(surface.category or "UNKNOWN"), 1)

    local modelOptions = {
        absoluteMaxStaticRutDepthM = surface.maxStaticRutDepthM,
        absoluteMaxSlipRutDepthM = surface.maxSlipRutDepthM,
        plasticYieldEnabled = RealismExtensionsConfig ~= nil
            and RealismExtensionsConfig.modules ~= nil
            and RealismExtensionsConfig.modules.TerrainPlasticYield == true,
        surfaceCategory = surface.category
    }
    local actorPolicy = RealismExtensionsTerrainActorPolicy
    local actorOverrides = actorPolicy ~= nil
        and type(actorPolicy.getModelOverrides) == "function"
        and actorPolicy.getModelOverrides(actor) or nil
    for key, value in pairs(actorOverrides or {}) do
        modelOptions[key] = value
    end

    local response = RealismExtensionsTerrainResponseModel.compute(
        context,
        footprint,
        history,
        dtMs,
        modelOptions
    )
    if response == nil or response.available ~= true then
        diagCount("responseRejects", 1)
        trialStage("responseUnavailable",x,z)
        return false
    end

    if response.plasticYield01 ~= nil then
        diagMax("plasticYieldMax01", response.plasticYield01)
        diagMax("plasticDemandBearingRatioMax",
            tonumber(response.plasticDemandBearingRatio) or 0)
        if response.plasticYield01 <= 0 and previousDepth <= 0 then
            -- No permanent mechanical yield: Mud may sink transiently and
            -- SoilCompaction may densify, but RE must not allocate an empty
            -- SpatialHistory tombstone or a native heightmap write.
            diagCount("plasticSupportedSamples", 1)
            trialStage("plasticNoYield",x,z)
            return false
        end
        if response.plasticYield01 > 0 then
            diagCount("plasticYieldSamples", 1)
        end
    end

    diagMax("maxRutDepthM", tonumber(response.rutDepthM) or 0)
    diagMax("maxRutCapacityM", tonumber(response.rutCapacityM) or 0)
    diagMax("maxStaticRutCapacityM", tonumber(response.staticRutCapacityM) or 0)
    diagMax("maxSlipRutCapacityM", tonumber(response.slipRutCapacityM) or 0)
    diagMax("maxSlipSinkageMultiplier", tonumber(response.slipSinkageMultiplier) or 0)
    diagMax("maxObservedSinkDepthM", tonumber(response.observedSinkDepthM) or 0)
    diagMax("maxPersistentSinkDepthM", tonumber(response.persistentSinkDepthM) or 0)
    diagMax("maxSinkPlasticTransfer", tonumber(response.sinkPlasticTransfer01) or 0)

    -- Keep one coherent sample snapshot alongside maxima. This avoids
    -- comparing peak wetness from one moment to peak rut from another.
    diagSet("lastPlasticWetness01", tonumber(response.physicalGroundWetness01) or 0)
    diagSet("lastPlasticSlip01", tonumber(response.longitudinalSlip01) or 0)
    diagSet("lastObservedSinkDepthM", tonumber(response.observedSinkDepthM) or 0)
    diagSet("lastSinkPlasticTransfer01", tonumber(response.sinkPlasticTransfer01) or 0)
    diagSet("lastPersistentSinkDepthM", tonumber(response.persistentSinkDepthM) or 0)
    diagSet("lastStaticRutCapacityM", tonumber(response.staticRutCapacityM) or 0)
    diagSet("lastSlipRutCapacityM", tonumber(response.slipRutCapacityM) or 0)
    diagSet("lastRutDepthM", tonumber(response.rutDepthM) or 0)

    local desiredDelta = math.max(0, tonumber(response.rutDepthM) - previousDepth)
    diagCount("requestedDepthM", desiredDelta)
    local appliedDepth = math.min(
        desiredDelta,
        Engine.DEFAULTS.maxBrushDepthM
    )
    appliedDepth = appliedDepth
        * math.max(0, math.min(1, tonumber(surface.deformability01) or 1))

    local trial=RealismExtensionsTerrainControlledWriteTrial
    trialStage("eligible",x,z)
    if trial~=nil and trial.enabled() and not trial.isArmed() then
        -- Read-only A/B baseline: compute wheel state, demand, and ground
        -- context, but never commit SpatialHistory or request native edits.
        diagCount("trialReadOnlyWheelSamples",1)
        return false
    end
    if trial~=nil and trial.enabled()
        and (type(trial.isWithinMarkedRegion)~="function"
            or not trial.isWithinMarkedRegion(x,z)) then
        -- A fully authorized test still MUST NOT commit off-site logical
        -- history, open a journal transaction or enqueue any native edit.
        trialStage("outsideTrial",x,z)
        return false
    end

    if appliedDepth <= writer.options.minDepthM then
        if trial~=nil and trial.enabled() then
            -- Test-only: tiny requests are not permission to mutate RE's
            -- SpatialHistory outside the one native trial job.
            trialStage("tooShallow",x,z)
            return false
        end
        -- Preserve shear/pass history even when the geometric delta is too
        -- small to justify a brush.
        historyStore:commit(x, z, copyHistoryForAppliedDepth(response, previousDepth, 0, history))
        diagCount("belowBrushThreshold", 1)
        return false
    end

    local transport = nil
    if travelDirX ~= nil and travelDirZ ~= nil then
        transport = {
            travelDirX = travelDirX,
            travelDirZ = travelDirZ,
            wetness01 = tonumber(context.physicalGroundWetness) or 0,
            deformability01 = tonumber(surface.deformability01) or 0,
            longitudinalSlip = tonumber(context.longitudinalSlip) or 0,
            lateralSlip = tonumber(context.lateralSlip) or 0,
            innerBermSide = resolveInnerBermSide(
                vehicle, x, z, travelDirX, travelDirZ
            )
        }
    end

    -- First-touch reference is taken from the snapped SpatialHistory cell,
    -- NOT from the arbitrary wheel/brush centre. Later brushes preserve the
    -- first value rather than measuring terrain that RE has already lowered.
    -- Never retroactively "recover" an existing legacy rut from current height.
    local preDeformReferenceY = nil
    if previousDepth <= 0
        and (history == nil or history.preDeformHeightM == nil)
        and type(historyStore.getCellCoordinates) == "function" then
        local ix, iz = historyStore:getCellCoordinates(x, z)
        local unit = tonumber(historyStore.cellSizeM) or 0.20
        preDeformReferenceY = sampleTerrainHeight(ix * unit, iz * unit)
        if preDeformReferenceY == nil then
            diagCount("preDeformReferenceUnavailable", 1)
        end
    end

    local journal = RealismExtensionsTerrainRuntime.geometryJournal
    local causalRequired = RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainCausalRecovery == true
    -- Experimental fail-closed protection: if a previous native callback
    -- observed a severe excess, stop new wheel writes for this session.
    -- Mud transient physics and causal recovery remain active.
    if causalRequired and RealismExtensionsTerrainRuntime.nativeDamageQuarantined then
        diagCount("nativeAmplitudeQuarantineSkips",1)
        return false
    end
    if causalRequired and (journal == nil or journal.unitM == nil) then
        diagCount("geometryJournalFailClosed", 1)
        return false
    end
    local journalToken = nil
    local pendingReason = nil
    -- Optional coarse queue-concurrency correlation, never proof that
    -- another job changed THIS terrain patch. Direct apply() is invisible.
    local externalQueueBaseline=nil
    local externalDirectBaseline=nil
    local overlapQueueBaseline=nil
    local overlapDirectBaseline=nil
    local brushRadius = math.max(0.10, response.rutWidthM * 0.5)
    if journal ~= nil and causalRequired then
        -- Independent native-grid safety ceiling: once excavation exceeds
        -- the confirmed physical budget (or enters an existing deep hollow),
        -- suppress further RE writes. Mud can still sink temporarily.
        local remaining,reason=journal:getLoweringBudget(
            x,z,brushRadius,
            Engine.DEFAULTS.maxVerifiedNativeRutDepthM,
            Engine.DEFAULTS.maxPreExistingHollowM
        )
        if remaining==nil or remaining<=0 then
            diagCount("nativeRutGuardBlocked",1)
            if remaining==nil then
                diagCount("nativeRutGuardUnavailable",1)
            elseif reason=="DEPTH_CAP" then
                diagCount("nativeRutGuardCap",1)
            elseif reason=="DEEP_EXISTING_HOLLOW" then
                diagCount("nativeRutGuardOldHollow",1)
            else
                diagCount("nativeRutGuardUntrusted",1)
            end
            trialStage(reason=="UNTRUSTED_EDIT" and "budgetUntrusted"
                or "budgetOther",x,z)
            return false
        end
        appliedDepth=math.min(appliedDepth,remaining)
        if appliedDepth<=writer.options.minDepthM then
            diagCount("nativeRutGuardCap",1)
            trialStage("tooShallow",x,z)
            return false
        end
    end
    if journal ~= nil then
        -- Explicit per-native-vertex exclusion avoids claiming concurrent
        -- lower writes as independent geometry. Retry on next wheel sample.
        local logicalKey = historyStore:getKey(x, z)
        journalToken, pendingReason = journal:begin(
            logicalKey, x, z, brushRadius
        )
        if journalToken == nil then
            diagCount("geometryJournalDeferred", 1)
            trialStage("journalDeferred",x,z)
            return false
        end
    end

    local trialTicket=nil
    if trial~=nil and trial.enabled() then
        trialTicket=trial.tryReserve(x,z)
        if trialTicket~=nil then trialStage("ticketReserved",x,z) end
        if trialTicket==nil then
            if journalToken~=nil then journal:complete(journalToken,false) end
            return false
        end
    end
    local accepted = writer:enqueue({
        trialTicket=trialTicket,
        x = x,
        z = z,
        depthM = appliedDepth,
        radiusM = brushRadius,
        hardness = Engine.DEFAULTS.brushHardness,
        massTransport = transport,
        -- A journal token is captured at ENQUEUE, and therefore needs a
        -- second, just-in-time native-vertex check when TerrainWriter submits
        -- it. A changed patch must never be silently attributed to RE.
        beforeSubmit = journalToken ~= nil and function()
            if RealismExtensionsTerrainRuntime.nativeDamageQuarantined then
                diagCount("nativeAmplitudeQuarantineSkips",1)
                return false,"NATIVE_AMPLITUDE_QUARANTINE"
            end
            local okay,reason=journal:validateBeforeSubmit(journalToken)
            if not okay then
                diagCount("geometryJournalSubmitRejected",1)
                if reason=="QUEUED_GEOMETRY_DRIFT" then
                    diagCount("geometryJournalQueueDriftRejected",1)
                end
            end
            return okay,reason
        end or nil,
        -- Only a submitted RE native job can delimit the observation.
        -- Submission is notified before the actual GIANTS queue call.
        onSubmitted = function()
            local probe=RealismExtensionsTerrainNativeQueueProbe
            if probe~=nil and probe.enabled==true then
                externalQueueBaseline=
                    (probe.stats or {}).externalDuringREPending or 0
                local spatial=RealismExtensionsTerrainNativeSpatialProbe
                if spatial~=nil and spatial.owner~=nil then
                    externalDirectBaseline=
                        (spatial.stats or {}).directDuringREPending or 0
                    overlapQueueBaseline=
                        (spatial.stats or {}).spatialOverlapQueue or 0
                    overlapDirectBaseline=
                        (spatial.stats or {}).spatialOverlapDirect or 0
                end
            end
        end,
        -- Callback-bearing writes MUST stay uncoalesced by TerrainWriter.
        onApplied = journalToken ~= nil and function(state,deltaY,beforeY,afterY,callbackVolume)
            if trialTicket~=nil then
                trial.callback(trialTicket,state,callbackVolume)
            end
            local otherQueueWhilePending=nil
            local probe=RealismExtensionsTerrainNativeQueueProbe
            if externalQueueBaseline~=nil and probe~=nil then
                otherQueueWhilePending=math.max(0,
                    ((probe.stats or {}).externalDuringREPending or 0)
                    -externalQueueBaseline)
            end
            local otherDirectWhilePending=nil
            local queueEnvelopeOverlaps=nil
            local directEnvelopeOverlaps=nil
            local spatial=RealismExtensionsTerrainNativeSpatialProbe
            if spatial~=nil and spatial.owner~=nil
                and externalDirectBaseline~=nil then
                local ds=spatial.stats or {}
                otherDirectWhilePending=math.max(0,
                    (ds.directDuringREPending or 0)-externalDirectBaseline)
                queueEnvelopeOverlaps=math.max(0,
                    (ds.spatialOverlapQueue or 0)-overlapQueueBaseline)
                directEnvelopeOverlaps=math.max(0,
                    (ds.spatialOverlapDirect or 0)-overlapDirectBaseline)
            end
            local success = state ~= false
                and (state == nil or TerrainDeformation == nil
                    or TerrainDeformation.STATE_SUCCESS == nil
                    or state == TerrainDeformation.STATE_SUCCESS)
            local physical = journal:complete(journalToken, success)
            if physical ~= nil and physical.success
                and physical.loweredVertices > 0 then
                -- Maintain a physical debt consistent with the REAL native
                -- height change rather than the requested 2-3mm command.
                -- Before this correction a 148mm native rut received only
                -- 2.4mm of SpatialHistory debt, making passive NPC/public
                -- maintenance wrongly skip even a deep, journal-owned rut.
                -- This is a coarse 0.20m proxy: the immutable per-native-
                -- vertex GeometryJournal remains the recovery authority.
                local observed=math.max(0,physical.maxLowerM)
                -- GIANTS callback displacedVolume is a second, independent
                -- outcome signal. It is NOT a per-vertex depth measurement;
                -- a soft brush also does not excavate a full cylinder.
                local nominalCylinderM3=math.pi*brushRadius*brushRadius*appliedDepth
                local nativeVolumeM3=type(callbackVolume)=="number"
                    and callbackVolume==callbackVolume
                    and callbackVolume>=0 and callbackVolume<math.huge
                    and callbackVolume or nil
                local nativeVolumeLabel=nativeVolumeM3~=nil
                    and string.format("%.7f",nativeVolumeM3) or "missing"
                local volumeRatioLabel=nativeVolumeM3~=nil
                    and nominalCylinderM3>0
                    and string.format("%.2f",nativeVolumeM3/nominalCylinderM3)
                    or "missing"
                -- Detection must PRECEDE any physical debt commit. The
                -- callback interval is not globally exclusive to RE; a
                -- concurrent native writer or a nonlinear GIANTS brush can
                -- make the observed delta larger than this request. In that
                -- case do not grant RE authority to restore that terrain.
                local excess=observed>appliedDepth+0.002
                local unexpectedRise=(physical.raisedVertices or 0)>0
                local untrustedOutcome=excess or unexpectedRise
                if untrustedOutcome then
                    if type(journal.invalidateCompletedFootprint)=="function" then
                        journal:invalidateCompletedFootprint(
                            journalToken,
                            unexpectedRise and "UNEXPECTED_LOWER_RISE"
                                or "EXCESS_NATIVE_LOWERING")
                    end
                    diagCount("geometryJournalOwnershipQuarantined",1)
                end
                if observed > 0.00005 and not untrustedOutcome then
                    local current = historyStore:get(x, z)
                    local currentDepth = current ~= nil
                        and tonumber(current.rutDepthM) or previousDepth
                    historyStore:commit(
                        x,
                        z,
                        copyHistoryForAppliedDepth(
                            response, currentDepth, observed, current,
                            preDeformReferenceY
                        )
                    )
                    diagCount("geometryJournalConfirmedDepthM", observed)
                end
                if not untrustedOutcome then
                    diagCount("geometryJournalConfirmed", 1)
                end
                -- Geometry outcome is the engine result, not the 3mm request.
                -- Compare the SAME brush's pre-/post-heightmap delta with
                -- its submitted amount to catch native amplification.
                diagCount("nativeMeasuredLowerEvents",1)
                diagCount("nativeMeasuredLowerMaxSumM",physical.maxLowerM)
                diagCount("nativeMeasuredRequestedSumM",appliedDepth)
                if excess then
                    diagCount("nativeMeasuredExcessEvents",1)
                    local rt=RealismExtensionsTerrainRuntime
                    -- One 25mm+ response to a 2-3mm request is already an
                    -- unacceptable risk for a live game save. Do not allow
                    -- another RE native lowering until the actuator has been
                    -- studied; this does not erase or regrade existing soil.
                    if not rt.nativeDamageQuarantined
                        and physical.maxLowerM>math.max(0.025,appliedDepth*8) then
                        rt.nativeDamageQuarantined=true
                        diagCount("nativeAmplitudeQuarantineTriggers",1)
                        if RealismExtensionsDiagnostics~=nil
                            and type(RealismExtensionsDiagnostics.info)=="function" then
                            RealismExtensionsDiagnostics.info(string.format(
                                "TerrainNativeQuarantine | x=%.2f z=%.2f request=%.4fm observed=%.4fm reason=EXCESS_NATIVE_LOWERING nativeCallbackVolumeM3=%s nominalCylinderM3=%.7f volumeRatio=%s otherQueuedWhilePending=%s otherDirectWhilePending=%s overlappingQueueBrushes=%s overlappingDirectBrushes=%s (brush overlap is NOT physical height attribution)",
                                x,z,appliedDepth,physical.maxLowerM,
                                nativeVolumeLabel,nominalCylinderM3,volumeRatioLabel,
                                otherQueueWhilePending~=nil
                                    and tostring(otherQueueWhilePending)
                                    or "unobserved",
                                otherDirectWhilePending~=nil
                                    and tostring(otherDirectWhilePending)
                                    or "unobserved",
                                queueEnvelopeOverlaps~=nil
                                    and tostring(queueEnvelopeOverlaps)
                                    or "unobserved",
                                directEnvelopeOverlaps~=nil
                                    and tostring(directEnvelopeOverlaps)
                                    or "unobserved"))
                        end
                    end
                    rt.nativeExcessExamples=(rt.nativeExcessExamples or 0)+1
                    if rt.nativeExcessExamples<=6
                        and RealismExtensionsDiagnostics~=nil
                        and type(RealismExtensionsDiagnostics.info)=="function" then
                        RealismExtensionsDiagnostics.info(string.format(
                            "TerrainNativeDelta | x=%.2f z=%.2f requested=%.4fm actualMax=%.4fm samples=%d moved=%d wetness=%.3f frozen=%s pressurePa=%.0f slip=%.3f bearingRatio=%.3f vertex=%s beforeY=%.6f afterY=%.6f nativeCallbackVolumeM3=%s nominalCylinderM3=%.7f volumeRatio=%s otherQueuedWhilePending=%s otherDirectWhilePending=%s overlappingQueueBrushes=%s overlappingDirectBrushes=%s",
                            x,z,appliedDepth,physical.maxLowerM,
                            physical.sampledVertices or 0,physical.loweredVertices or 0,
                            tonumber(context.physicalGroundWetness) or -1,
                            tostring(context.hardFrozen==true),
                            tonumber(footprint.groundPressurePa) or 0,
                            tonumber(context.longitudinalSlip) or 0,
                            tonumber(response.plasticDemandBearingRatio) or -1,
                            tostring(physical.maxLowerPoint ~= nil
                                and physical.maxLowerPoint.key or "none"),
                            tonumber(physical.maxLowerPoint ~= nil
                                and physical.maxLowerPoint.beforeY) or 0,
                            tonumber(physical.maxLowerPoint ~= nil
                                and physical.maxLowerPoint.afterY) or 0,
                            nativeVolumeLabel,nominalCylinderM3,volumeRatioLabel,
                            otherQueueWhilePending~=nil
                                and tostring(otherQueueWhilePending)
                                or "unobserved",
                            otherDirectWhilePending~=nil
                                and tostring(otherDirectWhilePending)
                                or "unobserved",
                            queueEnvelopeOverlaps~=nil
                                and tostring(queueEnvelopeOverlaps)
                                or "unobserved",
                            directEnvelopeOverlaps~=nil
                                and tostring(directEnvelopeOverlaps)
                                or "unobserved"
                        ))
                    end
                end
            elseif physical ~= nil and physical.success then
                diagCount("geometryJournalNoLowering", 1)
            else
                diagCount("geometryJournalFailed", 1)
            end
        end or nil
    })

    if accepted then
        if journalToken == nil then
            -- Legacy experimental mode only: a queued request counts as debt.
            historyStore:commit(
                x,
                z,
                copyHistoryForAppliedDepth(
                    response, previousDepth, appliedDepth, history,
                    preDeformReferenceY
                )
            )
            if preDeformReferenceY ~= nil then
                diagCount("preDeformReferenceCaptured", 1)
            elseif history ~= nil and history.preDeformHeightM ~= nil then
                diagCount("preDeformReferencePreserved", 1)
            else
                diagCount("preDeformReferenceLegacyOrUnavailable", 1)
            end
        end
        -- Journal mode also owns an accepted request, but NOT physical debt.
        -- Its native callback alone commits that debt when height lowered.
        diagCount("brushesAccepted", 1)
        diagCount("appliedDepthM", appliedDepth)
        if actor ~= nil then
            local kind = tostring(actor.kind or "UNKNOWN")
            diagCount("actorBrushes_" .. kind, 1)
            diagCount("actorAppliedDepth_" .. kind, appliedDepth)
        end
        local workApi = RealismExtensionsTerrainWorkContext
        local vehicleLabel = workApi ~= nil
            and workApi.getVehicleLabel(vehicle) or "vehicle"
        local rootVehicle = workApi ~= nil
            and workApi.getCombinationRoot(vehicle) or vehicle
        local rootLabel = workApi ~= nil
            and workApi.getVehicleLabel(rootVehicle) or vehicleLabel
        diagCount("rutWriter_" .. vehicleLabel, 1)
        diagCount("rutWriterRoot_" .. rootLabel, 1)
        -- Bounded causal samples pair spatial rut writes with R1 TARGET's
        -- fixed-reference samples. These observations NEVER gate rut writing.
        local diag = RealismExtensionsConfig ~= nil
            and RealismExtensionsConfig.diagnostics or nil
        if diag ~= nil and diag.verbose == true
            and diag.rutCausalSamples ~= false
            and (tonumber(response.rutDepthM) or 0) >= 0.04 then
            local stats = RealismExtensionsTerrainRuntime.stats
            stats.rutCausalSamplesByVehicle =
                stats.rutCausalSamplesByVehicle or {}
            local taken = stats.rutCausalSamplesByVehicle[vehicleLabel] or 0
            local total = tonumber(stats.rutCausalSamplesCount) or 0
            if taken < 3 and total < 18 then
                stats.rutCausalSamplesByVehicle[vehicleLabel] = taken + 1
                stats.rutCausalSamplesCount = total + 1
                local height = type(writer.sampleHeightAt) == "function"
                    and writer:sampleHeightAt(x, z) or nil
                if RealismExtensionsDiagnostics ~= nil
                    and type(RealismExtensionsDiagnostics.verbose) == "function" then
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainRutSample | writer=%s root=%s actor=%s x=%.2f z=%.2f height=%s surface=%s wet=%.3f slip=%.3f sink=%.3f transfer=%.3f plasticYield=%.3f loadN=%.0f pressurePa=%.0f oldHistory=%.3f newModel=%.3f acceptedDelta=%.4f wheelspin=%s",
                        tostring(vehicleLabel), tostring(rootLabel),
                        tostring(actor ~= nil and actor.kind or "UNKNOWN"),
                        x, z, tostring(height),
                        tostring(surface.category or "UNKNOWN"),
                        tonumber(context.physicalGroundWetness) or 0,
                        tonumber(context.longitudinalSlip) or 0,
                        tonumber(context.sinkDepthM) or 0,
                        tonumber(response.sinkPlasticTransfer01) or 0,
                        tonumber(response.plasticYield01) or -1,
                        tonumber(footprint.wheelLoadN) or 0,
                        tonumber(footprint.groundPressurePa) or 0,
                        previousDepth, tonumber(response.rutDepthM) or 0,
                        appliedDepth, tostring(stationaryWheelspin == true)
                    ))
                end
            end
        end
        diagCount("surfaceBrushes_" .. tostring(surface.category or "UNKNOWN"), 1)
        diagCount("surfaceAppliedDepth_" .. tostring(surface.category or "UNKNOWN"), appliedDepth)
        if stationaryWheelspin == true then
            diagCount("stationaryBrushesAccepted", 1)
            diagCount("stationaryAppliedDepthM", appliedDepth)
            diagMax("stationaryMaxRutDepthM", tonumber(response.rutDepthM) or 0)
            diagMax("stationaryMaxRutCapacityM", tonumber(response.rutCapacityM) or 0)
        end
        return true
    end

    if trialTicket~=nil and trial~=nil then
        trial.abandon(trialTicket)
    end
    if journalToken ~= nil then journal:complete(journalToken, false) end
    diagCount("writerRejects", 1)
    return false
end

function Engine.processWheel(vehicle, wheel, dt)
    if wheel == nil then return end
    diagCount("wheelTicks", 1)
    local physics = wheel.physics
    if physics == nil then return end

    local spec = vehicle[Engine.SPEC_FIELD]
    local state = spec.states[wheel]
    if state == nil then
        state = {
            elapsedMs = Engine.DEFAULTS.sampleIntervalMs,
            loadedContactKnown = false,
            loadedContactRefreshElapsedMs = 0
        }
        spec.states[wheel] = state
    end

    local sample, elapsedMs = shouldSample(
        state,
        dt,
        Engine.DEFAULTS.sampleIntervalMs
    )
    if not sample then return end
    diagCount("sampleTicks", 1)

    local active, bodySpeedKph, wheelSpeedMps =
        cheapActivityGate(vehicle, wheel, physics, state)

    local forcedLoadedContactRefresh = false
    if not active and loadedContactGuardEnabled()
        and state.loadedContactKnown == true then
        state.loadedContactRefreshElapsedMs =
            (state.loadedContactRefreshElapsedMs or 0) + elapsedMs
        if state.loadedContactRefreshElapsedMs
            >= Engine.DEFAULTS.loadedContactRefreshIntervalMs then
            active = true
            forcedLoadedContactRefresh = true
            diagCount("loadedContactRefreshes", 1)
        end
    end

    if not active then
        diagCount("activityGateSkips", 1)
        return
    end

    local stationaryWheelspin =
        bodySpeedKph < Engine.DEFAULTS.inactiveSpeedKph
        and wheelSpeedMps >= Engine.DEFAULTS.inactiveWheelSpeedMps
    if stationaryWheelspin then
        diagCount("stationaryWheelspinCandidates", 1)
    end

    local actor = nil
    if RealismExtensionsTerrainActorPolicy ~= nil
        and type(RealismExtensionsTerrainActorPolicy.classify) == "function" then
        actor = RealismExtensionsTerrainActorPolicy.classify(vehicle)
    end

    diagCount("contextRequests", 1)
    local context = RealismExtensionsState.getWheelContext(vehicle, wheel, {
        speedKph = bodySpeedKph,
        wheelSurfaceSpeedMps = wheelSpeedMps
    })
    if context == nil then
        if RealismExtensionsLoadedContactRegistry ~= nil then
            RealismExtensionsLoadedContactRegistry.remove(wheel)
        end
        state.loadedContactKnown = false
        state.loadedContactRefreshElapsedMs = 0
        diagCount("contextUnavailable", 1)
        state.lastX, state.lastZ = nil, nil
        return
    end
    if context.grounded ~= true then
        if RealismExtensionsLoadedContactRegistry ~= nil then
            RealismExtensionsLoadedContactRegistry.remove(wheel)
        end
        state.loadedContactKnown = false
        state.loadedContactRefreshElapsedMs = 0
        diagCount("notGrounded", 1)
        state.lastX, state.lastZ = nil, nil
        return
    end
    if type(context.worldX) ~= "number" or type(context.worldZ) ~= "number" then
        if RealismExtensionsLoadedContactRegistry ~= nil then
            RealismExtensionsLoadedContactRegistry.remove(wheel)
        end
        state.loadedContactKnown = false
        state.loadedContactRefreshElapsedMs = 0
        diagCount("missingContactPosition", 1)
        state.lastX, state.lastZ = nil, nil
        return
    end

    diagCount("contextAccepted", 1)
    state.hadContext = true
    -- A marked-patch context sample is not a terrain write. It distinguishes
    -- "some wheel moved anywhere" from "a grounded wheel crossed our exact
    -- measurement zone" in the read-only baseline.
    if RealismExtensionsTerrainControlledWriteTrial~=nil
        and RealismExtensionsTerrainControlledWriteTrial.enabled()
        and RealismExtensionsTerrainGeometryProbe~=nil
        and type(RealismExtensionsTerrainGeometryProbe.observeWheelContact)
            =="function" then
        RealismExtensionsTerrainGeometryProbe.observeWheelContact(
            context.worldX,context.worldZ,"context")
    end
    -- Per-wheel 250ms-capability sampling is passive and makes NO native
    -- heightmap or wheel-physics change. Crucially, it records any non-1
    -- scale already owned by another mod before we plan a future writer.
    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.NativeWheelDisplacementObservation == true
        and RealismExtensionsTerrainNativeWheelBridge ~= nil then
        RealismExtensionsTerrainNativeWheelBridge.observe(vehicle,wheel)
    end
    -- Single transition record, NOT per-wheel/per-frame climate spam. This
    -- compares the Mud-provided frozen state with current GIANTS air temp.
    local rt=RealismExtensionsTerrainRuntime
    if rt~=nil and type(context.hardFrozen)=="boolean" then
        if context.hardFrozen then
            diagCount("freezeContextSamples",1)
        end
        if rt.lastFreezeState==nil
            or rt.lastFreezeState~=context.hardFrozen then
            rt.lastFreezeState=context.hardFrozen
            rt.freezeTransitionCount=(rt.freezeTransitionCount or 0)+1
            if rt.freezeTransitionCount<=8
                and RealismExtensionsDiagnostics~=nil
                and type(RealismExtensionsDiagnostics.info)=="function" then
                local env=g_currentMission~=nil
                    and g_currentMission.environment or nil
                local weather=env~=nil and env.weather or nil
                local air=nil
                if weather~=nil
                    and type(weather.getCurrentTemperature)=="function" then
                    local ok,v=pcall(weather.getCurrentTemperature,weather)
                    if ok and type(v)=="number" then air=v end
                end
                RealismExtensionsDiagnostics.info(string.format(
                    "TerrainFreezeState | frozen=%s airC=%s wetness=%.3f x=%.1f z=%.1f (source=Mud via RC; air is not soil temperature)",
                    tostring(context.hardFrozen),
                    air~=nil and string.format("%.2f",air) or "unknown",
                    tonumber(context.physicalGroundWetness) or -1,
                    context.worldX or 0,context.worldZ or 0
                ))
            end
        end
    end

    local footprint = RealismExtensionsFootprintModel.compute(context)
    if footprint == nil or footprint.available ~= true then
        if RealismExtensionsLoadedContactRegistry ~= nil then
            RealismExtensionsLoadedContactRegistry.remove(wheel)
        end
        state.loadedContactKnown = false
        state.loadedContactRefreshElapsedMs = 0
        diagCount("footprintRejects", 1)
        state.lastX, state.lastZ = context.worldX, context.worldZ
        return
    end

    diagCount("footprintAccepted", 1)

    -- Footprint telemetry is intentionally source-state focused. It lets the
    -- next runtime test prove how MR/Mud represent duals before RE invents any
    -- dual-specific multiplier.
    local supportWidthM = tonumber(footprint.supportWidthM)
    local baseWidthM = tonumber(context.baseTireWidthM)
    local contactAreaM2 = tonumber(footprint.contactAreaM2)
    local groundPressurePa = tonumber(footprint.groundPressurePa)
    local wheelLoadN = tonumber(footprint.wheelLoadN or context.wheelLoadN)
    local inflationBar = tonumber(footprint.inflationPressureBar or context.tirePressureBar)

    if loadedContactGuardEnabled() then
        local contactWidthM = math.max(0, supportWidthM or 0)
        local contactLengthM = math.max(0, tonumber(footprint.footprintLengthM) or 0)
        local contactRadiusM = 0.5 * math.sqrt(
            contactWidthM * contactWidthM + contactLengthM * contactLengthM
        )
        if contactRadiusM <= 0 then
            contactRadiusM = math.max(
                0.10,
                tonumber(context.structuralRadiusM) or 0.10
            ) * 0.35
        end
        local recorded = RealismExtensionsLoadedContactRegistry.record(
            wheel,
            vehicle,
            context.worldX,
            context.worldZ,
            contactRadiusM,
            wheelLoadN or 0,
            g_currentMission ~= nil and g_currentMission.time or 0
        )
        state.loadedContactKnown = recorded == true
        state.loadedContactRefreshElapsedMs = 0
        if recorded then
            diagCount("loadedContactRecords", 1)
            diagMax("maxLoadedContactRadiusM", contactRadiusM)
            if forcedLoadedContactRefresh then
                diagCount("loadedContactRefreshSuccess", 1)
            end
        elseif forcedLoadedContactRefresh then
            diagCount("loadedContactRefreshReleased", 1)
        end
    elseif state.loadedContactKnown == true then
        RealismExtensionsLoadedContactRegistry.remove(wheel)
        state.loadedContactKnown = false
        state.loadedContactRefreshElapsedMs = 0
    end

    if forcedLoadedContactRefresh then
        -- Safety refresh owns no terrain consequence. Refresh the contact
        -- anchor so a later movement does not interpolate a synthetic path
        -- from an old parked position, then leave before TerrainResponse.
        state.lastX, state.lastZ = context.worldX, context.worldZ
        diagCount("loadedContactRefreshOnly", 1)
        return
    end

    Engine.updateAxleCrestDiagnostics(vehicle, physics, context)

    diagMax("maxSupportWidthM", supportWidthM)
    diagMax("maxBaseTireWidthM", baseWidthM)
    diagMax("maxContactAreaM2", contactAreaM2)
    diagMax("maxWheelLoadN", wheelLoadN)
    diagMax("maxInflationPressureBar", inflationBar)
    diagMin("minGroundPressurePa", groundPressurePa)
    diagMax("maxGroundPressurePa", groundPressurePa)

    if supportWidthM ~= nil and baseWidthM ~= nil and baseWidthM > 0 then
        local ratio = supportWidthM / baseWidthM
        diagMax("maxSupportWidthRatio", ratio)
        if ratio >= 1.45 then
            diagCount("wideSupportContexts", 1)
        end
    end

    local x, z = context.worldX, context.worldZ
    local lastX, lastZ = state.lastX, state.lastZ
    state.lastX, state.lastZ = x, z

    if lastX == nil or lastZ == nil then
        Engine.processSample(
            vehicle, wheel, state, context, footprint,
            x, z, elapsedMs, stationaryWheelspin, nil, nil, actor
        )
        return
    end

    local pathDistance = distance2D(lastX, lastZ, x, z)
    local spacing = math.max(
        Engine.DEFAULTS.minPathSpacingM,
        math.min(footprint.supportWidthM, footprint.footprintLengthM)
            * Engine.DEFAULTS.pathSpacingFactor
    )

    local movingSamples = math.max(1, math.ceil(pathDistance / spacing))
    movingSamples = math.min(
        movingSamples,
        Engine.DEFAULTS.maxSamplesPerWheelTick
    )

    -- Stationary wheelspin is still processed at the current contact cell.
    if pathDistance < Engine.DEFAULTS.minPathSpacingM then
        movingSamples = 1
        diagCount("stationaryContactSamples", 1)
    else
        diagCount("movingContactSamples", movingSamples)
    end

    local sampleDt = elapsedMs / movingSamples
    local travelDirX, travelDirZ = nil, nil
    if pathDistance > 0.0001 then
        travelDirX = (x - lastX) / pathDistance
        travelDirZ = (z - lastZ) / pathDistance
    end

    for i = 1, movingSamples do
        local t = i / movingSamples
        local sx = lastX + (x - lastX) * t
        local sz = lastZ + (z - lastZ) * t
        Engine.processSample(
            vehicle,
            wheel,
            state,
            context,
            footprint,
            sx,
            sz,
            sampleDt,
            stationaryWheelspin,
            travelDirX,
            travelDirZ,
            actor
        )
    end
end

function Engine:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local perfStarted = RealismExtensionsTerrainPerformance ~= nil
        and RealismExtensionsTerrainPerformance.begin() or nil
    diagCount("vehicleUpdateCalls", 1)
    if RealismExtensionsConfig == nil
        or RealismExtensionsConfig.modules == nil
        or RealismExtensionsConfig.modules.TerrainDeformation ~= true then
        return
    end

    if self.isServer ~= true then return end
    if RealismExtensionsTerrainRuntime == nil
        or RealismExtensionsTerrainRuntime.history == nil
        or RealismExtensionsTerrainRuntime.writer == nil then
        return
    end

    local spec = self[Engine.SPEC_FIELD]
    if spec == nil then return end
    spec.diagnosticEpoch = (spec.diagnosticEpoch or 0) + 1

    for _, wheel in pairs(spec.wheels or {}) do
        Engine.processWheel(self, wheel, dt)
    end
    if RealismExtensionsTerrainPerformance ~= nil then
        RealismExtensionsTerrainPerformance.finish("vehicleUpdate", perfStarted)
    end
end

function Engine:onDelete()
    local spec = self[Engine.SPEC_FIELD]
    if spec ~= nil and RealismExtensionsLoadedContactRegistry ~= nil then
        for _, wheel in pairs(spec.wheels or {}) do
            RealismExtensionsLoadedContactRegistry.remove(wheel)
        end
    end
    self[Engine.SPEC_FIELD] = nil
end

RealismExtensionsTerrainRuntime = RealismExtensionsTerrainRuntime or {
    history = nil,
    writer = nil,
    geometryJournal = nil,
    absoluteShadow = nil,
    stats = {}
}

function RealismExtensionsTerrainRuntime.initialize()
    RealismExtensionsTerrainRuntime.stats = {}
    RealismExtensionsTerrainRuntime.nativeDamageQuarantined=false
    if RealismExtensionsTerrainRuntime.history == nil then
        RealismExtensionsTerrainRuntime.history = RealismExtensionsSpatialHistory.new({
            cellSizeM = Engine.DEFAULTS.historyCellSizeM,
            maxCells = Engine.DEFAULTS.maxHistoryCells
        })
    end

    if RealismExtensionsTerrainRuntime.writer == nil then
        RealismExtensionsTerrainRuntime.writer = RealismExtensionsTerrainWriter.new()
    end
    RealismExtensionsTerrainRuntime.tryInitializeGeometryJournal()
end

-- The initial loadMap hook can run before mission.terrainRootNode exists.
-- Retry only until a real native map node and a positive unit are available.
function RealismExtensionsTerrainRuntime.tryInitializeGeometryJournal()
    if RealismExtensionsTerrainRuntime.geometryJournal ~= nil then return true end
    if RealismExtensionsConfig == nil or RealismExtensionsConfig.modules == nil
        or RealismExtensionsConfig.modules.TerrainGeometryJournal ~= true
        or RealismExtensionsTerrainGeometryJournal == nil then return false end
    local missionNode = g_currentMission ~= nil
        and g_currentMission.terrainRootNode or nil
    local terrainNode = type(missionNode) == "number" and missionNode > 0
        and missionNode or g_terrainNode
    if type(terrainNode) ~= "number" or terrainNode <= 0 then return false end
    local candidate = RealismExtensionsTerrainGeometryJournal.new(terrainNode)
    if candidate.unitM == nil then return false end
    RealismExtensionsTerrainRuntime.geometryJournal = candidate
    if RealismExtensionsConfig~=nil
        and RealismExtensionsConfig.modules~=nil
        and RealismExtensionsConfig.modules.TerrainAbsoluteHeightShadow==true
        and RealismExtensionsTerrainAbsoluteHeightPlanner~=nil then
        RealismExtensionsTerrainRuntime.absoluteShadow =
            RealismExtensionsTerrainAbsoluteHeightPlanner.new({
                unitM=candidate.unitM,maxSources=50000
            })
    end
    return true
end

function RealismExtensionsTerrainRuntime.flush()
    if RealismExtensionsTerrainRuntime.writer ~= nil then
        return RealismExtensionsTerrainRuntime.writer:flush()
    end
    return 0, 0
end

function RealismExtensionsTerrainRuntime.getDiagnostics()
    local out = {}
    for key, value in pairs(RealismExtensionsTerrainRuntime.stats or {}) do
        out[key] = value
    end
    return out
end

function RealismExtensionsTerrainRuntime.clear()
    if RealismExtensionsLoadedContactRegistry ~= nil
        and type(RealismExtensionsLoadedContactRegistry.clear) == "function" then
        RealismExtensionsLoadedContactRegistry.clear()
    end
    if RealismExtensionsTerrainSurfaceResponse ~= nil
        and RealismExtensionsTerrainSurfaceResponse.clear ~= nil then
        RealismExtensionsTerrainSurfaceResponse.clear()
    end
    if RealismExtensionsTerrainRuntime.history ~= nil then
        RealismExtensionsTerrainRuntime.history:clear()
    end
    if RealismExtensionsTerrainRuntime.writer ~= nil then
        RealismExtensionsTerrainRuntime.writer:clear()
    end
    if RealismExtensionsTerrainRuntime.geometryJournal ~= nil then
        RealismExtensionsTerrainRuntime.geometryJournal:reset()
    end
    RealismExtensionsTerrainRuntime.history = nil
    RealismExtensionsTerrainRuntime.writer = nil
    RealismExtensionsTerrainRuntime.geometryJournal = nil
    RealismExtensionsTerrainRuntime.absoluteShadow = nil
    RealismExtensionsTerrainRuntime.stats = {}
    RealismExtensionsTerrainRuntime.nativeDamageQuarantined=false
end
