-- Research-only adapter for FS25's NATIVE wheel/ground-displacement path.
-- The wheel field WheelPhysics.displacementScale is forwarded by GIANTS into
-- setWheelShapeTerrainDisplacement() when the wheel shape is refreshed.
-- This is a DIFFERENT channel from RE's 1m main-heightmap rut brush.
-- Not loaded by modDesc, no hooks, no runtime mutation without explicit
-- injected writeNative function and researchWrite=true.
RealismExtensionsTerrainNativeWheelDisplacementPolicy =
    RealismExtensionsTerrainNativeWheelDisplacementPolicy or {}
local Policy=RealismExtensionsTerrainNativeWheelDisplacementPolicy
Policy.VERSION=1
local function finite(n)
    return type(n)=="number" and n==n
        and n~=math.huge and n~=-math.huge
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end

function Policy.new(options)
    options=options or {}
    return setmetatable({
        researchWrite=options.researchWrite==true,
        writeNative=options.writeNative,
        baseScale=tonumber(options.baseScale) or 1,
        maxMultiplier=clamp(tonumber(options.maxMultiplier) or 1.5,1,2),
        owned=setmetatable({},{__mode="k"}),
        stats={proposed=0,blocked=0,applied=0,
            released=0,drift=0,errors=0}
    },{__index=Policy})
end

-- This pilot computes a *bounded capability proposal*, not a calibrated
-- yield-to-displacement law. Normal rut strength is still owned by FS25.
-- The input plasticYield01 is an RE eligibility signal, not proven to
-- map linearly to fine 0.125m physical rut depth.
function Policy:propose(wheelPhysics,plasticYield01)
    if type(wheelPhysics)~="table"
        or wheelPhysics.supportsWheelSink==false
        or wheelPhysics.displacementAllowed==false
        or type(wheelPhysics.vehicle)~="table"
        or wheelPhysics.vehicle.isServer~=true
        or not finite(wheelPhysics.displacementScale)
        or not finite(plasticYield01) then
        self.stats.blocked=self.stats.blocked+1
        return nil,"NATIVE_WHEEL_UNAVAILABLE"
    end
    local current=wheelPhysics.displacementScale
    local prior=self.owned[wheelPhysics]
    -- An unknown non-baseline scale belongs to some other system. Do not
    -- replace it or fight it each frame. Only our last known write is owned.
    if prior==nil and math.abs(current-self.baseScale)>0.001 then
        self.stats.blocked=self.stats.blocked+1
        return nil,"EXTERNAL_DISPLACEMENT_OWNER"
    end
    if prior~=nil and math.abs(current-prior.appliedScale)>0.001 then
        self.owned[wheelPhysics]=nil
        self.stats.drift=self.stats.drift+1
        return nil,"DISPLACEMENT_POINTER_OR_VALUE_DRIFT"
    end
    local yield=clamp(plasticYield01,0,1)
    local target=self.baseScale+
        (self.maxMultiplier-self.baseScale)*yield
    if yield<=0 then target=self.baseScale end
    self.stats.proposed=self.stats.proposed+1
    return {targetScale=target,beforeScale=current,
        yield01=yield,owner=prior~=nil},nil
end

-- Merely computing a plan never changes a wheel. In this pilot, a writer
-- must be explicitly injected: there is NO automatic low-level GIANTS call.
function Policy:apply(wheelPhysics,proposal)
    if not self.researchWrite or type(self.writeNative)~="function" then
        self.stats.blocked=self.stats.blocked+1
        return false,"RESEARCH_NATIVE_WRITER_DISABLED"
    end
    if type(proposal)~="table"
        or not finite(proposal.targetScale)
        or type(wheelPhysics)~="table"
        or not finite(wheelPhysics.displacementScale)
        or math.abs(wheelPhysics.displacementScale-proposal.beforeScale)>0.001 then
        self.stats.blocked=self.stats.blocked+1
        return false,"STALE_WHEEL_PROPOSAL"
    end
    -- Revalidate the owner at the mutation boundary as other mods can change
    -- wheel values after our proposal. In particular NEVER scale 1.75x twice.
    local prior=self.owned[wheelPhysics]
    if prior==nil and math.abs(proposal.beforeScale-self.baseScale)>0.001 then
        self.stats.blocked=self.stats.blocked+1
        return false,"EXTERNAL_DISPLACEMENT_OWNER"
    end
    if prior~=nil
        and math.abs(proposal.beforeScale-prior.appliedScale)>0.001 then
        self.stats.drift=self.stats.drift+1
        self.owned[wheelPhysics]=nil
        return false,"DISPLACEMENT_OWNER_LOST"
    end
    -- Pass the value through the caller-owned GIANTS bridge; do not
    -- modify radius, sink, traction, wear or the main heightmap.
    local ok,result=pcall(self.writeNative,wheelPhysics,proposal.targetScale)
    if not ok or result==false then
        self.stats.errors=self.stats.errors+1
        return false,"NATIVE_WHEEL_APPLY_FAILED"
    end
    wheelPhysics.displacementScale=proposal.targetScale
    if math.abs(proposal.targetScale-self.baseScale)<=0.001 then
        self.owned[wheelPhysics]=nil
        self.stats.released=self.stats.released+1
    else
        self.owned[wheelPhysics]={appliedScale=proposal.targetScale}
    end
    self.stats.applied=self.stats.applied+1
    return true,nil
end

function Policy:release(wheelPhysics)
    local prior=self.owned[wheelPhysics]
    if prior==nil then return false,"NOT_OWNED" end
    if type(wheelPhysics)~="table"
        or not finite(wheelPhysics.displacementScale)
        or math.abs(wheelPhysics.displacementScale-prior.appliedScale)>0.001 then
        self.owned[wheelPhysics]=nil
        self.stats.drift=self.stats.drift+1
        return false,"EXTERNAL_DISPLACEMENT_OWNER"
    end
    if not self.researchWrite or type(self.writeNative)~="function" then
        return false,"RESEARCH_NATIVE_WRITER_DISABLED"
    end
    local ok,result=pcall(self.writeNative,wheelPhysics,self.baseScale)
    if not ok or result==false then
        self.stats.errors=self.stats.errors+1
        return false,"RELEASE_APPLY_FAILED"
    end
    wheelPhysics.displacementScale=self.baseScale
    self.owned[wheelPhysics]=nil
    self.stats.released=self.stats.released+1
    return true,nil
end
return Policy
