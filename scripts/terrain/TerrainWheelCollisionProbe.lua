-- Read-only GIANTS wheel-physics contact diagnostics for the terrain trial.
-- This module reads a wheel contact and the separate MAIN terrain height API.
-- It does NOT query a 0.125m deformation cell, write geometry, claim physics
-- ownership, or prove that a contact-height residual causes a visual clip.
RealismExtensionsTerrainWheelCollisionProbe =
    RealismExtensionsTerrainWheelCollisionProbe or {}
local Probe=RealismExtensionsTerrainWheelCollisionProbe
Probe.VERSION=2

local function finite(x)
    return type(x)=="number" and x==x
        and x~=math.huge and x~=-math.huge
end
local function position(t,x,y,z)
    if finite(x) and finite(y) and finite(z) then
        return {x=x,y=y,z=z}
    end
    return nil
end
local function distance(a,b)
    if a==nil or b==nil then return math.huge end
    local dx,dy,dz=a.x-b.x,a.y-b.y,a.z-b.z
    return math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function planar(a,x,z)
    if a==nil or not finite(x) or not finite(z) then
        return math.huge
    end
    return math.sqrt((a.x-x)^2+(a.z-z)^2)
end

-- GIANTS documents the 4-component contact-point tuple but does not state
-- in that API description whether its coordinates are local or world.
-- Compute both interpretations and accept one only when proximity to the
-- actual wheel representation ('wheel.repr') discriminates them. Wheel.node
-- is a physics PARENT COMPONENT and may be many meters away from the tire.
-- Ambiguity is not evidence. 'repr' is a spatial approximation, not a
-- certified native contact collider center.
function Probe.resolvePointFrame(node,raw,options)
    options=options or {}
    local maxDist=tonumber(options.maxWheelContactDistanceM) or 3.0
    if not finite(maxDist) or maxDist<0.25 or maxDist>10 then
        return nil,"INVALID_FRAME_DISTANCE"
    end
    if type(node)~="number" or node==0 or type(raw)~="table"
        or not (finite(raw.x) and finite(raw.y) and finite(raw.z))
        or type(getWorldTranslation)~="function"
        or type(localToWorld)~="function" then
        return nil,"FRAME_TRANSFORMS_UNAVAILABLE"
    end
    -- Never substitute component-root coordinates for a missing wheel
    -- reference: on tractors/harvesters with long components a 3m
    -- contact envelope around the root rejects physically valid wheels.
    local repr=options.wheelCenterNode
    if type(repr)~="number" or repr==0 then
        return nil,"WHEEL_REPR_UNAVAILABLE"
    end
    local o,nx,ny,nz=pcall(getWorldTranslation,repr)
    if not o then return nil,"WHEEL_REPR_POSITION_UNAVAILABLE" end
    local origin=position(nil,nx,ny,nz)
    if origin==nil then return nil,"WHEEL_REPR_POSITION_UNAVAILABLE" end
    local ok,lx,ly,lz=pcall(localToWorld,node,raw.x,raw.y,raw.z)
    if not ok then return nil,"LOCAL_TRANSFORM_UNAVAILABLE" end
    local fromLocal=position(nil,lx,ly,lz)
    if fromLocal==nil then return nil,"LOCAL_TRANSFORM_UNAVAILABLE" end
    local rawWorld={x=raw.x,y=raw.y,z=raw.z}
    local dw=distance(rawWorld,origin)
    local dl=distance(fromLocal,origin)
    local worldClose=dw<=maxDist
    local localClose=dl<=maxDist
    if worldClose==localClose then
        return nil,worldClose and "FRAME_AMBIGUOUS" or "CONTACT_OUTSIDE_WHEEL_ENVELOPE"
    end
    return {
        frame=worldClose and "WORLD_INFERRED" or "LOCAL_INFERRED",
        contact=worldClose and rawWorld or fromLocal,
        wheelOrigin=origin,worldDistanceM=dw,localDistanceM=dl,
        -- Spatial proximity is an inference, not official frame metadata.
        frameVerifiedByEngine=false
    },nil
end

function Probe.sampleWheel(vehicle,wheel,terrainId,options)
    if type(vehicle)~="table" or vehicle.isServer~=true
        or vehicle.isAddedToPhysics~=true then
        return nil,"SERVER_PHYSICS_REQUIRED"
    end
    local p=type(wheel)=="table" and wheel.physics or nil
    if type(p)~="table" or type(wheel.node)~="number"
        or wheel.node==0 or type(p.wheelShape)~="number"
        or p.wheelShape==0 or type(terrainId)~="number"
        or terrainId==0 then
        return nil,"WHEEL_OR_TERRAIN_SHAPE_UNAVAILABLE"
    end
    if type(getWheelShapeContactPoint)~="function"
        or type(getWheelShapeContactObject)~="function"
        or type(getTerrainHeightAtWorldPos)~="function" then
        return nil,"NATIVE_CONTACT_API_UNAVAILABLE"
    end
    local hit,x,y,z,skin=pcall(getWheelShapeContactPoint,
        wheel.node,p.wheelShape)
    if not hit then return nil,"NATIVE_CONTACT_QUERY_FAILED" end
    if x==nil then
        return {state="NO_CONTACT",terrainContact=false,
            physicsScale=p.displacementScale},nil
    end
    if not (finite(x) and finite(y) and finite(z)) then
        return nil,"NONFINITE_CONTACT_POINT"
    end
    local ok,obj,sub=pcall(getWheelShapeContactObject,
        wheel.node,p.wheelShape)
    if not ok or obj==nil then
        return nil,"CONTACT_OBJECT_UNAVAILABLE"
    end
    if obj~=terrainId then
        return {state="NON_TERRAIN_CONTACT",terrainContact=false,
            contactObject=obj,contactSubShape=sub,
            physicsScale=p.displacementScale},nil
    end
    local resolved,why=Probe.resolvePointFrame(wheel.node,
        {x=x,y=y,z=z},{
            wheelCenterNode=wheel.repr,
            maxWheelContactDistanceM=options~=nil
                and options.maxWheelContactDistanceM or nil
        })
    if resolved==nil then
        return {state="CONTACT_FRAME_UNVERIFIED",
            reason=why,terrainContact=true,
            rawPoint={x=x,y=y,z=z},
            contactSubShape=sub,skinWidthM=finite(skin) and skin or nil,
            physicsScale=p.displacementScale,
            provesFineSurfaceHeight=false},nil
    end
    local w=resolved.contact
    local h,yMain=pcall(getTerrainHeightAtWorldPos,
        terrainId,w.x,0,w.z)
    if not h or not finite(yMain) then
        return nil,"MAIN_HEIGHT_READBACK_UNAVAILABLE"
    end
    return {
        state="TERRAIN_CONTACT_OBSERVED",
        terrainContact=true,contact=w,
        mainHeightM=yMain,
        -- A contact point may lie within a collision skin width and may
        -- respond to wheel displacement/soil sink, not only the MAIN grid.
        -- DO NOT call this a direct measurement of fine-cell deformation.
        contactMinusMainM=w.y-yMain,
        physicsScale=p.displacementScale,
        subShapeIndex=sub,
        skinWidthM=finite(skin) and skin or nil,
        frame=resolved.frame,
        frameVerifiedByEngine=false,
        provesFineSurfaceHeight=false,
        provesCollisionAgreement=false,
        authorizesTerrainWrite=false
    },nil
end

-- Explicit diagnostic only, scanning a bounded number of loaded vehicle
-- wheels near a previously marked region. No automatic per-frame work.
function Probe.scanMark(mission,markX,markZ,options)
    options=options or {}
    if g_server==nil or type(mission)~="table"
        or not finite(markX) or not finite(markZ) then
        return nil,"SERVER_MARK_UNAVAILABLE"
    end
    local terrainId=mission.terrainRootNode
    if type(terrainId)~="number" or terrainId==0 then
        return nil,"TERRAIN_NODE_UNAVAILABLE"
    end
    -- GIANTS FS25 keeps loaded vehicles in VehicleSystem.vehicles, not
    -- mission.vehicles. The old lookup was dead on the live Sao Carlos
    -- session (2026-11-03: MISSION_VEHICLE_LIST_UNAVAILABLE).
    -- Prefer the native FS25 owner; legacy fallback is for compatible
    -- tests/hosts and may not exist in production.
    local system=mission.vehicleSystem
    local vehicles=type(system)=="table" and system.vehicles or nil
    local source="VEHICLE_SYSTEM"
    if type(vehicles)~="table" then
        vehicles=mission.vehicles
        source="LEGACY_MISSION"
    end
    if type(vehicles)~="table" then
        return nil,"VEHICLE_SYSTEM_LIST_UNAVAILABLE"
    end
    local radius=tonumber(options.radiusM) or 3
    if not finite(radius) or radius<0.2 or radius>10 then
        return nil,"INVALID_CONTACT_SCAN_RADIUS"
    end
    local results={}
    local examined=0
    local visited=0
    local rejected=0
    local states={NO_CONTACT=0,NON_TERRAIN_CONTACT=0,
        TERRAIN_CONTACT_OBSERVED=0,CONTACT_FRAME_UNVERIFIED=0,
        TERRAIN_CONTACT_OUTSIDE_MARK=0,ERROR=0}
    local errors={}
    local closestReprM=nil
    local closestContactM=nil
    local maxWheels=math.floor(tonumber(options.maxWheels) or 512)
    maxWheels=math.max(1,math.min(2048,maxWheels))
    local maxVehicles=math.floor(tonumber(options.maxVehicles) or 256)
    maxVehicles=math.max(1,math.min(1024,maxVehicles))
    for _,vehicle in pairs(vehicles) do
        visited=visited+1
        if visited>maxVehicles then break end
        if type(vehicle)=="table" and vehicle.isServer==true
            and vehicle.isAddedToPhysics==true then
            local list=vehicle.spec_wheels and vehicle.spec_wheels.wheels
            if type(list)=="table" then
                for i,wheel in ipairs(list) do
                    if examined>=maxWheels then break end
                    examined=examined+1
                    -- wheel.repr is closer to the physical tire than
                    -- wheel.node, which is the vehicle COMPONENT root.
                    if type(wheel.repr)=="number" and wheel.repr~=0
                        and type(getWorldTranslation)=="function" then
                        local ok,wx,wy,wz=pcall(getWorldTranslation,wheel.repr)
                        if ok and finite(wx) and finite(wy) and finite(wz) then
                            local d=math.sqrt((wx-markX)^2+(wz-markZ)^2)
                            closestReprM=closestReprM==nil and d
                                or math.min(closestReprM,d)
                        end
                    end
                    local p,reason=Probe.sampleWheel(vehicle,wheel,terrainId,options)
                    if p~=nil then
                        local state=p.state
                        if states[state]~=nil then
                            states[state]=states[state]+1
                        else
                            states.ERROR=states.ERROR+1
                            errors[tostring(state)]=(errors[tostring(state)] or 0)+1
                        end
                        if p.contact~=nil then
                            local d=planar(p.contact,markX,markZ)
                            closestContactM=closestContactM==nil and d
                                or math.min(closestContactM,d)
                            if d<=radius then
                                p.distanceToMarkM=d
                                p.wheelIndex=i
                                results[#results+1]=p
                            else
                                states.TERRAIN_CONTACT_OUTSIDE_MARK=
                                    states.TERRAIN_CONTACT_OUTSIDE_MARK+1
                            end
                        elseif state=="CONTACT_FRAME_UNVERIFIED" then
                            rejected=rejected+1
                            local why=tostring(p.reason or "UNKNOWN_FRAME")
                            errors[why]=(errors[why] or 0)+1
                        end
                    else
                        rejected=rejected+1
                        states.ERROR=states.ERROR+1
                        local why=tostring(reason or "UNKNOWN_SAMPLE_FAILURE")
                        errors[why]=(errors[why] or 0)+1
                    end
                end
            end
        end
        if examined>=maxWheels then break end
    end
    table.sort(results,function(a,b)
        return a.distanceToMarkM<b.distanceToMarkM
    end)
    return {
        state="READ_ONLY",vehicleSource=source,results=results,
        scannedWheels=examined,scannedVehicles=visited,
        unclassified=rejected,states=states,errorReasons=errors,
        nearestWheelReprM=closestReprM,
        nearestTerrainContactM=closestContactM,
        radiusM=radius,
        truncated=examined>=maxWheels or visited>maxVehicles,
        provesFineSurfaceHeight=false,
        authorizesTerrainWrite=false
    },nil
end

function Probe.consoleAtMarkedArea()
    local gp=RealismExtensionsTerrainGeometryProbe
    local p=gp~=nil and gp.position or nil
    if p==nil then return false,"MARK_AREA_FIRST" end
    local report,why=Probe.scanMark(g_currentMission,p.x,p.z)
    if report==nil then return false,why end
    local counts=report.states or {}
    local lines={string.format(
        "RE CollisionProbe | READ ONLY | source=%s nearMark=%d scannedWheels=%d noContact=%d nonTerrain=%d terrainTotal=%d terrainOutsideMark=%d frameUnknown=%d errors=%d unclassified=%d nearestWheelReprM=%s nearestTerrainContactM=%s radiusM=%.1f truncated=%s. Contact point coordinate frame inferred (NOT engine-certified); MAIN height != fine 0.125m restitution.",
        tostring(report.vehicleSource),#report.results,report.scannedWheels,
        counts.NO_CONTACT or 0,counts.NON_TERRAIN_CONTACT or 0,
        counts.TERRAIN_CONTACT_OBSERVED or 0,
        counts.TERRAIN_CONTACT_OUTSIDE_MARK or 0,
        counts.CONTACT_FRAME_UNVERIFIED or 0,counts.ERROR or 0,
        report.unclassified,
        report.nearestWheelReprM~=nil
            and string.format("%.2f",report.nearestWheelReprM) or "UNAVAILABLE",
        report.nearestTerrainContactM~=nil
            and string.format("%.2f",report.nearestTerrainContactM) or "UNAVAILABLE",
        report.radiusM,tostring(report.truncated))}
    local hints={}
    for reason,count in pairs(report.errorReasons or {}) do
        hints[#hints+1]=reason.."="..tostring(count)
    end
    table.sort(hints)
    if #hints>0 then
        lines[#lines+1]="RE CollisionProbe | skippedReasons=["
            ..table.concat(hints,",").."] (NO terrain write)"
    end
    if #report.results==0 then
        lines[#lines+1]="RE CollisionProbe | No classified terrain-wheel contact near mark. Check nearestWheelReprM and terrainOutsideMark before interpreting clipping; no negative collision conclusion."
    end
    for i=1,math.min(4,#report.results) do
        local s=report.results[i]
        lines[#lines+1]=string.format(
            "RE CollisionProbe | wheel#%d distance=%.3fm world=(%.3f,%.4f,%.3f) frame=%s contactMinusMAIN=%+.5fm mainY=%.4fm skin=%s nativeScale=%s subShape=%s. Difference is NOT proof of clipping or fine-mesh height.",
            s.wheelIndex,s.distanceToMarkM,
            s.contact.x,s.contact.y,s.contact.z,
            tostring(s.frame),s.contactMinusMainM,
            s.mainHeightM,tostring(s.skinWidthM),
            tostring(s.physicsScale),tostring(s.subShapeIndex))
    end
    for _,line in ipairs(lines) do
        if type(print)=="function" then print(line) end
    end
    return true,table.concat(lines,"\n")
end

return Probe
