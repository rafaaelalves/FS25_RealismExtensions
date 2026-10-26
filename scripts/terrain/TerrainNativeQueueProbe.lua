-- Passive, optional runtime attribution at GIANTS terrain job SUBMISSION.
-- It does NOT observe physical terrain outcomes, detect intersecting areas,
-- or cover direct TerrainDeformation:apply() or native wheel displacement.
-- Disabled unless TerrainQueueSubmissionProbe=true in EXPERIMENTAL config.
-- Never modifies jobs, callbacks, deformation objects, preview or args.
RealismExtensionsTerrainNativeQueueProbe =
    RealismExtensionsTerrainNativeQueueProbe or {}
local Probe=RealismExtensionsTerrainNativeQueueProbe
Probe.VERSION=1
Probe.enabled=false
Probe.owner=nil
Probe.original=nil
Probe.wrapper=nil

local function counter(key)
    Probe.stats[key]=(Probe.stats[key] or 0)+1
end
local function shortName(s)
    if type(s)~="string" then return nil end
    if #s>72 then return nil end
    -- Callback names are diagnostic hints, NEVER an attribution proof.
    if not s:match("^[%w_]+$") then return nil end
    return s
end

function Probe.reset()
    Probe.stats={
        submissions=0,reSubmissions=0,externalSubmissions=0,
        externalDuringREPending=0,unknownDuringREPending=0,
        callbackNames={},callbackNameOverflow=0,
        installs=0,pointerDrifts=0,sourceUnavailable=0
    }
    Probe.lastExternal=nil
    Probe.lastRE=nil
end

function Probe._record(deformation,preview,callbackName,target)
    counter("submissions")
    local rt=RealismExtensionsTerrainRuntime
    local writer=rt~=nil and rt.writer or nil
    local isRE=type(target)=="table" and writer~=nil
        and target.owner==writer
        and target.deformation==deformation
    local rePending=writer~=nil and writer.nativeCausalPending==true
    -- The optional class-level companion observes direct apply() and
    -- brush footprints. Queue and direct events remain separate.
    local spatial=RealismExtensionsTerrainNativeSpatialProbe
    if spatial~=nil and spatial.owner~=nil then
        pcall(spatial.onQueueSubmission,deformation,not isRE and rePending)
    end
    if isRE then
        counter("reSubmissions")
        if spatial~=nil and spatial.owner~=nil then
            pcall(spatial.captureRE,target)
        end
        Probe.lastRE=shortName(callbackName)
    else
        counter("externalSubmissions")
        if rePending then
            counter("externalDuringREPending")
            if type(target)~="table" then
                counter("unknownDuringREPending")
            end
        end
        local name=shortName(callbackName)
        if name~=nil then
            local counts=Probe.stats.callbackNames
            if counts[name]~=nil then
                counts[name]=counts[name]+1
            else
                local n=0
                for _ in pairs(counts) do n=n+1 end
                if n<12 then counts[name]=1
                else counter("callbackNameOverflow") end
            end
            Probe.lastExternal=name
        end
    end
    -- In particular, these numbers do NOT imply main-height edits: jobs
    -- may be painting, preview, leveling, unrelated regions or do nothing.
end

function Probe.install(queue)
    if type(queue)~="table" or type(queue.queueJob)~="function" then
        counter("sourceUnavailable")
        return false,"NATIVE_QUEUE_UNAVAILABLE"
    end
    if Probe.owner~=nil then
        if Probe.owner==queue and queue.queueJob==Probe.wrapper then
            Probe.enabled=true
            return true,"ALREADY_INSTALLED"
        end
        -- A later mod may have wrapped our wrapper. Never overwrite its
        -- pointer to reclaim ownership. The previous wrapper remains a
        -- transparent pass-through until map unload.
        counter("pointerDrifts")
        return false,"QUEUE_POINTER_DRIFT_OR_OWNER_CHANGED"
    end
    local original=queue.queueJob
    -- Hook generations are separate: on a future map load, an older wrapper
    -- retained by a third-party wrapper must NOT start counting again.
    local hookState={active=true}
    local wrapper=function(self,deformation,preview,callbackName,target,...)
        if hookState.active and Probe.enabled then
            -- Observability MUST NOT be able to prevent a native job even
            -- if a diagnostic writer crashes.
            pcall(Probe._record,deformation,preview,callbackName,target)
        end
        -- Preserve exact arg order, multiple return values, native errors
        -- and asynchronous completion behavior.
        return original(self,deformation,preview,callbackName,target,...)
    end
    Probe.owner=queue
    Probe.original=original
    Probe.wrapper=wrapper
    Probe.hookState=hookState
    Probe.enabled=true
    queue.queueJob=wrapper
    counter("installs")
    return true,nil
end

function Probe.pollIntegrity()
    if Probe.owner==nil then return false,"NOT_INSTALLED" end
    if Probe.owner.queueJob~=Probe.wrapper then
        counter("pointerDrifts")
        return false,"POINTER_DRIFT"
    end
    return true,nil
end

function Probe.shutdown()
    Probe.enabled=false
    if Probe.hookState~=nil then Probe.hookState.active=false end
    if Probe.owner~=nil and Probe.owner.queueJob==Probe.wrapper then
        Probe.owner.queueJob=Probe.original
    end
    -- If some later wrapper holds our function, leave a harmless transparent
    -- pass-through rather than destroying another mod's hook chain.
    Probe.owner=nil
    Probe.original=nil
    Probe.wrapper=nil
    Probe.hookState=nil
end

function Probe.formatSnapshot()
    local s=Probe.stats
    local names={}
    for name,count in pairs(s.callbackNames or {}) do
        names[#names+1]=name.."="..tostring(count)
    end
    table.sort(names)
    return string.format(
        "TerrainQueueProbe | passive=true submissions=%d RE=%d other=%d otherDuringREPending=%d missingTarget=%d pointerDrift=%d callbackLabels=[%s] (NOT physical height attribution)",
        s.submissions or 0,s.reSubmissions or 0,
        s.externalSubmissions or 0,s.externalDuringREPending or 0,
        s.unknownDuringREPending or 0,s.pointerDrifts or 0,
        table.concat(names,",")
    )
end
Probe.reset()
return Probe
