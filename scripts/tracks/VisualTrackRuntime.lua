RealismExtensionsVisualTrackRuntime = RealismExtensionsVisualTrackRuntime or {}
local Runtime = RealismExtensionsVisualTrackRuntime

Runtime.VERSION = 1
Runtime.active = Runtime.active == true
Runtime.journal = Runtime.journal
Runtime.observer = Runtime.observer

function Runtime.initialize(adapter, options)
    if Runtime.active == true then return true, nil end
    adapter = adapter or RealismExtensionsNativeTireTrackAdapter

    if type(adapter) ~= "table"
        or adapter.installed ~= true
        or type(adapter.addObserver) ~= "function" then
        return false, "native TireTrack adapter unavailable"
    end
    if RealismExtensionsVisualTrackJournal == nil
        or type(RealismExtensionsVisualTrackJournal.new) ~= "function" then
        return false, "visual track journal unavailable"
    end

    local journal = RealismExtensionsVisualTrackJournal.new(options)
    local observer = journal:makeAdapterObserver()
    if adapter.addObserver(observer) ~= true then
        return false, "unable to register journal observer"
    end

    Runtime.adapter = adapter
    Runtime.journal = journal
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
    Runtime.active = false
end

function Runtime.getSnapshot()
    if Runtime.journal == nil then return nil end
    return Runtime.journal:getSnapshot()
end

function Runtime.getDiagnostics()
    local stats = Runtime.journal ~= nil and Runtime.journal.stats or {}
    return {
        active = Runtime.active == true,
        creates = stats.creates or 0,
        pointsSeen = stats.pointsSeen or 0,
        pointsAccepted = stats.pointsAccepted or 0,
        pointsSimplified = stats.pointsSimplified or 0,
        cuts = stats.cuts or 0,
        rejectedCalls = stats.rejectedCalls or 0,
        prunedPoints = stats.prunedPoints or 0,
        retainedPoints = Runtime.journal ~= nil
            and Runtime.journal.retainedPoints or 0,
        lastRejectReason = Runtime.journal ~= nil
            and Runtime.journal.lastRejectReason or nil
    }
end

return Runtime
