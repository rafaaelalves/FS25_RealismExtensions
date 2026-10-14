dofile("scripts/tracks/NativeTireTrackAdapter.lua")
local A=RealismExtensionsNativeTireTrackAdapter
A.uninstall()
A.resetProbe()
A.observers={}
A.setProbeEnabled(true)

local order={}
local mt={}
mt.__index=mt
function mt:createTrack(width,atlas)
    order[#order+1]="nativeCreate"
    return 41,nil,"ok"
end
function mt:addTrackPoint(trackId,x,y,z,flag)
    order[#order+1]="nativePoint"
    return true
end
function mt:cutTrack(trackId)
    order[#order+1]="nativeCut"
    return "cut"
end

local sys=setmetatable({},mt)
local observer={}
function observer:createTrack(system,args,results)
    order[#order+1]="observerCreate"
    assert(system==sys and args.n==2)
    assert(results.n==3 and results[1]==41 and results[2]==nil and results[3]=="ok")
end
function observer:addTrackPoint(system,args,results) assert(args.n==5) end
function observer:cutTrack(system,args,results) assert(args.n==1) end
assert(A.addObserver(observer))
assert(A.addObserver({addTrackPoint=function() error("observer failure") end}))

assert(A.install(sys))
local a,b,c=sys:createTrack(0.6,3)
assert(a==41 and b==nil and c=="ok")
assert(order[1]=="nativeCreate" and order[2]=="observerCreate")
assert(sys:addTrackPoint(41,1,2,3,true)==true)
assert(sys:cutTrack(41)=="cut")

local d=A.getDiagnostics()
assert(d.createTrackCalls==1 and d.addTrackPointCalls==1 and d.cutTrackCalls==1)
assert(d.maxCreateArgs==2 and d.maxPointArgs==5 and d.maxCutArgs==1)
assert(d.observerErrors==1)
assert(d.signatures.createTrack["number,number"]==1)

-- Remove observers: probe-only path must still work without result/arg packing.
A.observers={}
local before=A.stats.addTrackPointCalls
assert(sys:addTrackPoint(41,2,3,4,false)==true)
assert(A.stats.addTrackPointCalls==before+1)

-- Later instance owner is detected once and is never overwritten on uninstall.
local laterOwner=function(self,...) return 99 end
sys.createTrack=laterOwner
local healthy,why=A.pollIntegrity()
assert(healthy==false and string.find(why,"createTrack",1,true)~=nil)
local drift=A.stats.pointerDrift
A.pollIntegrity()
assert(A.stats.pointerDrift==drift)
A.uninstall()
assert(sys.createTrack==laterOwner)

-- Methods originally inherited from the class are restored to inheritance,
-- not frozen as direct instance copies.
assert(rawget(sys,"addTrackPoint")==nil)
assert(sys:addTrackPoint(1,1,1,1,true)==true)

print("native_tire_track_adapter_harness: OK")
