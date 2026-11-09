-- Probe is deliberately pass-through, WITHOUT native terrain edits.
dofile("scripts/terrain/TerrainNativeQueueProbe.lua")
local P=RealismExtensionsTerrainNativeQueueProbe
local calls={}
local q={queueJob=function(self,deformation,preview,name,target,...)
    calls[#calls+1]={self=self,d=deformation,preview=preview,
        name=name,target=target,extras={...}}
    return 137,nil,"native-ok"
end}
local d={}
local writer={nativeCausalPending=false}
RealismExtensionsTerrainRuntime={writer=writer}
local target={owner=writer,deformation=d}
assert(P.install(q)==true)
local a,b,c=q:queueJob(d,false,"done",target,42)
assert(a==137 and b==nil and c=="native-ok")
assert(calls[1].d==d and calls[1].extras[1]==42)
assert(P.stats.reSubmissions==1 and P.stats.externalSubmissions==0)
writer.nativeCausalPending=true
local otherTarget={className="TerraFarmLike"}
local da={}
assert(select(1,q:queueJob(da,false,"externalCallback",otherTarget))==137)
assert(P.stats.externalDuringREPending==1)
assert(P.stats.externalSubmissions==1)
assert(P.stats.callbackNames.externalCallback==1)
assert(P.stats.reSubmissions==1)
assert(select(1,q:queueJob({},false,"placeableCallback",nil))==137)
assert(P.stats.unknownDuringREPending==1)
assert(P.stats.externalDuringREPending==2)
assert(P.stats.externalSubmissions==2)
assert(P.stats.submissions==3)
assert(P.pollIntegrity()==true)
local text=P.formatSnapshot()
assert(text:find("RE=1",1,true) and text:find("otherDuringREPending=2",1,true))
local wrapper=P.wrapper
assert(P.install(q)==true and P.stats.installs==1)
P.shutdown()
assert(q.queueJob~=wrapper)
assert(select(1,q:queueJob(d,false,"done",target))==137)
assert(P.stats.submissions==3) -- no tracking after shutdown

-- Preserve native failures exactly; observer must not swallow errors.
local errorQ={queueJob=function() error("engine-nope") end}
assert(P.install(errorQ)==true)
local ok,err=pcall(errorQ.queueJob,errorQ,{},false,"done",nil)
assert(ok==false and tostring(err):find("engine-nope",1,true))
P.shutdown()

-- When a peer wraps AFTER our install, never break their wrapper on unload.
local chained={queueJob=function() return "native" end}
assert(P.install(chained)==true)
local ourWrapper=chained.queueJob
local later=function(self,...) return ourWrapper(self,...) end
chained.queueJob=later
assert(P.pollIntegrity()==false)
P.shutdown()
assert(chained.queueJob==later)
assert(chained:queueJob({})=="native")
local before=P.stats.submissions
chained:queueJob({})
assert(P.stats.submissions==before) -- inert but forwarded
-- Another map load can re-install a NEW wrapper around that older peer
-- chain. The old generation must remain inert, never count twice.
assert(P.install(chained)==true)
chained:queueJob({},false,"anotherCallback",nil)
assert(P.stats.submissions==before+1)
P.shutdown()
chained:queueJob({},false,"anotherCallback",nil)
assert(P.stats.submissions==before+1)
print("terrain_native_queue_probe_harness: OK")
