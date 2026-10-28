-- Experimental no-write planner for permanent MAIN-heightmap rut geometry.
-- Keeps the sub-quantum demand in a separate, volatile ledger; NEVER calls
-- GIANTS setters, changes SpatialHistory, or certifies recovery ownership.
-- Main 1m vertices are NOT the separate fine wheel-displacement surface.
RealismExtensionsTerrainAbsoluteHeightPlanner =
    RealismExtensionsTerrainAbsoluteHeightPlanner or {}
local Planner=RealismExtensionsTerrainAbsoluteHeightPlanner
Planner.VERSION=1
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
            capacityRefusals=0,unverifiedQuantumEvents=0}
    },{__index=Planner})
end

function Planner:observe(sourceKey,x,z,cumulativeTargetM)
    local st=self.stats
    st.observations=st.observations+1
    if type(sourceKey)~="string" or sourceKey==""
        or not finite(x) or not finite(z)
        or not finite(cumulativeTargetM)
        or cumulativeTargetM<0 or cumulativeTargetM>self.maxDemandPerSourceM then
        st.rejected=st.rejected+1
        return nil,"INVALID_WHEEL_TARGET"
    end
    local sx,ix=snap(x,self.unitM)
    local sz,iz=snap(z,self.unitM)
    local vertexKey=tostring(ix)..":"..tostring(iz)
    local source=self.sources[sourceKey]
    if source==nil then
        if self.sourceCount>=self.maxSources then
            st.capacityRefusals=st.capacityRefusals+1
            return nil,"SHADOW_SOURCE_CAPACITY"
        end
        source={vertexKey=vertexKey,targetM=0}
        self.sources[sourceKey]=source
        self.sourceCount=self.sourceCount+1
    elseif source.vertexKey~=vertexKey then
        -- A single logical 0.2m history cell must not move its accumulated
        -- history from one native vertex to another when a wheel shifts.
        st.rejected=st.rejected+1
        return nil,"SOURCE_VERTEX_DRIFT"
    end
    local delta=math.max(0,cumulativeTargetM-source.targetM)
    if delta<=0.0000001 then
        st.duplicates=st.duplicates+1
        return {state="UNCHANGED",vertexKey=vertexKey,
            x=sx,z=sz,addedM=0,targetM=source.targetM}
    end
    source.targetM=cumulativeTargetM
    local vertex=self.vertices[vertexKey]
    if vertex==nil then
        vertex={x=sx,z=sz,demandM=0,crossed=false}
        self.vertices[vertexKey]=vertex
    end
    vertex.demandM=math.min(0.10,vertex.demandM+delta)
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

function Planner:getVertex(ix,iz)
    return self.vertices[tostring(ix)..":"..tostring(iz)]
end
function Planner:summary()
    local vertices=0
    for _ in pairs(self.vertices) do vertices=vertices+1 end
    return string.format(
        "TerrainAbsoluteShadow | mode=NO_WRITE mapUnit=%.3fm quantum=%s sources=%d vertices=%d samples=%d targetIncreases=%d duplicates=%d pendingDemandSumM=%.6f quantumReadyVertices=%d rejected=%d capacityRefusals=%d",
        self.unitM,self.verifiedQuantumM~=nil
            and string.format("%.6fm",self.verifiedQuantumM) or "UNVERIFIED",
        self.sourceCount,vertices,self.stats.observations,
        self.stats.sourceIncreases,self.stats.duplicates,
        self.stats.accumulatedM,self.stats.vertexCrossings,
        self.stats.rejected,self.stats.capacityRefusals)
end
return Planner
