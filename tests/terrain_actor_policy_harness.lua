dofile("scripts/terrain/TerrainActorPolicy.lua")

local P=RealismExtensionsTerrainActorPolicy

local player={}
local p=P.classify(player)
assert(p.kind=="PLAYER")
assert(p.aiActive==false)
assert(P.getSuppressionReason(p,false)==nil)
assert(P.getModelOverrides(p)==nil)

local field={
    spec_aiFieldWorker={isActive=true,isTurning=false},
    getIsAIActive=function() return true end,
    getIsFieldWorkActive=function() return true end,
    getAIFieldWorkerIsTurning=function() return false end
}
local a=P.classify(field)
assert(a.kind=="AI_FIELD")
assert(a.fieldWorkActive==true)
assert(P.getSuppressionReason(a,false)==nil)
assert(P.getModelOverrides(a)==nil)

field.getAIFieldWorkerIsTurning=function() return true end
a=P.classify(field)
assert(P.getSuppressionReason(a,false)=="AI_TURN")

field.getAIFieldWorkerIsTurning=function() return false end
a=P.classify(field)
assert(P.getSuppressionReason(a,true)=="AI_STATIONARY_SPIN")

local generic={
    getIsAIActive=function() return true end
}
local g=P.classify(generic)
assert(g.kind=="AI_GENERIC")
assert(g.aiActive==true)
assert(g.fieldWorkActive==false)
assert(P.getSuppressionReason(g,false)==nil)
assert(P.getModelOverrides(g)==nil)

print("terrain_actor_policy_harness: OK")
