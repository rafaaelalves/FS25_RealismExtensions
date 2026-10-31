-- A read-only integration contract for the active RE specialization.
-- The injected native setter exercises the deliberately dormant research
-- candidate; observe() never calls it.
dofile("scripts/terrain/TerrainNativeWheelBridge.lua")
local Bridge=RealismExtensionsTerrainNativeWheelBridge
local calls={}
setWheelShapeTerrainDisplacement=function(node,shape,scale)
    calls[#calls+1]={node=node,shape=shape,scale=scale}
end
local server={isServer=true,isAddedToPhysics=true}
local wheel={node=1337}
local physics={wheel=wheel,vehicle=server,wheelShape=77,
    displacementScale=1,supportsWheelSink=true,
    displacementAllowed=true}
wheel.physics=physics

local available,why=Bridge.observe(server,wheel)
assert(available==true and why==nil)
assert(Bridge.stats.samples==1 and Bridge.stats.ready==1)
assert(Bridge.stats.baseScale==1 and Bridge.stats.distinctWheels==1)
assert(#calls==0 and physics.displacementScale==1)
Bridge.observe(server,wheel)
assert(Bridge.stats.distinctWheels==1 and Bridge.stats.scaleChanges==0)
physics.displacementScale=1.75
available,why=Bridge.observe(server,wheel)
assert(available==true and why==nil)
assert(Bridge.stats.nonDefaultScale==1 and Bridge.stats.externalCandidates==1)
assert(Bridge.stats.scaleChanges==1)
assert(Bridge.stats.nonDefaultMinScale==1.75)
assert(#calls==0) -- non-default discovered passively, not overwritten

local client={isServer=false,isAddedToPhysics=true}
assert(Bridge.observe(client,wheel)==false)
assert(Bridge.stats.notServer==1)
local missingNode={physics=physics,node=nil}
assert(Bridge.observe(server,missingNode)==false)
assert(Bridge.stats.wheelNodeMissing==1)
local disabled={node=1337,physics={
    displacementScale=1,displacementAllowed=false,
    supportsWheelSink=true,wheelShape=77}}
assert(Bridge.observe(server,disabled)==false)
assert(Bridge.stats.disabledByWheel==1)
local shapeMissing={node=1337,physics={
    displacementScale=1,displacementAllowed=true,
    supportsWheelSink=true,wheelShape=0}}
assert(Bridge.observe(server,shapeMissing)==false)
assert(Bridge.stats.noNativeShape==1)
assert(#calls==0)

-- Explicit *test-only* candidate can call the native setter, but neither
-- regular passively-observed wheels nor any runtime RE function calls it.
Platform={gameplay={wheelTerrainDisplacement=true}}
local apply,reason=Bridge.nativeSetterCandidate(physics,1.4)
assert(apply==true and reason==nil)
assert(#calls==1)
assert(calls[1].node==1337 and calls[1].shape==77)
assert(calls[1].scale==1.4)
assert(physics.displacementScale==1.75) -- native caller owns Lua field
Platform.gameplay.wheelTerrainDisplacement=false
assert(Bridge.nativeSetterCandidate(physics,1.4)==false)
assert(#calls==1)
Platform.gameplay.wheelTerrainDisplacement=true
assert(Bridge.nativeSetterCandidate(physics,5)==false)
assert(#calls==1)
physics.wheelShape=0
assert(Bridge.nativeSetterCandidate(physics,1.2)==false)
assert(#calls==1)
Bridge.reset()
assert(Bridge.stats.samples==0 and Bridge.stats.distinctWheels==0)
print("terrain_native_wheel_bridge_harness: OK")
