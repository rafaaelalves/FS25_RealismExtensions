RealismExtensionsVisualTrackJournal = RealismExtensionsVisualTrackJournal or {}
local Journal = RealismExtensionsVisualTrackJournal

Journal.VERSION = 2
Journal.EXPECTED_CREATE_ARGS = 2
Journal.EXPECTED_POINT_ARGS = 15
Journal.EXPECTED_CUT_ARGS = 1

Journal.DEFAULTS = {
    minSpacingM = 0.30,
    maxSpacingM = 1.00,
    maxGapM = 6.0,
    maxChordErrorM = 0.04,
    maxDirectionDeltaRad = math.rad(6),
    maxRetainedPoints = 75000,
    terrainOnly = true,
    retainClosedFragments = true
}

Journal.ATTRIBUTE_EPS = {
    r = 0.03,
    g = 0.03,
    b = 0.03,
    dirtAmount = 0.05,
    groundDepth = 0.005,
    tireDirection = 0.01,
    colorBlendWithTerrain = 0.05
}

local function validNumber(v)
    return type(v) == "number"
        and v == v
        and v ~= math.huge
        and v ~= -math.huge
end

local function clamp(v, lo, hi)
    if not validNumber(v) then return lo end
    return math.max(lo, math.min(hi, v))
end

local function copyPoint(p)
    local out = {}
    for k,v in pairs(p or {}) do out[k]=v end
    return out
end

local function distance2D(a,b)
    local dx,dz=(b.x or 0)-(a.x or 0),(b.z or 0)-(a.z or 0)
    return math.sqrt(dx*dx+dz*dz)
end

local function chordError2D(a,b,c)
    local vx,vz=(c.x or 0)-(a.x or 0),(c.z or 0)-(a.z or 0)
    local len2=vx*vx+vz*vz
    if len2 <= 0.0000001 then return distance2D(a,b) end
    local wx,wz=(b.x or 0)-(a.x or 0),(b.z or 0)-(a.z or 0)
    local t=clamp((wx*vx+wz*vz)/len2,0,1)
    local px,pz=(a.x or 0)+vx*t,(a.z or 0)+vz*t
    local dx,dz=(b.x or 0)-px,(b.z or 0)-pz
    return math.sqrt(dx*dx+dz*dz)
end

local function normalizedDot(ax,az,bx,bz)
    local al=math.sqrt(ax*ax+az*az)
    local bl=math.sqrt(bx*bx+bz*bz)
    if al < 0.000001 or bl < 0.000001 then return 1 end
    return clamp((ax*bx+az*bz)/(al*bl),-1,1)
end

local function directionDelta(a,b)
    return math.acos(normalizedDot(
        tonumber(a.ux) or 0, tonumber(a.uz) or 0,
        tonumber(b.ux) or 0, tonumber(b.uz) or 0
    ))
end

local function attributesChanged(a,b)
    if a.onTerrain ~= b.onTerrain then return true end
    for k,eps in pairs(Journal.ATTRIBUTE_EPS) do
        local av,bv=tonumber(a[k]),tonumber(b[k])
        if av == nil or bv == nil then
            if av ~= bv then return true end
        elseif math.abs(av-bv) > eps then
            return true
        end
    end
    return false
end

local function parsePoint(args, timestampMs)
    if type(args)~="table" or tonumber(args.n)~=Journal.EXPECTED_POINT_ARGS then
        return nil,"unexpected point argument count"
    end
    for i=2,13 do
        if not validNumber(args[i]) then
            return nil,"invalid numeric point argument "..tostring(i)
        end
    end
    if type(args[14])~="boolean" then
        return nil,"invalid terrain-contact flag"
    end
    if not validNumber(args[15]) then
        return nil,"invalid color blend"
    end

    return {
        x=args[2],y=args[3],z=args[4],
        ux=args[5],uy=args[6],uz=args[7],
        r=args[8],g=args[9],b=args[10],
        dirtAmount=args[11],
        groundDepth=args[12],
        tireDirection=args[13],
        onTerrain=args[14],
        colorBlendWithTerrain=args[15],
        sessionTimeMs=tonumber(timestampMs) or 0
    }
end

local function newFragment(track, sequence)
    local f={
        logicalTrackId=track.logicalTrackId,
        sequence=sequence,
        points={},
        pending=nil,
        closed=false,
        pruned=false
    }
    track.fragments[#track.fragments+1]=f
    return f
end

function Journal.new(options)
    options=options or {}
    local settings={}
    for k,v in pairs(Journal.DEFAULTS) do settings[k]=v end
    for k,v in pairs(options) do settings[k]=v end

    local self={
        settings=settings,
        tracksByNativeId={},
        tracks={},
        sinks={},
        sequence=0,
        logicalTrackSequence=0,
        retainedPoints=0,
        closedQueue={},
        closedQueueHead=1,
        stats={
            creates=0,
            nativeIdReuses=0,
            pointsSeen=0,
            pointsAccepted=0,
            pointsDeferred=0,
            cuts=0,
            gapCuts=0,
            nonTerrainSkipped=0,
            rejectedCalls=0,
            prunedPoints=0,
            sinkErrors=0,
            fragmentsFinalized=0
        }
    }
    return setmetatable(self,{__index=Journal})
end

function Journal:_nextSequence()
    self.sequence=self.sequence+1
    return self.sequence
end

function Journal:_nextLogicalTrackId()
    self.logicalTrackSequence=self.logicalTrackSequence+1
    return self.logicalTrackSequence
end

function Journal:addFragmentSink(sink)
    if type(sink)~="table" then return false end
    for _,existing in ipairs(self.sinks) do
        if existing==sink then return true end
    end
    self.sinks[#self.sinks+1]=sink
    return true
end

function Journal:removeFragmentSink(sink)
    for i=#self.sinks,1,-1 do
        if self.sinks[i]==sink then
            table.remove(self.sinks,i)
            return true
        end
    end
    return false
end

function Journal:_accept(fragment,point)
    fragment.points[#fragment.points+1]=copyPoint(point)
    self.retainedPoints=self.retainedPoints+1
    self.stats.pointsAccepted=self.stats.pointsAccepted+1
end

function Journal:_acceptEndpointIfDistinct(fragment,point)
    if point==nil then return end
    local last=fragment.points[#fragment.points]
    if last==nil
        or distance2D(last,point)>=math.max(0.001,self.settings.minSpacingM*0.25)
        or attributesChanged(last,point)
        or directionDelta(last,point)>=self.settings.maxDirectionDeltaRad*0.5 then
        self:_accept(fragment,point)
    end
end

function Journal:_flushPending(fragment)
    if fragment~=nil and fragment.pending~=nil then
        self:_acceptEndpointIfDistinct(fragment,fragment.pending)
        fragment.pending=nil
    end
end

function Journal:_currentFragment(track)
    local f=track.fragments[#track.fragments]
    if f==nil or f.closed==true then
        f=newFragment(track,self:_nextSequence())
    end
    return f
end

function Journal:_emitFinalized(track,fragment,reason)
    for _,sink in ipairs(self.sinks) do
        local fn=sink~=nil and sink.onFragmentClosed or nil
        if type(fn)=="function" then
            local ok=pcall(fn,sink,track,fragment,reason)
            if not ok then
                self.stats.sinkErrors=self.stats.sinkErrors+1
            end
        end
    end
end

function Journal:_pruneClosed()
    local limit=math.max(
        100,
        math.floor(tonumber(self.settings.maxRetainedPoints) or 75000)
    )

    while self.retainedPoints>limit
        and self.closedQueueHead<=#self.closedQueue do
        local fragment=self.closedQueue[self.closedQueueHead]
        self.closedQueue[self.closedQueueHead]=false
        self.closedQueueHead=self.closedQueueHead+1

        if fragment~=nil and fragment~=false and fragment.pruned~=true then
            local n=#(fragment.points or {})
            fragment.points={}
            fragment.pruned=true
            self.retainedPoints=math.max(0,self.retainedPoints-n)
            self.stats.prunedPoints=self.stats.prunedPoints+n
        end
    end

    if self.closedQueueHead>256
        and self.closedQueueHead>#self.closedQueue*0.5 then
        local compact={}
        for i=self.closedQueueHead,#self.closedQueue do
            local f=self.closedQueue[i]
            if f~=nil and f~=false then compact[#compact+1]=f end
        end
        self.closedQueue=compact
        self.closedQueueHead=1
    end
end

function Journal:_finalizeFragment(track,fragment,reason)
    if fragment==nil or fragment.closed==true then return false end
    self:_flushPending(fragment)
    fragment.closed=true
    fragment.closedSequence=self:_nextSequence()
    fragment.closeReason=reason or "CUT"
    self.stats.fragmentsFinalized=self.stats.fragmentsFinalized+1

    self:_emitFinalized(track,fragment,fragment.closeReason)

    if self.settings.retainClosedFragments==true then
        self.closedQueue[#self.closedQueue+1]=fragment
        self:_pruneClosed()
    else
        local n=#(fragment.points or {})
        fragment.points={}
        fragment.pruned=true
        self.retainedPoints=math.max(0,self.retainedPoints-n)
    end
    return true
end

function Journal:onCreate(nativeTrackId,width,atlasIndex,timestampMs)
    if nativeTrackId==nil or not validNumber(width) or width<=0 then
        self.stats.rejectedCalls=self.stats.rejectedCalls+1
        return false
    end

    local existing=self.tracksByNativeId[nativeTrackId]
    if existing~=nil then
        self:_finalizeFragment(
            existing,
            existing.fragments[#existing.fragments],
            "NATIVE_ID_REUSED"
        )
        existing.retired=true
        self.stats.nativeIdReuses=self.stats.nativeIdReuses+1
    end

    local track={
        logicalTrackId=self:_nextLogicalTrackId(),
        nativeTrackId=nativeTrackId,
        widthM=width,
        atlasIndex=tonumber(atlasIndex),
        createdSessionTimeMs=tonumber(timestampMs) or 0,
        fragments={}
    }
    self.tracksByNativeId[nativeTrackId]=track
    self.tracks[#self.tracks+1]=track
    self.stats.creates=self.stats.creates+1
    return true
end

function Journal:onPoint(nativeTrackId,point)
    self.stats.pointsSeen=self.stats.pointsSeen+1
    local track=self.tracksByNativeId[nativeTrackId]
    if track==nil or type(point)~="table" then
        self.stats.rejectedCalls=self.stats.rejectedCalls+1
        return false
    end

    if self.settings.terrainOnly==true and point.onTerrain~=true then
        self:_finalizeFragment(
            track,
            track.fragments[#track.fragments],
            "LEFT_TERRAIN"
        )
        self.stats.nonTerrainSkipped=self.stats.nonTerrainSkipped+1
        return true
    end

    local f=self:_currentFragment(track)
    local accepted=f.points
    if #accepted==0 then
        self:_accept(f,point)
        return true
    end

    local anchor=accepted[#accepted]
    local previousObserved=f.pending or anchor
    local gap=distance2D(previousObserved,point)
    if gap>math.max(self.settings.maxSpacingM,self.settings.maxGapM) then
        self:_finalizeFragment(track,f,"GAP")
        f=self:_currentFragment(track)
        self:_accept(f,point)
        self.stats.gapCuts=self.stats.gapCuts+1
        return true
    end

    local pending=f.pending
    local minSpacing=math.max(0.01,tonumber(self.settings.minSpacingM) or 0.30)
    local maxSpacing=math.max(minSpacing,tonumber(self.settings.maxSpacingM) or 1.00)
    local dirThreshold=math.max(
        0,
        tonumber(self.settings.maxDirectionDeltaRad) or math.rad(6)
    )
    local errorThreshold=math.max(
        0,
        tonumber(self.settings.maxChordErrorM) or 0.04
    )

    if attributesChanged(anchor,point)
        or directionDelta(anchor,point)>=dirThreshold
        or distance2D(anchor,point)>=maxSpacing then
        self:_flushPending(f)
        self:_acceptEndpointIfDistinct(f,point)
        return true
    end

    if pending~=nil then
        local error=chordError2D(anchor,pending,point)
        if error>=errorThreshold
            or directionDelta(pending,point)>=dirThreshold then
            self:_accept(f,pending)
            f.pending=copyPoint(point)
            self.stats.pointsDeferred=self.stats.pointsDeferred+1
            return true
        end
    end

    f.pending=copyPoint(point)
    self.stats.pointsDeferred=self.stats.pointsDeferred+1
    return true
end

function Journal:onCut(nativeTrackId)
    local track=self.tracksByNativeId[nativeTrackId]
    if track==nil then
        self.stats.rejectedCalls=self.stats.rejectedCalls+1
        return false
    end
    self:_finalizeFragment(track,track.fragments[#track.fragments],"CUT")
    self.stats.cuts=self.stats.cuts+1
    return true
end

function Journal:makeAdapterObserver(nowFn)
    local journal=self
    nowFn=nowFn or function()
        return g_currentMission~=nil and g_currentMission.time or 0
    end

    local observer={}

    function observer:createTrack(system,args,results)
        if tonumber(args.n)~=Journal.EXPECTED_CREATE_ARGS
            or type(results)~="table" or results[1]==nil then
            journal.stats.rejectedCalls=journal.stats.rejectedCalls+1
            return
        end
        journal:onCreate(results[1],args[1],args[2],nowFn())
    end

    function observer:addTrackPoint(system,args,results)
        local id=args[1]
        local p,reason=parsePoint(args,nowFn())
        if p==nil then
            journal.stats.rejectedCalls=journal.stats.rejectedCalls+1
            journal.lastRejectReason=reason
            return
        end
        journal:onPoint(id,p)
    end

    function observer:cutTrack(system,args,results)
        if tonumber(args.n)~=Journal.EXPECTED_CUT_ARGS then
            journal.stats.rejectedCalls=journal.stats.rejectedCalls+1
            return
        end
        journal:onCut(args[1])
    end

    return observer
end

function Journal:getSnapshot()
    local out={
        version=Journal.VERSION,
        retainedPoints=self.retainedPoints,
        stats={},
        tracks={}
    }
    for k,v in pairs(self.stats or {}) do out.stats[k]=v end

    for _,track in ipairs(self.tracks) do
        local t={
            logicalTrackId=track.logicalTrackId,
            widthM=track.widthM,
            atlasIndex=track.atlasIndex,
            createdSessionTimeMs=track.createdSessionTimeMs,
            retired=track.retired==true,
            fragments={}
        }
        for _,f in ipairs(track.fragments) do
            if f.pruned~=true then
                local ff={
                    sequence=f.sequence,
                    closed=f.closed==true,
                    closeReason=f.closeReason,
                    points={}
                }
                for _,p in ipairs(f.points or {}) do
                    ff.points[#ff.points+1]=copyPoint(p)
                end
                if f.pending~=nil then ff.pending=copyPoint(f.pending) end
                t.fragments[#t.fragments+1]=ff
            end
        end
        out.tracks[#out.tracks+1]=t
    end
    return out
end

Journal.parsePoint = parsePoint
return Journal
