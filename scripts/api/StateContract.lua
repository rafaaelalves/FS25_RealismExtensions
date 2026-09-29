-- Public consumer-side contract for normalized realism state.
--
-- 0.0.1.0 intentionally provides no specialist adapters. RealismExtensions
-- must not reach into MR/Mud/Reifen/RMS internals from feature modules.
-- A future provider boundary (preferably supplied by RealismCompatibility)
-- will populate this contract.

RealismExtensionsState = {
    API_VERSION = 1,
    provider = nil
}

function RealismExtensionsState.registerProvider(provider)
    if type(provider) ~= "table" then
        return false, "provider must be a table"
    end
    if type(provider.getWheelContext) ~= "function" then
        return false, "provider.getWheelContext is required"
    end

    RealismExtensionsState.provider = provider
    return true
end

function RealismExtensionsState.clearProvider(provider)
    if provider == nil or RealismExtensionsState.provider == provider then
        RealismExtensionsState.provider = nil
    end
end

function RealismExtensionsState.getWheelContext(vehicle, wheel)
    local provider = RealismExtensionsState.provider
    if provider == nil then
        return nil
    end

    return provider:getWheelContext(vehicle, wheel)
end
