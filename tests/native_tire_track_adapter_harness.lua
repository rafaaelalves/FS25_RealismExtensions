dofile("scripts/tracks/NativeTireTrackAdapter.lua")
local A=RealismExtensionsNativeTireTrackAdapter
A.uninstall()
A.resetProbe()
A.observers={}

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
local observed={create=0,point=0,cut=0}
local observer={}
function observer:createTrack(system,args,results)
    order[#order+1]="observerCreate"
    observed.create=observed.create+1
    assert(system==sys)
    assert(args.n==2 and args[1]==0.6 and args[2]==3)
    assert(results.n==3 and results[1]==41 and results[2]==nil and results[3]=="ok")
end
function observer:addTrackPoint(system,args,results)
    observed.point=observed.point+1
    assert(args.n==5)
end
function observer:cutTrack(system,args,results)
    observed.cut=observed.cut+1
    assert(args.n==1 and args[1]==41)
end
assert(A.addObserver(observer))

-- Observer failures are telemetry only; they must never break GIANTS/native.
assert(A.addObserver({
    addTrackPoint=function() error("observer failure") end
}))

local ok,reason=A.install(sys)
assert(ok==true and reason==nil and A.installed==true)
assert(A.checkIntegrity()==true)

local a,b,c=sys:createTrack(0.6,3)
assert(a==41 and b==nil and c=="ok")
assert(order[1]=="nativeCreate" and order[2]=="observerCreate")
assert(sys:addTrackPoint(41,1,2,3,true)==true)
assert(sys:cutTrack(41)=="cut")
assert(observed.create==1 and observed.point==1 and observed.cut==1)

local d=A.getDiagnostics()
assert(d.createTrackCalls==1)
assert(d.addTrackPointCalls==1)
assert(d.cutTrackCalls==1)
assert(d.maxCreateArgs==2 and d.maxPointArgs==5 and d.maxCutArgs==1)
assert(d.observerErrors==1)
assert(d.signatures.createTrack["number,number"]==1)
assert(d.signatures.addTrackPoint["number,number,number,number,boolean"]==1)

-- A later owner must be detected and must not be overwritten during uninstall.
local laterOwner=function(self,...) return 99 end
mt.createTrack=laterOwner
local healthy,why=A.checkIntegrity()
assert(healthy==false and string.find(why,"createTrack",1,true)~=nil)
assert((A.stats.pointerDrift or 0)>=1)
A.uninstall()
assert(mt.createTrack==laterOwner)
-- Methods still owned by RE are safely restored.
assert(mt.addTrackPoint~=nil and mt.addTrackPoint~=A.wrappers)

print("native_tire_track_adapter_harness: OK")
