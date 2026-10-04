RealismExtensionsCore = {
    providerRetryMs = 1000,
    providerElapsedMs = 1000,
    tireTrackProbeRetryMs = 1000,
    tireTrackProbeElapsedMs = 1000,
    terrainDiagElapsedMs = 0,
    terrainDiagPrevious = nil
}

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

    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.NativeTireTrackProbe == true
        and RealismExtensionsNativeTireTrackAdapter ~= nil then
        local ok, reason = RealismExtensionsNativeTireTrackAdapter.installFromMission()
        if ok then
            RealismExtensionsDiagnostics.info("native TireTrack probe active")
        else
            RealismExtensionsDiagnostics.verbose(
                "native TireTrack probe pending: " .. tostring(reason)
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

    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.NativeTireTrackProbe == true
        and RealismExtensionsNativeTireTrackAdapter ~= nil
        and RealismExtensionsNativeTireTrackAdapter.installed ~= true then
        self.tireTrackProbeElapsedMs = (self.tireTrackProbeElapsedMs or 0)
            + math.max(tonumber(dt) or 0, 0)
        if self.tireTrackProbeElapsedMs >= self.tireTrackProbeRetryMs then
            self.tireTrackProbeElapsedMs = 0
            RealismExtensionsNativeTireTrackAdapter.installFromMission()
        end
    end

    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.VisualTrackCapture == true
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
    end

    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsTerrainRuntime ~= nil then
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
                        "TerrainRecovery v22 | calls=%d worked=%d coverage=%d stampSkips=%d enqueued=%d rejected=%d callbacks=%d roughness=%d improved=%d worsened=%d neutral=%d improve=%.4fm worsen=%.4fm centerUp=%d centerDown=%d historyRecoveredCells=%d historyRecoveredDepth=%.3fm protectedMarks=%d workAreas=%d width=%.2f..%.2fm depth=%.2f..%.2fm machineSmoothJobs=%d machineSmoothBrushes=%d activeMarks=%d activeQueries=%d activeHits=%d physical=%d changed=%d repeat=%d areaPositive=%d preMarks=%d changedArea=%.0f processedArea=%.0f repeatArea=%.0f",
                        r.workAreaCalls or 0,
                        r.workedAreaCalls or 0,
                        r.coveragePoints or 0,
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
                        "TerrainPerf | timer=%s vehicleUpdate=%d avg=%.4fms max=%.3fms total=%.1fms flush=%d avg=%.4fms max=%.3fms total=%.1fms callback=%d avg=%.4fms max=%.3fms total=%.1fms recovery=%d avg=%.4fms max=%.3fms total=%.1fms",
                        tostring(p.timerAvailable),
                        vu.samples or 0, vu.avgMs or 0, vu.maxMs or 0, vu.totalMs or 0,
                        fl.samples or 0, fl.avgMs or 0, fl.maxMs or 0, fl.totalMs or 0,
                        cb.samples or 0, cb.avgMs or 0, cb.maxMs or 0, cb.totalMs or 0,
                        rc.samples or 0, rc.avgMs or 0, rc.maxMs or 0, rc.totalMs or 0
                    ))
                end

                RealismExtensionsDiagnostics.verbose(string.format(
                    "TerrainDeformation runtime | vehicles=%d wheels=%d vehicleUpdates=%d wheelTicks=%d sampleTicks=%d activitySkips=%d wheelspinCandidates=%d context=%d/%d noGround=%d noSoil=%d noContact=%d footprint=%d/%d samples=%d activeCultivatorRutSkips=%d cultivationProtected=%d responseRejects=%d belowThreshold=%d brushesAccepted=%d cells=%d queue=%d enqueued=%d coalesced=%d submittedBrushes=%d submittedJobs=%d failedJobs=%d nativeBrushesAvoided=%d callbackJobs=%d displacedVolume=%.3f maxJobVolume=%.3f volumeMissing=%d geometryProbe=%d shallowProbe=%d zeroProbe=%d requestedDepth=%.3f observedLoweringProbe=%.3f maxRequested=%.3f maxLoweringProbe=%.3f modelRut=%.3f modelCap=%.3f staticCap=%.3f slipCap=%.3f slipMult=%.2f stationaryBrushes=%d stationaryApplied=%.3f stationaryRut=%.3f stationaryCap=%.3f lastFlush=%d/%d",
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
                    writer ~= nil and #(writer.queue or {}) or 0,
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
                        "Footprint runtime | contexts=%d wideSupport=%d maxBaseWidth=%.3f maxSupportWidth=%.3f maxWidthRatio=%.2f maxLoadN=%.0f maxArea=%.3f pressurePa=%.0f..%.0f maxInflationBar=%.2f",
                        d.footprintAccepted or 0,
                        d.wideSupportContexts or 0,
                        d.maxBaseTireWidthM or 0,
                        d.maxSupportWidthM or 0,
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
                        "VisualTrackCapture | active=%s create=%d points=%d accepted=%d simplified=%d cuts=%d retained=%d rejected=%d pruned=%d",
                        tostring(v.active),
                        v.creates or 0,
                        v.pointsSeen or 0,
                        v.pointsAccepted or 0,
                        v.pointsSimplified or 0,
                        v.cuts or 0,
                        v.retainedPoints or 0,
                        v.rejectedCalls or 0,
                        v.prunedPoints or 0
                    ))
                end

                if RealismExtensionsNativeTireTrackAdapter ~= nil
                    and RealismExtensionsConfig.modules.NativeTireTrackProbe == true then
                    local t = RealismExtensionsNativeTireTrackAdapter.getDiagnostics()
                    RealismExtensionsDiagnostics.verbose(string.format(
                        "TireTrackProbe | installed=%s integrity=%s create=%d point=%d cut=%d maxArgs=%d/%d/%d observerErrors=%d drift=%d",
                        tostring(t.installed),
                        tostring(t.integrity),
                        t.createTrackCalls or 0,
                        t.addTrackPointCalls or 0,
                        t.cutTrackCalls or 0,
                        t.maxCreateArgs or 0,
                        t.maxPointArgs or 0,
                        t.maxCutArgs or 0,
                        t.observerErrors or 0,
                        t.pointerDrift or 0
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
