local state={
    revision=1,
    modeToken="1000",
    shaftRpm=1000,
    effectiveMotorRatio=2.0,
    handThrottlePercent=0.45,
    handThrottleRpm=1500,
    mismatch=false,
    requirementKnown=true,
    requiredShaftRpm=1000,
    hasPtoConsumer=true
}
local speedKph=12
local engaged=true
local motor={
    getLastRealMotorRpm=function() return 1800 end
}
local vehicle={
    getMotor=function() return motor end,
    getLastSpeed=function() return speedKph end
}
RealismExtensionsPTOResolver={
    isPtoEngaged=function(v)
        assert(v==vehicle)
        return engaged, engaged and "IMPLEMENT_PTO_ACTIVE" or "NO_ACTIVE_CONSUMER"
    end
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
local icon={
    width=0,
    height=0,
    x=0,
    y=0,
    color=nil,
    deleted=false
}
function icon:setDimension(w,h) self.width,self.height=w,h end
function icon:setPosition(x,y) self.x,self.y=x,y end
function icon:setColor(r,g,b,a) self.color={r,g,b,a} end
function icon:render() order[#order+1]="icon" end
function icon:delete() self.deleted=true end

local textureConfigLoads=0
local overlayCreates=0
g_overlayManager={
    addTextureConfigFile=function(self,path,id)
        textureConfigLoads=textureConfigLoads+1
        assert(string.find(path,"pto_dashboardHud.xml",1,true)~=nil)
        assert(id=="re_PTODashboardHud")
    end,
    createOverlay=function(self,id,x,y,w,h)
        overlayCreates=overlayCreates+1
        assert(id=="re_PTODashboardHud.pto")
        return icon
    end
}

function renderText(x,y,size,text)
    order[#order+1]="text"
    drawn[#drawn+1]={x=x,y=y,size=size,text=text}
end
function getCorrectTextSize(v) return v end
function setTextAlignment() end
function setTextVerticalAlignment() end
function setTextColor() end
function setTextBold() end
function new2DLayer() end
RenderText={
    ALIGN_RIGHT=1,
    ALIGN_LEFT=0,
    ALIGN_CENTER=2,
    VERTICAL_ALIGN_MIDDLE=3,
    VERTICAL_ALIGN_BOTTOM=4
}
function addModEventListener(listener) end
local consoleCommands={}
function addConsoleCommand(name,description,method,target)
    consoleCommands[name]={method=method,target=target}
end
function removeConsoleCommand(name)
    consoleCommands[name]=nil
end

Utils={
    appendedFunction=function(original,appended)
        return function(...)
            local values={original(...)}
            appended(...)
            return table.unpack(values)
        end
    end
}

local speedBg={
    getPosition=function() return 0.70,0.10 end
}
local speedMeter={
    vehicle=vehicle,
    speedBg=speedBg,
    speedGaugeCenterOffsetX=0.10,
    speedGaugeCenterOffsetY=0.10,
    scalePixelValuesToScreenVector=function(self,x,y)
        return x/1920,y/1080
    end,
    scalePixelToScreenHeight=function(self,v)
        return v/1080
    end
}
local missionHud={
    isVisible=true,
    speedMeter=speedMeter,
    drawControlledEntityHUD=function()
        order[#order+1]="base"
    end
}
g_currentMission={hud=missionHud,time=0}
g_localPlayer={
    getCurrentVehicle=function() return vehicle end
}
g_gui={getIsGuiVisible=function() return false end}
g_currentModDirectory="/mods/FS25_RealismExtensions/"

dofile("scripts/pto/PTOHUD.lua")
local H=RealismExtensionsPTOHUD

H:loadMap()
assert(H._hookedHud==nil)
assert(consoleCommands.rePTOHud~=nil)
assert(consoleCommands.rePTOHudMove~=nil)
assert(consoleCommands.rePTOHudScale~=nil)
assert(consoleCommands.rePTOHudReset~=nil)

local summary=H:consoleCommandMove(10,-5)
assert(string.find(summary,"x=-43.0",1,true)~=nil)
assert(string.find(summary,"y=-16.0",1,true)~=nil)
summary=H:consoleCommandScale(2)
assert(string.find(summary,"w=60.0",1,true)~=nil)
summary=H:consoleCommandLayout(-70,50,32,20,10,6)
assert(string.find(summary,"x=-70.0",1,true)~=nil)
assert(string.find(summary,"w=32.0",1,true)~=nil)
H:update(250)
assert(H._hookedHud==missionHud)

missionHud.drawControlledEntityHUD()
assert(order[1]=="base")
assert(order[2]=="icon")
assert(order[3]=="text")
assert(order[4]=="text")
assert(#drawn==2)
assert(drawn[1].text=="1000")
assert(drawn[2].text=="≈900")
assert(drawn[2].y < drawn[1].y)
assert(drawn[2].size < drawn[1].size)
assert(textureConfigLoads==1)
assert(overlayCreates==1)
assert(icon.color[1]==H.COLOR_ACTIVE[1])
assert(icon.color[2]==H.COLOR_ACTIVE[2])

local d=H.getDiagnostics()
assert(d.installed==true)
assert(d.overlayReady==true)
assert(d.hookInstalls==1)
assert(d.drawCalls==1)
assert(d.graphicalRendered==1)
assert(d.fallbackRendered==0)
assert(d.rendered==1)
assert(d.noVehicle==0)
assert(d.noState==0)
assert(d.lastMode=="1000")
assert(d.lastEngaged==true)
assert(d.lastEngagementSource=="IMPLEMENT_PTO_ACTIVE")
assert(math.abs(d.lastActualRpm-900)<0.000001)
assert(math.abs(d.lastEstimatedRpm-900)<0.000001)
assert(math.abs(d.lastDisplayedRpm-900)<0.000001)
assert(d.lastHandThrottleRpm==1500)
assert(d.lastTransportWarning==false)

-- Mode text is revision cached, while engagement/speed/RPM remain live.
engaged=false
motor.getLastRealMotorRpm=function() return 1600 end
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(d.lastEngaged==false)
assert(d.lastActualRpm==nil)
assert(d.lastEstimatedRpm==nil)
assert(d.lastDisplayedRpm==nil)
assert(drawn[3].text=="1000")
assert(#drawn==3)
assert(icon.color[1]==H.COLOR_OFF[1])

-- A mismatch while disengaged keeps the icon off but makes the selector text
-- a warning. Revision advances because mismatch is owner state.
state.revision=2
state.mismatch=true
state.requiredShaftRpm=540
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(d.lastMismatch==true)
assert(d.lastEngaged==false)

-- Transport warning is presentation-only and only exists while PTO is engaged.
engaged=true
state.revision=3
state.mismatch=false
speedKph=30
g_currentMission.time=0
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(d.lastTransportWarning==true)
assert(d.warningFrames==1)
assert(icon.color[1]==H.COLOR_CRITICAL[1])

-- Next blink phase keeps active semantics but alternates warning colour.
g_currentMission.time=600
missionHud.drawControlledEntityHUD()
assert(icon.color[1]==H.COLOR_ACTIVE[1])

-- Smooth a sharp engine speed change strictly in the HUD; physics is raw.
motor.getLastRealMotorRpm=function() return 2000 end
g_currentMission.time=700
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(math.abs(d.lastEstimatedRpm-1000)<0.000001)
assert(d.lastDisplayedRpm>800 and d.lastDisplayedRpm<1000)
local smoothedLabel=drawn[#drawn].text
assert(smoothedLabel:find("≈",1,true)==1)
assert(smoothedLabel~="≈1000")
-- No under-speed color/alarm: only the existing transport warning applies.
assert(icon.color[1]==H.COLOR_ACTIVE[1] or icon.color[1]==H.COLOR_CRITICAL[1])

-- Missing ratio means no guessed shaft RPM; restore immediate sample later.
state.effectiveMotorRatio=nil
state.revision=4
g_currentMission.time=800
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(d.lastEstimatedRpm==nil)
assert(d.lastDisplayedRpm==nil)
assert(drawn[#drawn].text=="1000")
state.effectiveMotorRatio=2
state.revision=5
g_currentMission.time=900
missionHud.drawControlledEntityHUD()
assert(H.getDiagnostics().lastDisplayedRpm==1000)

-- Disabling the supplemental readout never disables the nominal gear HUD.
RealismExtensionsConfig.ptoHud={showEstimatedRpm=false}
g_currentMission.time=1000
local before= #drawn
missionHud.drawControlledEntityHUD()
assert(#drawn==before+1)
assert(drawn[#drawn].text=="1000")

-- A consumer with an unresolved physical gearbox family displays a neutral
-- question mark rather than a fabricated mismatch or red alert.
state.revision=6
state.hasPtoConsumer=true
state.gearCompatibility="UNKNOWN"
state.mismatch=false
speedKph=12
engaged=false
missionHud.drawControlledEntityHUD()
assert(drawn[#drawn].text=="1000 ?")
assert(H.getDiagnostics().lastMismatch==false)
assert(H.getDiagnostics().lastGearCompatibility=="UNKNOWN")

-- HUD visibility follows the mission HUD.
missionHud.isVisible=false
missionHud.drawControlledEntityHUD()
d=H.getDiagnostics()
assert(d.hidden==1)

H:deleteMap()
assert(icon.deleted==true)
assert(consoleCommands.rePTOHud==nil)
assert(consoleCommands.rePTOHudMove==nil)

print("pto_hud_harness: OK")
