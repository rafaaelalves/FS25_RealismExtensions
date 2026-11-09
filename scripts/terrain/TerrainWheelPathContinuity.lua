-- Server-side, no-write wheel movement continuity for RE terrain sampling.
-- Prevents interpolation across a teleported/reloaded/long-idle wheel and
-- distinguishes genuine measured movement from a merely inferred path.
-- Does NOT query fine 0.125m GIANTS deformation, grant MAIN writer ownership,
-- change wheel slip, or manufacture cumulative native heightmap demand.
RealismExtensionsTerrainWheelPathContinuity =
    RealismExtensionsTerrainWheelPathContinuity or {}
local Path=RealismExtensionsTerrainWheelPathContinuity
Path.VERSION=1

local function finite(n)
    return type(n)=="number" and n==n
        and n~=math.huge and n~=-math.huge
end
local function bound(n,lo,hi,default)
    if not finite(n) then return default end
    return math.max(lo,math.min(hi,n))
end

-- options.vehicleSpeedKph may be absent; a missing speed source cannot
-- certify continuity, but one measured travel segment can still be sampled.
-- No memory/global state is needed: the caller owns lastX/lastZ and dt.
function Path.analyze(lastX,lastZ,x,z,dtMs,options)
    options=options or {}
    local result={
        state="UNKNOWN",reason="UNVERIFIED",
        pathContinuous=false,completeCoverage=false,
        movingSamples=1,dirX=nil,dirZ=nil,distanceM=0
    }
    if not finite(x) or not finite(z) then
        result.state="REJECT"
        result.reason="INVALID_CONTACT_POSITION"
        result.reject=true
        return result
    end
    local dt=tonumber(dtMs)
    if not finite(dt) or dt<=0 or dt>bound(options.maxGapMs,
        50,2000,750) then
        result.state="RESET_ANCHOR"
        result.reason="SAMPLE_GAP_OR_CLOCK_RESET"
        return result
    end
    if not finite(lastX) or not finite(lastZ) then
        result.state="RESET_ANCHOR"
        result.reason="NO_VALID_PRIOR_CONTACT"
        return result
    end
    local dx,dz=x-lastX,z-lastZ
    local distance=math.sqrt(dx*dx+dz*dz)
    if not finite(distance) then
        result.state="REJECT"
        result.reason="DISTANCE_OVERFLOW"
        result.reject=true
        return result
    end
    result.distanceM=distance
    local maxSpeedMps=bound(options.absoluteMaxSpeedMps,2,100,50)
    local allowance=bound(options.positionSlackM,0.1,4,0.75)
    local frameS=dt*0.001
    local physicallyPossible=maxSpeedMps*frameS+allowance
    local speed=tonumber(options.vehicleSpeedKph)
    if finite(speed) and speed>=0 then
        local bodySpeedMps=speed/3.6
        -- A wheel path may be longer than the body's movement during tight
        -- turns, lateral slide, a reversing maneuver, or suspension movement.
        -- 3x plus slack is only an implausibility filter, not wheel odometry.
        physicallyPossible=math.min(physicallyPossible,
            bodySpeedMps*frameS*3+allowance)
    end
    if distance>physicallyPossible then
        result.state="RESET_ANCHOR"
        result.reason="IMPLAUSIBLE_POSITION_JUMP"
        return result
    end
    local spacing=tonumber(options.spacingM)
    if not finite(spacing) or spacing<=0 then
        result.state="REJECT"
        result.reason="INVALID_SPACING"
        result.reject=true
        return result
    end
    local stationaryThreshold=bound(options.stationaryThresholdM,
        0.001,0.5,0.10)
    if distance<stationaryThreshold then
        result.state="STATIONARY"
        result.reason="NO_MEASURED_TRAVEL_ORIENTATION"
        return result
    end
    result.dirX=dx/distance
    result.dirZ=dz/distance
    local needed=math.max(1,math.ceil(distance/spacing))
    local maxSamples=math.floor(bound(options.maxSamples,1,32,6))
    result.movingSamples=math.min(needed,maxSamples)
    result.pathContinuous=true
    result.completeCoverage=needed<=maxSamples
    result.state=result.completeCoverage and "CONTINUOUS"
        or "UNDER_SAMPLED"
    result.reason=result.completeCoverage and "MEASURED_WHEEL_TRAVEL"
        or "PATH_INTERPOLATION_CAP"
    return result
end

return Path
