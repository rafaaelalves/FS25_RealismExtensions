-- StateContract v2 harness.

dofile("scripts/api/StateContract.lua")

assert(RealismExtensionsState.API_VERSION == 2)
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)

local provider = {
    API_VERSION = 1,
    WHEEL_CONTEXT_VERSION = 1,
    getProviderInfo = function(self)
        return {
            id = "test-provider",
            apiVersion = self.API_VERSION,
            wheelContextVersion = self.WHEEL_CONTEXT_VERSION
        }
    end,
    getWheelContext = function(self, vehicle, wheel)
        return {
            contextVersion = 1,
            grounded = true,
            longitudinalSlip = 0.42,
            lateralSlip = -0.06,
            physicalGroundWetness = 0.75,
            wheelLoadN = 22000,
            sinkDepthM = 0.08
        }
    end
}

local ok, reason = RealismExtensionsState.registerProvider(provider)
assert(ok == true, tostring(reason))

local available, statusReason, info = RealismExtensionsState.getProviderStatus()
assert(available == true)
assert(statusReason == nil)
assert(info.id == "test-provider")

local state = RealismExtensionsState.getWheelContext({}, {})
assert(state ~= nil)
assert(state.grounded == true)
assert(state.longitudinalSlip == 0.42)
assert(state.lateralSlip == -0.06)
assert(state.physicalGroundWetness == 0.75)
assert(state.wheelLoadN == 22000)
assert(state.sinkDepthM == 0.08)

RealismExtensionsState.clearProvider(provider)
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)

local bad = {
    API_VERSION = 2,
    WHEEL_CONTEXT_VERSION = 1,
    getWheelContext = function() return { contextVersion = 1 } end
}
local badOk, badReason = RealismExtensionsState.registerProvider(bad)
assert(badOk == false)
assert(string.find(badReason, "version pair mismatch", 1, true) ~= nil)

_G.FS25_RealismCompatibility = {
    RealismCompatStateProvider = provider
}
_G.RealismCompatStateProvider = nil

local discovered, discoverReason = RealismExtensionsState.discoverProvider()
assert(discovered == true, tostring(discoverReason))
assert(RealismExtensionsState.getWheelContext({}, {}) ~= nil)
assert(RealismExtensionsState.provider == provider)

-- A context with a mismatched schema must fail closed.
provider.getWheelContext = function()
    return { contextVersion = 999, grounded = true }
end
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)

print("state_contract_harness: OK")


-- Optional hints must be forwarded without changing the provider contract version.
local hintedSeen = nil
local hintProvider = {
    API_VERSION = 1,
    WHEEL_CONTEXT_VERSION = 1,
    getWheelContext = function(self, vehicle, wheel, hints)
        hintedSeen = hints
        return { contextVersion = 1, grounded = true }
    end
}
assert(RealismExtensionsState.registerProvider(hintProvider))
local hintedCtx = RealismExtensionsState.getWheelContext({}, {}, {
    speedKph = 3.5,
    wheelSurfaceSpeedMps = 1.25
})
assert(hintedCtx ~= nil)
assert(hintedSeen ~= nil)
assert(hintedSeen.speedKph == 3.5)
assert(hintedSeen.wheelSurfaceSpeedMps == 1.25)

-- RC 0.2.0.2 advertises API v2 / context v2. It preserves terrain's
-- historical fields while distinguishing tire-contact width vs wheel span.
local rc2 = {
    API_VERSION = 2,
    WHEEL_CONTEXT_VERSION = 2,
    getProviderInfo = function(self)
        return {
            id = "RC-v2",
            apiVersion = self.API_VERSION,
            wheelContextVersion = self.WHEEL_CONTEXT_VERSION
        }
    end,
    getWheelContext = function(self)
        return {
            contextVersion = 2,
            grounded = true, soilContact = true,
            longitudinalSlip = 0.31,
            physicalGroundWetness = 0.60,
            structuralRadiusM = 0.85,
            tireWidthM = 0.62, supportWidthM = 1.24,
            supportContactWidthM = 1.24,
            supportSpanM = 1.46, supportGapWidthM = 0.22,
            supportKind = "MULTI",
            supportSegmentCount = 2,
            isCrawler = false,
            wheelLoadN = 36000, sinkDepthM = 0.04
        }
    end
}
assert(RealismExtensionsState.registerProvider(rc2))
local state2 = RealismExtensionsState.getWheelContext({}, {})
assert(state2 ~= nil and state2.contextVersion == 2)
assert(state2.longitudinalSlip == 0.31)
assert(state2.physicalGroundWetness == 0.60)
assert(state2.wheelLoadN == 36000)
assert(state2.supportWidthM == 1.24 and state2.supportSpanM == 1.46)
assert(state2.supportSegmentCount == 2)
local _, _, v2Info = RealismExtensionsState.getProviderStatus()
assert(v2Info.apiVersion == 2)
assert(RealismExtensionsState.negotiatedWheelContextVersion == 2)
-- A returned v1 record from an accepted v2 provider is not v2.
rc2.getWheelContext = function() return { contextVersion = 1 } end
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)
RealismExtensionsState.clearProvider(rc2)
assert(RealismExtensionsState.negotiatedWheelContextVersion == nil)

-- Do not silently approve newer or mixed API revisions.
local unknown = {
    API_VERSION = 3,
    WHEEL_CONTEXT_VERSION = 3,
    getWheelContext = function() return {contextVersion = 3} end
}
local accepted, unsupportedReason =
    RealismExtensionsState.registerProvider(unknown)
assert(accepted == false)
assert(string.find(unsupportedReason, "unsupported provider API", 1, true))
local mixed = {
    API_VERSION = 1,
    WHEEL_CONTEXT_VERSION = 2,
    getWheelContext = function() return {contextVersion = 2} end
}
accepted, unsupportedReason = RealismExtensionsState.registerProvider(mixed)
assert(accepted == false)
assert(string.find(unsupportedReason, "version pair mismatch", 1, true))
