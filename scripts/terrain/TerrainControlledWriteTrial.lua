-- Fail-closed, game-session-only one-shot test for the *native additive*
-- RE wheel terrain writer. No actor/terrain writes in default OBSERVE mode.
-- This is a TEST PROFILE, never a substitute for map backups or physics QA.
RealismExtensionsTerrainControlledWriteTrial =
    RealismExtensionsTerrainControlledWriteTrial or {}
local Trial=RealismExtensionsTerrainControlledWriteTrial
Trial.VERSION=1
Trial.MAX_REQUEST_M=0.003001
Trial.MAX_RADIUS_M=0.60

local function speak(s)
    local msg="RE Terrain Trial | "..tostring(s)
    if type(print)=="function" then print(msg) end
    return msg
end

function Trial.enabled()
    return RealismExtensionsConfig~=nil
        and RealismExtensionsConfig.modules~=nil
        and RealismExtensionsConfig.modules.TerrainControlledWriteTrial==true
end

function Trial.reset()
    Trial.armed=false
    Trial.reserved=nil
    Trial.pending=false
    Trial.nextId=0
    Trial.stats={intents=0,intentsDenied=0,reservations=0,
        nativeApproved=0,nativeRejected=0,callbackOutcomes=0,
        armRequests=0,deniedArm=0}
end

function Trial.isArmed()
    return Trial.enabled() and Trial.armed and Trial.reserved==nil
        and Trial.pending~=true
end

function Trial.tryReserve()
    if not Trial.isArmed() then
        Trial.stats.intentsDenied=Trial.stats.intentsDenied+1
        return nil,"TRIAL_NOT_ARMED_OR_RESERVED"
    end
    Trial.nextId=Trial.nextId+1
    local id=Trial.nextId
    Trial.reserved=id
    Trial.stats.intents=Trial.stats.intents+1
    Trial.stats.reservations=Trial.stats.reservations+1
    return id,nil
end

function Trial.abandon(id)
    if Trial.reserved==id and Trial.pending~=true then
        Trial.reserved=nil
        -- A failed enqueue does not grant permission to retry endlessly.
        Trial.armed=false
        return true
    end
    return false
end

function Trial.beforeNative(mode,brushes,amount)
    if not Trial.enabled() then return true,nil end
    local b=type(brushes)=="table" and brushes[1] or nil
    local validRequest=type(brushes)=="table" and #brushes==1
        and mode=="LOWER" and type(b)=="table"
        and type(b.onApplied)=="function"
        and type(b.trialTicket)=="number"
        and b.trialTicket==Trial.reserved
        and Trial.armed==true and Trial.pending~=true
        and type(amount)=="number" and amount>0
        and amount<=Trial.MAX_REQUEST_M
        and type(b.radiusM)=="number" and b.radiusM>0
        and b.radiusM<=Trial.MAX_RADIUS_M
        and g_server~=nil
    if not validRequest then
        Trial.stats.nativeRejected=Trial.stats.nativeRejected+1
        return false,"TRIAL_RE_NATIVE_WRITE_BLOCKED"
    end
    -- Important: consume the one-shot *before* the native submission, even
    -- when a future preflight/engine error prevents the actual write.
    Trial.armed=false
    Trial.pending=true
    Trial.stats.nativeApproved=Trial.stats.nativeApproved+1
    speak(string.format(
        "TerrainTrialNativeSubmit | ticket=%d x=%.3f z=%.3f depth=%.5fm radius=%.3fm (one-shot consumed BEFORE native call)",
        b.trialTicket,tonumber(b.x) or 0,tonumber(b.z) or 0,
        amount,tonumber(b.radiusM) or 0
    ))
    return true,nil
end

function Trial.callback(id,state,volume)
    if type(id)=="number" and Trial.reserved==id then
        Trial.reserved=nil
        Trial.pending=false
        Trial.armed=false
        Trial.stats.callbackOutcomes=Trial.stats.callbackOutcomes+1
        speak(string.format(
            "TerrainTrialNativeCallback | ticket=%d state=%s volumeM3=%s disarmed=true",
            id,tostring(state),
            type(volume)=="number" and tostring(volume) or "unknown"))
        return true
    end
    return false
end

function Trial.isSinglePlayer()
    if g_server==nil or g_currentMission==nil then
        return false
    end
    local mission=g_currentMission
    local d=mission.missionDynamicInfo
    local i=mission.missionInfo
    if (type(d)=="table" and d.isMultiplayer==true)
        or (type(i)=="table" and i.isMultiplayer==true) then
        return false
    end
    return true
end

function Trial:consoleCommand(action)
    if not Trial.enabled() then
        return speak("Inactive in this build; no trial controls installed")
    end
    action=tostring(action or "status"):lower()
    if action=="status" then
        local q=RealismExtensionsTerrainNativeQueueProbe
        local sp=RealismExtensionsTerrainNativeSpatialProbe
        return speak(string.format(
            "mode=%s armed=%s reserved=%s pending=%s approved=%d rejected=%d callbacks=%d queueProbe=%s spatialProbe=%s. OBSERVE is non-writing; arm allows ONE native RE wheel job on a COPIED save.",
            Trial.armed and "ONE_SHOT_ARMED" or "OBSERVE",
            tostring(Trial.armed),tostring(Trial.reserved or "-"),
            tostring(Trial.pending),Trial.stats.nativeApproved or 0,
            Trial.stats.nativeRejected or 0,
            Trial.stats.callbackOutcomes or 0,
            tostring(q~=nil and q.owner~=nil),
            tostring(sp~=nil and sp.owner~=nil)
        ))
    elseif action=="probe" then
        RealismExtensionsConfig.modules.TerrainQueueSubmissionProbe=true
        local q=RealismExtensionsTerrainNativeQueueProbe
        local sp=RealismExtensionsTerrainNativeSpatialProbe
        local queue=g_terrainDeformationQueue
            or (g_currentMission~=nil and g_currentMission.terrainDeformationQueue)
        if q~=nil and queue~=nil then q.install(queue) end
        if sp~=nil then sp.install(TerrainDeformation) end
        return speak("Pass-through queue/direct observers requested. Check reTerrainTrial status; they can be unavailable if GIANTS class methods cannot be hooked.")
    elseif action=="cancel" or action=="observe" then
        if Trial.pending then
            return speak("A native RE job is already in flight; cannot undo it. Further RE writes remain disarmed.")
        end
        Trial.armed=false
        Trial.reserved=nil
        return speak("OBSERVE: native terrain writes from RE are blocked")
    elseif action=="arm" then
        Trial.stats.armRequests=Trial.stats.armRequests+1
        local q=RealismExtensionsTerrainNativeQueueProbe
        local sp=RealismExtensionsTerrainNativeSpatialProbe
        if not Trial.isSinglePlayer()
            or Trial.reserved~=nil or Trial.pending==true
            or RealismExtensionsTerrainRuntime==nil
            or RealismExtensionsTerrainRuntime.nativeDamageQuarantined==true
            or q==nil or q.owner==nil or q.enabled~=true
            or sp==nil or sp.owner==nil
            or type(sp.checkIntegrity)~="function"
            or sp.checkIntegrity()~=true
            or type(q.pollIntegrity)~="function"
            or q.pollIntegrity()~=true then
            Trial.stats.deniedArm=Trial.stats.deniedArm+1
            return speak("ARM REFUSED: need single-player server, healthy native journal, no native quarantine, idle trial and both intact queue/direct observers; run reTerrainTrial probe first.")
        end
        local journal=RealismExtensionsTerrainRuntime.geometryJournal
        if journal==nil or journal.unitM==nil
            or RealismExtensionsConfig.modules.TerrainCausalRecovery~=true then
            Trial.stats.deniedArm=Trial.stats.deniedArm+1
            return speak("ARM REFUSED: causal native journal unavailable")
        end
        Trial.armed=true
        return speak("ONE-SHOT ARMED: next eligible RE wheel sample may submit ONE <=3mm, <=0.60m-radius native LOWER. Then automatically disarmed. COPIED SAVE ONLY.")
    end
    return speak("Usage: reTerrainTrial [status|probe|arm|cancel]")
end

function Trial.installCommands()
    if Trial.commandsInstalled or not Trial.enabled()
        or type(addConsoleCommand)~="function" or g_server==nil then
        return false
    end
    addConsoleCommand("reTerrainTrial",
        "Protected RE terrain A/B test: status, probe, arm, cancel",
        "consoleCommand",Trial,"[status|probe|arm|cancel]")
    Trial.commandsInstalled=true
    return true
end

function Trial.uninstallCommands()
    if Trial.commandsInstalled and type(removeConsoleCommand)=="function" then
        removeConsoleCommand("reTerrainTrial")
    end
    Trial.commandsInstalled=false
    Trial.reset()
end
Trial.reset()
return Trial
