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
assert(string.find(badReason, "provider API version mismatch", 1, true) ~= nil)

_G.RealismCompatStateProvider = provider
local discovered, discoverReason = RealismExtensionsState.discoverProvider()
assert(discovered == true, tostring(discoverReason))
assert(RealismExtensionsState.getWheelContext({}, {}) ~= nil)

-- A context with a mismatched schema must fail closed.
provider.getWheelContext = function()
    return { contextVersion = 999, grounded = true }
end
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)

print("state_contract_harness: OK")
