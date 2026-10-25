-- Synthetic native-grid field restoration integration. GIANTS writer is
-- intentionally mocked to distinguish accepted queue from completed geometry.
dofile("scripts/terrain/TerrainGeometryJournal.lua")
dofile("scripts/terrain/TerrainCausalRecovery.lua")
local C=RealismExtensionsTerrainCausalRecovery
local Journal=RealismExtensionsTerrainGeometryJournal
local height={}
local function key(x,z) return x..":"..z end
local function sample(x,z) return height[key(x,z)] or 100 end
local function set(x,z,y) height[key(x,z)]=y end
local j=Journal.new(42,{unitM=1,sample=sample})
local queued={}
local historyCells={}
local fakeHistory={
    get=function(self,x,z) return historyCells[key(x,z)] end,
    applyRecoveryAt=function(self,x,z,amount)
        local h=historyCells[key(x,z)]
        if h then h.rutDepthM=math.max(0,(h.rutDepthM or 0)-amount) end
    end
}
RealismExtensionsTerrainRuntime={
    geometryJournal=j,history=fakeHistory,
    writer={enqueue=function(self,brush)
        assert(brush.mode=="TARGET" and brush.source=="RECOVERY")
        assert(brush.skipRecoveryGeometryProbe==true)
        assert(brush.radiusM<1 and brush.radiusM>0.5)
        queued[#queued+1]=brush
        return true
    end}
}
TerrainDeformation={STATE_SUCCESS=1}
RealismExtensionsConfig={modules={
    TerrainDeformation=true,TerrainRecovery=true,
    TerrainGeometryJournal=true,TerrainCausalRecovery=true
}}
g_server={}
g_currentMission={time=1000}
local contactBlock=false
RealismExtensionsLoadedContactRegistry={
    overlapsCircle=function() return contactBlock end
}
local area={xs=-0.7,zs=-0.7,ux=1.4,uz=0,vx=0,vz=1.4}
local otherArea={xs=3,zs=3,ux=1,uz=0,vx=0,vz=1}
local profile={id="PLOW",surfaceRegrade01=0.9}
assert(C.enabled()==true)
RealismExtensionsConfig.modules.TerrainCausalRecovery=false
assert(C.enabled()==false)
assert(C.observeWorkedArea(area,profile)==0)
RealismExtensionsConfig.modules.TerrainCausalRecovery=true
-- Physical rut exists only after a completed LOWER callback.
local op=assert(j:begin("wheel:0",0,0,0.3))
set(0,0,99.7)
assert(j:complete(op,true).maxLowerM>0.29)
historyCells[key(0,0)]={rutDepthM=0.08}
assert(C.observeWorkedArea(otherArea,profile)==0)
assert(C.observeWorkedArea(area,profile)==1)
assert(C.observeWorkedArea(area,profile)==0) -- no duplicate work fragment
assert(#queued==0)
contactBlock=true
C.update()
assert(C.stats.blocked==1 and #queued==0 and C.inFlight==nil)
contactBlock=false
g_currentMission.time=1500
C.update()
assert(#queued==1 and C.inFlight~=nil)
assert(math.abs(queued[1].targetY-99.97)<0.000001)
-- Job accepted into RE queue is NOT yet submitted to the native engine.
assert(C.inFlight.startMs==nil)
g_currentMission.time=1500+C.DEFAULTS.inFlightTimeoutMs+100
C.update()
assert(C.inFlight~=nil and j.pendingCount==1
    and (C.stats.callbackTimeoutAlerts or 0)==0,
    "queued recovery cannot expire its journal lock before native submit")
queued[1].onSubmitted()
assert(C.inFlight.startMs==g_currentMission.time)
g_currentMission.time=g_currentMission.time+C.DEFAULTS.inFlightTimeoutMs+100
C.update()
assert(C.inFlight~=nil and j.pendingCount==1
    and C.stats.callbackTimeoutAlerts==1,
    "slow native completion must report timeout but retain lock")
-- Enqueue did NOT reduce the mechanical debt or restore physical height.
assert(historyCells[key(0,0)].rutDepthM==0.08)
assert(math.abs(j.observations["0:0"].observedHeightM-99.7)<0.000001)
-- Actual GIANTS callback produces physical height movement:
set(0,0,99.97)
queued[1].onApplied(1)
assert(C.inFlight==nil and C.stats.improved==1)
assert(C.stats.gainSumM>0.26 and C.stats.maxGainM>0.26)
assert(C.stats.physicallyClosed==0)
assert(j.observations["0:0"].owned==true)
assert(historyCells[key(0,0)].rutDepthM==0.08) -- not yet closed
queued[1].onApplied(1) -- callback may repeat; must not double count
assert(C.stats.improved==1)
g_currentMission.time=2100
assert(C.observeWorkedArea(area,profile)==1)
C.update()
assert(#queued==2)
set(0,0,99.999)
queued[2].onApplied(1)
assert(j.observations["0:0"]==nil) -- confirmed restoration
assert(historyCells[key(0,0)].rutDepthM==0)
assert(C.stats.improved==2)
assert(C.stats.physicallyClosed==1 and C.stats.gainSumM>0.29)
-- Unowned, terraformed or legacy deformation cannot be flattened by RE.
set(0,0,99.6)
g_currentMission.time=3000
assert(C.observeWorkedArea(area,profile)==0)
local newlyLowered=assert(j:begin("wheel:retry",0,0,0.3))
set(0,0,99.5)
assert(j:complete(newlyLowered,true).loweredVertices>=1)
local e=j.observations["0:0"]
assert(e.owned==true and math.abs(e.preREHeightM-99.6)<0.000001)
set(0,0,99.3) -- unexplained external edit
assert(C.observeWorkedArea(area,profile)==0)
assert(j.observations["0:0"].owned==false)
-- Command failure releases ownership lock and does not clear debt.
C.reset()
local b=assert(j:begin("wheel:2",4,4,0.3))
set(4,4,99.9)
assert(j:complete(b,true).loweredVertices>0)
local area2={xs=3.4,zs=3.4,ux=1.2,uz=0,vx=0,vz=1.2}
g_currentMission.time=4000
assert(C.observeWorkedArea(area2,profile)==1)
C.update()
assert(#queued==3)
queued[3].onApplied(false)
assert(C.inFlight==nil and j.pendingCount==0 and C.stats.failed==1)
assert(j.observations["4:4"].owned==true)
-- A 25cm subsoiler strip may partially touch a 1m native grid vertex
-- despite never containing its exact centre; do not lose its worked area.
C.reset()
local narrowLower=assert(j:begin("wheel:narrow",8,0,0.3))
set(8,0,99.93)
assert(j:complete(narrowLower,true).loweredVertices==1)
local narrow={xs=8.30,zs=-0.20,ux=0.25,uz=0,vx=0,vz=0.4}
local sub={id="SUBSOILER",surfaceRegrade01=0.35}
assert(C.observeWorkedArea(narrow,sub)==1)
assert(C.stats.toolSUBSOILER==1)
assert(C.observeWorkedArea({xs=8.60,zs=-0.20,ux=0.2,uz=0,
    vx=0,vz=0.4},sub)==0) -- beyond the half-grid support margin
assert(C.stats.noBaselineVisits>=0)
-- Periodic recovery must not accept arbitrary owners, absent references
-- or duplicate scheduling on the same verified native vertex.
C.reset()
local ok,why=C.enqueueAuthorizedVertex(8,0,0.5,"PLAYER",120000)
assert(ok==false and why=="UNAUTHORIZED_CAUSE")
ok,why=C.enqueueAuthorizedVertex(9,0,0.5,"NEIGHBOR",120000)
assert(ok==false and why=="NO_TRUSTED_DEBT")
ok,why=C.enqueueAuthorizedVertex(8,0,0.5,"NEIGHBOR",120000)
assert(ok==true)
ok,why=C.enqueueAuthorizedVertex(8,0,0.5,"NEIGHBOR",120000)
assert(ok==false and why=="ALREADY_PENDING")
-- Monthly authorization is rechecked just before writer submission, not
-- trusted merely because the vertex was queued at the start of the month.
local totalQueued=#queued
g_currentMission.time=5000
C.update()  -- no ownership policy present, so execution must fail closed
assert(#queued==totalQueued)
assert((C.stats.unauthorized or 0)==1)
print("terrain_causal_recovery_harness: OK")
