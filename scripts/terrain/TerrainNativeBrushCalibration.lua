-- Opt-in actuator calibration: one protected GIANTS ADDITIVE LOWER through
-- the REAL RE TerrainWriter, without dependence on wheel/surface/yield model.
-- Only on a disposable SP save. Does not grant recovery ownership or save.
RealismExtensionsTerrainNativeBrushCalibration =
    RealismExtensionsTerrainNativeBrushCalibration or {}
local Cal=RealismExtensionsTerrainNativeBrushCalibration
Cal.DEPTH_M=0.0015
Cal.RADIUS_M=0.45

local function report(msg)
    local s="RE Terrain Calibration | "..tostring(msg)
    if type(print)=="function" then print(s) end
    return s
end

local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end

-- Called only by the user's explicit "reTerrainTrial calibrate" command.
-- All rejection checks happen BEFORE any RE native job can be scheduled.
function Cal.run()
    local trial=RealismExtensionsTerrainControlledWriteTrial
    local rt=RealismExtensionsTerrainRuntime
    local gp=RealismExtensionsTerrainGeometryProbe
    if trial==nil or not trial.enabled() or rt==nil or gp==nil
        or trial.armed==true or trial.pending==true
        or trial.reserved~=nil then
        return false,report("REFUSED: trial not idle, available or enabled")
    end
    -- Reuse ALL standard mark/snapshot, journal, server and hook checks.
    trial:consoleCommand("arm")
    if not trial.isArmed() or trial.armCenter==nil then
        return false,report("REFUSED: prerequisite one-shot arm failed")
    end

    local writer,journal=rt.writer,rt.geometryJournal
    local p=trial.armCenter
    local x,z=p.x,p.z
    local function refuse(reason)
        trial:consoleCommand("cancel")
        return false,report("REFUSED before native write: "..tostring(reason))
    end
    if writer==nil or journal==nil
        or type(writer.enqueue)~="function"
        or type(writer.getQueueSize)~="function"
        or type(journal.getLoweringBudget)~="function"
        or type(journal.begin)~="function"
        or type(journal.complete)~="function"
        or type(journal.validateBeforeSubmit)~="function"
        or type(journal.getHeight)~="function"
        or writer:getQueueSize()~=0 or writer.nativeCausalPending==true then
        return refuse("WRITER_OR_JOURNAL_NOT_IDLE")
    end
    local remaining,why=journal:getLoweringBudget(
        x,z,Cal.RADIUS_M,0.10,0.12)
    if not finite(remaining) or remaining<Cal.DEPTH_M then
        return refuse("NATIVE_JOURNAL_BUDGET_"..tostring(why or remaining))
    end

    local token,reason=journal:begin(
        "CALIBRATE:"..string.format("%.3f:%.3f",x,z),
        x,z,Cal.RADIUS_M)
    if token==nil then return refuse(reason or "JOURNAL_BUSY") end

    local ticket,whyTicket=trial.tryReserve(x,z)
    if ticket==nil then
        journal:complete(token,false)
        return refuse(whyTicket or "TRIAL_RESERVATION_FAILED")
    end

    local recorded=false
    local onApplied=function(state,deltaY,beforeY,afterY,volume)
        if recorded then return end
        recorded=true
        -- Do not assert native callback success from a non-nil state.
        local success=state~=false and (TerrainDeformation==nil
            or TerrainDeformation.STATE_SUCCESS==nil
            or state==TerrainDeformation.STATE_SUCCESS)
        local lower,raise,moved=0,0,0
        local valid=0
        for _,v in ipairs(token.points or {}) do
            local now=journal:getHeight(v.x,v.z)
            if finite(now) then
                valid=valid+1
                local delta=now-v.beforeY
                if delta< -0.00005 then
                    lower=math.max(lower,-delta)
                    moved=moved+1
                elseif delta>0.00005 then
                    raise=math.max(raise,delta)
                    moved=moved+1
                end
                -- A diagnostic writing operation is NEVER recoverable
                -- ownership. Don't allow calibration to certify old sidecars.
                local entry=journal.observations
                    and journal.observations[v.key] or nil
                if entry~=nil and math.abs(delta)>0.00005 then
                    entry.owned=false
                    entry.observedHeightM=now
                end
            end
        end
        journal:complete(token,false)
        trial.callback(ticket,state,volume)
        -- The older 25mm/8x emergency ceiling misses a real 7.78mm
        -- result from a 1.5mm request. In a diagnostic one-shot, ANY
        -- >2x (and >4mm) height amplitude is unacceptable evidence:
        -- block the rest of this disposable session, not just >25mm pits.
        -- This does not prove the cause (quantization vs native brush).
        local ratio=lower/math.max(Cal.DEPTH_M,0.000001)
        local mismatch=lower>math.max(0.004,Cal.DEPTH_M*2)
        if mismatch or not success or valid~=#(token.points or {}) then
            rt.nativeDamageQuarantined=true
        end
        report(string.format(
            "CALLBACK ticket=%d nativeSuccess=%s nativeVolumeM3=%s depthRequestedM=%.5f maxLowerM=%.5f maxRaiseM=%.5f amplitudeRatio=%.2fx mismatchQuarantine=%s movedVertices=%d sampled=%d/%d (calibration is NOT owned rut geometry)",
            ticket,tostring(success),finite(volume)
                and string.format("%.7f",volume) or "missing",
            Cal.DEPTH_M,lower,raise,ratio,
            tostring(rt.nativeDamageQuarantined==true),
            moved,valid,#(token.points or {})))
    end

    local accepted=writer:enqueue({
        x=x,z=z,radiusM=Cal.RADIUS_M,
        depthM=Cal.DEPTH_M,mode="LOWER",hardness=0.35,
        source="CALIBRATION",trialTicket=ticket,
        beforeSubmit=function()
            if rt.nativeDamageQuarantined then
                return false,"CALIBRATION_QUARANTINED"
            end
            return journal:validateBeforeSubmit(token)
        end,
        onApplied=onApplied
    })
    if not accepted then
        journal:complete(token,false)
        trial.abandon(ticket)
        return refuse("WRITER_ENQUEUE_REJECTED")
    end
    report(string.format(
        "ONE_NATIVE_ACTUATOR_QUEUED ticket=%d x=%.3f z=%.3f depth=%.5fm radius=%.2fm. COPIED SAVE ONLY; quit WITHOUT saving.",
        ticket,x,z,Cal.DEPTH_M,Cal.RADIUS_M))
    return true,nil
end

return Cal
