dofile("scripts/terrain/LoadedContactRegistry.lua")
local R = RealismExtensionsLoadedContactRegistry

R.clear()
local w1,w2 = {},{}
assert(R.record(w1,{id=1},0,0,0.45,12000,1000)==true)
assert(R.record(w2,{id=2},5,5,0.35,8000,1000)==true)

local hit,e = R.overlapsCircle(0.6,0,0.20,1100)
assert(hit==true and e~=nil and e.wheel==w1)

local miss = R.overlapsCircle(3,0,0.20,1100)
assert(miss==false)

-- Updating one wheel must move its spatial ownership rather than duplicating it.
assert(R.record(w1,{id=1},4.7,5,0.45,12000,1200)==true)
assert(R.overlapsCircle(0,0,0.20,1200)==false)
local moved,movedEntry=R.overlapsCircle(5,5,0.20,1200)
assert(moved==true and movedEntry~=nil)

-- Expired contacts cannot block terrain recovery.
assert(R.overlapsCircle(5,5,0.20,1900)==false)

-- Low/unloaded contacts are removed rather than retained as blockers.
assert(R.record(w2,{id=2},1,1,0.30,100,2000)==false)
local stats=R.getStats(2000)
assert(stats.activeContacts==0)

-- Owner exclusion is available for future operation-specific arbitration.
assert(R.record(w1,{id=1},0,0,0.4,10000,2100)==true)
local owner=R.entriesByWheel[w1].owner
assert(R.overlapsCircle(0,0,0.2,2100,{excludeOwner=owner})==false)

R.remove(w1)
assert(R.getStats(2100).activeContacts==0)
print("loaded_contact_registry_harness: OK")
