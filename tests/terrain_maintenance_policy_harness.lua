FarmlandManager={
    NO_OWNER_FARM_ID=0,
    NOT_BUYABLE_FARM_ID=255
}

local ownerByLand={
    [1]=7,
    [2]=9,
    [3]=0,
    [4]=0
}

g_farmlandManager={
    currentId=1,
    getFarmlandIdAtWorldPosition=function(self,x,z)
        return self.currentId
    end,
    getFarmlandOwner=function(self,id)
        return ownerByLand[id] or 0
    end
}

g_currentMission={
    getFarmId=function() return 7 end
}

local npcField={
    getHasOwner=function() return false end
}
g_fieldManager={
    farmlandIdFieldMapping={
        [3]=npcField
    }
}

dofile("scripts/terrain/TerrainMaintenancePolicy.lua")
local P=RealismExtensionsTerrainMaintenancePolicy

g_farmlandManager.currentId=1
local c=P.classifyAt(0,0)
assert(c.class=="PLAYER_PRIVATE")
assert(c.maintainer=="NONE")
assert(P.isPassiveMaintenanceEligible(c)==false)

g_farmlandManager.currentId=2
c=P.classifyAt(0,0)
assert(c.class=="OTHER_FARM_PRIVATE")
assert(c.maintainer=="NONE")

g_farmlandManager.currentId=3
c=P.classifyAt(0,0)
assert(c.class=="NPC_FIELD")
assert(c.maintainer=="NEIGHBOR")
assert(P.isPassiveMaintenanceEligible(c)==true)

g_farmlandManager.currentId=4
c=P.classifyAt(0,0)
assert(c.class=="UNOWNED_BUYABLE")
assert(c.maintainer=="NONE")

g_farmlandManager.currentId=0
c=P.classifyAt(0,0)
assert(c.class=="PUBLIC_WORLD")
assert(c.maintainer=="MUNICIPAL")

g_farmlandManager.currentId=FarmlandManager.NOT_BUYABLE_FARM_ID
c=P.classifyAt(0,0)
assert(c.class=="PUBLIC_WORLD")
assert(c.maintainer=="MUNICIPAL")
assert(P.isPassiveMaintenanceEligible(c)==true)

g_farmlandManager.currentId=nil
c=P.classifyAt(0,0)
assert(c.class=="PUBLIC_WORLD")
assert(c.maintainer=="MUNICIPAL")

print("terrain_maintenance_policy_harness: OK")
