-- Public consumer-side contract for normalized realism state.
--
-- Feature modules consume only this API. Specialist-mod internals stay behind
-- provider boundaries so ownership can move later without rewriting consumers.

RealismExtensionsState = {
    API_VERSION = 2,
    -- RC v2 is additive for the terrain state consumed today and introduces
    -- grouped support geometry (segments/contact width vs lateral span).
    -- Negotiate only explicit, paired v1/v2 contracts; never accept an unknown
    -- future schema simply because the method name still exists.
    SUPPORTED_PROVIDER_API_VERSIONS = { [1] = true, [2] = true },
    SUPPORTED_WHEEL_CONTEXT_VERSIONS = { [1] = true, [2] = true },
    negotiatedWheelContextVersion = nil,
    provider = nil,
    providerInfo = nil,
    providerReason = nil
}

local function getProviderInfo(provider)
    if type(provider) ~= "table" then return nil end
    if type(provider.getProviderInfo) == "function" then
        local ok, info = pcall(provider.getProviderInfo, provider)
        if ok and type(info) == "table" then
            return info
        end
    end
    return {
        apiVersion = provider.API_VERSION,
        wheelContextVersion = provider.WHEEL_CONTEXT_VERSION
    }
end

function RealismExtensionsState.validateProvider(provider)
    if type(provider) ~= "table" then
        return false, "provider must be a table", nil
    end
    if type(provider.getWheelContext) ~= "function" then
        return false, "provider.getWheelContext is required", nil
    end

    local info = getProviderInfo(provider)
    if type(info) ~= "table" then
        return false, "provider info unavailable", nil
    end

    local apiVersion = tonumber(info.apiVersion)
    local wheelContextVersion = tonumber(info.wheelContextVersion)
    if RealismExtensionsState.SUPPORTED_PROVIDER_API_VERSIONS[apiVersion]
        ~= true then
        return false, string.format(
            "unsupported provider API version: got %s (supports 1, 2)",
            tostring(info.apiVersion)
        ), info
    end

    if RealismExtensionsState.SUPPORTED_WHEEL_CONTEXT_VERSIONS[wheelContextVersion]
        ~= true then
        return false, string.format(
            "unsupported wheel context version: got %s (supports 1, 2)",
            tostring(info.wheelContextVersion)
        ), info
    end

    -- The supported RC generations use paired revisions; v1/v2 mixed metadata
    -- is not a reviewed contract. Fail closed rather than trusting field names.
    if wheelContextVersion ~= apiVersion then
        return false, string.format(
            "provider/wheel context version pair mismatch: %s/%s",
            tostring(info.apiVersion),
            tostring(info.wheelContextVersion)
        ), info
    end

    return true, nil, info
end

function RealismExtensionsState.registerProvider(provider)
    local ok, reason, info = RealismExtensionsState.validateProvider(provider)
    if not ok then
        RealismExtensionsState.provider = nil
        RealismExtensionsState.providerInfo = info
        RealismExtensionsState.providerReason = reason
        RealismExtensionsState.negotiatedWheelContextVersion = nil
        return false, reason
    end

    RealismExtensionsState.provider = provider
    RealismExtensionsState.providerInfo = info
    RealismExtensionsState.providerReason = nil
    RealismExtensionsState.negotiatedWheelContextVersion =
        tonumber(info.wheelContextVersion)
    return true
end

local function resolveCompatibilityEnvironment()
    if _G == nil then return nil end

    -- FS25 script mods execute in separate Lua environments. Cross-mod symbols
    -- are exposed through the mod environment stored under the active mod name,
    -- not reliably as plain globals in this mod's own environment.
    local env = _G["FS25_RealismCompatibility"]
    if type(env) == "table" then return env end

    return nil
end

function RealismExtensionsState.discoverProvider()
    local env = resolveCompatibilityEnvironment()
    local provider = env ~= nil and env.RealismCompatStateProvider or nil

    -- Keep a same-environment fallback for isolated harnesses and development
    -- builds, but production discovery should resolve the RC mod environment.
    if provider == nil and _G ~= nil then
        provider = _G.RealismCompatStateProvider
    end

    if provider == nil then
        RealismExtensionsState.providerReason =
            "FS25_RealismCompatibility environment/provider not available"
        return false, RealismExtensionsState.providerReason
    end

    return RealismExtensionsState.registerProvider(provider)
end

function RealismExtensionsState.clearProvider(provider)
    if provider == nil or RealismExtensionsState.provider == provider then
        RealismExtensionsState.provider = nil
        RealismExtensionsState.providerInfo = nil
        RealismExtensionsState.providerReason = nil
        RealismExtensionsState.negotiatedWheelContextVersion = nil
    end
end

function RealismExtensionsState.getProviderStatus()
    return RealismExtensionsState.provider ~= nil,
        RealismExtensionsState.providerReason,
        RealismExtensionsState.providerInfo
end

function RealismExtensionsState.getWheelContext(vehicle, wheel, hints)
    local provider = RealismExtensionsState.provider
    if provider == nil then
        return nil
    end

    local ok, context = pcall(
        provider.getWheelContext,
        provider,
        vehicle,
        wheel,
        hints
    )
    if not ok or type(context) ~= "table" then
        return nil
    end

    if tonumber(context.contextVersion)
        ~= RealismExtensionsState.negotiatedWheelContextVersion then
        return nil
    end

    return context
end
