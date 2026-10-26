-- Test the fail-closed read-only/default, opt-in observer requirement and
-- one-shot native wheel admission. No physical heightmap access is involved.
RealismExtensionsConfig={modules={
    TerrainControlledWriteTrial=true,
    TerrainCausalRecovery=true,
    TerrainQueueSubmissionProbe=false
}}
g_server={}
g_currentMission={missionInfo={isMultiplayer=false},
    missionDynamicInfo={isMultiplayer=false}}
RealismExtensionsTerrainRuntime={
    geometryJournal={unitM=1},nativeDamageQuarantined=false
}
local messages={}
local origPrint=print
print=function(msg) messages[#messages+1]=tostring(msg) end
dofile("scripts/terrain/TerrainControlledWriteTrial.lua")
local Trial=RealismExtensionsTerrainControlledWriteTrial
assert(Trial.enabled()==true)
assert(Trial.isArmed()==false)
assert(Trial.beforeNative("LOWER",{
    {radiusM=0.4,trialTicket=1,onApplied=function() end}},0.002)==false)
assert(Trial.stats.nativeRejected==1)
assert(Trial.tryReserve()==nil)

local q={owner={},enabled=true,pollIntegrity=function() return true end}
local sp={owner={},checkIntegrity=function() return true end}
RealismExtensionsTerrainNativeQueueProbe=q
RealismExtensionsTerrainNativeSpatialProbe=sp

-- Refusal must be explicit when observer integrity or causal ownership fails.
sp.owner=nil
Trial:consoleCommand("arm")
assert(Trial.isArmed()==false and Trial.stats.deniedArm==1)
sp.owner={}
Trial:consoleCommand("arm")
assert(Trial.isArmed()==true)
local id=assert(Trial.tryReserve())
assert(Trial.tryReserve()==nil) -- never two queued requests
local brush={radiusM=0.50,trialTicket=id,onApplied=function()end}
assert(Trial.beforeNative("TARGET",{brush},0.002)==false)
assert(Trial.armed==true and Trial.reserved==id)
assert(Trial.beforeNative("LOWER",{brush},0.002)==true)
assert(Trial.armed==false and Trial.pending==true)
assert(Trial.beforeNative("LOWER",{brush},0.002)==false)
assert(Trial.callback(id)==true)
assert(Trial.callback(id)==false)
assert(Trial.isArmed()==false and Trial.pending==false)
assert(Trial.stats.nativeApproved==1)
assert(Trial.stats.callbackOutcomes==1)

-- A missing native response cannot rearm automatically.
Trial:consoleCommand("arm")
local n=assert(Trial.tryReserve())
assert(Trial.beforeNative("LOWER",{
    {radiusM=2,trialTicket=n,onApplied=function()end}},0.002)==false)
assert(Trial.abandon(n)==true)
assert(Trial.armed==false)
Trial:consoleCommand("arm")
n=assert(Trial.tryReserve())
assert(Trial.beforeNative("LOWER",{
    {radiusM=0.5,trialTicket=n,onApplied=function()end}},0.004)==false)
assert(Trial.abandon(n)==true)

-- Cancel is immediate before native submission; cannot erase in-flight work.
Trial:consoleCommand("arm")
n=assert(Trial.tryReserve())
Trial:consoleCommand("cancel")
assert(Trial.armed==false and Trial.reserved==nil)
Trial:consoleCommand("arm")
n=assert(Trial.tryReserve())
assert(Trial.beforeNative("LOWER",{
    {radiusM=0.5,trialTicket=n,onApplied=function()end}},0.002)==true)
Trial:consoleCommand("cancel")
assert(Trial.pending==true)
assert(Trial.callback(n)==true)

-- In multiplayer, the experiment must never arm.
g_currentMission.missionDynamicInfo.isMultiplayer=true
Trial:consoleCommand("arm")
assert(Trial.armed==false)
g_currentMission.missionDynamicInfo.isMultiplayer=false
RealismExtensionsTerrainRuntime.nativeDamageQuarantined=true
Trial:consoleCommand("arm")
assert(Trial.armed==false)
RealismExtensionsTerrainRuntime.nativeDamageQuarantined=false

local added={}
addConsoleCommand=function(name,...) added[name]=true end
removeConsoleCommand=function(name) added[name]=nil end
assert(Trial.installCommands()==true)
assert(added.reTerrainTrial==true)
Trial.uninstallCommands()
assert(added.reTerrainTrial==nil)
assert(Trial.stats.nativeApproved==0 and Trial.armed==false)

RealismExtensionsConfig.modules.TerrainControlledWriteTrial=false
assert(Trial.enabled()==false)
assert(Trial.beforeNative("TARGET",{},1)==true) -- not a release guard
print=origPrint
print("terrain_controlled_write_trial_harness: OK")
