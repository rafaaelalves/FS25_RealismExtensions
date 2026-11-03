-- Explicit calibration must be fail-closed and geometry-journal based.
-- This tests the command, authorization, async callback and attribution
-- without a real GIANTS engine. No terrain write occurs inside this harness.
local lines={}
local printer=print
print=function(s)lines[#lines+1]=tostring(s)end
TerrainDeformation={STATE_SUCCESS=1}
RealismExtensionsConfig={modules={
    TerrainControlledWriteTrial=true,
    TerrainCausalRecovery=true
}}
g_server={}
g_currentMission={missionInfo={isMultiplayer=false},
    missionDynamicInfo={isMultiplayer=false}}
RealismExtensionsTerrainNativeQueueProbe={
    owner={},enabled=true,pollIntegrity=function()return true end
}
RealismExtensionsTerrainNativeSpatialProbe={
    owner={},checkIntegrity=function()return true end
}
RealismExtensionsTerrainGeometryProbe={
    position={x=250,z=350},
    previous={x=250,z=350,label="beforeOneShot"}
}
local pending=nil
local postHeight=10
local allowed=true
local journal={
    unitM=1,observations={
        ["250:350"]={owned=true,observedHeightM=10}
    },
    getLoweringBudget=function()
        if not allowed then return 0,"UNTRUSTED_EDIT" end
        return 0.10,nil
    end,
    begin=function(self,key,x,z,r)
        assert(key:find("CALIBRATE:",1,true))
        assert(x==250 and z==350 and r==0.45)
        local tok={active=true,points={{key="250:350",x=x,z=z,beforeY=10}}}
        self.active=tok
        return tok,nil
    end,
    complete=function(self,token,success)
        assert(token==self.active and token.active==true)
        assert(success==false)
        token.active=false
        self.active=nil
        return {success=false}
    end,
    getHeight=function(self,x,z)
        assert(x==250 and z==350)
        return postHeight
    end,
    validateBeforeSubmit=function(self,token)
        assert(token==self.active)
        return true,nil
    end
}
local writer={
    nativeCausalPending=false,
    getQueueSize=function()return pending and 1 or 0 end,
    enqueue=function(self,brush)
        assert(not pending)
        pending=brush
        return true
    end
}
RealismExtensionsTerrainRuntime={
    geometryJournal=journal,writer=writer,nativeDamageQuarantined=false
}
dofile("scripts/terrain/TerrainControlledWriteTrial.lua")
dofile("scripts/terrain/TerrainNativeBrushCalibration.lua")
local Trial=RealismExtensionsTerrainControlledWriteTrial
local Cal=RealismExtensionsTerrainNativeBrushCalibration

-- A legacy/untrusted footprint must never reach a native submission.
allowed=false
local ok,why=Cal.run()
assert(ok==false and why:find("UNTRUSTED_EDIT",1,true))
assert(pending==nil and journal.active==nil and Trial.isArmed()==false)
allowed=true
ok,why=Cal.run()
assert(ok==true and why==nil)
assert(pending and pending.x==250 and pending.z==350)
assert(pending.depthM==0.0015 and pending.radiusM==0.45)
assert(pending.mode=="LOWER" and pending.source=="CALIBRATION")
assert(pending.massTransport==nil)
assert(pending.beforeSubmit()==true)
assert(Trial.armed==true and Trial.pending==false)
assert(Trial.beforeNative("LOWER",{pending},pending.depthM)==true)
assert(Trial.armed==false and Trial.pending==true)
assert(Trial.beforeNative("LOWER",{pending},pending.depthM)==false)
postHeight=9.945
pending.onApplied(TerrainDeformation.STATE_SUCCESS,nil,10,postHeight,0.00015)
assert(journal.active==nil)
assert(Trial.pending==false and Trial.armed==false)
assert(Trial.stats.nativeApproved==1)
assert(RealismExtensionsTerrainRuntime.nativeDamageQuarantined==true)
assert(journal.observations["250:350"].owned==false)
assert(journal.observations["250:350"].observedHeightM==postHeight)
local joined=table.concat(lines,"\n")
assert(joined:find("ONE_NATIVE_ACTUATOR_QUEUED",1,true))
assert(joined:find("maxLowerM=0.05500",1,true))
assert(joined:find("mismatchQuarantine=true",1,true))
assert(joined:find("amplitudeRatio=36.67x",1,true))

-- Regression from 2026-10-27 GIANTS runtime: 1.5mm native brush became
-- 7.78mm at one vertex, not 25mm. It is still a severe ~5.19x mismatch
-- and must be quarantined during a disposable diagnostic session.
pending=nil
Trial.reset()
RealismExtensionsTerrainRuntime.nativeDamageQuarantined=false
RealismExtensionsTerrainGeometryProbe.previous={
    x=250,z=350,label="beforeOneShot"}
ok=Cal.run()
assert(ok==true and pending~=nil)
assert(Trial.beforeNative("LOWER",{pending},pending.depthM)==true)
postHeight=10-0.007782
pending.onApplied(TerrainDeformation.STATE_SUCCESS,nil,10,postHeight,0.005859375)
assert(RealismExtensionsTerrainRuntime.nativeDamageQuarantined==true)
assert(table.concat(lines,"\n"):find("amplitudeRatio=5.19x",1,true))

-- Busy writer or missing verified baseline refuses before touching terrain.
pending=nil
Trial.reset()
RealismExtensionsTerrainRuntime.nativeDamageQuarantined=false
RealismExtensionsTerrainGeometryProbe.previous=nil
ok=Cal.run()
assert(ok==false and pending==nil)
print=printer
print("terrain_native_brush_calibration_harness: OK")
