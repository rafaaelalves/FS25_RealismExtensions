local state={
    revision=1,
    modeToken="1000",
    shaftRpm=1000,
    effectiveMotorRatio=2.0,
    handThrottlePercent=0.45,
    mismatch=false,
    requirementKnown=true,
    requiredShaftRpm=1000,
    hasPtoConsumer=true
}
local motor={
    getLastRealMotorRpm=function() return 1800 end
}
local vehicle={
    getMotor=function() return motor end,
    getIsPowerTakeOffActive=function() return true end
}

RealismExtensionsPTO={
    getVehicleState=function(v)
        assert(v==vehicle)
        return state
    end
}
RealismExtensionsDiagnostics={
    info=function() end
}
RealismExtensionsConfig={modules={PTOControl=true}}

local order={}
local drawn={}
function renderText(x,y,size,text)
    order[#order+1]="pto"
    drawn[#drawn+1]=text
end
function getCorrectTextSize(v) return v end
function setTextAlignment() end
function setTextColor() end
function setTextBold() end
function new2DLayer() end
RenderText={ALIGN_RIGHT=1,ALIGN_LEFT=0}
function addModEventListener(listener) end

Utils={
    appendedFunction=function(original,appended)
        return function(...)
            local values={original(...)}
            appended(...)
            return table.unpack(values)
        end
    end
}

local missionHud={
    isVisible=true,
    drawControlledEntityHUD=function()
        order[#order+1]="base"
    end
}
g_currentMission={hud=missionHud}
g_localPlayer={
    getCurrentVehicle=function() return vehicle end
}

dofile("scripts/pto/PTOHUD.lua")
local H=RealismExtensionsPTOHUD

H:loadMap()
assert(H._hookedHud==nil)
H:update(250)
assert(H._hookedHud==missionHud)

missionHud.drawControlledEntityHUD()
assert(order[1]=="base")
assert(order[2]=="pto")
assert(#drawn==1)
assert(string.find(drawn[1],"PTO 1000",1,true)~=nil)
assert(string.find(drawn[1],"hand 45%",1,true)~=nil)
assert(string.find(drawn[1],"1000 ok",1,true)~=nil)
assert(string.find(drawn[1],"900 rpm",1,true)~=nil)

local d=H.getDiagnostics()
assert(d.installed==true)
assert(d.hookInstalls==1)
assert(d.drawCalls==1)
assert(d.rendered==1)
assert(d.noVehicle==0)
assert(d.noState==0)

-- Same revision reuses only the static/base text. Live shaft RPM still updates.
state.handThrottlePercent=0.90
motor.getLastRealMotorRpm=function() return 1600 end
missionHud.drawControlledEntityHUD()
assert(string.find(drawn[2],"hand 45%",1,true)~=nil)
assert(string.find(drawn[2],"800 rpm",1,true)~=nil)

state.revision=2
state.handThrottlePercent=0.90
state.mismatch=true
state.requiredShaftRpm=540
missionHud.drawControlledEntityHUD()
assert(string.find(drawn[3],"hand 90%",1,true)~=nil)
assert(string.find(drawn[3],"! requires 540",1,true)~=nil)

-- HUD visibility follows the mission HUD.
missionHud.isVisible=false
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(d.hidden==1)
assert(d.rendered==3)

print("pto_hud_harness: OK")
