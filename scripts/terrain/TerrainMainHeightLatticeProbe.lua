-- Strictly READ-ONLY MAIN vertex lattice evidence probe.
-- Samples real getTerrainHeightAtWorldPos through the existing journal.
-- A good lattice fit is a HYPOTHESIS, not a calibrated native setter and
-- NEVER supplies quantumVerified permission to any RE writer.
RealismExtensionsTerrainMainHeightLatticeProbe =
    RealismExtensionsTerrainMainHeightLatticeProbe or {}
local Probe=RealismExtensionsTerrainMainHeightLatticeProbe
Probe.VERSION=1
Probe.DEFAULT_HEIGHT_SCALES={64,127.5,128,255,256,512,1024}
Probe.MAX_SAMPLES=81

local function finite(x)
    return type(x)=="number" and x==x
        and x~=math.huge and x~=-math.huge
end
local function say(msg)
    local line="RE Main Lattice | "..tostring(msg)
    if type(print)=="function" then print(line) end
    return line
end
local function round(x) return math.floor(x+0.5) end
local function validScale(scale)
    return finite(scale) and scale>=1 and scale<=4096
end

-- The 65535 divisor is conditional on a genuine 16-bit grayscale map
-- (0..65535 inclusive). We do not discover the loaded map's heightScale.
-- Differences, rather than absolute Y, avoid assuming a world Y origin.
-- Do not treat an even-multiple sublattice as evidence of a smaller q.
function Probe.analyzeHeights(heights,explicitScale)
    if type(heights)~="table" or #heights<16
        or #heights>Probe.MAX_SAMPLES then
        return nil,"SAMPLE_COUNT_OUT_OF_RANGE"
    end
    if explicitScale~=nil and not validScale(explicitScale) then
        return nil,"INVALID_EXPLICIT_HEIGHT_SCALE"
    end
    local first=heights[1]
    if not finite(first) then return nil,"NONFINITE_SAMPLE" end
    for i=2,#heights do
        if not finite(heights[i]) then return nil,"NONFINITE_SAMPLE" end
    end
    local scales=explicitScale~=nil and {explicitScale}
        or Probe.DEFAULT_HEIGHT_SCALES
    local result={count=#heights,candidates={},sampleMinimumM=first,
        sampleMaximumM=first,status="INSUFFICIENT_VARIATION",
        authorizesNativeWrite=false}
    for _,y in ipairs(heights) do
        result.sampleMinimumM=math.min(y,result.sampleMinimumM)
        result.sampleMaximumM=math.max(y,result.sampleMaximumM)
    end
    result.rangeM=result.sampleMaximumM-result.sampleMinimumM
    local supported={}
    local possible={}
    for _,scale in ipairs(scales) do
        local q=scale/65535
        local minLevel,maxLevel=0,0
        local levels={}
        local maxError,sumError=0,0
        local fit=0
        local tol=math.min(0.00005,q*0.02)
        for _,y in ipairs(heights) do
            local level=round((y-first)/q)
            local err=math.abs((y-first)-level*q)
            levels[level]=true
            minLevel=math.min(minLevel,level)
            maxLevel=math.max(maxLevel,level)
            maxError=math.max(maxError,err)
            sumError=sumError+err
            if err<=tol then fit=fit+1 end
        end
        local distinct,adjacent=0,0
        for lv in pairs(levels) do
            distinct=distinct+1
            if levels[lv+1] then adjacent=adjacent+1 end
        end
        local allFit=fit==#heights and maxError<=tol
        local hasDiversity=distinct>=6 and maxLevel-minLevel>=8
        local hasAdjacent=adjacent>=2
        local supports=allFit and hasDiversity and hasAdjacent
        local candidate={
            heightScaleM=scale,quantumM=q,maxResidualM=maxError,
            averageResidualM=sumError/#heights,
            inTolerance=fit,distinctLevels=distinct,
            spanLevels=maxLevel-minLevel,
            adjacentLevelPairs=adjacent,
            supportsLattice=supports,
            evidence= supports and "LATTICE_SUPPORTED"
                or not allFit and "RESIDUAL_MISMATCH"
                or not hasDiversity and "INSUFFICIENT_DIVERSITY"
                or "SUBLEVEL_OR_SPARSE_ALIAS",
            authorizesNativeWrite=false
        }
        result.candidates[#result.candidates+1]=candidate
        if supports then supported[#supported+1]=candidate end
        if allFit then possible[#possible+1]=candidate end
    end
    if #supported==1 then
        result.status="ONE_LATTICE_CANDIDATE"
        result.best=supported[1]
    elseif #supported>1 then
        result.status="AMBIGUOUS_LATTICE_CANDIDATES"
    elseif #possible>0 then
        result.status="INSUFFICIENT_OR_ALIASED_EVIDENCE"
    else
        result.status="NO_LATTICE_CANDIDATE"
    end
    return result,nil
end

function Probe.scanMarkedArea(explicitScale)
    if explicitScale~=nil and not validScale(explicitScale) then
        return nil,"INVALID_EXPLICIT_HEIGHT_SCALE"
    end
    local gp=RealismExtensionsTerrainGeometryProbe
    local rt=RealismExtensionsTerrainRuntime
    local j=rt~=nil and rt.geometryJournal or nil
    if gp==nil or gp.position==nil
        or j==nil or type(j.getHeight)~="function"
        or not finite(j.unitM) or j.unitM<=0
        or not finite(gp.position.x) or not finite(gp.position.z) then
        return nil,"MARK_OR_MAIN_JOURNAL_UNAVAILABLE"
    end
    if g_server==nil or g_currentMission==nil then
        return nil,"SERVER_MISSION_UNAVAILABLE"
    end
    local u=j.unitM
    local x,z=round(gp.position.x/u)*u,round(gp.position.z/u)*u
    local heights={}
    for ix=-4,4 do
        for iz=-4,4 do
            local y=j:getHeight(x+ix*u,z+iz*u)
            if not finite(y) then
                return nil,"MAIN_VERTEX_HEIGHT_UNAVAILABLE"
            end
            heights[#heights+1]=y
        end
    end
    local result,why=Probe.analyzeHeights(heights,explicitScale)
    if result~=nil then
        result.centerX=x;result.centerZ=z;result.horizontalUnitM=u
    end
    return result,why
end

function Probe.consoleAtMarkedArea(scaleText)
    local scale=nil
    if scaleText~=nil then
        scale=tonumber(scaleText)
        if not validScale(scale) then
            return false,say("REFUSED invalid heightScale; use reTerrainTrial lattice [1..4096]. NO WRITE.")
        end
    end
    local result,why=Probe.scanMarkedArea(scale)
    if result==nil then
        return false,say("REFUSED "..tostring(why).." NO WRITE.")
    end
    local best=result.best
    say(string.format(
        "READ ONLY x=%.3f z=%.3f horizontalUnitM=%.4f samples=%d sampledRangeM=%.5f status=%s candidates=%d. Assumed 16-bit DEM; NO native write permission.",
        result.centerX,result.centerZ,result.horizontalUnitM,
        result.count,result.rangeM,result.status,#result.candidates))
    if best~=nil then
        say(string.format(
            "LATTICE HYPOTHESIS heightScaleM=%.3f stepM=%.8f maxResidualM=%.8f adjacentPairs=%d distinctLevels=%d. This DOES NOT verify the map i3d, setter rounding, persistence, or fine tire track mesh.",
            best.heightScaleM,best.quantumM,best.maxResidualM,
            best.adjacentLevelPairs,best.distinctLevels))
    else
        -- Retain enough evidence to distinguish ambiguous, flat and
        -- mismatched maps without logging unbounded per-vertex output.
        -- Bounded candidate count (seven defaults, one explicit). Report
        -- EVERY candidate rather than accidentally hiding 255m, the fourth
        -- default, whenever the sampled patch is flat or ambiguous.
        for i=1,#result.candidates do
            local c=result.candidates[i]
            say(string.format(
                "candidate heightScaleM=%.3f qM=%.8f evidence=%s fit=%d/%d maxResidualM=%.8f adjacentPairs=%d",
                c.heightScaleM,c.quantumM,c.evidence,
                c.inTolerance,result.count,c.maxResidualM,
                c.adjacentLevelPairs))
        end
    end
    return true,result
end

return Probe
