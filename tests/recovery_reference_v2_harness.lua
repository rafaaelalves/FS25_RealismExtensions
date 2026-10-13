dofile("scripts/terrain/RecoverySurfaceEstimator.lua")
dofile("scripts/terrain/RecoveryReferenceV2.lua")
local E = RealismExtensionsRecoveryReferenceV2
local function slope(x,z) return 10 + .04*x-.025*z end
local function gauss(x,c,sigma)
    local d=(x-c)/sigma
    return math.exp(-.5*d*d)
end
local function samples(fn, debt)
    local all={{dx=0,dz=0,y=fn(0,0),center=true}}
    for _,r in ipairs({1.2,2.04}) do
        for i=0,15 do
            local a=2*math.pi*i/16
            local x,z=r*math.cos(a),r*math.sin(a)
            all[#all+1]={
                dx=x,dz=z,y=fn(x,z),boundary=true,
                ring=r<2 and "inner" or "outer",
                rutDebtM=debt and debt(x,z) or 0
            }
        end
    end
    return all
end
local function validate(name,shape,debt,expected,tolerance)
    local m,reason=E.measure(samples(shape,debt),{innerRadiusM=1.2})
    assert(m, name..": "..tostring(reason))
    assert(math.abs(m.centerDeficitM-expected)<=tolerance,
        string.format("%s: expected %.4f observed %.4f",name,expected,m.centerDeficitM))
    print(string.format("reference_v2 | %s observed=%.4fm clean=%d masked=%d drift=%.4fm",
        name,m.centerDeficitM,m.referenceCleanCount,
        m.referenceMaskedCount,m.referenceInterRingDriftM))
    return m
end
validate("sloped field",slope,nil,0,.00001)
local narrow=function(x,z)
    return slope(x,z)-.12*math.exp(-(x*x+z*z)/(.20*.20)*.5)
end
validate("isolated 12cm",narrow,function(x,z)
    return slope(x,z)-narrow(x,z)>0.008 and .12 or 0
end,.12,.004)
local lanes=function(x,z)
    return slope(x,z)-.12*math.max(gauss(x,0,.28),gauss(x,1.05,.28))
end
local history=function(x,z)
    local observed=slope(x,z)-lanes(x,z)
    return observed>0.008 and observed or 0
end
validate("parallel 12cm lanes",lanes,history,.12,.025)

local curved=function(x,z)
    return slope(x,z)+.12*(x*x+z*z)/(1.2*1.2)
end
local curvedRef,curvedReason=E.measure(samples(curved),{innerRadiusM=1.2})
assert(curvedRef==nil and curvedReason=="CURVED_OR_INCONSISTENT",
    "natural bowl must never become a synthetic TARGET")

local allDamaged=function(x,z)
    return x==0 and z==0 and .10 or .10
end
local empty,reason=E.measure(samples(slope,allDamaged),{innerRadiusM=1.2})
assert(empty==nil and reason=="NO_CLEAN_REFERENCE",
    "cannot reconstruct a baseline when no clean reference exists")

local unbalanced=function(x,z)
    if x>0 then return .10 end
    return 0
end
local blocked,blockedReason=E.measure(samples(slope,unbalanced),{innerRadiusM=1.2})
assert(blocked==nil and
    (blockedReason=="UNBALANCED_REFERENCE"
        or blockedReason=="INSUFFICIENT_CROSS_RADIUS"),
    "cannot extrapolate only from one side")
print("recovery_reference_v2_harness: OK")
