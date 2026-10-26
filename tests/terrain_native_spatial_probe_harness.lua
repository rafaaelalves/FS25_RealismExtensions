-- No engine required. Validate direct native apply and spatial correlation
-- without mutating any terrain heights, callback objects or hook arguments.
dofile("scripts/terrain/TerrainNativeSpatialProbe.lua")
local P=RealismExtensionsTerrainNativeSpatialProbe
local calls={}
local Native={}
function Native:addSoftCircleBrush(x,z,r,hardness,strength,material)
    calls[#calls+1]={"circle",x,z,r,hardness,strength,material}
    return 7,nil,"brush-ok"
end
function Native:addSoftSquareBrush(x,z,side,hardness,strength,material)
    calls[#calls+1]={"square",x,z,side,hardness,strength,material}
    return 8,nil,"square-ok"
end
function Native:apply(preview,callbackName,target,extra)
    calls[#calls+1]={"apply",preview,callbackName,target,extra}
    return "engine",nil,15
end
local baseCircle=Native.addSoftCircleBrush
local baseSquare=Native.addSoftSquareBrush
local baseApply=Native.apply
local w={nativeCausalPending=true}
RealismExtensionsTerrainRuntime={writer=w}
assert(P.install(Native)==true)
local reDef=setmetatable({}, {__index=Native})
local theirDef=setmetatable({}, {__index=Native})
local farDef=setmetatable({}, {__index=Native})
local unknownDef=setmetatable({}, {__index=Native})
local reTarget={owner=w,deformation=reDef,
    brushes={{x=100,z=100,radiusM=0.6}}}
P.captureRE(reTarget)
local x,y,z=theirDef:addSoftCircleBrush(100.3,100,0.5,0.8,1,-1)
assert(x==7 and y==nil and z=="brush-ok")
assert(P.classify(theirDef)=="overlap")
x,y,z=theirDef:apply(false,"terrainCallback",{other="TerraFarm"},31)
assert(x=="engine" and y==nil and z==15)
assert(P.stats.directDuringREPending==1)
assert(P.stats.spatialOverlapDirect==1)
assert(calls[2][4].other=="TerraFarm" and calls[2][5]==31)
assert(P.envelopes[theirDef].count==1)

farDef:addSoftCircleBrush(500,500,0.5,0.8,1,-1)
assert(P.classify(farDef)=="none")
farDef:apply(false,"terrainCallback",{})
assert(P.stats.directDuringREPending==2)
assert(P.stats.spatialOverlapDirect==1)
unknownDef:apply(false,"terrainCallback",{})
assert(P.stats.directDuringREPending==3)
assert(P.stats.unknownGeometry==1)

-- Best-effort Lua stack hints are restricted to sanitized mod folder and
-- filename only. A wrapper may be the caller, not the original mod.
local getInfo=debug.getinfo
debug.getinfo=function() return {
    source="@C:/Users/Somebody/Documents/My Games/FarmingSimulator2025/mods/FS25_TerraFarm/scripts/landscaping/LandscapingInput.lua"
} end
local site=P.callsiteHint(3)
assert(site=="FS25_TerraFarm/LandscapingInput.lua")
local hintDef=setmetatable({}, {__index=Native})
hintDef:addSoftCircleBrush(700,700,0.5,0.8,1,-1)
hintDef:apply(false,"callback",{})
assert(P.stats.sourceHints[site]==1)
assert(P.formatSnapshot():find("FS25_TerraFarm/LandscapingInput.lua",1,true))
assert(not P.formatSnapshot():find("Somebody",1,true))
debug.getinfo=nil
hintDef:apply(false,"callback",{})
assert(P.stats.sourceHintsUnavailable>=1)
debug.getinfo=getInfo

-- Native queue submission uses already-captured geometry and the RE writer's
-- window but must never assume spatial overlap means an actual height change.
P.onQueueSubmission(theirDef,true)
P.onQueueSubmission(farDef,true)
P.onQueueSubmission(unknownDef,true)
assert(P.stats.queueSubmissions==3)
assert(P.stats.spatialOverlapQueue==1)
assert(P.stats.unknownGeometry==2)
local square=setmetatable({}, {__index=Native})
square:addSoftSquareBrush(101,100,2,0.4,0.8,-1)
assert(P.classify(square)=="overlap") -- square corner covers rut envelope
assert(P.stats.capturedBrushes==4)

-- Only explicit writer-owned direct calls count as RE. Never as external.
reDef:apply(false,"done",reTarget)
assert(P.stats.directRESubmissions==1)
assert(P.stats.directDuringREPending==5)

-- A native method throwing must throw unchanged through the pass-through.
function Native.badApply(self) error("native-failure") end
local eClass={
    apply=function() error("direct-native-failed") end,
    addSoftCircleBrush=function() return true end
}
assert(P.install(eClass)==false) -- cannot overwrite active class
P.shutdown()
assert(Native.addSoftCircleBrush==baseCircle)
assert(Native.addSoftSquareBrush==baseSquare)
assert(Native.apply==baseApply)
assert(P.install(eClass)==true)
local eObj=setmetatable({}, {__index=eClass})
local ok,err=pcall(eObj.apply,eObj,false,"done",{})
assert(ok==false and err:find("direct-native-failed",1,true))
P.shutdown()

-- Later wrappers retain old probes but they must remain pass-through and
-- remain inert across map loads (no doubled counts).
assert(P.install(Native)==true)
local old=Native.apply
Native.apply=function(self,...) return old(self,...) end
local later=Native.apply
assert(P.checkIntegrity()==false)
P.shutdown()
assert(Native.apply==later)
local before=P.stats.directSubmissions
local t=setmetatable({}, {__index=Native})
t:apply(false,"afterUnload",{})
assert(P.stats.directSubmissions==before)
assert(P.install(Native)==true)
t:apply(false,"newMap",{})
assert(P.stats.directSubmissions==before+1)
P.shutdown()
assert(Native.apply==later)

-- If the engine class lacks apply(), research hook fails closed.
assert(P.install({addSoftCircleBrush=function()end})==false)
local summary=P.formatSnapshot()
assert(summary:find("overlappingBrushEnvelopesDirect=1",1,true))
print("terrain_native_spatial_probe_harness: OK")
