local state={
    revision=1,
    modeToken="1000",
    shaftRpm=1000,
    handThrottlePercent=0.45,
    mismatch=false,
    requirementKnown=true,
    requiredShaftRpm=1000
}
local vehicle={}
RealismExtensionsPTO={
    getVehicleState=function(v)
        assert(v==vehicle)
        return state
    end
}
g_currentMission={controlledVehicle=vehicle}

local drawn={}
function renderText(x,y,size,text)
    drawn[#drawn+1]=text
end
function getCorrectTextSize(v) return v end
function addModEventListener(listener) end

dofile("scripts/pto/PTOHUD.lua")
local H=RealismExtensionsPTOHUD

H:draw()
assert(#drawn==1)
assert(string.find(drawn[1],"PTO 1000",1,true)~=nil)
assert(string.find(drawn[1],"45%",1,true)~=nil)
assert(string.find(drawn[1],"1000 ok",1,true)~=nil)

-- Same revision reuses cached text even if backing fields are mutated. The
-- owner contract requires revision to advance for public-state changes.
state.handThrottlePercent=0.90
H:draw()
assert(drawn[2]==drawn[1])

state.revision=2
state.handThrottlePercent=0.90
state.mismatch=true
state.requiredShaftRpm=540
H:draw()
assert(string.find(drawn[3],"90%",1,true)~=nil)
assert(string.find(drawn[3],"! requer 540",1,true)~=nil)

print("pto_hud_harness: OK")
