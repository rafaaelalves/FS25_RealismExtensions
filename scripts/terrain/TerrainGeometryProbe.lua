-- Read-only controlled snapshots of the main terrain-height sampling API.
-- DOES NOT expose or assert access to FS25 0.125 m displacement vertices.
RealismExtensionsTerrainGeometryProbe = RealismExtensionsTerrainGeometryProbe or {}
local Probe = RealismExtensionsTerrainGeometryProbe
Probe.VERSION = 1
Probe.THRESHOLD_M = 0.002
Probe.commandsInstalled = false
Probe.position = nil
Probe.previous = nil
Probe.captureIndex = 0

local function newWriteEvents()
    return {
        near2m={lower=0,target=0,other=0,raise=0,lowerCenterDown=0,targetCenterUp=0,targetCenterDown=0},
        near4m={lower=0,target=0,other=0,raise=0,lowerCenterDown=0,targetCenterUp=0,targetCenterDown=0}
    }
end

Probe.writeEvents = newWriteEvents()

local function newContactEvents()
    return {
        context={total=0,near2m=0,near4m=0,minDistanceM=nil},
        eligible={total=0,near2m=0,near4m=0,minDistanceM=nil}
    }
end
Probe.contactEvents = newContactEvents()

local function finite(value)
    return type(value) == "number"
        and value == value and value ~= math.huge and value ~= -math.huge
end

local function speak(msg)
    local line = "REGeoProbe | " .. tostring(msg)
    if type(print) == "function" then print(line) end
    return line
end

local function getTerrain()
    local mission = g_currentMission
    return mission ~= nil and mission.terrainRootNode or g_terrainNode
end

local function getSample(terrain, x, z)
    if type(getTerrainHeightAtWorldPos) ~= "function"
        or terrain == nil or terrain == 0 then
        return nil
    end
    local ok, h = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and finite(h) then return h end
    return nil
end

function Probe.reset()
    Probe.position = nil
    Probe.previous = nil
    Probe.captureIndex = 0
    Probe.writeEvents = newWriteEvents()
    Probe.contactEvents = newContactEvents()
end

-- GIANTS FS25 Player uses g_localPlayer:getPosition() on foot;
-- g_currentMission.player is not the local player in the real runtime.
-- For an occupied vehicle the player's foot position may be stale.
local function getPlayerPosition()
    local player = g_localPlayer
    if player == nil and g_currentMission ~= nil then
        player = g_currentMission.player
    end
    if player == nil then return nil, nil, "no-local-player" end

    if type(player.getCurrentVehicle) == "function" then
        local okVehicle, vehicle = pcall(player.getCurrentVehicle, player)
        if okVehicle and vehicle ~= nil then
            local node = vehicle.rootNode
            if type(getWorldTranslation) == "function"
                and node ~= nil and node ~= 0 then
                local ok, x, _, z = pcall(getWorldTranslation, node)
                if ok and finite(x) and finite(z) then
                    return x, z, "vehicle-root"
                end
            end
            -- Do not silently mark a stale on-foot location while driving.
            return nil, nil, "vehicle-position-unavailable"
        end
    end

    if type(player.getPosition) == "function" then
        local ok, x, _, z = pcall(player.getPosition, player)
        if ok and finite(x) and finite(z) then
            return x, z, "player-position"
        end
    end

    if type(player.getMapPositionAndLookYaw) == "function" then
        local ok, x, z = pcall(player.getMapPositionAndLookYaw, player)
        if ok and finite(x) and finite(z) then
            return x, z, "player-map-position"
        end
    end

    local node = player.rootNode
    if type(getWorldTranslation) == "function"
        and node ~= nil and node ~= 0 then
        local ok, x, _, z = pcall(getWorldTranslation, node)
        if ok and finite(x) and finite(z) then
            return x, z, "player-root"
        end
    end
    return nil, nil, "player-position-unavailable"
end

function Probe:consoleMark(xText, zText)
    local x, z = tonumber(xText), tonumber(zText)
    local origin = "explicit"
    if xText ~= nil or zText ~= nil then
        if not (finite(x) and finite(z)) then
            return speak("Invalid coordinates; use reGeoMark <x> <z> or reGeoMark")
        end
    else
        x, z, origin = getPlayerPosition()
        if not (finite(x) and finite(z)) then
            return speak("Cannot mark " .. tostring(origin)
                .. "; stand on foot at the hole or use reGeoMark <x> <z>")
        end
    end

    self.position = { x = x, z = z }
    self.previous = nil
    self.captureIndex = 0
    self.writeEvents = newWriteEvents()
    self.contactEvents = newContactEvents()
    return speak(string.format(
        "MARK x=%.3f z=%.3f origin=%s | 4m x 4m main grid; 2m x 2m sampled every 0.125m; READ ONLY",
        x, z, origin
    ))
end

-- Callback-based *proximity* telemetry from RE's own TerrainWriter only.
-- It is not a native write attribution for every measured heightmap sample.
-- Called after a successful native writer callback; no new terrain writes.
-- Read-only evidence that a moving grounded RE wheel really touched
-- the *marked patch* between snapshots. Mere global wheel ticks are not
-- evidence of a pass through the marked coordinates. Both stages require
-- the experimental observe-only profile and change no terrain state.
function Probe.observeWheelContact(x,z,stage)
    local p=Probe.position
    if p==nil or not finite(x) or not finite(z) then return end
    local c=Probe.contactEvents
    local e=c~=nil and c[stage] or nil
    if e==nil then return end
    local dx,dz=x-p.x,z-p.z
    local dist=math.sqrt(dx*dx+dz*dz)
    e.total=e.total+1
    e.minDistanceM=e.minDistanceM==nil and dist
        or math.min(e.minDistanceM,dist)
    if dist<=2 then e.near2m=e.near2m+1 end
    if dist<=4 then e.near4m=e.near4m+1 end
end

local function formatContactEvents(stage,event,interval)
    return string.format(
        "WHEEL_CONTACT interval=%s stage=%s total=%d near2m=%d near4m=%d nearest=%s (contact sample, NOT proof of native height edit)",
        tostring(interval),stage,event.total or 0,
        event.near2m or 0,event.near4m or 0,
        event.minDistanceM~=nil
            and string.format("%.3fm",event.minDistanceM) or "none")
end

local function overlapsSquare(px, pz, brush, halfWidthM)
    local radius = tonumber(brush.radiusM) or 0
    local dx = math.max(0, math.abs(brush.x - px) - halfWidthM)
    local dz = math.max(0, math.abs(brush.z - pz) - halfWidthM)
    return dx*dx + dz*dz <= radius*radius
end

function Probe.observeWriterCallback(brush, mode, source, deltaY)
    local p = Probe.position
    if p == nil or type(brush) ~= "table"
        or not finite(brush.x) or not finite(brush.z) then
        return
    end
    local kind = mode == "LOWER" and "lower"
        or (mode == "TARGET" and source == "RECOVERY") and "target"
        or mode == "RAISE" and "raise" or "other"
    local events = Probe.writeEvents
    for _, desc in ipairs({{"near2m",1}, {"near4m",2}}) do
        if overlapsSquare(p.x,p.z,brush,desc[2]) then
            local e = events[desc[1]]
            e[kind] = e[kind] + 1
            if finite(deltaY) then
                if kind == "lower" and deltaY < -0.00005 then
                    e.lowerCenterDown = e.lowerCenterDown + 1
                elseif kind == "target" and deltaY > 0.00005 then
                    e.targetCenterUp = e.targetCenterUp + 1
                elseif kind == "target" and deltaY < -0.00005 then
                    e.targetCenterDown = e.targetCenterDown + 1
                end
            end
        end
    end
end

local function sampleGrid(terrain, x, z, stepM, halfSteps)
    local samples = {}
    local minY, maxY = math.huge, -math.huge
    local n = 0
    for iz = -halfSteps, halfSteps do
        for ix = -halfSteps, halfSteps do
            local wx, wz = x + ix * stepM, z + iz * stepM
            local y = getSample(terrain, wx, wz)
            if y == nil then return nil end
            n = n + 1
            samples[n] = { x = wx, z = wz, y = y, ix = ix, iz = iz }
            minY = math.min(minY, y)
            maxY = math.max(maxY, y)
        end
    end
    return {samples=samples, count=n, minY=minY, maxY=maxY}
end

local function residualAgainstCornerPlane(grid, halfSteps)
    local stride = halfSteps * 2 + 1
    local samples = grid.samples
    local a = samples[1].y
    local b = samples[stride].y
    local c = samples[(stride-1)*stride+1].y
    local d = samples[#samples].y
    local minResidual, maxResidual = math.huge, -math.huge
    local centerResidual = 0
    for _, point in ipairs(samples) do
        local u = (point.ix + halfSteps) / (2*halfSteps)
        local v = (point.iz + halfSteps) / (2*halfSteps)
        local plane = a*(1-u)*(1-v) + b*u*(1-v)
                    + c*(1-u)*v + d*u*v
        local residual = point.y - plane
        minResidual = math.min(minResidual, residual)
        maxResidual = math.max(maxResidual, residual)
        if point.ix == 0 and point.iz == 0 then
            centerResidual = residual
        end
    end
    return minResidual, maxResidual, centerResidual
end

local function formatWriterEvents(prefix, events, interval)
    return string.format(
        "WRITER_NEAR interval=%s area=%s wheelLower=%d (centerDown=%d) recoveryTarget=%d (centerUp=%d centerDown=%d) raise=%d other=%d (callback brush overlap, NOT per-vertex ownership)",
        tostring(interval),prefix,events.lower,events.lowerCenterDown,
        events.target,events.targetCenterUp,events.targetCenterDown,
        events.raise,events.other
    )
end

local function compareSamples(previous, current)
    if previous == nil or current == nil
        or #previous.samples ~= #current.samples then return nil end
    local changed, maxUp, maxDown = 0, 0, 0
    local sumAbs = 0
    for i, after in ipairs(current.samples) do
        local before = previous.samples[i]
        local delta = after.y - before.y
        if math.abs(delta) >= Probe.THRESHOLD_M then changed = changed + 1 end
        maxUp = math.max(maxUp, delta)
        maxDown = math.min(maxDown, delta)
        sumAbs = sumAbs + math.abs(delta)
    end
    return {
        changed=changed, maxUpM=maxUp, maxDownM=maxDown,
        meanAbsM=sumAbs/#current.samples
    }
end

function Probe.capture(label)
    if Probe.position == nil then
        return nil, speak("No marked location. Stand over the hole and run reGeoMark")
    end
    local terrain = getTerrain()
    local p = Probe.position
    local unit = nil
    if type(getTerrainHeightmapUnitSize) == "function" then
        local ok, size = pcall(getTerrainHeightmapUnitSize, terrain)
        if ok and finite(size) and size > 0 then unit = size end
    end
    local fine = sampleGrid(terrain,p.x,p.z,0.125,8)
    local main = sampleGrid(terrain,p.x,p.z,1.0,2)
    if fine == nil or main == nil then
        return nil, speak("Main terrain-height API unavailable; no snapshot stored")
    end
    local rrMin, rrMax, rrCenter = residualAgainstCornerPlane(fine,8)
    local history = RealismExtensionsTerrainRuntime
        and RealismExtensionsTerrainRuntime.history or nil
    local h = history ~= nil and type(history.get)=="function"
        and history:get(p.x,p.z) or nil
    local rut = h ~= nil and tonumber(h.rutDepthM) or nil
    local ref = h ~= nil and tonumber(h.preDeformHeightM) or nil
    local nearbyCells, nearbyMax = 0, 0
    if history ~= nil and type(history.getRecoveryCellsCircle) == "function" then
        local candidates = history:getRecoveryCellsCircle(
            p.x,p.z,1.5,{minRutM=0.003,maxCells=256}
        )
        if type(candidates) == "table" then
            nearbyCells = #candidates
            for _,candidate in ipairs(candidates) do
                nearbyMax = math.max(nearbyMax,tonumber(candidate.rutDepthM) or 0)
            end
        end
    end

    Probe.captureIndex = Probe.captureIndex + 1
    local current = {
        label=tostring(label or ("snap"..Probe.captureIndex)),
        x=p.x,z=p.z,fine=fine,main=main,unitM=unit,
        rutDepthM=rut,preDeformHeightM=ref,
        valleyResidualM=rrMin,peakResidualM=rrMax,
        centerResidualM=rrCenter
    }
    speak(string.format(
        "SNAP #%d label=%s x=%.3f z=%.3f mainUnit=%s samples=25(main),289(dense SAME API) minY=%.4f maxY=%.4f centerResidual=%.4fm valleyResidual=%.4fm peakResidual=%.4fm rutDebt=%s firstTouch=%s",
        Probe.captureIndex,current.label,p.x,p.z,
        unit ~= nil and string.format("%.3fm",unit) or "unknown",
        fine.minY,fine.maxY,rrCenter,rrMin,rrMax,
        rut ~= nil and string.format("%.4fm",rut) or "none",
        ref ~= nil and string.format("%.4fm",ref) or "none"
    ))
    speak(string.format(
        "HISTORY_NEAR radius=1.5m cells=%d maxRut=%.4fm center=%s (not proof of native vertex ownership)",
        nearbyCells,nearbyMax,
        rut ~= nil and string.format("%.4fm",rut) or "none"
    ))
    local previous = Probe.previous
    local interval = previous ~= nil
        and (previous.label .. "->" .. current.label)
        or ("mark->" .. current.label)
    for _,area in ipairs({"near2m","near4m"}) do
        speak(formatWriterEvents(area, Probe.writeEvents[area], interval))
    end
    for _,stage in ipairs({"context","eligible"}) do
        speak(formatContactEvents(stage,Probe.contactEvents[stage],interval))
    end
    if previous ~= nil then
        speak(string.format(
            "SHAPE from=%s to=%s valleyResidualChange=%+.4fm peakResidualChange=%+.4fm centerResidualChange=%+.4fm (relative to measured patch corner surface, NOT restoration proof)",
            previous.label,current.label,
            current.valleyResidualM-previous.valleyResidualM,
            current.peakResidualM-previous.peakResidualM,
            current.centerResidualM-previous.centerResidualM
        ))
        for _, key in ipairs({"main","fine"}) do
            local d = compareSamples(previous[key],current[key])
            speak(string.format(
                "DELTA from=%s to=%s grid=%s changed(>=2mm)=%d/%d maxRaise=%.4fm maxLower=%.4fm avgAbsChange=%.4fm",
                previous.label,current.label,
                key=="main" and "1m" or "0.125m-sampled-MAIN-API",
                d.changed,#current[key].samples,d.maxUpM,d.maxDownM,
                d.meanAbsM
            ))
        end
    end
    Probe.previous = current
    Probe.writeEvents = newWriteEvents()
    Probe.contactEvents = newContactEvents()
    return current
end

function Probe:consoleSnap(label)
    local current = self.capture(label)
    if current == nil then return "REGeoProbe snapshot failed" end
    return "REGeoProbe snapshot " .. current.label .. " captured (READ ONLY)"
end

function Probe.installCommands()
    if Probe.commandsInstalled or type(addConsoleCommand) ~= "function" then
        return false
    end
    if g_server == nil then
        return false
    end
    addConsoleCommand("reGeoMark", "Mark diagnostic area at player or explicit x z", "consoleMark", Probe, "[x] [z]")
    addConsoleCommand("reGeoSnap", "Snapshot main terrain height API and compare with prior snapshot", "consoleSnap", Probe, "[label]")
    Probe.commandsInstalled = true
    return true
end

function Probe.uninstallCommands()
    if Probe.commandsInstalled and type(removeConsoleCommand) == "function" then
        removeConsoleCommand("reGeoMark")
        removeConsoleCommand("reGeoSnap")
    end
    Probe.commandsInstalled = false
    Probe.reset()
end
