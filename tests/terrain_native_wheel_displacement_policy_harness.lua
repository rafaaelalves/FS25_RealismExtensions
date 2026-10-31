-- Pure ownership/capability simulation; no GIANTS wheel APIs executed.
dofile("scripts/terrain/TerrainNativeWheelDisplacementPolicy.lua")
local P=RealismExtensionsTerrainNativeWheelDisplacementPolicy
local vehicle={isServer=true,isAddedToPhysics=true}
local wheel={
    displacementScale=1,supportsWheelSink=true,
    displacementAllowed=true,vehicle=vehicle
}
local silent=P.new({maxMultiplier=1.5})
local proposal=assert(silent:propose(wheel,0.7))
assert(math.abs(proposal.targetScale-1.35)<1e-8)
assert(silent:apply(wheel,proposal)==false)
assert(wheel.displacementScale==1) -- read-only is default
local external={
    displacementScale=1.75,supportsWheelSink=true,
    displacementAllowed=true,vehicle=vehicle
}
local canModify,why=silent:propose(external,0.9)
assert(canModify==nil and why=="EXTERNAL_DISPLACEMENT_OWNER")
local client={
    displacementScale=1,supportsWheelSink=false,
    displacementAllowed=true,vehicle=vehicle
}
assert(silent:propose(client,0.5)==nil)
local writes={}
local function writeNative(physics,scale)
    writes[#writes+1]=scale
    physics.appliedNativeScale=scale
    return true
end
local policy=P.new({
    researchWrite=true,writeNative=writeNative,
    baseScale=1,maxMultiplier=1.5
})
local initial=assert(policy:propose(wheel,1))
assert(initial.targetScale==1.5)
assert(policy:apply(wheel,initial)==true)
assert(wheel.displacementScale==1.5 and wheel.appliedNativeScale==1.5)
-- Replanning on our own 1.5x is legal; never multiply it again to 2.25.
local same=assert(policy:propose(wheel,1))
assert(same.targetScale==1.5)
assert(policy:apply(wheel,same)==true)
-- Dry/hard-frozen yield returns control to native unmodified strength.
local dry=assert(policy:propose(wheel,0))
assert(dry.targetScale==1)
assert(policy:apply(wheel,dry)==true)
assert(wheel.displacementScale==1 and policy.owned[wheel]==nil)
-- Refuse a stale proposal after an external mod changes ownership.
local old=assert(policy:propose(wheel,0.5))
wheel.displacementScale=1.75
assert(policy:apply(wheel,old)==false)
assert(wheel.displacementScale==1.75)
assert(policy:propose(wheel,0.5)==nil)
wheel.displacementScale=1
-- After our write, if someone changes scale we MUST NOT restore over them.
local now=assert(policy:propose(wheel,0.8))
assert(policy:apply(wheel,now)==true)
wheel.displacementScale=1.8
assert(policy:release(wheel)==false)
assert(wheel.displacementScale==1.8 and policy.owned[wheel]==nil)
assert(policy.stats.drift>=1)
-- Normal release returns a still-owned wheel to its baseline.
wheel.displacementScale=1
local pass=assert(policy:propose(wheel,0.6))
assert(policy:apply(wheel,pass)==true)
assert(policy:release(wheel)==true)
assert(wheel.displacementScale==1)
assert(policy.owned[wheel]==nil)
assert(#writes==6) -- two 1.5x writes, release, drift setup, final setup/release
print("terrain_native_wheel_displacement_policy_harness: OK")
