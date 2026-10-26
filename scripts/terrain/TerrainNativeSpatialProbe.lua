-- Optional, PASS-THROUGH instrumentation for GIANTS TerrainDeformation.
-- Covers native brush footprints and direct deformation:apply() submissions
-- *without* reading or changing terrain, physics, callbacks or brush settings.
-- Not a provenance oracle: spatial footprint overlap is a collision of
-- submitted envelopes, not proof of vertex movement or source authorship.
RealismExtensionsTerrainNativeSpatialProbe =
    RealismExtensionsTerrainNativeSpatialProbe or {}
local Probe=RealismExtensionsTerrainNativeSpatialProbe
Probe.VERSION=1
Probe.owner=nil
Probe.hookState=nil
Probe.wrappers={}
Probe.originals={}
Probe.stats={}
Probe.envelopes=setmetatable({},{__mode="k"})
Probe.MAX_BRUSHES=24

local function valid(n)
    return type(n)=="number" and n==n
        and n~=math.huge and n~=-math.huge
end
local function object(v)
    return type(v)=="table" or type(v)=="userdata"
end
local function inc(key)
    Probe.stats[key]=(Probe.stats[key] or 0)+1
end
local function boxOverlap(a,b)
    return a.minX<=b.maxX and a.maxX>=b.minX
        and a.minZ<=b.maxZ and a.maxZ>=b.minZ
end

function Probe.reset()
    Probe.envelopes=setmetatable({},{__mode="k"})
    Probe.stats={
        capturedBrushes=0,skippedBrushes=0,tooManyBrushes=0,
        queueSubmissions=0,directSubmissions=0,
        directDuringREPending=0,spatialOverlapQueue=0,
        spatialOverlapDirect=0,broadEnvelopeQueue=0,
        broadEnvelopeDirect=0,unknownGeometry=0,
        directRESubmissions=0,hookInstalls=0,
        hookDrifts=0,hookUnavailable=0,hookErrors=0
    }
    Probe.activeRE=nil
end

function Probe.capture(def,x,z,extent)
    if not object(def) or not valid(x) or not valid(z)
        or not valid(extent) or extent<=0 or extent>500 then
        inc("skippedBrushes")
        return false
    end
    local e=Probe.envelopes[def]
    if e==nil then
        e={circles={},count=0,truncated=false,
            minX=x-extent,maxX=x+extent,
            minZ=z-extent,maxZ=z+extent}
        Probe.envelopes[def]=e
    end
    e.count=e.count+1
    e.minX=math.min(e.minX,x-extent)
    e.maxX=math.max(e.maxX,x+extent)
    e.minZ=math.min(e.minZ,z-extent)
    e.maxZ=math.max(e.maxZ,z+extent)
    if #e.circles<Probe.MAX_BRUSHES then
        e.circles[#e.circles+1]={x=x,z=z,r=extent}
    else
        e.truncated=true
        inc("tooManyBrushes")
    end
    inc("capturedBrushes")
    return true
end

function Probe.captureRE(target)
    if type(target)~="table" then return nil end
    local e={circles={},count=0,truncated=false}
    for _,brush in ipairs(target.brushes or {}) do
        local x,z=brush.x,brush.z
        local r=brush.radiusM
        if valid(x) and valid(z) and valid(r) and r>0 and r<500 then
            e.count=e.count+1
            if e.count==1 then
                e.minX=x-r;e.maxX=x+r
                e.minZ=z-r;e.maxZ=z+r
            else
                e.minX=math.min(e.minX,x-r)
                e.maxX=math.max(e.maxX,x+r)
                e.minZ=math.min(e.minZ,z-r)
                e.maxZ=math.max(e.maxZ,z+r)
            end
            if #e.circles<Probe.MAX_BRUSHES then
                e.circles[#e.circles+1]={x=x,z=z,r=r}
            else e.truncated=true end
        end
    end
    if e.count==0 then return nil end
    Probe.activeRE=e
    return e
end

-- A precise intersection of nominal SOFT brush envelopes is a *candidate*
-- for simultaneous physical terrain writes, not a causal proof.
function Probe.classify(def)
    local a=Probe.activeRE
    local e=object(def) and Probe.envelopes[def] or nil
    if a==nil or e==nil then return "unknown" end
    if not boxOverlap(a,e) then return "none" end
    for _,x in ipairs(a.circles) do
        for _,y in ipairs(e.circles) do
            if (x.x-y.x)^2+(x.z-y.z)^2<=(x.r+y.r)^2 then
                return "overlap"
            end
        end
    end
    if a.truncated or e.truncated then return "broad" end
    return "none"
end

-- Called from native queue observer for jobs not owned by RE.
function Probe.onQueueSubmission(def,externalDuringRE)
    inc("queueSubmissions")
    if not externalDuringRE then return end
    local kind=Probe.classify(def)
    if kind=="overlap" then inc("spatialOverlapQueue")
    elseif kind=="broad" then inc("broadEnvelopeQueue")
    elseif kind=="unknown" then inc("unknownGeometry") end
end

local function isRE(def,target)
    local rt=RealismExtensionsTerrainRuntime
    local w=rt~=nil and rt.writer or nil
    return type(target)=="table" and w~=nil
        and target.owner==w and target.deformation==def
end

function Probe.onDirectSubmission(def,preview,callbackName,target)
    inc("directSubmissions")
    if isRE(def,target) then
        inc("directRESubmissions")
        Probe.captureRE(target)
        return
    end
    local rt=RealismExtensionsTerrainRuntime
    local writer=rt~=nil and rt.writer or nil
    if writer==nil or writer.nativeCausalPending~=true then return end
    inc("directDuringREPending")
    local kind=Probe.classify(def)
    if kind=="overlap" then inc("spatialOverlapDirect")
    elseif kind=="broad" then inc("broadEnvelopeDirect")
    elseif kind=="unknown" then inc("unknownGeometry") end
end

function Probe.install(nativeClass)
    if type(nativeClass)~="table"
        or type(nativeClass.apply)~="function" then
        inc("hookUnavailable")
        return false,"NATIVE_APPLY_UNAVAILABLE"
    end
    if Probe.owner~=nil then
        if Probe.owner==nativeClass then
            for method,wrapper in pairs(Probe.wrappers) do
                if nativeClass[method]~=wrapper then
                    inc("hookDrifts")
                    return false,"NATIVE_METHOD_POINTER_DRIFT"
                end
            end
            return true,"ALREADY_INSTALLED"
        end
        inc("hookDrifts")
        return false,"NATIVE_CLASS_CHANGED"
    end

    local methods={}
    for _,name in ipairs({"addSoftCircleBrush","addSoftSquareBrush","apply"}) do
        if type(nativeClass[name])=="function" then
            methods[#methods+1]=name
        end
    end
    if #methods==1 then
        inc("hookUnavailable")
        return false,"NO_NATIVE_BRUSH_METHOD"
    end
    local originals,wrappers={},{}
    local hookState={active=true}
    for _,name in ipairs(methods) do
        local original=nativeClass[name]
        originals[name]=original
        if name=="apply" then
            wrappers[name]=function(self,preview,cbName,target,...)
                if hookState.active then
                    pcall(Probe.onDirectSubmission,self,preview,cbName,target)
                end
                return original(self,preview,cbName,target,...)
            end
        else
            wrappers[name]=function(self,x,z,radius,...)
                if hookState.active then
                    local extent=radius
                    -- GIANTS square brush's third parameter is side length.
                    if name=="addSoftSquareBrush" and valid(radius) then
                        extent=radius*0.7071067811865476
                    end
                    pcall(Probe.capture,self,x,z,extent)
                end
                return original(self,x,z,radius,...)
            end
        end
    end
    local written={}
    for _,name in ipairs(methods) do
        local ok=pcall(function()nativeClass[name]=wrappers[name] end)
        if not ok then
            inc("hookErrors")
            hookState.active=false
            for _,prev in ipairs(written) do
                if nativeClass[prev]==wrappers[prev] then
                    pcall(function()nativeClass[prev]=originals[prev] end)
                end
            end
            return false,"NATIVE_METHOD_NOT_WRITABLE"
        end
        written[#written+1]=name
    end
    Probe.owner=nativeClass
    Probe.originals=originals
    Probe.wrappers=wrappers
    Probe.hookState=hookState
    inc("hookInstalls")
    return true,nil
end

function Probe.checkIntegrity()
    if Probe.owner==nil then return false,"NOT_INSTALLED" end
    for name,wrapper in pairs(Probe.wrappers) do
        if Probe.owner[name]~=wrapper then
            inc("hookDrifts")
            return false,"NATIVE_METHOD_POINTER_DRIFT"
        end
    end
    return true,nil
end

function Probe.shutdown()
    if Probe.hookState~=nil then Probe.hookState.active=false end
    if Probe.owner~=nil then
        for name,wrapper in pairs(Probe.wrappers) do
            if Probe.owner[name]==wrapper then
                pcall(function()Probe.owner[name]=Probe.originals[name] end)
            end
        end
    end
    Probe.owner=nil
    Probe.originals={}
    Probe.wrappers={}
    Probe.hookState=nil
    Probe.activeRE=nil
    Probe.envelopes=setmetatable({},{__mode="k"})
end

function Probe.formatSnapshot()
    local s=Probe.stats
    return string.format(
        "TerrainSpatialProbe | passive=true circleBrushes=%d direct=%d directWhileRE=%d queuedObserved=%d overlappingBrushEnvelopesQueued=%d overlappingBrushEnvelopesDirect=%d broadOverlapQueued=%d broadOverlapDirect=%d geometryUnknown=%d truncated=%d hooks=%d drifts=%d unavailable=%d (overlap is NOT physical authorship)",
        s.capturedBrushes or 0,s.directSubmissions or 0,
        s.directDuringREPending or 0,s.queueSubmissions or 0,
        s.spatialOverlapQueue or 0,s.spatialOverlapDirect or 0,
        s.broadEnvelopeQueue or 0,s.broadEnvelopeDirect or 0,
        s.unknownGeometry or 0,s.tooManyBrushes or 0,
        s.hookInstalls or 0,s.hookDrifts or 0,
        s.hookUnavailable or 0
    )
end

Probe.reset()
return Probe
