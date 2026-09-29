-- Minimal Lua harness for the infrastructure-only 0.0.1.0 contract.

dofile("scripts/api/StateContract.lua")

assert(RealismExtensionsState.API_VERSION == 1)
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)

local provider = {
    getWheelContext = function(self, vehicle, wheel)
        return {
            grounded = true,
            longitudinalSlip = 0.42,
            localWetness = 0.75
        }
    end
}

local ok, reason = RealismExtensionsState.registerProvider(provider)
assert(ok == true, tostring(reason))

local state = RealismExtensionsState.getWheelContext({}, {})
assert(state ~= nil)
assert(state.grounded == true)
assert(state.longitudinalSlip == 0.42)
assert(state.localWetness == 0.75)

RealismExtensionsState.clearProvider(provider)
assert(RealismExtensionsState.getWheelContext({}, {}) == nil)

print("state_contract_harness: OK")
