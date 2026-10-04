RealismExtensionsCore = {
    providerRetryMs = 1000,
    providerElapsedMs = 1000,
    tireTrackProbeRetryMs = 1000,
    tireTrackProbeElapsedMs = 1000,
    terrainDiagElapsedMs = 0,
    terrainDiagPrevious = nil
}

local function getModules()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules or {}
end

local function tireTrackProbeEnabled()
    return getModules().NativeTireTrackProbe == true
end

local function visualTrackCaptureEnabled()
    return getModules().VisualTrackCapture == true
end

local function tireTrackAdapterNeeded()
    return tireTrackProbeEnabled() or visualTrackCaptureEnabled()
end

local function configureTireTrackAdapterProbe()
    if RealismExtensionsNativeTireTrackAdapter ~= nil
        and type(RealismExtensionsNativeTireTrackAdapter.setProbeEnabled) == "function" then
        RealismExtensionsNativeTireTrackAdapter.setProbeEnabled(
            tireTrackProbeEnabled()
        )
    end
end

function RealismExtensionsCore:tryDiscoverProvider()
    if RealismExtensionsState == nil then return false end

    local available = RealismExtensionsState.getProviderStatus()
    if available then return true end

    local ok, reason = RealismExtensionsState.discoverProvider()
    if ok then
        local _, _, info = RealismExtensionsState.getProviderStatus()
        local id = info ~= nil and info.id or "unknown"
        RealismExtensionsDiagnostics.info(
            "normalized state provider active: " .. tostring(id)
        )
        return true
    end

    RealismExtensionsDiagnostics.verbose(
        "normalized state provider unavailable: " .. tostring(reason)
    )
    return false
end

function RealismExtensionsCore:loadMap()
    self.providerElapsedMs = self.providerRetryMs
    self.tireTrackProbeElapsedMs = self.tireTrackProbeRetryMs
    self.terrainDiagElapsedMs = 0
    self.terrainDiagPrevious = nil

    if RealismExtensionsTerrainRecovery ~= nil
        and type(RealismExtensionsTerrainRecovery.resetRuntimeState) == "function" then
        RealismExtensionsTerrainRecovery.resetRuntimeState()
    end

    self:tryDiscoverProvider()

    configureTireTrackAdapterProbe()
    if tireTrackAdapterNeeded()
        and RealismExtensionsNativeTireTrackAdapter ~= nil then
        local ok, reason = RealismExtensionsNativeTireTrackAdapter.installFromMission()
        if ok then
            RealismExtensionsDiagnostics.info(
                "native TireTrack adapter active; probe="
                .. tostring(tireTrackProbeEnabled())
                .. " capture=" .. tostring(visualTrackCaptureEnabled())
            )
        else
            RealismExtensionsDiagnostics.verbose(
                "native TireTrack adapter pending: " .. tostring(reason)
            )
        end
    end

    if RealismExtensionsTerrainRuntime ~= nil then
        RealismExtensionsTerrainRuntime.initialize()
    end

    local tdEnabled = RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true

    if tdEnabled
        and g_server ~= nil
        and RealismExtensionsTerrainPersistence ~= nil
        and RealismExtensionsTerrainRuntime ~= nil
        and RealismExtensionsTerrainRuntime.history ~= nil then
        local ok, detail = RealismExtensionsTerrainPersistence.load(
            g_currentMission ~= nil and g_currentMission.missionInfo or nil,
            RealismExtensionsTerrainRuntime.history
        )
        if ok then
            RealismExtensionsDiagnostics.info(
                "restored terrain history cells=" .. tostring(detail)
            )
        elseif detail ~= "no persisted terrain history" then
            RealismExtensionsDiagnostics.verbose(
                "terrain history not restored: " .. tostring(detail)
            )
        end
    end

    if RealismExtensionsTerrainMaintenance ~= nil
        and type(RealismExtensionsTerrainMaintenance.initialize) == "function" then
        RealismExtensionsTerrainMaintenance.initialize()
    end

    RealismExtensionsDiagnostics.info(
        "v" .. tostring(RealismExtensionsConfig.version)
        .. " loaded; TerrainDeformation="
        .. tostring(tdEnabled and "ENABLED" or "disabled")
    )

    local build = RealismExtensionsBuildInfo or {}
    RealismExtensionsDiagnostics.info(string.format(
        "BuildIdentity | branch=%s commit=%s run=%s builtAt=%s",
        tostring(build.branch or "unknown"),
        tostring(build.commit or "unknown"),
        tostring(build.runId or "unknown"),
        tostring(build.builtAtUtc or "unknown")
    ))
end

function RealismExtensionsCore:update(dt)
    if RealismExtensionsState ~= nil then
        local available = RealismExtensionsState.getProviderStatus()
        if not available then
            self.providerElapsedMs = self.providerElapsedMs
                + math.max(tonumber(dt) or 0, 0)

            if self.providerElapsedMs >= self.providerRetryMs then
                self.providerElapsedMs = 0
                self:tryDiscoverProvider()
            end
        end
    end

    configureTireTrackAdapterProbe()

    if tireTrackAdapterNeeded()
        and RealismExtensionsNativeTireTrackAdapter ~= nil
        and RealismExtensionsNativeTireTrackAdapter.installed ~= true then
        self.tireTrackProbeElapsedMs = (self.tireTrackProbeElapsedMs or 0)
            + math.max(tonumber(dt) or 0, 0)
        if self.tireTrackProbeElapsedMs >= self.tireTrackProbeRetryMs then
            self.tireTrackProbeElapsedMs = 0
            RealismExtensionsNativeTireTrackAdapter.installFromMission()
        end
    elseif not tireTrackAdapterNeeded()
        and RealismExtensionsNativeTireTrackAdapter ~= nil
        and RealismExtensionsNativeTireTrackAdapter.installed == true then
        if RealismExtensionsVisualTrackRuntime ~= nil then
            RealismExtensionsVisualTrackRuntime.shutdown()
        end
        RealismExtensionsNativeTireTrackAdapter.uninstall()
    end

    if visualTrackCaptureEnabled()
        and RealismExtensionsVisualTrackRuntime ~= nil
        and RealismExtensionsVisualTrackRuntime.active ~= true
        and RealismExtensionsNativeTireTrackAdapter ~= nil
        and RealismExtensionsNativeTireTrackAdapter.installed == true then
        local ok, reason = RealismExtensionsVisualTrackRuntime.initialize(
            RealismExtensionsNativeTireTrackAdapter
        )
        if not ok then
            RealismExtensionsDiagnostics.verbose(
                "visual track capture pending: " .. tostring(reason)
            )
        end
    elseif not visualTrackCaptureEnabled()
        and RealismExtensionsVisualTrackRuntime ~= nil
        and RealismExtensionsVisualTrackRuntime.active == true then
        RealismExtensionsVisualTrackRuntime.shutdown()
    end

    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsTerrainRuntime ~= nil then
        if RealismExtensionsTerrainRecovery ~= nil
            and type(RealismExtensionsTerrainRecovery.update) == "function" then
            RealismExtensionsTerrainRecovery.update(dt)
        end

        if RealismExtensionsTerrainMaintenance ~= nil
            and type(RealismExtensionsTerrainMaintenance.update) == "function" then
            RealismExtensionsTerrainMaintenance.update(dt)
        end

        local brushes, jobs = RealismExtensionsTerrainRuntime.flush()

        if RealismExtensionsConfig.diagnostics ~= nil
            and RealismExtensionsConfig.diagnostics.verbose == true then
            self.terrainDiagElapsedMs = (self.terrainDiagElapsedMs or 0)
                + math.max(tonumber(dt) or 0, 0)

            local diagConfig = RealismExtensionsConfig.diagnostics or {}
            local diagWindowMs = math.max(1000, tonumber(diagConfig.windowMs) or 5000)
            if self.terrainDiagElapsedMs >= diagWindowMs then
                self.terrainDiagElapsedMs = 0
                local runtime = RealismExtensionsTerrainRuntime
                local writer = runtime.writer
                local history = runtime.history
                local writerStats = writer ~= nil and writer.stats or {}
                local d = runtime.getDiagnostics ~= nil
                    and runtime.getDiagnostics() or {}
                local r = RealismExtensionsTerrainRecovery ~= nil
                    and RealismExtensionsTerrainRecovery.getDiagnostics() or {}
                local telemetry = RealismExtensionsTerrainTelemetry
                local window, nextSnapshot = {}, nil
                if telemetry ~= nil then
                    window, nextSnapshot = telemetry.buildWindow(
                        self.terrainDiagPrevious, r, d
                    )
                end

                if RealismExtensionsTerrainRecovery ~= nil then
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainRecovery v32R7 | calls=%d worked=%d intentCells=%d intentPoints=%d intentEmpty=%d intentMaxRut=%.3fm staleDeferred=%d stampSkips=%d enqueued=%d rejected=%d callbacks=%d roughness=%d improved=%d worsened=%d neutral=%d improve=%.4fm worsen=%.4fm centerUp=%d centerDown=%d historyRecoveredCells=%d historyRecoveredDepth=%.3fm deferredCreated=%d deferredApplied=%d deferredBlocked=%d deferredExpired=%d deferredSuperseded=%d deferredRejected=%d deferredQueued=%d deferredPeak=%d protectedMarks=%d workAreas=%d width=%.2f..%.2fm depth=%.2f..%.2fm machineSmoothJobs=%d machineSmoothBrushes=%d activeMarks=%d activeQueries=%d activeHits=%d physical=%d changed=%d repeat=%d areaPositive=%d preMarks=%d changedArea=%.0f processedArea=%.0f repeatArea=%.0f",
                        r.workAreaCalls or 0,
                        r.workedAreaCalls or 0,
                        r.intentCandidateCells or 0,
                        r.intentPoints or 0,
                        r.intentEmptyWorkAreas or 0,
                        r.intentMaxRutM or 0,
                        r.intentDeferredGone or 0,
                        r.stampSkips or 0,
                        r.brushesEnqueued or 0,
                        r.brushesRejected or 0,
                        r.callbacks or 0,
                        r.roughnessVerified or 0,
                        r.roughnessImproved or 0,
                        r.roughnessWorsened or 0,
                        r.roughnessNeutral or 0,
                        r.roughnessImprovementM or 0,
                        r.roughnessWorseningM or 0,
                        r.centerRaised or 0,
                        r.centerLowered or 0,
                        r.historyRecoveredCells or 0,
                        r.historyRecoveredDepthM or 0,
                        r.deferredCreated or 0,
                        r.deferredApplied or 0,
                        r.deferredStillBlocked or 0,
                        r.deferredExpired or 0,
                        r.deferredSuperseded or 0,
                        r.deferredRejected or 0,
                        r.deferredCount or 0,
                        r.deferredQueuePeak or 0,
                        r.protectedCellsMarked or 0,
                        r.workAreaGeometrySamples or 0,
                        r.minWorkAreaWidthM or 0,
                        r.maxWorkAreaWidthM or 0,
                        r.minWorkAreaDepthM or 0,
                        r.maxWorkAreaDepthM or 0,
                        writerStats.recoveryMachineSmoothJobs or 0,
                        writerStats.recoveryMachineSmoothBrushes or 0,
                        r.activeCombinationMarks or 0,
                        r.activeCombinationQueries or 0,
                        r.activeCombinationHits or 0,
                        r.physicalWorkAreaCalls or 0,
                        r.changedWorkAreaCalls or 0,
                        r.repeatWorkAreaCalls or 0,
                        r.areaPositiveCalls or 0,
                        r.preSuperActiveMarks or 0,
                        r.changedAreaUnits or 0,
                        r.processedAreaUnits or 0,
                        r.repeatAreaUnits or 0
                    ))

                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainRecoveryGeometry | relief=%d improved=%d worsened=%d neutral=%d improve=%.4fm worsen=%.4fm maxBefore=%.4fm maxAfter=%.4fm centerDeficit=%d improved=%d worsened=%d neutral=%d reduce=%.4fm worsen=%.4fm maxBefore=%.4fm maxAfter=%.4fm convergence=%d/%d complete=%d stalled=%d expired=%d deferredChecks=%d deferredCoalesced=%d deferredDropped=%d",
                        r.reliefVerified or 0,
                        r.reliefImproved or 0,
                        r.reliefWorsened or 0,
                        r.reliefNeutral or 0,
                        r.reliefImprovementM or 0,
                        r.reliefWorseningM or 0,
                        r.maxReliefBeforeM or 0,
                        r.maxReliefAfterM or 0,
                        r.centerDeficitVerified or 0,
                        r.centerDeficitImproved or 0,
                        r.centerDeficitWorsened or 0,
                        r.centerDeficitNeutral or 0,
                        r.centerDeficitReductionM or 0,
                        r.centerDeficitWorseningM or 0,
                        r.maxCenterDeficitBeforeM or 0,
                        r.maxCenterDeficitAfterM or 0,
                        r.convergenceScheduled or 0,
                        r.convergenceApplied or 0,
                        r.convergenceCompleted or 0,
                        r.convergenceStalled or 0,
                        r.convergenceExpired or 0,
                        r.deferredChecks or 0,
                        r.deferredCoalesced or 0,
                        r.deferredDroppedCapacity or 0
                    ))

                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainRecoveryTarget | scheduled=%d applied=%d complete=%d stalled=%d ownershipExhausted=%d targetApplied=%d targetComplete=%d noOp=%d improved=%d worsened=%d initialPositiveSkip=%d lowConfidence=%d signCross=%d residualReduce=%.4fm residualWorsen=%.4fm maxAbs=%.4f->%.4fm centerRaise=%.4fm centerLower=%.4fm amountMax=%.3f patch=%d/%d retained=%d sampleFail=%d patchDepth=%.4fm patchMaxResidual=%.4fm inFlight=%d timeouts=%d targetJobs=%d targetBrushes=%d targetRaised=%d targetLowered=%d targetAbsDelta=%.4fm targetMaxDelta=%.4fm machineTargetJobs=%d machineTargetBrushes=%d preProbeReuse=%d raiseJobs=%d smoothJobs=%d",
                        r.structuralScheduled or 0,
                        r.structuralApplied or 0,
                        r.structuralCompleted or 0,
                        r.structuralStalled or 0,
                        r.structuralOwnershipExhausted or 0,
                        r.targetPlaneApplied or 0,
                        r.targetPlaneCompleted or 0,
                        r.targetPlaneNoop or 0,
                        r.targetPlaneImproved or 0,
                        r.targetPlaneWorsened or 0,
                        r.targetPlaneInitialPositiveSkips or 0,
                        r.targetPlaneLowConfidence or 0,
                        r.targetPlaneSignCrossings or 0,
                        r.targetPlaneResidualReductionM or 0,
                        r.targetPlaneResidualWorseningM or 0,
                        r.targetPlaneMaxAbsBeforeM or 0,
                        r.targetPlaneMaxAbsAfterM or 0,
                        r.targetPlaneCenterRaisedM or 0,
                        r.targetPlaneCenterLoweredM or 0,
                        r.targetPlaneAmountMax or 0,
                        r.targetPatchCellsExamined or 0,
                        r.targetPatchCellsConverged or 0,
                        r.targetPatchCellsRetained or 0,
                        r.targetPatchSampleFailures or 0,
                        r.targetPatchRecoveredDepthM or 0,
                        r.targetPatchMaxResidualM or 0,
                        r.structuralInFlight or 0,
                        r.structuralInFlightTimeouts or 0,
                        writerStats.recoveryTargetJobs or 0,
                        writerStats.recoveryTargetBrushes or 0,
                        writerStats.recoveryTargetRaisedSamples or 0,
                        writerStats.recoveryTargetLoweredSamples or 0,
                        writerStats.recoveryTargetAbsDeltaM or 0,
                        writerStats.recoveryTargetMaxDeltaM or 0,
                        writerStats.recoveryMachineTargetJobs or 0,
                        writerStats.recoveryMachineTargetBrushes or 0,
                        writerStats.recoveryPreProbeReused or 0,
                        writerStats.recoveryRaiseJobs or 0,
                        writerStats.recoverySmoothJobs or 0
                    ))

                    local toolParts = {}
                    local toolOrder = {
                        "CULTIVATOR",
                        "SHALLOW_DISC",
                        "POWER_HARROW",
                        "SUBSOILER",
                        "PLOW",
                        "PLOW_PACKER"
                    }
                    local toolStats = r.toolProfiles or {}
                    for _, id in ipairs(toolOrder) do
                        local t = toolStats[id]
                        if t ~= nil then
                            toolParts[#toolParts + 1] = string.format(
                                "%s=%d/%d/%d/%d",
                                id,
                                t.workAreas or 0,
                                t.intentPoints or 0,
                                t.targetScheduled or 0,
                                t.targetApplied or 0
                            )
                        end
                    end
                    if #toolParts > 0 then
                        RealismExtensionsDiagnostics.verbose(
                            "TerrainRecoveryTools | "
                            .. "profile=workAreas/intentPoints/scheduled/applied "
                            .. table.concat(toolParts, " ")
                        )
                    end

                    if diagConfig.causalWindows ~= false then
                        RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainWindow %dms | work=%d changed=%d repeat=%d processedArea=%.0f repeatArea=%.0f smooth=%d callbacks=%d improved=%d worsened=%d rutBlocked=%d protected=%d rutAccepted=%d",
                        diagWindowMs,
                        window.work or 0,
                        window.changed or 0,
                        window.repeatWork or 0,
                        window.processedArea or 0,
                        window.repeatArea or 0,
                        window.smooth or 0,
                        window.callbacks or 0,
                        window.improved or 0,
                        window.worsened or 0,
                        window.rutBlocked or 0,
                        window.protected or 0,
                        window.rutAccepted or 0
                        ))
                    end
                end

                if RealismExtensionsTerrainPerformance ~= nil then
                    local p = RealismExtensionsTerrainPerformance.snapshot()
                    local vu, fl, cb, rc = p.vehicleUpdate, p.flush, p.callback, p.recovery
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainPerf | timer=%s vehicleUpdate=%d avg=%.4fms max=%.3fms total=%.1fms flushInclusive=%d avg=%.4fms max=%.3fms total=%.1fms callbackNested=%d avg=%.4fms max=%.3fms total=%.1fms recovery=%d avg=%.4fms max=%.3fms total=%.1fms",
                        tostring(p.timerAvailable),
                        vu.samples or 0, vu.avgMs or 0, vu.maxMs or 0, vu.totalMs or 0,
                        fl.samples or 0, fl.avgMs or 0, fl.maxMs or 0, fl.totalMs or 0,
                        cb.samples or 0, cb.avgMs or 0, cb.maxMs or 0, cb.totalMs or 0,
                        rc.samples or 0, rc.avgMs or 0, rc.maxMs or 0, rc.totalMs or 0
                    ))
                end

                RealismExtensionsDiagnostics.verbose(string.format(
                    "TerrainDeformation runtime | vehicles=%d wheels=%d vehicleUpdates=%d wheelTicks=%d sampleTicks=%d activitySkips=%d wheelspinCandidates=%d context=%d/%d noGround=%d noSoil=%d noContact=%d footprint=%d/%d samples=%d activeCultivatorRutSkips=%d cultivationProtected=%d responseRejects=%d belowThreshold=%d brushesAccepted=%d cells=%d retired=%d queue=%d enqueued=%d coalesced=%d submittedBrushes=%d submittedJobs=%d failedJobs=%d nativeBrushesAvoided=%d callbackJobs=%d displacedVolume=%.3f maxJobVolume=%.3f volumeMissing=%d geometryProbe=%d shallowProbe=%d zeroProbe=%d additiveDepth=%.3f observedLoweringProbe=%.3f maxAdditive=%.3f maxLoweringProbe=%.3f targetIntensity=%d/%.3f/max%.3f preProbeReuse=%d modelRut=%.3f modelCap=%.3f staticCap=%.3f slipCap=%.3f slipMult=%.2f stationaryBrushes=%d stationaryApplied=%.3f stationaryRut=%.3f stationaryCap=%.3f lastFlush=%d/%d",
                    d.vehiclesLoaded or 0,
                    d.wheelsAttached or 0,
                    d.vehicleUpdateCalls or 0,
                    d.wheelTicks or 0,
                    d.sampleTicks or 0,
                    d.activityGateSkips or 0,
                    d.stationaryWheelspinCandidates or 0,
                    d.contextAccepted or 0,
                    d.contextRequests or 0,
                    d.notGrounded or 0,
                    d.notSoilContact or 0,
                    d.missingContactPosition or 0,
                    d.footprintAccepted or 0,
                    d.contextAccepted or 0,
                    d.samplesProcessed or 0,
                    d.activeCultivatorRutSkips or 0,
                    d.cultivationProtectionSkips or 0,
                    d.responseRejects or 0,
                    d.belowBrushThreshold or 0,
                    d.brushesAccepted or 0,
                    history ~= nil and (history.count or 0) or 0,
                    history ~= nil and (history.retiredCount or 0) or 0,
                    writer ~= nil and type(writer.getQueueSize) == "function"
                        and writer:getQueueSize()
                        or 0,
                    writerStats.enqueued or 0,
                    writerStats.coalescedBrushes or 0,
                    writerStats.submittedBrushes or 0,
                    writerStats.submittedJobs or 0,
                    writerStats.failedJobs or 0,
                    writerStats.coalescedBrushes or 0,
                    writerStats.callbackSuccessJobs or 0,
                    writerStats.callbackDisplacedVolumeM3 or 0,
                    writerStats.callbackMaxDisplacedVolumeM3 or 0,
                    writerStats.callbackVolumeMissing or 0,
                    writerStats.geometrySamples or 0,
                    writerStats.geometryShallowSamples or 0,
                    writerStats.geometryZeroChangeSamples or 0,
                    writerStats.geometryRequestedDepthM or 0,
                    writerStats.geometryObservedLoweringM or 0,
                    writerStats.maxRequestedDepthM or 0,
                    writerStats.maxObservedLoweringM or 0,
                    writerStats.targetIntensitySamples or 0,
                    writerStats.targetIntensitySum or 0,
                    writerStats.targetIntensityMax or 0,
                    writerStats.recoveryPreProbeReused or 0,
                    d.maxRutDepthM or 0,
                    d.maxRutCapacityM or 0,
                    d.maxStaticRutCapacityM or 0,
                    d.maxSlipRutCapacityM or 0,
                    d.maxSlipSinkageMultiplier or 0,
                    d.stationaryBrushesAccepted or 0,
                    d.stationaryAppliedDepthM or 0,
                    d.stationaryMaxRutDepthM or 0,
                    d.stationaryMaxRutCapacityM or 0,
                    brushes or 0,
                    jobs or 0
                ))

                local actorKinds = {
                    "PLAYER",
                    "AI_FIELD",
                    "AI_GENERIC"
                }
                local actorParts = {}
                for _, kind in ipairs(actorKinds) do
                    local samples = d["actorSamples_" .. kind] or 0
                    local brushesForActor = d["actorBrushes_" .. kind] or 0
                    local depthForActor = d["actorAppliedDepth_" .. kind] or 0
                    if samples > 0 or brushesForActor > 0 then
                        actorParts[#actorParts + 1] = string.format(
                            "%s=%d/%d/%.3f",
                            kind,
                            samples,
                            brushesForActor,
                            depthForActor
                        )
                    end
                end
                local aiTurnSkips = d.actorSuppressed_AI_TURN or 0
                local aiSpinSkips = d.actorSuppressed_AI_STATIONARY_SPIN or 0
                if #actorParts > 0 or aiTurnSkips > 0 or aiSpinSkips > 0 then
                    RealismExtensionsDiagnostics.verbose(
                        "TerrainActors | samples/brushes/depthM "
                        .. table.concat(actorParts, " ")
                        .. string.format(
                            " suppressedTurn=%d suppressedSpin=%d",
                            aiTurnSkips,
                            aiSpinSkips
                        )
                    )
                end

                if RealismExtensionsTerrainMaintenance ~= nil
                    and type(RealismExtensionsTerrainMaintenance.getDiagnostics)
                        == "function" then
                    local m = RealismExtensionsTerrainMaintenance.getDiagnostics()
                    if (m.periods or 0) > 0
                        or (m.pending or 0) > 0
                        or (m.targetApplied or 0) > 0 then
                        RealismExtensionsDiagnostics.verbose(string.format(
                            "TerrainMaintenance v1 | periods=%d scanned=%d eligible=%d/%d buckets=%d/%d queued=%d/%d started=%d target=%d complete=%d neighbor=%d municipal=%d stale=%d blocked=%d/%d boundaryReject=%d surfaceReject=%d ownershipChanged=%d historyGone=%d probeFail=%d targetReject=%d callbackFail=%d patch=%d/%d depth=%.3fm pending=%d inFlight=%d maxQueue=%d",
                            m.periods or 0,
                            m.historyScanned or 0,
                            m.eligibleNeighborCells or 0,
                            m.eligibleMunicipalCells or 0,
                            m.neighborBuckets or 0,
                            m.municipalBuckets or 0,
                            m.queuedNeighbor or 0,
                            m.queuedMunicipal or 0,
                            m.tasksStarted or 0,
                            m.targetApplied or 0,
                            m.completed or 0,
                            m.neighborCompleted or 0,
                            m.municipalCompleted or 0,
                            m.staleDebtCleared or 0,
                            m.blockedContacts or 0,
                            m.blockedExpired or 0,
                            m.boundaryRejected or 0,
                            m.surfaceRejected or 0,
                            m.ownershipChanged or 0,
                            m.historyGone or 0,
                            m.probeFailed or 0,
                            m.targetRejected or 0,
                            m.callbackFailed or 0,
                            m.patchCellsExamined or 0,
                            m.patchCellsRecovered or 0,
                            m.patchRecoveredDepthM or 0,
                            m.pending or 0,
                            m.inFlight or 0,
                            m.maxQueue or 0
                        ))
                    end
                end

                local categories = {
                    "FIELD_SOFT", "FIELD", "FIELD_FIRM",
                    "MUD", "DIRT_WET", "DIRT_COMPACTED",
                    "GRAVEL_WET", "GRAVEL", "HARD", "UNKNOWN"
                }
                local parts = {}
                for _, category in ipairs(categories) do
                    local seen = d["surfaceSeen_" .. category] or 0
                    local brushesForSurface = d["surfaceBrushes_" .. category] or 0
                    local depthForSurface = d["surfaceAppliedDepth_" .. category] or 0
                    if seen > 0 or brushesForSurface > 0 then
                        parts[#parts + 1] = string.format(
                            "%s=%d/%d/%.3f",
                            category,
                            seen,
                            brushesForSurface,
                            depthForSurface
                        )
                    end
                end
                if #parts > 0 then
                    RealismExtensionsDiagnostics.verbose(
                        "SurfaceResponse runtime | seen/brushes/appliedDepthM "
                        .. table.concat(parts, " ")
                    )
                end

                if diagConfig.writerAttribution ~= false
                    and telemetry ~= nil
                    and (#(window.writers or {}) > 0
                        or #(window.rootWriters or {}) > 0) then
                    RealismExtensionsDiagnostics.verbose(
                        "RutWriters runtime | vehicles=["
                        .. telemetry.formatWriters(window.writers,5)
                        .. "] roots=["
                        .. telemetry.formatWriters(window.rootWriters,5)
                        .. "]"
                    )
                end
                if nextSnapshot ~= nil then
                    self.terrainDiagPrevious = nextSnapshot
                end

                if (d.footprintAccepted or 0) > 0 then
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "Footprint runtime | contexts=%d wideSupport=%d segmented=%d crawler=%d patches=%d/%d maxBaseWidth=%.3f maxContactWidth=%.3f maxSpan=%.3f maxGap=%.3f maxSegments=%d trackFx=%.2f trackLength=%.3f maxWidthRatio=%.2f maxLoadN=%.0f maxArea=%.3f pressurePa=%.0f..%.0f maxInflationBar=%.2f",
                        d.footprintAccepted or 0,
                        d.wideSupportContexts or 0,
                        d.segmentedSupportContexts or 0,
                        d.crawlerContexts or 0,
                        d.segmentedWheelPatches or 0,
                        d.crawlerTerrainPatches or 0,
                        d.maxBaseTireWidthM or 0,
                        d.maxSupportWidthM or 0,
                        d.maxSupportSpanM or 0,
                        d.maxSupportGapWidthM or 0,
                        d.maxSupportSegmentCount or 0,
                        d.maxTrackFootprintFactor or 0,
                        d.maxTrackContactLengthM or 0,
                        d.maxSupportWidthRatio or 0,
                        d.maxWheelLoadN or 0,
                        d.maxContactAreaM2 or 0,
                        d.minGroundPressurePa or 0,
                        d.maxGroundPressurePa or 0,
                        d.maxInflationPressureBar or 0
                    ))
                end

                if (d.axleCrestSamples or 0) > 0 then
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainClearance runtime | axleSamples=%d maxSpan=%.2f maxCentralCrest=%.3f crest>5cm=%d crest>10cm=%d crest>15cm=%d",
                        d.axleCrestSamples or 0,
                        d.maxAxleSpanM or 0,
                        d.maxCentralTerrainCrestM or 0,
                        d.centralCrestOver5cm or 0,
                        d.centralCrestOver10cm or 0,
                        d.centralCrestOver15cm or 0
                    ))
                end

                if (d.samplesProcessed or 0) > 0 then
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainPlasticity sample | wet=%.2f slip=%.3f instantSink=%.3f transfer=%.2f persistentSink=%.3f staticCap=%.3f slipCap=%.3f rut=%.3f maxInstant=%.3f maxPersistent=%.3f maxTransfer=%.2f",
                        d.lastPlasticWetness01 or 0,
                        d.lastPlasticSlip01 or 0,
                        d.lastObservedSinkDepthM or 0,
                        d.lastSinkPlasticTransfer01 or 0,
                        d.lastPersistentSinkDepthM or 0,
                        d.lastStaticRutCapacityM or 0,
                        d.lastSlipRutCapacityM or 0,
                        d.lastRutDepthM or 0,
                        d.maxObservedSinkDepthM or 0,
                        d.maxPersistentSinkDepthM or 0,
                        d.maxSinkPlasticTransfer or 0
                    ))

                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainSinkHandoffProbe | observed=%.3f historyRepresented=%.3f residual=%.3f maxRepresented=%.3f maxResidual=%.3f loadedContacts=%d maxContactRadius=%.2f",
                        d.lastSinkObservedProxyM or 0,
                        d.lastSinkRepresentedByHistoryProxyM or 0,
                        d.lastSinkResidualProxyM or 0,
                        d.maxSinkRepresentedByHistoryProxyM or 0,
                        d.maxSinkResidualProxyM or 0,
                        d.loadedContactRecords or 0,
                        d.maxLoadedContactRadiusM or 0
                    ))
                end

                if (r.loadedContactQueries or 0) > 0 then
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TerrainRecoveryContactGuard | queries=%d blocked=%d maxBlockingLoadN=%.0f",
                        r.loadedContactQueries or 0,
                        r.loadedContactSkips or 0,
                        r.loadedContactMaxLoadN or 0
                    ))
                end

                if RealismExtensionsVisualTrackRuntime ~= nil
                    and RealismExtensionsConfig.modules.VisualTrackCapture == true then
                    local v = RealismExtensionsVisualTrackRuntime.getDiagnostics()
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "VisualTrackCapture | active=%s create=%d reuse=%d points=%d accepted=%d deferred=%d cuts=%d gapCuts=%d nonTerrain=%d finalized=%d retained=%d chunks=%d chunkFragments=%d chunkPoints=%d rejected=%d sinkErrors=%d",
                        tostring(v.active),
                        v.creates or 0,
                        v.nativeIdReuses or 0,
                        v.pointsSeen or 0,
                        v.pointsAccepted or 0,
                        v.pointsDeferred or 0,
                        v.cuts or 0,
                        v.gapCuts or 0,
                        v.nonTerrainSkipped or 0,
                        v.fragmentsFinalized or 0,
                        v.retainedPoints or 0,
                        v.chunkCount or 0,
                        v.chunkFragments or 0,
                        v.chunkPointReferences or 0,
                        v.rejectedCalls or 0,
                        v.sinkErrors or 0
                    ))
                end

                if RealismExtensionsAIVisualTrackPolicy ~= nil
                    and type(RealismExtensionsAIVisualTrackPolicy.getDiagnostics) == "function" then
                    local a = RealismExtensionsAIVisualTrackPolicy.getDiagnostics()
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "AIVisualTracks | enabled=%s AIImplement=%s AIJobVehicle=%s calls=%d baseAllowed=%d baseDenied=%d",
                        tostring(a.enabled),
                        tostring(a.aiImplementPatched),
                        tostring(a.aiJobVehiclePatched),
                        a.calls or 0,
                        a.baseAllowed or 0,
                        a.baseDenied or 0
                    ))
                end

                if RealismExtensionsNativeTireTrackAdapter ~= nil
                    and RealismExtensionsConfig.modules.NativeTireTrackProbe == true then
                    local t = RealismExtensionsNativeTireTrackAdapter.getDiagnostics()
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TireTrackProbe | installed=%s integrity=%s create=%d point=%d cut=%d maxArgs=%d/%d/%d observerErrors=%d drift=%d bootstrapPreLoad=%d bootstrapInstalls=%d captureBootstrap=%d captureFailures=%d",
                        tostring(t.installed),
                        tostring(t.integrity),
                        t.createTrackCalls or 0,
                        t.addTrackPointCalls or 0,
                        t.cutTrackCalls or 0,
                        t.maxCreateArgs or 0,
                        t.maxPointArgs or 0,
                        t.maxCutArgs or 0,
                        t.observerErrors or 0,
                        t.pointerDrift or 0,
                        RealismExtensionsNativeTireTrackBootstrap ~= nil
                            and (RealismExtensionsNativeTireTrackBootstrap.stats.preLoadCalls or 0) or 0,
                        RealismExtensionsNativeTireTrackBootstrap ~= nil
                            and (RealismExtensionsNativeTireTrackBootstrap.stats.adapterInstalls or 0) or 0,
                        RealismExtensionsNativeTireTrackBootstrap ~= nil
                            and (RealismExtensionsNativeTireTrackBootstrap.stats.captureInitializations or 0) or 0,
                        RealismExtensionsNativeTireTrackBootstrap ~= nil
                            and (RealismExtensionsNativeTireTrackBootstrap.stats.captureInitFailures or 0) or 0
                    ))
                end

                if (writerStats.massTransportSourceVolumeM3 or 0) > 0 then
                    local target = writerStats.massTransportTargetVolumeM3 or 0
                    local raised = writerStats.massTransportRaisedVolumeM3 or 0
                    local errorM3 = raised - target
                    local realization = target > 0 and raised / target or 0
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "SoilMassTransport runtime | source=%.3f targetTransport=%.3f raised=%.3f realization=%.2f compaction=%.3f balanceError=%+.3f berms=%d raiseJobs=%d rejects=%d recoveryRaised=%.3f recoveryRaiseJobs=%d otherRaised=%.3f otherRaiseJobs=%d",
                        writerStats.massTransportSourceVolumeM3 or 0,
                        target,
                        raised,
                        realization,
                        writerStats.massTransportCompactionVolumeM3 or 0,
                        errorM3,
                        writerStats.massTransportBermsEnqueued or 0,
                        writerStats.massTransportRaiseJobs or 0,
                        writerStats.massTransportModelRejects or 0,
                        writerStats.recoveryRaisedVolumeM3 or 0,
                        writerStats.recoveryRaiseJobs or 0,
                        writerStats.unclassifiedRaisedVolumeM3 or 0,
                        writerStats.unclassifiedRaiseJobs or 0
                    ))
                end
            end
        end
    end
end

function RealismExtensionsCore:deleteMap()
    if RealismExtensionsVisualTrackRuntime ~= nil then
        RealismExtensionsVisualTrackRuntime.shutdown()
    end
    if RealismExtensionsNativeTireTrackAdapter ~= nil then
        RealismExtensionsNativeTireTrackAdapter.uninstall()
        RealismExtensionsNativeTireTrackAdapter.resetProbe()
    end
    RealismExtensionsState.clearProvider()
    self.providerElapsedMs = self.providerRetryMs
    self.tireTrackProbeElapsedMs = self.tireTrackProbeRetryMs
    self.terrainDiagElapsedMs = 0
    self.terrainDiagPrevious = nil
    self._terrainDiagNextSnapshot = nil

    if RealismExtensionsTerrainRecovery ~= nil
        and type(RealismExtensionsTerrainRecovery.resetRuntimeState) == "function" then
        RealismExtensionsTerrainRecovery.resetRuntimeState()
    end

    if RealismExtensionsTerrainMaintenance ~= nil
        and type(RealismExtensionsTerrainMaintenance.shutdown) == "function" then
        RealismExtensionsTerrainMaintenance.shutdown()
    end

    if RealismExtensionsTerrainRuntime ~= nil then
        RealismExtensionsTerrainRuntime.clear()
    end
end

addModEventListener(RealismExtensionsCore)


function RealismExtensionsCore.saveToXMLFile(missionInfo)
    if RealismExtensionsConfig == nil
        or RealismExtensionsConfig.modules == nil
        or RealismExtensionsConfig.modules.TerrainDeformation ~= true
        or RealismExtensionsTerrainPersistence == nil
        or RealismExtensionsTerrainRuntime == nil
        or RealismExtensionsTerrainRuntime.history == nil then
        return
    end

    local ok, detail = RealismExtensionsTerrainPersistence.save(
        missionInfo,
        RealismExtensionsTerrainRuntime.history
    )
    if ok then
        RealismExtensionsDiagnostics.verbose(
            "saved terrain history cells=" .. tostring(detail)
        )
    else
        RealismExtensionsDiagnostics.verbose(
            "terrain history not saved: " .. tostring(detail)
        )
    end
end

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(
    FSCareerMissionInfo.saveToXMLFile,
    RealismExtensionsCore.saveToXMLFile
)
