RealismExtensionsCore = {
    providerRetryMs = 1000,
    providerElapsedMs = 1000,
    terrainDiagElapsedMs = 0
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
    self:tryDiscoverProvider()

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
        and RealismExtensionsConfig.modules.TerrainDeformation == true
        and RealismExtensionsTerrainRuntime ~= nil then
        local brushes, jobs = RealismExtensionsTerrainRuntime.flush()

        if RealismExtensionsConfig.diagnostics ~= nil
            and RealismExtensionsConfig.diagnostics.verbose == true then
            self.terrainDiagElapsedMs = (self.terrainDiagElapsedMs or 0)
                + math.max(tonumber(dt) or 0, 0)

            if self.terrainDiagElapsedMs >= 5000 then
                self.terrainDiagElapsedMs = 0
                local runtime = RealismExtensionsTerrainRuntime
                local writer = runtime.writer
                local history = runtime.history
                local writerStats = writer ~= nil and writer.stats or {}
                local d = runtime.getDiagnostics ~= nil
                    and runtime.getDiagnostics() or {}

                RealismExtensionsDiagnostics.verbose(string.format(
                    "TerrainDeformation runtime | vehicles=%d wheels=%d vehicleUpdates=%d wheelTicks=%d sampleTicks=%d activitySkips=%d wheelspinCandidates=%d context=%d/%d noGround=%d noSoil=%d noContact=%d footprint=%d/%d samples=%d responseRejects=%d belowThreshold=%d brushesAccepted=%d cells=%d queue=%d enqueued=%d coalesced=%d submittedBrushes=%d submittedJobs=%d failedJobs=%d nativeBrushesAvoided=%d lastFlush=%d/%d",
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
                    brushes or 0,
                    jobs or 0
                ))
            end
        end
    end
end

function RealismExtensionsCore:deleteMap()
    RealismExtensionsState.clearProvider()
    self.providerElapsedMs = self.providerRetryMs
    self.terrainDiagElapsedMs = 0

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
