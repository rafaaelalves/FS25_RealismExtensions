dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
local E=RealismExtensionsRecoverySurfaceEstimator

local function sampleSet(centerOffset,boundaryOverrides,verticalShift)
    verticalShift=verticalShift or 0
    local r=2
    local coords={
        {0,0,false},
        {r,0,true},{-r,0,true},{0,r,true},{0,-r,true},
        {1.414,1.414,true},{-1.414,1.414,true},
        {1.414,-1.414,true},{-1.414,-1.414,true}
    }
    local out={}
    for i,p in ipairs(coords) do
        local x,z=p[1],p[2]
        local y=10 + 0.05*x - 0.03*z + verticalShift
        if i==1 then y=y+(centerOffset or 0) end
        if boundaryOverrides and boundaryOverrides[i] then
            y=y+boundaryOverrides[i]
        end
        out[#out+1]={dx=x,dz=z,y=y,boundary=p[3],center=i==1}
    end
    return out
end

local flat=assert(E.measure(sampleSet(0)))
assert(flat.reliefRangeM<0.000001)
assert(flat.centerDeficitM<0.000001)
assert(math.abs(flat.planeAx-0.05)<0.0001)
assert(math.abs(flat.planeAz+0.03)<0.0001)

local rut=assert(E.measure(sampleSet(-0.12)))
assert(math.abs(rut.centerDeficitM-0.12)<0.0001)
assert(rut.valleyDepthM>=0.119)
assert(rut.reliefRangeM>=0.119)

local lower=assert(E.measure(sampleSet(-0.12,nil,-0.20)))
assert(math.abs(lower.centerDeficitM-rut.centerDeficitM)<0.0001)
assert(math.abs(lower.reliefRangeM-rut.reliefRangeM)<0.0001)

local noisy=assert(E.measure(sampleSet(-0.12,{[2]=0.30})))
assert(noisy.boundaryInlierRatio<1)
assert(noisy.centerDeficitM>0.10)

local before=assert(E.measure(sampleSet(-0.12,nil,0)))
local after=assert(E.measure(sampleSet(-0.03,nil,-0.04)))
local delta=E.compare(before,after)
assert(delta.centerDeficitReductionM>0.08)
assert(delta.reliefReductionM>0.08)
assert(delta.meanShiftM<0)

print("recovery_surface_estimator_harness: OK")
