-- Experimental, main-heightmap-unit geometry journal.
-- Unlike SpatialHistory's 0.20m mechanical model, these are observed positions
-- on the GIANTS MAIN terrain heightmap. This module NEVER writes terrain.
-- No promise is made about the separate fine tyre-track/displacement channel.
RealismExtensionsTerrainGeometryJournal =
    RealismExtensionsTerrainGeometryJournal or {}
local Journal = RealismExtensionsTerrainGeometryJournal

-- Version 2 revokes unverified ownership from old v1 sidecars. Legacy
-- geometry remains unchanged; only automatic recovery authority changes.
Journal.VERSION = 5
-- Only this small unobserved drift may preserve RE physical ownership.
-- The legacy 2mm runtime and 5mm reload tolerances are for recording
-- contextual observations, not authorizing future soil RESTORATION.
Journal.OWNED_HEIGHT_DRIFT_M = 0.00001

local function finite(v)
    return type(v) == "number" and v == v
        and v ~= math.huge and v ~= -math.huge
end

local function unitForTerrain(terrain, fallback)
    local v
    -- C++/Luau bindings emit a script error even inside pcall when given nil.
    if type(getTerrainHeightmapUnitSize) == "function"
        and type(terrain) == "number" and terrain > 0 then
        local ok, result = pcall(getTerrainHeightmapUnitSize, terrain)
        if ok then v = result end
    end
    if not finite(v) or v <= 0 then v = tonumber(fallback) end
    if not finite(v) or v <= 0 then return nil end
    return v
end

local function nativeHeight(terrain, x, z)
    if type(getTerrainHeightAtWorldPos) ~= "function"
        or type(terrain) ~= "number" or terrain <= 0 then return nil end
    local ok, v = pcall(getTerrainHeightAtWorldPos, terrain, x, 0, z)
    if ok and finite(v) then return v end
    return nil
end

function Journal.new(terrain, options)
    options = options or {}
    return setmetatable({
        terrain = terrain,
        unitM = unitForTerrain(terrain, options.unitM),
        sample = options.sample,
        observations = {},
        observationCount=0,
        -- Every new native vertex that MIGHT be altered by an enqueued
        -- operation must be reserved BEFORE the native setter runs.
        -- There is deliberately no eviction of historical deny markers.
        maxObservations=math.max(1,
            math.floor(tonumber(options.maxObservations) or 50000)),
        reservedObservationSlots=0,
        pendingByVertex = {},
        pendingByLogicalKey = {},
        pendingCount = 0,
        nextId = 0,
        -- Short-lived, one-shot recovery receipts, never serialized as
        -- physical ownership and only emitted by opted-in callers.
        recoveryProofs = {},
        nextRecoveryProofId = 0,
        -- Persisted safety tombstones: a physically verified recovery may
        -- erase its original observation, but old wheel debt is STILL stale.
        -- A foreign change downgrades its fence; never silently rebase it.
        recoveryFences = {},
        -- No unsafe eviction: old recovery epochs must never silently
        -- disappear just to make room for new automatic excavation.
        maxRecoveryFences=math.max(1,
            math.floor(tonumber(options.maxRecoveryFences) or 50000)),
        recoveryFenceCount=0,
        -- A missing/corrupt sidecar cannot make old paid recovery history
        -- disappear and silently re-enable new MAIN writes.
        quarantined=false,
        quarantineReason=nil,
        stats = {
            requested = 0,started = 0,overlapRejected = 0,
            unavailable = 0,aborted = 0,completed = 0,
            movedVertices = 0,loweredVertices = 0,raisedVertices = 0,
            noEffect = 0,untrustedRise = 0,
            submitChecks = 0,submitDriftRejected = 0,
            submitHeightUnavailable = 0,submitMaxDriftM = 0,
            anomalousCompletedFootprints = 0,
            anomalousOwnershipInvalidated = 0,
            legacyProvenanceDowngraded = 0,
            reloadOwnershipDriftDowngraded = 0,
            runtimeOwnershipDriftDowngraded = 0,
            preSaveOwnershipDriftDowngraded = 0,
            recoveredFenceDowngraded = 0,
            reloadedRecoveryFences = 0,
            importQuarantines=0,
            importForeignHeightDowngrades=0,
            recoveryFenceCapacityRefusals = 0,
            observationCapacityRefusals=0,
            observationReservationReleased=0,
            recoveryProofsUnaccounted = 0,
            recoveryProofsReconciled = 0
        }
    }, {__index=Journal})
end

function Journal:getHeight(x,z)
    if type(self.sample) == "function" then
        local v = self.sample(x,z)
        return finite(v) and v or nil
    end
    return nativeHeight(self.terrain,x,z)
end

-- A portable (Lua 5.4, no bit libraries) coordinate fingerprint.
-- Counts detect truncated XML; sorted native vertex keys detect duplicate
-- or substituted records even when the row count happens to match.
-- Hash does NOT certify numeric heights or GIANTS save atomicity; those
-- still require independent native height readback and ownership checks.
local function vertexFingerprint(rows,unit)
    if type(rows)~="table" or not finite(unit) or unit<=0 then
        return nil
    end
    local keys={}
    for _,v in ipairs(rows) do
        if type(v)~="table" or not finite(v.x) or not finite(v.z) then
            return nil
        end
        local ix=math.floor(v.x/unit+0.5)
        local iz=math.floor(v.z/unit+0.5)
        if math.abs(ix*unit-v.x)>0.00001
            or math.abs(iz*unit-v.z)>0.00001 then
            return nil
        end
        keys[#keys+1]=tostring(ix)..":"..tostring(iz)
    end
    table.sort(keys)
    local hash=2166136261
    for _,key in ipairs(keys) do
        for i=1,#key do
            -- Keep intermediate multiplication exact under 2^53.
            hash=(hash*131+key:byte(i))%4294967296
        end
        hash=(hash*131+124)%4294967296
    end
    return string.format("%08x",hash)
end

-- A malformed, incompatible or incomplete EXISTING sidecar is a global
-- loss-of-provenance event. Never salvage its partial entries into a
-- new authorization epoch or overwrite the original on a later save.
function Journal:quarantine(reason)
    self.quarantined=true
    self.quarantineReason=tostring(reason or "GEOMETRY_PROVENANCE_UNAVAILABLE")
    self.stats.importQuarantines=self.stats.importQuarantines+1
    for _,e in pairs(self.observations) do e.owned=false end
    for _,f in pairs(self.recoveryFences) do
        f.trusted=false
        f.accounted=false
    end
    self.recoveryProofs={}
    return false,self.quarantineReason
end

-- Coordinate/vertex ownership is deliberately explicit. 0.20m RE history
-- cells are NOT presumed to correspond to 1.00m main heightmap vertices.
-- The conservative radius+half-unit envelope covers interpolated soft brushes.
function Journal:enumerateVertices(x,z,radius)
    local unit = self.unitM
    if not finite(unit) or not finite(x) or not finite(z)
        or not finite(radius) or radius <= 0 then return nil end
    local reach = radius + unit * 0.75
    local fromX,toX = math.floor((x-reach)/unit),math.ceil((x+reach)/unit)
    local fromZ,toZ = math.floor((z-reach)/unit),math.ceil((z+reach)/unit)
    local out={}
    for ix=fromX,toX do
        for iz=fromZ,toZ do
            local vx,vz=ix*unit,iz*unit
            if (vx-x)^2+(vz-z)^2 <= reach^2 then
                out[#out+1]={key=tostring(ix)..":"..tostring(iz),x=vx,z=vz}
            end
        end
    end
    return out
end

-- Read-only, native-height-validated persisted post-recovery fence.
-- Trusted means ONLY that the same recovered MAIN geometry still exists;
-- it is NOT an automatic wheel write or a substitute for fine displacement.
function Journal:getRecoveryFence(key)
    local f=self.recoveryFences[key]
    if f==nil then return nil end
    if f.trusted==true then
        local y=self:getHeight(f.x,f.z)
        local entry=self.observations[key]
        if not finite(y)
            or math.abs(y-f.observedHeightM)>Journal.OWNED_HEIGHT_DRIFT_M
            or (f.completed and entry~=nil)
            or (not f.completed and (entry==nil or entry.owned~=true
                or math.abs(entry.preREHeightM-f.originalY)>
                    Journal.OWNED_HEIGHT_DRIFT_M
                or math.abs(entry.observedHeightM-f.observedHeightM)>
                    Journal.OWNED_HEIGHT_DRIFT_M)) then
            f.trusted=false
            self.stats.recoveredFenceDowngraded=
                self.stats.recoveredFenceDowngraded+1
        end
    end
    return f
end

-- Keep RE from turning a real/native depression into an unbounded pit
-- while restitution is still experimental. This is a write-time safety gate,
-- NOT a recovery command or a replacement for Mud's traction/sink physics.
-- Only samples the principal heightmap and is slope-invariant for a plane.
function Journal:getLoweringBudget(x,z,radiusM,maxVerifiedDepthM,maxConcavityM)
    if self.quarantined then return 0,"GEOMETRY_JOURNAL_QUARANTINED" end
    if not finite(self.unitM) then return nil,"UNIT_UNAVAILABLE" end
    local cap=tonumber(maxVerifiedDepthM) or 0.10
    local reliefCap=tonumber(maxConcavityM) or 0.12
    if not finite(cap) or cap<=0 or not finite(reliefCap) then
        return nil,"INVALID_LIMITS"
    end
    local verts=self:enumerateVertices(x,z,radiusM)
    if verts==nil then return nil,"FOOTPRINT_UNAVAILABLE" end
    local largestDebt=0
    for _,p in ipairs(verts) do
        local fence=self:getRecoveryFence(p.key)
        if fence~=nil and fence.trusted~=true then
            return 0,"UNTRUSTED_RECOVERY_EPOCH"
        end
        -- The main native lowering gate must independently reject a
        -- genuine but UNACCOUNTED recovery. Otherwise an isolated caller
        -- can seed a new in-RAM budget from current owned MAIN height
        -- after restart and replay pre-tillage damage without the fresh
        -- post-recovery wheel-generation capability.
        if fence~=nil and fence.accounted~=true then
            return 0,"UNACCOUNTED_RECOVERY_EPOCH"
        end
        local existing=self.observations[p.key]
        if existing~=nil then
            if existing.owned~=true then return 0,"UNTRUSTED_EDIT" end
            local y=self:getHeight(existing.x,existing.z)
            if not finite(y) then return nil,"HEIGHT_UNAVAILABLE" end
            if math.abs(y-existing.observedHeightM)>
                Journal.OWNED_HEIGHT_DRIFT_M then
                existing.owned=false
                existing.observedHeightM=y
                self.stats.runtimeOwnershipDriftDowngraded=
                    self.stats.runtimeOwnershipDriftDowngraded+1
                return 0,"EXTERNAL_EDIT"
            end
            local depth=existing.preREHeightM-y
            if not finite(depth) then return nil,"INVALID_REFERENCE" end
            largestDebt=math.max(largestDebt,depth)
        end
    end
    if largestDebt>=cap then return 0,"DEPTH_CAP" end

    -- Legacy saves lack a trusted first-touch height. Detect a deep local
    -- hollow using opposing samples so a linear natural slope cancels out.
    -- Refuse additional RE excavation in it; do not invent an old baseline.
    local u=self.unitM
    local c=self:getHeight(x,z)
    local a=self:getHeight(x-u,z)
    local b=self:getHeight(x+u,z)
    local d=self:getHeight(x,z-u)
    local e=self:getHeight(x,z+u)
    if not (finite(c) and finite(a) and finite(b)
        and finite(d) and finite(e)) then return nil,"RELIEF_UNKNOWN" end
    local concavity=math.max((a+b)*0.5-c,(d+e)*0.5-c)
    if concavity>reliefCap then return 0,"DEEP_EXISTING_HOLLOW" end
    return cap-largestDebt,nil
end

function Journal:begin(logicalKey,x,z,radiusM)
    if self.quarantined then return nil,"GEOMETRY_JOURNAL_QUARANTINED" end
    self.stats.requested=self.stats.requested+1
    local verts = self:enumerateVertices(x,z,radiusM)
    if verts == nil or #verts == 0 or logicalKey == nil
        or self.pendingByLogicalKey[logicalKey] ~= nil then
        self.stats.unavailable=self.stats.unavailable+1
        return nil,"NO_VERTICES_OR_PENDING_LOGICAL"
    end
    local newObservationSlots=0
    local before={}
    for _,v in ipairs(verts) do
        if self.pendingByVertex[v.key] ~= nil then
            self.stats.overlapRejected=self.stats.overlapRejected+1
            return nil,"OVERLAPPING_RE_WRITE"
        end
        if self.observations[v.key]==nil then
            newObservationSlots=newObservationSlots+1
        end
        local y=self:getHeight(v.x,v.z)
        if not finite(y) then
            self.stats.unavailable=self.stats.unavailable+1
            return nil,"HEIGHT_UNAVAILABLE"
        end
        before[#before+1]={key=v.key,x=v.x,z=v.z,beforeY=y}
    end
    -- All reservations are charged BEFORE applying any native mutation.
    -- Disjoint, simultaneously queued jobs must not each assume the
    -- other's free observation quota is still available.
    if self.observationCount+self.reservedObservationSlots
            +newObservationSlots>self.maxObservations then
        self.stats.observationCapacityRefusals=
            self.stats.observationCapacityRefusals+1
        return nil,"GEOMETRY_OBSERVATION_CAPACITY"
    end
    -- Any unexpected geometry edit between two RE writes ends ownership
    -- of the old baseline at that native vertex. Do not overwrite baseline.
    -- This guard is conservative and is not an attribution of the external
    -- writer; it protects deliberate TerraFarm/Construction edits.
    for _,p in ipairs(before) do
        local entry=self.observations[p.key]
        local fence=self.recoveryFences[p.key]
        if fence~=nil and fence.trusted==true
            and math.abs(fence.observedHeightM-p.beforeY)>
                Journal.OWNED_HEIGHT_DRIFT_M then
            fence.trusted=false
            self.stats.recoveredFenceDowngraded=
                self.stats.recoveredFenceDowngraded+1
        end
        if entry~=nil and math.abs(entry.observedHeightM-p.beforeY)>
                Journal.OWNED_HEIGHT_DRIFT_M then
            if entry.owned==true then
                self.stats.runtimeOwnershipDriftDowngraded=
                    self.stats.runtimeOwnershipDriftDowngraded+1
            end
            entry.owned=false
            entry.observedHeightM=p.beforeY
        end
    end
    self.nextId=self.nextId+1
    local token={id=self.nextId,key=logicalKey,points=before,
        observationReservation=newObservationSlots,
        active=true,journal=self,completed=false}
    self.reservedObservationSlots=
        self.reservedObservationSlots+newObservationSlots
    for _,p in ipairs(before) do
        -- Any subsequent native write touching the 3x3 footprint
        -- invalidates an unconsumed prior recovery receipt.
        self.recoveryProofs[p.key]=nil
        self.pendingByVertex[p.key]=token
    end
    self.pendingByLogicalKey[logicalKey]=token
    self.pendingCount=self.pendingCount+1
    self.stats.started=self.stats.started+1
    return token,nil
end

-- A journal token is captured when a wheel sample is ENQUEUED, not when
-- TerrainWriter submits the native GIANTS operation. The queued ground may
-- change meanwhile (other mods, gameplay or a long deformation queue).
-- Resample immediately before submission, reject changed ground, and rebase
-- the callback delta to these just-in-time heights. This is NOT a global
-- lock on third-party writers while GIANTS executes the native queue job.
function Journal:validateBeforeSubmit(token,maxAllowedDriftM)
    if type(token)~="table" or token.active~=true
        or self.pendingByLogicalKey[token.key]~=token then
        return false,"STALE_OR_INVALID_TOKEN"
    end
    -- Preserve the 2mm legacy queue threshold for unrelated callers.
    -- The one-vertex ABSOLUTE actuator supplies a much tighter threshold:
    -- a 0.1mm foreign edit is NOT harmless during a ~3.891mm transaction.
    local maxDrift=0.002
    if maxAllowedDriftM~=nil then
        if not finite(maxAllowedDriftM)
            or maxAllowedDriftM<=0 then
            return false,"INVALID_SUBMISSION_DRIFT_LIMIT"
        end
        maxDrift=math.min(maxDrift,maxAllowedDriftM)
    end
    local afterQueue={}
    local largestDrift=0
    for i,p in ipairs(token.points) do
        local y=self:getHeight(p.x,p.z)
        if not finite(y) then
            self.stats.submitHeightUnavailable =
                self.stats.submitHeightUnavailable+1
            return false,"SUBMISSION_HEIGHT_UNAVAILABLE"
        end
        afterQueue[i]=y
        largestDrift=math.max(largestDrift,math.abs(y-p.beforeY))
    end
    self.stats.submitChecks=self.stats.submitChecks+1
    self.stats.submitMaxDriftM=math.max(
        self.stats.submitMaxDriftM,largestDrift)
    if largestDrift>maxDrift then
        -- Do not dig into an altered patch or count queue-wait changes as a
        -- new RE rut. Invalidate any trusted first-touch baseline affected.
        for i,p in ipairs(token.points) do
            if math.abs(afterQueue[i]-p.beforeY)>maxDrift then
                local entry=self.observations[p.key]
                if entry~=nil then
                    entry.owned=false
                    entry.observedHeightM=afterQueue[i]
                end
            end
        end
        self.stats.submitDriftRejected=self.stats.submitDriftRejected+1
        return false,"QUEUED_GEOMETRY_DRIFT"
    end
    for i,p in ipairs(token.points) do
        p.beforeY=afterQueue[i]
    end
    token.submissionValidated=true
    return true,nil
end

function Journal:complete(token,successful,maxChangeIgnoreM)
    if type(token)~="table" or token.active~=true
        or self.pendingByLogicalKey[token.key]~=token then
        return nil,"STALE_OR_INVALID_TOKEN"
    end
    -- 50um is the legacy generic queue journal threshold, but the
    -- isolated absolute setter must not conceal a 20um NEIGHBOR change
    -- merely because the center moved by exactly one native quantum.
    -- Research caller can request a STRICTER threshold, never loosen it.
    local changeThreshold=0.00005
    if maxChangeIgnoreM~=nil then
        if not finite(maxChangeIgnoreM) or maxChangeIgnoreM<=0 then
            return nil,"INVALID_COMPLETION_MOVEMENT_LIMIT"
        end
        changeThreshold=math.min(changeThreshold,maxChangeIgnoreM)
    end
    -- Release ALL locks even if the engine failed.
    token.active=false
    for _,p in ipairs(token.points) do
        if self.pendingByVertex[p.key]==token then
            self.pendingByVertex[p.key]=nil
        end
    end
    self.pendingByLogicalKey[token.key]=nil
    self.pendingCount=math.max(0,self.pendingCount-1)
    self.reservedObservationSlots=math.max(0,
        self.reservedObservationSlots-(token.observationReservation or 0))
    self.stats.observationReservationReleased=
        self.stats.observationReservationReleased+1
    if self.quarantined then
        return nil,"GEOMETRY_JOURNAL_QUARANTINED"
    end

    if not successful then
        self.stats.aborted=self.stats.aborted+1
        return {success=false,movedVertices=0,maxLowerM=0,maxRaiseM=0}
    end

    -- First read the entire affected footprint. Partial reads never certify
    -- ownership of an operation; the old baseline is not silently overwritten.
    local after={}
    for i,p in ipairs(token.points) do
        local y=self:getHeight(p.x,p.z)
        if not finite(y) then
            self.stats.unavailable=self.stats.unavailable+1
            return nil,"POST_HEIGHT_UNAVAILABLE"
        end
        after[i]=y
    end

    local result={
        success=true,movedVertices=0,loweredVertices=0,raisedVertices=0,
        maxLowerM=0,maxRaiseM=0,deltaSumM=0,unitM=self.unitM,
        sampledVertices=#token.points
    }
    for i,p in ipairs(token.points) do
        local y=after[i]
        local delta=y-p.beforeY
        if math.abs(delta)>changeThreshold then
            result.movedVertices=result.movedVertices+1
            result.deltaSumM=result.deltaSumM+delta
            local entry=self.observations[p.key]
            if delta<0 then
                local lowering=-delta
                result.loweredVertices=result.loweredVertices+1
                if lowering>result.maxLowerM then
                    result.maxLowerM=lowering
                    result.maxLowerPoint={key=p.key,x=p.x,z=p.z,
                        beforeY=p.beforeY,afterY=y}
                end
                if entry==nil then
                    entry={x=p.x,z=p.z,preREHeightM=p.beforeY,observedHeightM=y,owned=true}
                else
                    -- Once provenance was invalidated, track subsequent known
                    -- geometry changes WITHOUT resurrecting the old reference.
                    entry.observedHeightM=y
                end
            else
                result.raisedVertices=result.raisedVertices+1
                result.maxRaiseM=math.max(result.maxRaiseM,delta)
                if entry==nil then
                    entry={x=p.x,z=p.z,preREHeightM=p.beforeY,observedHeightM=y,owned=false}
                else
                    entry.observedHeightM=y
                    entry.owned=false
                end
                self.stats.untrustedRise=self.stats.untrustedRise+1
            end
            if self.observations[p.key]==nil then
                self.observationCount=self.observationCount+1
            end
            self.observations[p.key]=entry
            local fence=self.recoveryFences[p.key]
            if fence~=nil then
                if delta<0 and entry.owned==true
                    and fence.trusted==true
                    and math.abs(fence.observedHeightM-p.beforeY)
                        <=Journal.OWNED_HEIGHT_DRIFT_M
                    and math.abs(entry.preREHeightM-fence.originalY)
                        <=Journal.OWNED_HEIGHT_DRIFT_M then
                    fence.observedHeightM=y
                    fence.completed=false
                else
                    -- A foreign or upward generic brush is NOT a
                    -- journal-confirmed recovery of a previous generation.
                    fence.trusted=false
                end
            end
        end
    end
    token.completed=true
    self.stats.completed=self.stats.completed+1
    if result.movedVertices==0 then self.stats.noEffect=self.stats.noEffect+1 end
    self.stats.movedVertices=self.stats.movedVertices+result.movedVertices
    self.stats.loweredVertices=self.stats.loweredVertices+result.loweredVertices
    self.stats.raisedVertices=self.stats.raisedVertices+result.raisedVertices
    return result,nil
end

-- An anomalous LOWER outcome must NEVER become recovery authority merely
-- because it happened before the RE callback. Other writers may have changed
-- the same terrain during the asynchronous native operation, and a large
-- amplitude may exceed our own requested delta. This after-completion veto
-- invalidates *all* possibly affected native vertices, including previously
-- trusted baselines, but does not undo or raise any physical ground.
-- Must be called synchronously in the callback after complete(token,true).
function Journal:invalidateCompletedFootprint(token,reason)
    if type(token)~="table" or token.journal~=self
        or token.active==true or token.completed~=true
        or token.ownershipInvalidated==true then
        return false,"COMPLETED_TOKEN_UNAVAILABLE"
    end
    local invalidated=0
    for _,point in ipairs(token.points or {}) do
        local e=self.observations[point.key]
        if e~=nil then
            if e.owned==true then invalidated=invalidated+1 end
            e.owned=false
        end
        -- Native anomalies can touch an independently RE-owned recovery
        -- vertex even if its OWN center height happens not to move.
        -- The old 3x3 provenance is no longer exclusive, so do not keep
        -- a paid fence trusted after quarantining this footprint.
        local f=self.recoveryFences[point.key]
        if f~=nil and f.trusted==true then
            f.trusted=false
            self.stats.recoveredFenceDowngraded=
                self.stats.recoveredFenceDowngraded+1
        end
        if f~=nil then f.accounted=false end
    end
    token.ownershipInvalidated=true
    token.ownershipInvalidationReason=tostring(reason or "UNTRUSTED_NATIVE_OUTCOME")
    self.stats.anomalousCompletedFootprints=
        (self.stats.anomalousCompletedFootprints or 0)+1
    self.stats.anomalousOwnershipInvalidated=
        (self.stats.anomalousOwnershipInvalidated or 0)+invalidated
    return true,invalidated
end

-- Experimental causal restitution applies only to a geometry vertex with
-- verified pre-RE reference and an unchanged, still-owned RE lowering.
-- It never infers a height from legacy 0.20m mechanical rut debt.
function Journal:getRecoverablePoint(ix, iz, minDepthM)
    if self.quarantined or not finite(self.unitM) then return nil end
    local key=tostring(ix)..":"..tostring(iz)
    if self.pendingByVertex[key]~=nil then return nil end
    local e=self.observations[key]
    if e==nil or e.owned~=true then return nil end
    local current=self:getHeight(e.x,e.z)
    if not finite(current) then return nil end
    if math.abs(current-e.observedHeightM)>
        Journal.OWNED_HEIGHT_DRIFT_M then
        -- Even a non-RE millimeter correction from TerraFarm, another
        -- mod, or player levelling cannot become "our" rut. Otherwise
        -- autonomous tillage would raise geometry against a stale owner.
        e.owned=false
        e.observedHeightM=current
        self.stats.runtimeOwnershipDriftDowngraded=
            self.stats.runtimeOwnershipDriftDowngraded+1
        return nil
    end
    local deficit=e.preREHeightM-current
    if deficit<math.max(0.003,tonumber(minDepthM) or 0.003)
        or deficit>0.4 then return nil end
    return {key=key,x=e.x,z=e.z,beforeY=current,
        originalY=e.preREHeightM,deficitM=deficit}
end

function Journal:beginRecovery(point, radiusM, requestProof)
    if self.quarantined then return nil,"GEOMETRY_JOURNAL_QUARANTINED" end
    if type(point)~="table" or not finite(self.unitM) then
        return nil,"NO_TRUSTED_VERTEX"
    end
    local ix=math.floor(point.x/self.unitM+0.5)
    local iz=math.floor(point.z/self.unitM+0.5)
    local current=self:getRecoverablePoint(ix,iz,0.003)
    if current==nil or current.key~=point.key then
        return nil,"REFERENCE_NOT_TRUSTED"
    end
    -- This is the PROVENANCE/READBACK envelope, not the physical
    -- writer's brush radius. enumerateVertices extends by 0.75 unit;
    -- 0.56+0.75=1.31 misses all four DIAGONAL vertices at sqrt(2).
    -- A recovery brush that moves one of those corners must fail CLOSED.
    -- Cover the full 3x3 even when a caller requested a narrow 0.56u
    -- recovery brush. Keep the actual native brush width unchanged.
    if self.recoveryFences[point.key]==nil
        and self.recoveryFenceCount>=self.maxRecoveryFences then
        self.stats.recoveryFenceCapacityRefusals=
            self.stats.recoveryFenceCapacityRefusals+1
        return nil,"RECOVERY_FENCE_CAPACITY"
    end
    local radius=self.unitM*0.70
    local token,reason=self:begin("RECOVER:"..point.key,
        current.x,current.z,radius)
    if token==nil then return nil,reason end
    token.targetKey=point.key
    token.targetOriginalY=current.originalY
    token.targetBeforeY=current.beforeY
    token.recoveryProofRequested=requestProof==true
    return token,nil
end

-- This differs from the LOWER callback path: a known RE depression may
-- legitimately be raised toward its immutable first-touch height. Every
-- altered *other* native vertex is flagged as collateral, not re-attributed.
function Journal:finishRecovery(token,success)
    if type(token)~="table" or token.active~=true
        or self.pendingByLogicalKey[token.key]~=token
        or token.targetKey==nil then return nil,"STALE_RECOVERY_TOKEN" end
    token.active=false
    for _,p in ipairs(token.points) do
        if self.pendingByVertex[p.key]==token then
            self.pendingByVertex[p.key]=nil
        end
    end
    self.pendingByLogicalKey[token.key]=nil
    self.pendingCount=math.max(0,self.pendingCount-1)
    self.reservedObservationSlots=math.max(0,
        self.reservedObservationSlots-(token.observationReservation or 0))
    self.stats.observationReservationReleased=
        self.stats.observationReservationReleased+1
    if self.quarantined then
        return nil,"GEOMETRY_JOURNAL_QUARANTINED"
    end
    if not success then return {success=false,gainM=0,collateral=0} end
    local post={}
    for i,p in ipairs(token.points) do
        local y=self:getHeight(p.x,p.z)
        if not finite(y) then return nil,"POST_HEIGHT_UNAVAILABLE" end
        post[i]=y
    end
    local target=nil
    local collateral=0
    for i,p in ipairs(token.points) do
        local y=post[i]
        local delta=y-p.beforeY
        if p.key==token.targetKey then
            target=y
        elseif math.abs(delta)>Journal.OWNED_HEIGHT_DRIFT_M then
            collateral=collateral+1
            local e=self.observations[p.key]
            if e~=nil then e.owned=false;e.observedHeightM=y end
            local fence=self.recoveryFences[p.key]
            if fence~=nil then fence.trusted=false end
        end
    end
    if not finite(target) then return nil,"TARGET_VERTEX_UNOBSERVED" end
    local beforeDeficit=token.targetOriginalY-token.targetBeforeY
    local afterDeficit=token.targetOriginalY-target
    local gain=beforeDeficit-math.max(0,afterDeficit)
    -- "Improved" must never be confused with "physically restored".
    -- On the measured 255/65535m MAIN lattice, the former 4mm closure
    -- threshold accepted ONE WHOLE q-sized hole (~3.891mm) as repaired.
    -- Retain the immutable baseline until the residual is small enough
    -- to be unrepresentable as an entire native MAIN step.
    local completedToleranceM=0.0011
    local noUnownedMovement=collateral==0
    local targetInBounds=target<=token.targetOriginalY
            +Journal.OWNED_HEIGHT_DRIFT_M
        and target>=token.targetBeforeY
            -Journal.OWNED_HEIGHT_DRIFT_M
    local safe=noUnownedMovement and targetInBounds
    local completed=safe and afterDeficit<=completedToleranceM
    local e=self.observations[token.targetKey]
    if e~=nil then
        e.observedHeightM=target
        if not safe then
            -- Unsafe brush movement is not recovery evidence and
            -- cannot authorize further autonomous repair after reload.
            e.owned=false
        elseif completed then
            self.observations[token.targetKey]=nil
            self.observationCount=math.max(0,self.observationCount-1)
        end
    end
    local result={success=true,gainM=math.max(0,gain),afterY=target,
        beforeY=token.targetBeforeY,collateral=collateral,
        completed=completed,safe=safe}
    if safe and gain>Journal.OWNED_HEIGHT_DRIFT_M then
        for _,p in ipairs(token.points) do
            if p.key==token.targetKey then
                if self.recoveryFences[p.key]==nil then
                    self.recoveryFenceCount=self.recoveryFenceCount+1
                end
                -- A native rising height alone cannot prove the PAID
                -- cumulative wheel ledger was reconciled. While a proof
                -- is outstanding this must be untrusted, including if
                -- the prior partial-recovery fence had been trusted.
                local pending=token.recoveryProofRequested==true
                self.recoveryFences[p.key]={
                    x=p.x,z=p.z,originalY=token.targetOriginalY,
                    observedHeightM=target,completed=completed,
                    trusted=true,accounted=false,pendingProof=pending
                }
                if pending then
                    self.stats.recoveryProofsUnaccounted=
                        self.stats.recoveryProofsUnaccounted+1
                end
                break
            end
        end
    elseif not safe and self.recoveryFences[token.targetKey]~=nil then
        self.recoveryFences[token.targetKey].trusted=false
    end
    if token.recoveryProofRequested and safe
        and gain>Journal.OWNED_HEIGHT_DRIFT_M then
        self.nextRecoveryProofId=self.nextRecoveryProofId+1
        local proof={
            id=self.nextRecoveryProofId,key=token.targetKey,
            originalY=token.targetOriginalY,
            beforeY=token.targetBeforeY,afterY=target,
            completed=completed
        }
        -- Recover the target's exact MAIN vertex coordinates from the
        -- transaction itself, not from any user-provided receipt fields.
        for _,p in ipairs(token.points) do
            if p.key==token.targetKey then
                proof.x,proof.z=p.x,p.z
                break
            end
        end
        self.recoveryProofs[proof.key]=proof
        result.recoveryProof=proof
    end
    return result
end

-- Read-only validation before the paid-depth ledger is changed. The
-- journal does not turn the new fence trusted until *after* the budget
-- verifies its old committed depth against measured physical beforeDepth.
-- For proofRequested=false the already observed physical fence is retained,
-- but there is NO automatic budget or replay-authorizing source.
function Journal:verifyRecoveryProof(proof)
    if type(proof)~="table" or type(proof.key)~="string"
        or self.recoveryProofs[proof.key]~=proof then
        return nil,"NO_JOURNAL_RECOVERY_PROOF"
    end
    if self.pendingByVertex[proof.key]~=nil then
        return nil,"RECOVERY_PROOF_VERTEX_PENDING"
    end
    local actual=self:getHeight(proof.x,proof.z)
    if not finite(actual)
        or math.abs(actual-proof.afterY)>Journal.OWNED_HEIGHT_DRIFT_M then
        return nil,"RECOVERY_PROOF_READBACK_CHANGED"
    end
    local entry=self.observations[proof.key]
    if proof.completed then
        if entry~=nil
            or math.abs(actual-proof.originalY)>0.0011 then
            return nil,"RECOVERY_PROOF_COMPLETION_INVALID"
        end
    elseif entry==nil or entry.owned~=true
        or math.abs(entry.preREHeightM-proof.originalY)>
            Journal.OWNED_HEIGHT_DRIFT_M
        or math.abs(entry.observedHeightM-proof.afterY)>
            Journal.OWNED_HEIGHT_DRIFT_M then
        return nil,"RECOVERY_PROOF_OWNERSHIP_INVALID"
    end
    return {
        key=proof.key,completed=proof.completed,
        x=proof.x,z=proof.z,
        originalY=proof.originalY,afterY=proof.afterY,
        beforeDepthM=math.max(0,proof.originalY-proof.beforeY),
        afterDepthM=math.max(0,proof.originalY-proof.afterY)
    },nil
end

-- Commit only after the quantized budget has checked its *previously
-- paid* depth. A failed or interrupted reconciliation leaves the saved
-- fence untrusted; old wheel state cannot become fresh damage by reload.
function Journal:consumeRecoveryProof(proof)
    local measured,reason=self:verifyRecoveryProof(proof)
    if measured==nil then return nil,reason end
    local fence=self.recoveryFences[measured.key]
    if fence==nil or fence.pendingProof~=true
        or fence.trusted~=true or fence.accounted==true
        or not finite(fence.originalY)
        or math.abs(fence.originalY-measured.originalY)>
            Journal.OWNED_HEIGHT_DRIFT_M
        or math.abs(fence.observedHeightM-measured.afterY)>
            Journal.OWNED_HEIGHT_DRIFT_M
        or fence.completed~=measured.completed then
        return nil,"RECOVERY_FENCE_NOT_PENDING_ACCOUNTING"
    end
    self.recoveryProofs[measured.key]=nil
    fence.pendingProof=false
    fence.accounted=true
    fence.trusted=true
    self.stats.recoveryProofsReconciled=
        self.stats.recoveryProofsReconciled+1
    return measured,nil
end

-- Snapshot is a geometry provenance sidecar, not a replacement for
-- GIANTS native heightmap persistence. Never serialize an in-flight job as if
-- the terrain result were confirmed, and never retroactively reconstruct an
-- unknown original from the observed rut.
function Journal:exportSnapshot()
    if self.quarantined then
        return nil,"GEOMETRY_JOURNAL_QUARANTINED"
    end
    if self.pendingCount>0 or self.reservedObservationSlots~=0 then
        return nil,"PENDING_NATIVE_WRITES"
    end
    if self.observationCount>self.maxObservations then
        return nil,"GEOMETRY_OBSERVATION_CAPACITY_EXCEEDED"
    end
    if not finite(self.unitM) or self.unitM<=0 then
        return nil,"native heightmap unit unavailable"
    end
    local cells={}
    local unknown=0
    for key,entry in pairs(self.observations) do
        local current=self:getHeight(entry.x,entry.z)
        if not finite(current) then
            -- Do not overwrite a previously good XML with a sidecar
            -- silently missing an owned cell while GIANTS height isn't
            -- readable during a native save phase.
            return nil,"GEOMETRY_EXPORT_HEIGHT_UNAVAILABLE"
        end
        local drift=math.abs(current-entry.observedHeightM)
        if drift>Journal.OWNED_HEIGHT_DRIFT_M
            and entry.owned==true then
            -- IMPORTANT: exporting a sidecar must never silently rebase
            -- an owned reference onto 20um..2mm of unknown native change.
            -- Revoke BEFORE creating the snapshot, not just on load.
            entry.owned=false
            self.stats.preSaveOwnershipDriftDowngraded=
                self.stats.preSaveOwnershipDriftDowngraded+1
        end
        if drift>0.002 then
            -- Preserve a foreign-edited vertex as an UNTRUSTED deny
            -- marker; dropping it would open the gate after reload.
            unknown=unknown+1
            entry.owned=false
        end
        entry.observedHeightM=current
        cells[#cells+1]={
            key=key,x=entry.x,z=entry.z,
            preREHeightM=entry.preREHeightM,
            observedHeightM=current,owned=entry.owned==true
        }
    end
    table.sort(cells,function(a,b)return a.key<b.key end)
    local fences={}
    if self.recoveryFenceCount>self.maxRecoveryFences then
        return nil,"RECOVERY_FENCE_CAPACITY_EXCEEDED"
    end
    for key,f in pairs(self.recoveryFences) do
        self:getRecoveryFence(key)
        fences[#fences+1]={
            x=f.x,z=f.z,originalY=f.originalY,
            observedHeightM=f.observedHeightM,
            completed=f.completed==true,trusted=f.trusted==true,
            accounted=f.accounted==true
        }
    end
    table.sort(fences,function(a,b)
        if a.x==b.x then return a.z<b.z end
        return a.x<b.x
    end)
    local cellFingerprint=vertexFingerprint(cells,self.unitM)
    local fenceFingerprint=vertexFingerprint(fences,self.unitM)
    if cellFingerprint==nil or fenceFingerprint==nil then
        return nil,"GEOMETRY_EXPORT_COORDINATES_INVALID"
    end
    return {version=Journal.VERSION,unitM=self.unitM,cells=cells,
        fences=fences,unknown=unknown,
        manifest={cellCount=#cells,fenceCount=#fences,
            cellKeys=cellFingerprint,fenceKeys=fenceFingerprint}}
end

function Journal:importSnapshot(snapshot)
    if self.quarantined then return false,"GEOMETRY_JOURNAL_QUARANTINED" end
    if self.pendingCount>0 then return false,"PENDING_NATIVE_WRITES" end
    local v=type(snapshot)=="table" and snapshot.version or nil
    local legacyV1=v==1
    local legacyV3=v==3
    local legacyV4=v==4
    local strict=v==Journal.VERSION
    if type(snapshot)~="table" or not (v==1 or v==2
            or legacyV3 or legacyV4 or strict)
        or not finite(snapshot.unitM) or not finite(self.unitM)
        or math.abs(snapshot.unitM-self.unitM)>0.00001
        or type(snapshot.cells)~="table" then
        return self:quarantine("GEOMETRY_JOURNAL_FORMAT_OR_UNIT_MISMATCH")
    end
    if #snapshot.cells>self.maxObservations then
        return self:quarantine("GEOMETRY_OBSERVATION_IMPORT_CAPACITY")
    end
    if strict then
        local m=snapshot.manifest
        if type(snapshot.fences)~="table" or type(m)~="table"
            or not finite(m.cellCount) or not finite(m.fenceCount)
            or m.cellCount~=#snapshot.cells
            or m.fenceCount~=#snapshot.fences
            or m.cellCount~=math.floor(m.cellCount)
            or m.fenceCount~=math.floor(m.fenceCount)
            or m.cellKeys~=vertexFingerprint(snapshot.cells,self.unitM)
            or m.fenceKeys~=vertexFingerprint(snapshot.fences,self.unitM) then
            return self:quarantine("GEOMETRY_JOURNAL_MANIFEST_MISMATCH")
        end
    end
    if (strict or legacyV3 or legacyV4)
        and (type(snapshot.fences)~="table"
            or #snapshot.fences>self.maxRecoveryFences) then
        return self:quarantine("RECOVERY_FENCE_IMPORT_CAPACITY")
    end
    local loaded,fences={},{}
    local restored,rejected,legacyDowngraded,driftDowngraded=0,0,0,0
    local foreignDowngraded=0
    for _,cell in ipairs(snapshot.cells) do
        local ok=type(cell)=="table" and finite(cell.x)
            and finite(cell.z) and finite(cell.preREHeightM)
            and finite(cell.observedHeightM)
        if ok then
            local ix=math.floor(cell.x/self.unitM+0.5)
            local iz=math.floor(cell.z/self.unitM+0.5)
            local x,z=ix*self.unitM,iz*self.unitM
            local key=tostring(ix)..":"..tostring(iz)
            local aligned=math.abs(x-cell.x)<=0.00001
                and math.abs(z-cell.z)<=0.00001
            local current=aligned and self:getHeight(x,z) or nil
            if strict and (not aligned or loaded[key]~=nil
                or not finite(current) or type(cell.owned)~="boolean") then
                return self:quarantine("GEOMETRY_JOURNAL_CELL_INVALID")
            end
            local drift=finite(current)
                and math.abs(current-cell.observedHeightM) or math.huge
            if aligned and finite(current)
                and (drift<=0.005 or strict) then
                local formerlyOwned=cell.owned==true
                local physicallyTrusted=drift<=Journal.OWNED_HEIGHT_DRIFT_M
                if strict and drift>0.005 then
                    -- This is an independently observed FOREIGN edit,
                    -- not malformed XML. Retain the native key but
                    -- remove its RE-owned ability to raise/dig.
                    foreignDowngraded=foreignDowngraded+1
                end
                loaded[key]={
                    x=x,z=z,preREHeightM=cell.preREHeightM,
                    observedHeightM=current,
                    owned=formerlyOwned and not legacyV1
                        and physicallyTrusted
                }
                if legacyV1 and formerlyOwned then
                    legacyDowngraded=legacyDowngraded+1
                elseif formerlyOwned and not physicallyTrusted then
                    driftDowngraded=driftDowngraded+1
                end
                restored=restored+1
            else
                rejected=rejected+1
            end
        elseif strict then
            return self:quarantine("GEOMETRY_JOURNAL_CELL_MALFORMED")
        else
            rejected=rejected+1
        end
    end
    local fenceCount=0
    if strict or legacyV3 or legacyV4 then
        for _,f in ipairs(snapshot.fences) do
            local ok=type(f)=="table" and finite(f.x)
                and finite(f.z) and finite(f.originalY)
                and finite(f.observedHeightM)
                and type(f.completed)=="boolean"
                and type(f.trusted)=="boolean"
            if strict then
                ok=ok and type(f.accounted)=="boolean"
            end
            if ok then
                local ix=math.floor(f.x/self.unitM+0.5)
                local iz=math.floor(f.z/self.unitM+0.5)
                local x,z=ix*self.unitM,iz*self.unitM
                local key=tostring(ix)..":"..tostring(iz)
                local aligned=math.abs(x-f.x)<=0.00001
                    and math.abs(z-f.z)<=0.00001
                if strict and (not aligned or fences[key]~=nil) then
                    return self:quarantine("RECOVERY_FENCE_KEY_INVALID")
                end
                if aligned and fences[key]==nil then
                    local y=self:getHeight(x,z)
                    if strict and not finite(y) then
                        return self:quarantine("RECOVERY_FENCE_NATIVE_HEIGHT_UNAVAILABLE")
                    end
                    local trusted=f.trusted==true and finite(y)
                        and math.abs(y-f.observedHeightM)
                            <=Journal.OWNED_HEIGHT_DRIFT_M
                    local e=loaded[key]
                    if trusted then
                        trusted=(f.completed and e==nil
                            and math.abs(f.originalY-y)<=0.0011)
                            or (not f.completed and e~=nil
                            and e.owned==true
                            and math.abs(e.preREHeightM-f.originalY)
                                <=Journal.OWNED_HEIGHT_DRIFT_M
                            and math.abs(e.observedHeightM-y)
                                <=Journal.OWNED_HEIGHT_DRIFT_M)
                    end
                    -- Old V3/V4 never carried structural v5 manifest;
                    -- physical readback may be trustworthy, but no
                    -- automatically PAID epoch is silently migrated.
                    local accounted=strict and f.accounted==true
                        and trusted==true
                    fences[key]={
                        x=x,z=z,originalY=f.originalY,
                        observedHeightM=f.observedHeightM,
                        completed=f.completed,trusted=trusted==true,
                        accounted=accounted==true,pendingProof=false
                    }
                    fenceCount=fenceCount+1
                    if f.trusted and not trusted then
                        self.stats.recoveredFenceDowngraded=
                            self.stats.recoveredFenceDowngraded+1
                    end
                end
            elseif strict then
                return self:quarantine("RECOVERY_FENCE_MALFORMED")
            end
        end
    end
    -- Atomic RAM publication: failed manifest/cap/duplicate/native probes
    -- never leave a half-loaded subset that subsequent wheel samples trust.
    local importedObservationCount=0
    for _ in pairs(loaded) do
        importedObservationCount=importedObservationCount+1
    end
    self.observations=loaded
    self.observationCount=importedObservationCount
    self.recoveryFences=fences
    self.recoveryFenceCount=fenceCount
    self.recoveryProofs={}
    self.stats.reloadedRecoveryFences=
        self.stats.reloadedRecoveryFences+fenceCount
    self.stats.legacyProvenanceDowngraded=
        self.stats.legacyProvenanceDowngraded+legacyDowngraded
    self.stats.reloadOwnershipDriftDowngraded=
        self.stats.reloadOwnershipDriftDowngraded+driftDowngraded
    self.stats.importForeignHeightDowngrades=
        self.stats.importForeignHeightDowngrades+foreignDowngraded
    return true,restored,rejected
end

function Journal:reset()
    self.quarantined=false
    self.quarantineReason=nil
    self.recoveryFenceCount=0
    self.recoveryFences={}
    self.recoveryProofs={}
    self.nextRecoveryProofId=0
    self.observations={}
    self.observationCount=0
    self.reservedObservationSlots=0
    self.pendingByVertex={}
    self.pendingByLogicalKey={}
    self.pendingCount=0
end

return Journal
