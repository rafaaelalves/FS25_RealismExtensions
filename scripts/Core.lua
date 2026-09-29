RealismExtensionsCore = {
    providerRetryMs = 1000,
    providerElapsedMs = 1000
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

    RealismExtensionsDiagnostics.info(
        "v" .. tostring(RealismExtensionsConfig.version)
        .. " foundation loaded; gameplay modules inactive"
    )
end

function RealismExtensionsCore:update(dt)
    if RealismExtensionsState == nil then return end

    local available = RealismExtensionsState.getProviderStatus()
    if available then return end

    self.providerElapsedMs = self.providerElapsedMs + math.max(tonumber(dt) or 0, 0)
    if self.providerElapsedMs < self.providerRetryMs then return end

    self.providerElapsedMs = 0
    self:tryDiscoverProvider()
end

function RealismExtensionsCore:deleteMap()
    RealismExtensionsState.clearProvider()
    self.providerElapsedMs = self.providerRetryMs
end

addModEventListener(RealismExtensionsCore)
