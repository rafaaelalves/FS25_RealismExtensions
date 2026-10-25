-- Passive runtime view of GIANTS wheel-displacement capability.
-- This subsystem is NOT TireTrackSystem and does NOT write terrain.
-- Published WheelPhysics:updateBase/setDisplacementAllowed forward
-- (displacementAllowed and displacementScale or 0) to the native wheel
-- collision-displacement setter. Reading the Lua scale does not measure the
-- native fine (0.125m) deformation depth and is not a fine-mesh readback.
RealismExtensionsTerrainNativeWheelBridge =
    RealismExtensionsTerrainNativeWheelBridge or {}
local Bridge=RealismExtensionsTerrainNativeWheelBridge
Bridge.VERSION=1

local function finite(v)
    return type(v)=="number" and v==v
        and v~=math.huge and v~=-math.huge
end

Bridge.stats={}
Bridge.last=setmetatable({},{__mode="k"})

function Bridge.reset()
    Bridge.stats={
        samples=0,distinctWheels=0,ready=0,
        noWheelPhysics=0,notServer=0,noNativeShape=0,
        nativeSetterMissing=0,wheelNodeMissing=0,
        disabledByWheel=0,sinkUnsupported=0,
        scaleUnavailable=0,baseScale=0,nonDefaultScale=0,
        zeroScale=0,scaleChanges=0,externalCandidates=0,
        minScale=nil,maxScale=nil,nonDefaultMinScale=nil,
        nonDefaultMaxScale=nil
    }
    Bridge.last=setmetatable({},{__mode="k"})
end

-- Read-only on one wheel once per RE physical contact sample. A non-default
-- scale is *not* attributed to MR/Mud or any other specific module; it merely
-- means RE cannot claim the default baseline for an intrusive future writer.
function Bridge.observe(vehicle,wheel)
    local s=Bridge.stats
    if s.samples==nil then Bridge.reset(); s=Bridge.stats end
    s.samples=s.samples+1
    local physics=type(wheel)=="table" and wheel.physics or nil
    if type(physics)~="table" then
        s.noWheelPhysics=s.noWheelPhysics+1
        return false,"NO_WHEEL_PHYSICS"
    end
    local prior=Bridge.last[physics]
    local scale=physics.displacementScale
    if prior==nil then
        s.distinctWheels=s.distinctWheels+1
    elseif finite(scale) and finite(prior.scale)
        and math.abs(scale-prior.scale)>0.0001 then
        s.scaleChanges=s.scaleChanges+1
    end
    Bridge.last[physics]={scale=scale}

    if type(vehicle)~="table" or vehicle.isServer~=true then
        s.notServer=s.notServer+1
        return false,"CLIENT_NO_NATIVE_WRITE"
    end
    if physics.supportsWheelSink==false then
        s.sinkUnsupported=s.sinkUnsupported+1
        return false,"SINK_UNSUPPORTED"
    end
    if physics.displacementAllowed==false then
        s.disabledByWheel=s.disabledByWheel+1
        return false,"DISPLACEMENT_DISABLED"
    end
    if not finite(scale) or scale<0 then
        s.scaleUnavailable=s.scaleUnavailable+1
        return false,"SCALE_UNAVAILABLE"
    end
    s.minScale=s.minScale==nil and scale or math.min(s.minScale,scale)
    s.maxScale=s.maxScale==nil and scale or math.max(s.maxScale,scale)
    if math.abs(scale-1)<0.0001 then
        s.baseScale=s.baseScale+1
    else
        s.nonDefaultScale=s.nonDefaultScale+1
        s.externalCandidates=s.externalCandidates+1
        s.nonDefaultMinScale=s.nonDefaultMinScale==nil
            and scale or math.min(s.nonDefaultMinScale,scale)
        s.nonDefaultMaxScale=s.nonDefaultMaxScale==nil
            and scale or math.max(s.nonDefaultMaxScale,scale)
    end
    if scale<=0.0001 then s.zeroScale=s.zeroScale+1 end
    if type(wheel.node)~="number" or wheel.node==0 then
        s.wheelNodeMissing=s.wheelNodeMissing+1
        return false,"WHEEL_NODE_UNAVAILABLE"
    end
    if type(physics.wheelShape)~="number" or physics.wheelShape==0 then
        s.noNativeShape=s.noNativeShape+1
        return false,"NATIVE_SHAPE_UNAVAILABLE"
    end
    if type(setWheelShapeTerrainDisplacement)~="function" then
        s.nativeSetterMissing=s.nativeSetterMissing+1
        return false,"GIANTS_SETTER_UNAVAILABLE"
    end
    s.ready=s.ready+1
    return true,nil
end

-- Only a candidate writer for future controlled validation. No runtime code
-- calls this automatically; unlike observe() it COULD modify native physics.
-- It is NEVER exported as an automatic default or installed as a global hook.
-- Callers must explicitly supply a research-enabled policy and verify they
-- still own the wheel's scale BEFORE invoking the returned function.
function Bridge.nativeSetterCandidate(physics,newScale)
    if type(physics)~="table" or not finite(newScale)
        or newScale<0 or newScale>2
        or type(physics.vehicle)~="table"
        or physics.vehicle.isServer~=true
        or physics.vehicle.isAddedToPhysics~=true
        or physics.supportsWheelSink==false
        or physics.displacementAllowed==false
        or type(physics.wheel)~="table"
        or type(physics.wheel.node)~="number"
        or physics.wheel.node==0
        or type(physics.wheelShape)~="number" or physics.wheelShape==0
        or type(setWheelShapeTerrainDisplacement)~="function"
        or (Platform~=nil and type(Platform)=="table"
            and type(Platform.gameplay)=="table"
            and Platform.gameplay.wheelTerrainDisplacement==false) then
        return false,"NATIVE_WHEEL_CAPABILITY_UNAVAILABLE"
    end
    local ok,err=pcall(setWheelShapeTerrainDisplacement,
        physics.wheel.node,physics.wheelShape,newScale)
    if not ok then return false,tostring(err) end
    return true,nil
end

Bridge.reset()
return Bridge
