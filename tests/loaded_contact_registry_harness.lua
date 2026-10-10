dofile("scripts/terrain/LoadedContactRegistry.lua")
local R=RealismExtensionsLoadedContactRegistry
R.clear()
local w1,w2={},{}
assert(R.record(w1,{id=1},0,0,0.45,12000,1000))
assert(R.record(w2,{id=2},5,5,0.35,8000,1000))
local hit,e=R.overlapsCircle(0.6,0,0.20,1100)
assert(hit and e~=nil and e.loadN==12000)
assert(R.overlapsCircle(3,0,0.20,1100)==false)

-- One contact is indexed into all cells touched by its footprint.
local stats=R.getStats(1100)
assert(stats.activeContacts==2 and stats.indexedCellReferences>=2)

assert(R.record(w1,{id=1},4.7,5,0.45,12000,1200))
assert(R.overlapsCircle(0,0,0.20,1200)==false)
assert(R.overlapsCircle(5,5,0.20,1200)==true)

-- Touch keeps a stationary loaded contact alive without moving/reindexing it.
assert(R.touch(w1,3000))
assert(R.overlapsCircle(5,5,0.20,5001)==true)
assert(R.overlapsCircle(5,5,0.20,5601)==false)

assert(R.record(w2,{id=2},1,1,0.30,100,6000)==false)
assert(R.getStats(6000).activeContacts==0)

assert(R.record(w1,{id=1},0,0,100,10000,6100))
assert(R.entriesByWheel[w1].radiusM==R.DEFAULTS.maxContactRadiusM)
local owner=R.entriesByWheel[w1].owner
assert(R.overlapsCircle(0,0,0.2,6100,{excludeOwner=owner})==false)
R.remove(w1)
assert(R.getStats(6100).activeContacts==0)
print("loaded_contact_registry_harness: OK")
