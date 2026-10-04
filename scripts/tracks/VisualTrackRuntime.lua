RealismExtensionsVisualTrackRuntime = RealismExtensionsVisualTrackRuntime or {}
local Runtime = RealismExtensionsVisualTrackRuntime

Runtime.VERSION = 2
Runtime.active = Runtime.active == true
Runtime.journal = Runtime.journal
Runtime.chunkStore = Runtime.chunkStore
Runtime.observer = Runtime.observer

function Runtime.initialize(adapter, options)
    if Runtime.active == true then return true, nil end
    adapter = adapter or RealismExtensionsNativeTireTrackAdapter
    options = options or {}

    if type(adapter) ~= "table"
        or adapter.installed ~= true
        or type(adapter.addObserver) ~= "function" then
        return false, "native TireTrack adapter unavailable"
    end
    if RealismExtensionsVisualTrackJournal == nil
        or type(RealismExtensionsVisualTrackJournal.new) ~= "function" then
        return false, "visual track journal unavailable"
    end
    if RealismExtensionsVisualTrackChunkStore == nil
        or type(RealismExtensionsVisualTrackChunkStore.new) ~= "function" then
        return false, "visual track chunk store unavailable"
    end

    local journalOptions = {}
    for k,v in pairs(options.journal or options) do
        if k ~= "chunkStore" then journalOptions[k]=v end
    end
    journalOptions.retainClosedFragments = false
    journalOptions.terrainOnly = true

    local journal = RealismExtensionsVisualTrackJournal.new(journalOptions)
    local chunkStore = RealismExtensionsVisualTrackChunkStore.new(
        options.chunkStore or {}
    )
    journal:addFragmentSink(chunkStore)

    local observer = journal:makeAdapterObserver()
    if adapter.addObserver(observer) ~= true then
        return false, "unable to register journal observer"
    end

    Runtime.adapter = adapter
    Runtime.journal = journal
    Runtime.chunkStore = chunkStore
    Runtime.observer = observer
    Runtime.active = true
    return true, nil
end

function Runtime.shutdown()
    if Runtime.adapter ~= nil
        and Runtime.observer ~= nil
        and type(Runtime.adapter.removeObserver) == "function" then
        Runtime.adapter.removeObserver(Runtime.observer)
    end
    Runtime.adapter = nil
    Runtime.observer = nil
    Runtime.journal = nil
    Runtime.chunkStore = nil
    Runtime.active = false
end

function Runtime.getSnapshot()
    if Runtime.journal == nil then return nil end
    return Runtime.journal:getSnapshot()
end

function Runtime.queryChunks(x,z,radiusM)
    if Runtime.chunkStore == nil then return {} end
    return Runtime.chunkStore:queryCircle(x,z,radiusM)
end

function Runtime.getDiagnostics()
    local stats = Runtime.journal ~= nil and Runtime.journal.stats or {}
    local chunkStats = Runtime.chunkStore ~= nil
        and Runtime.chunkStore:getStats() or {}
    return {
        active = Runtime.active == true,
        creates = stats.creates or 0,
        nativeIdReuses = stats.nativeIdReuses or 0,
        pointsSeen = stats.pointsSeen or 0,
        pointsAccepted = stats.pointsAccepted or 0,
        pointsDeferred = stats.pointsDeferred or 0,
        cuts = stats.cuts or 0,
        gapCuts = stats.gapCuts or 0,
        nonTerrainSkipped = stats.nonTerrainSkipped or 0,
        rejectedCalls = stats.rejectedCalls or 0,
        sinkErrors = stats.sinkErrors or 0,
        fragmentsFinalized = stats.fragmentsFinalized or 0,
        retainedPoints = Runtime.journal ~= nil
            and Runtime.journal.retainedPoints or 0,
        chunkCount = chunkStats.chunks or 0,
        chunkFragments = chunkStats.fragments or 0,
        chunkPointReferences = chunkStats.pointReferences or 0,
        lastRejectReason = Runtime.journal ~= nil
            and Runtime.journal.lastRejectReason or nil
    }
end

return Runtime
