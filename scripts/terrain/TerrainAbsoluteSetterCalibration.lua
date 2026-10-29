-- Research-only native ABSOLUTE-height command, not ADDITIVE deformation.
-- One voluntary, destructive-to-the-disposable-save experiment. No wheel
-- pass, no inferred map quantum, no automatic retries, no recovery ownership.
-- The SHADOW production wheel path remains entirely non-writing.
RealismExtensionsTerrainAbsoluteSetterCalibration =
    RealismExtensionsTerrainAbsoluteSetterCalibration or {}
local Cal=RealismExtensionsTerrainAbsoluteSetterCalibration
Cal.REQUEST_M=0.0015
Cal.used=Cal.used==true
Cal.VERSION=1

local function finite(v)
    return type(v)=="number" and v==v
        and v~=-math.huge and v~=math.huge
end
local function report(s)
    local line="RE Absolute Cal | "..tostring(s)
    if type(print)=="function" then print(line) end
    return line
end
local function absoluteContext()
    if Cal.used then return nil,"SESSION_ONE_SHOT_ALREADY_CONSUMED" end
    local cfg=RealismExtensionsConfig
    local m=cfg~=nil and cfg.modules or nil
    if m==nil or m.TerrainPermanentActuator~="SHADOW"
        or m.TerrainControlledWriteTrial~=true then
        return nil,"SHADOW_TRIAL_PROFILE_REQUIRED"
    end
    local trial=RealismExtensionsTerrainControlledWriteTrial
    if trial==nil or type(trial.isSinglePlayer)~="function"
        or not trial.isSinglePlayer()
        or trial.armed==true or trial.pending==true
        or trial.reserved~=nil then
        return nil,"SINGLEPLAYER_IDLE_TRIAL_REQUIRED"
    end
    local rt=RealismExtensionsTerrainRuntime
    local gp=RealismExtensionsTerrainGeometryProbe
    local journal=rt~=nil and rt.geometryJournal or nil
    local writer=rt~=nil and rt.writer or nil
    if rt==nil or rt.nativeDamageQuarantined==true
        or journal==nil or writer==nil
        or not finite(journal.unitM) or journal.unitM<=0
        or not finite(journal.terrain) or journal.terrain<=0
        or type(journal.getLoweringBudget)~="function"
        or type(journal.enumerateVertices)~="function"
        or type(journal.begin)~="function"
        or type(journal.complete)~="function"
        or type(journal.validateBeforeSubmit)~="function"
        or type(journal.getHeight)~="function"
        or type(writer.getQueueSize)~="function"
        or writer.nativeCausalPending==true or writer:getQueueSize()~=0 then
        return nil,"NATIVE_GEOMETRY_OR_WRITER_NOT_IDLE"
    end
    local q=RealismExtensionsTerrainNativeQueueProbe
    local sp=RealismExtensionsTerrainNativeSpatialProbe
    if q==nil or sp==nil or q.owner==nil or sp.owner==nil
        or type(q.pollIntegrity)~="function"
        or type(sp.checkIntegrity)~="function"
        or q.pollIntegrity()~=true
        or sp.checkIntegrity()~=true then
        return nil,"NATIVE_OBSERVERS_NOT_INSTALLED_OR_INTACT"
    end
    if gp==nil or gp.position==nil or gp.previous==nil
        or not finite(gp.position.x) or not finite(gp.position.z)
        or not finite(gp.previous.x) or not finite(gp.previous.z)
        or math.abs(gp.position.x-gp.previous.x)>0.001
        or math.abs(gp.position.z-gp.previous.z)>0.001
        or type(gp.previous.label)~="string"
        or not gp.previous.label:lower():find("beforeabsolute",1,true) then
        return nil,"REQUIRES_FRESH_REGEOMARK_AND_BEFOREABSOLUTE_SNAPSHOT"
    end
    if type(setTerrainHeightAtWorldPos)~="function" then
        return nil,"GIANTS_ABSOLUTE_SETTER_MISSING"
    end
    local unit=journal.unitM
    local x=math.floor(gp.position.x/unit+0.5)*unit
    local z=math.floor(gp.position.z/unit+0.5)*unit
    -- The on-foot position may be between 1m vertices. Refuse a mark
    -- too far from its chosen exact native vertex.
    local dx,dz=x-gp.position.x,z-gp.position.z
    if dx*dx+dz*dz>(0.75*unit)^2 then
        return nil,"MARK_TOO_FAR_FROM_MAIN_GRID_VERTEX"
    end
    local radius=unit*0.70
    local vertices=journal:enumerateVertices(x,z,radius)
    if vertices==nil or #vertices~=9 then
        return nil,"COMPLETE_THREE_BY_THREE_NEIGHBORHOOD_UNAVAILABLE"
    end
    local remaining,why=journal:getLoweringBudget(x,z,radius,0.10,0.12)
    if not finite(remaining) or remaining<Cal.REQUEST_M then
        return nil,"UNTRUSTED_OR_EXHAUSTED_TERRAIN_"..tostring(why or remaining)
    end
    return {rt=rt,journal=journal,writer=writer,
        x=x,z=z,radius=radius,unitM=unit,points=vertices},nil
end

function Cal.inspect()
    local ctx,why=absoluteContext()
    if ctx==nil then
        return false,report("CHECK REFUSED: "..tostring(why))
    end
    local hs={}
    for _,v in ipairs(ctx.points) do
        local y=ctx.journal:getHeight(v.x,v.z)
        if not finite(y) then
            return false,report("CHECK REFUSED: HEIGHT_UNAVAILABLE")
        end
        hs[#hs+1]=y
    end
    -- Point samples expose heights but do not certify the vertical quantum.
    return true,report(string.format(
        "CHECK READY x=%.3f z=%.3f mainUnitM=%.4f vertices=9 centerY=%.6f requestedAbsoluteDownM=%.5f quantum=UNVERIFIED consumed=false. NO WRITE. Run absolute ONLY on a disposable copy; exit WITHOUT SAVE.",
        ctx.x,ctx.z,ctx.unitM,hs[5],Cal.REQUEST_M))
end

function Cal.run()
    local ctx,why=absoluteContext()
    if ctx==nil then
        return false,report("REFUSED before any write: "..tostring(why))
    end
    local j=ctx.journal
    local rt=ctx.rt
    local token,reason=j:begin(
        "ABSOLUTE_CAL:"..string.format("%.3f:%.3f",ctx.x,ctx.z),
        ctx.x,ctx.z,ctx.radius)
    if token==nil then
        return false,report("REFUSED: "..tostring(reason))
    end
    local function abort(msg)
        j:complete(token,false)
        return false,report("REFUSED before any write: "..tostring(msg))
    end
    local good,preWhy=j:validateBeforeSubmit(token)
    if good~=true then return abort(preWhy) end
    -- Check the same session and job state immediately before the setter.
    local check,reasonNow=absoluteContext()
    if check==nil or check.x~=ctx.x or check.z~=ctx.z
        or check.journal~=j or check.rt~=rt then
        return abort(reasonNow or "ENVIRONMENT_CHANGED")
    end
    local centerY=j:getHeight(ctx.x,ctx.z)
    if not finite(centerY) then return abort("PRE_HEIGHT_UNAVAILABLE") end
    local requestedTarget=centerY-Cal.REQUEST_M

    -- Consume permission BEFORE calling native C++: even a Lua error or a
    -- deferred/no-op setter must NEVER be retried in this loaded session.
    Cal.used=true
    local ok,nativeReturn=pcall(setTerrainHeightAtWorldPos,
        j.terrain,ctx.x,0,ctx.z,requestedTarget)
    if ok and nativeReturn==false then ok=false end
    local moved,lower,raise,valid,centerDelta=0,0,0,0,nil
    for _,v in ipairs(token.points or {}) do
        local now=j:getHeight(v.x,v.z)
        if finite(now) then
            valid=valid+1
            local delta=now-v.beforeY
            if v.x==ctx.x and v.z==ctx.z then centerDelta=delta end
            if math.abs(delta)>0.00005 then
                moved=moved+1
                lower=math.max(lower,-delta)
                raise=math.max(raise,delta)
            end
            -- A diagnostic attempt never acquires ownership or recovery
            -- rights, even if readback matches the requested millimeters.
            local entry=j.observations and j.observations[v.key] or nil
            if entry~=nil and math.abs(delta)>0.00005 then
                entry.owned=false
                entry.observedHeightM=now
            end
        else
            local entry=j.observations and j.observations[v.key] or nil
            if entry~=nil then entry.owned=false end
        end
    end
    j:complete(token,false)
    -- Session-wide failsafe, regardless of apparent setter success: this
    -- research test cannot inadvertently resume ordinary native writes.
    rt.nativeDamageQuarantined=true
    report(string.format(
        "RESULT attempted=true setterCallOk=%s nativeReturn=%s x=%.3f z=%.3f requestedM=%.5f beforeY=%.6f targetY=%.6f centerDeltaM=%s maxLowerM=%.6f maxRaiseM=%.6f movedVertices=%d sampled=%d/9 quarantined=true quantum=UNVERIFIED. Immediate readback is NOT proof of persistence or collision. COPIED SAVE ONLY; quit WITHOUT SAVING.",
        tostring(ok),tostring(nativeReturn),ctx.x,ctx.z,
        Cal.REQUEST_M,centerY,requestedTarget,
        finite(centerDelta) and string.format("%+.6f",centerDelta) or "UNAVAILABLE",
        lower,raise,moved,valid))
    return true,nil
end
return Cal
