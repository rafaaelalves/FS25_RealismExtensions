-- Experimental no-write planner for permanent MAIN-heightmap rut geometry.
-- Keeps the sub-quantum demand in a separate, volatile ledger; NEVER calls
-- GIANTS setters, changes SpatialHistory, or certifies recovery ownership.
-- Main 1m vertices are NOT the separate fine wheel-displacement surface.
RealismExtensionsTerrainAbsoluteHeightPlanner =
    RealismExtensionsTerrainAbsoluteHeightPlanner or {}
local Planner=RealismExtensionsTerrainAbsoluteHeightPlanner
Planner.VERSION=3
local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end
local function snap(value,unit)
    local i=math.floor(value/unit+0.5)
    return i*unit,i
end
function Planner.new(options)
    options=options or {}
    local u=tonumber(options.unitM)
    if not finite(u) or u<=0 then return nil,"MAIN_UNIT_UNAVAILABLE" end
    -- A caller cannot use one 7.78mm event to infer a reliable map quantum.
    local quantum=tonumber(options.verifiedQuantumM)
    if quantum~=nil and (not finite(quantum)
        or quantum<0.00025 or quantum>0.05) then
        return nil,"QUANTUM_NOT_VERIFIED"
    end
    return setmetatable({
        unitM=u,verifiedQuantumM=quantum,
        maxSources=math.max(1,math.floor(options.maxSources or 50000)),
        maxDemandPerSourceM=math.max(0.0001,
            math.min(0.10,tonumber(options.maxDemandPerSourceM) or 0.10)),
        sources={},sourceCount=0,vertices={},
        stats={observations=0,sourceIncreases=0,duplicates=0,
            accumulatedM=0,vertexCrossings=0,rejected=0,
            capacityRefusals=0,unverifiedQuantumEvents=0,
            recoveries=0,recoveredDemandM=0,recoveryNoSource=0,
            unverifiedTargetDrops=0}
    },{__index=Planner})
end

function Planner:observe(sourceKey,x,z,cumulativeTargetM,existingDepthM)
    local st=self.stats
    st.observations=st.observations+1
    if type(sourceKey)~="string" or sourceKey==""
        or not finite(x) or not finite(z)
        or not finite(cumulativeTargetM)
        or cumulativeTargetM<0 or cumulativeTargetM>self.maxDemandPerSourceM
        or (existingDepthM~=nil and (not finite(existingDepthM)
            or existingDepthM<0
            or existingDepthM>self.maxDemandPerSourceM)) then
        st.rejected=st.rejected+1
        return nil,"INVALID_WHEEL_TARGET"
    end
    local sx,ix=snap(x,self.unitM)
    local sz,iz=snap(z,self.unitM)
    local vertexKey=tostring(ix)..":"..tostring(iz)
    local source=self.sources[sourceKey]
    if source==nil then
        local baseline=existingDepthM or 0
        if cumulativeTargetM<=baseline+0.0000001 then
            -- No NEW deformational demand: do not allocate a source for
            -- thousands of inactive/restored wheel cells. Otherwise a
            -- busy farm can exhaust the 50k source cap without one rut.
            st.duplicates=st.duplicates+1
            return {state="UNCHANGED",vertexKey=vertexKey,
                x=sx,z=sz,addedM=0,targetM=baseline}
        end
        if self.sourceCount>=self.maxSources then
            st.capacityRefusals=st.capacityRefusals+1
            return nil,"SHADOW_SOURCE_CAPACITY"
        end
        -- Seed the per-logical-cell shadow with any history RE loaded from
        -- the existing save. Otherwise first encounter would count an old
        -- persistent rut as *new* demand and duplicate its geometry.
        source={vertexKey=vertexKey,targetM=existingDepthM or 0,
            unappliedDemandM=0}
        self.sources[sourceKey]=source
        self.sourceCount=self.sourceCount+1
    elseif source.vertexKey~=vertexKey then
        -- A single logical 0.2m history cell must not move its accumulated
        -- history from one native vertex to another when a wheel shifts.
        st.rejected=st.rejected+1
        return nil,"SOURCE_VERTEX_DRIFT"
    end
    if cumulativeTargetM+0.0000001<source.targetM then
        -- Only a confirmed logical History recovery may lower the shadow
        -- source's baseline. A silent decrease could be stale model input.
        st.unverifiedTargetDrops=st.unverifiedTargetDrops+1
        return {state="TARGET_DECREASE_UNVERIFIED",vertexKey=vertexKey,
            x=sx,z=sz,addedM=0,targetM=source.targetM}
    end
    local delta=math.max(0,cumulativeTargetM-source.targetM)
    if delta<=0.0000001 then
        st.duplicates=st.duplicates+1
        return {state="UNCHANGED",vertexKey=vertexKey,
            x=sx,z=sz,addedM=0,targetM=source.targetM}
    end
    source.targetM=cumulativeTargetM
    source.unappliedDemandM=math.min(self.maxDemandPerSourceM,
        source.unappliedDemandM+delta)
    local vertex=self.vertices[vertexKey]
    if vertex==nil then
        vertex={x=sx,z=sz,demandM=0,crossed=false,
            sourceCount=0,members={}}
        self.vertices[vertexKey]=vertex
    end
    -- CRITICAL: one native 1m main-height vertex covers many logical 0.2m
    -- history cells. Summing every cell's depth would multiply the same
    -- wheel imprint by up to ~25 (or more with path interpolation).
    -- A geometry vertex represents a HEIGHT, not the integral of source
    -- depths. For now use the largest NEW depth observed per source;
    -- future footprint/area weighting is a separate calibrated model.
    local sourceDemand=source.unappliedDemandM
    vertex.demandM=math.max(vertex.demandM,sourceDemand)
    if delta>0 then
        if source.reportedToVertex~=true then
            source.reportedToVertex=true
            vertex.members[sourceKey]=true
            vertex.sourceCount=vertex.sourceCount+1
        end
    end
    st.sourceIncreases=st.sourceIncreases+1
    st.accumulatedM=st.accumulatedM+delta
    local q=self.verifiedQuantumM
    local crossed=q~=nil and vertex.demandM>=q or false
    if crossed and not vertex.crossed then
        st.vertexCrossings=st.vertexCrossings+1
    end
    vertex.crossed=crossed
    if q==nil then st.unverifiedQuantumEvents=st.unverifiedQuantumEvents+1 end
    return {state=q==nil and "QUANTUM_UNVERIFIED"
        or crossed and "QUANTUM_READY_SHADOW" or "SUB_QUANTUM_SHADOW",
        vertexKey=vertexKey,x=sx,z=sz,addedM=delta,
        targetM=cumulativeTargetM,demandM=vertex.demandM,
        quantumM=q,doesNotWrite=true}
end

-- A trusted logical-history recovery is an independent event: it is
-- propagated only AFTER SpatialHistory has applied a positive recovery.
-- Never infer recovery from a falling model target alone. Shadow demand is
-- reduced by the confirmed amount, without inventing native geometry.
function Planner:onHistoryRecovered(sourceKey,remainingRutM,appliedM)
    if type(sourceKey)~="string" or not finite(remainingRutM)
        or not finite(appliedM) or appliedM<=0 or remainingRutM<0 then
        return false,"INVALID_RECOVERY_EVENT"
    end
    local source=self.sources[sourceKey]
    if source==nil then
        self.stats.recoveryNoSource=self.stats.recoveryNoSource+1
        return false,"SOURCE_NOT_TRACKED"
    end
    local previous=source.targetM
    local confirmed=math.min(appliedM,math.max(0,previous-remainingRutM))
    if confirmed<=0 then return false,"NO_CONFIRMED_DECREASE" end
    source.targetM=remainingRutM
    source.unappliedDemandM=math.max(0,source.unappliedDemandM-confirmed)
    -- Completed restoration closes a logical rut epoch. Release the old
    -- source key when there is no remaining shadow demand. Otherwise a
    -- long-running farm eventually hits maxSources and new ruts stop being
    -- observed despite all old physical ruts having been repaired.
    local retired=remainingRutM<=0.000001
        and source.unappliedDemandM<=0.000001
    self.stats.recoveries=self.stats.recoveries+1
    self.stats.recoveredDemandM=self.stats.recoveredDemandM+confirmed
    local vertex=self.vertices[source.vertexKey]
    if vertex~=nil then
        if retired and vertex.members[sourceKey] then
            vertex.members[sourceKey]=nil
            vertex.sourceCount=math.max(0,vertex.sourceCount-1)
        end
        local largest=0
        for key in pairs(vertex.members) do
            local member=self.sources[key]
            if member~=nil then
                largest=math.max(largest,member.unappliedDemandM)
            end
        end
        vertex.demandM=largest
        local q=self.verifiedQuantumM
        vertex.crossed=q~=nil and largest>=q or false
        if vertex.sourceCount==0 and largest<=0.000001 then
            -- No active debt or source: avoid keeping every historical 1m
            -- vertex in RAM for the lifetime of a long-running farm.
            self.vertices[source.vertexKey]=nil
        end
    end
    if retired then
        self.sources[sourceKey]=nil
        self.sourceCount=math.max(0,self.sourceCount-1)
    end
    return true,nil
end

function Planner:getVertex(ix,iz)
    return self.vertices[tostring(ix)..":"..tostring(iz)]
end
function Planner:summary()
    local vertices=0
    for _ in pairs(self.vertices) do vertices=vertices+1 end
    local vertexDemandSumM=0
    local supportedVertices=0
    for _,v in pairs(self.vertices) do
        vertexDemandSumM=vertexDemandSumM+v.demandM
        if v.sourceCount>=2 then supportedVertices=supportedVertices+1 end
    end
    return string.format(
        "TerrainAbsoluteShadow | mode=NO_WRITE mapUnit=%.3fm quantum=%s sources=%d vertices=%d samples=%d targetIncreases=%d duplicates=%d sourceGrowthSumM=%.6f vertexDemandSumM=%.6f multiSourceVertices=%d quantumReadyVertices=%d recovered=%d recoveredDemandM=%.6f targetDropRefusals=%d rejected=%d capacityRefusals=%d",
        self.unitM,self.verifiedQuantumM~=nil
            and string.format("%.6fm",self.verifiedQuantumM) or "UNVERIFIED",
        self.sourceCount,vertices,self.stats.observations,
        self.stats.sourceIncreases,self.stats.duplicates,
        self.stats.accumulatedM,vertexDemandSumM,supportedVertices,
        self.stats.vertexCrossings,self.stats.recoveries,
        self.stats.recoveredDemandM,self.stats.unverifiedTargetDrops,
        self.stats.rejected,self.stats.capacityRefusals)
end
return Planner
