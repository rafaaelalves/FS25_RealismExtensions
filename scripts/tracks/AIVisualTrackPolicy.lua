RealismExtensionsAIVisualTrackPolicy =
    RealismExtensionsAIVisualTrackPolicy or {}
local Policy = RealismExtensionsAIVisualTrackPolicy

Policy.VERSION = 1
Policy.stats = Policy.stats or {
    installAttempts = 0,
    classesPatched = 0,
    calls = 0,
    baseAllowed = 0,
    baseDenied = 0,
    aiActiveCalls = 0
}
Policy.patched = Policy.patched or {}

local function enabled()
    return RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.modules ~= nil
        and RealismExtensionsConfig.modules.AIVisualTireTracks == true
end

-- GIANTS AI specializations normally implement:
--   return superFunc(self) and not self:getIsAIActive()
--
-- RE intentionally removes ONLY the AI-active suppression. The complete
-- lower getAllowTireTracks chain still executes, so TireTracks distance,
-- segment-quality and any earlier owner restrictions remain authoritative.
function Policy.getAllowTireTracks(self, superFunc)
    Policy.stats.calls = Policy.stats.calls + 1

    local allowed = superFunc(self) == true
    if allowed then
        Policy.stats.baseAllowed = Policy.stats.baseAllowed + 1
    else
        Policy.stats.baseDenied = Policy.stats.baseDenied + 1
    end

    if self ~= nil and type(self.getIsAIActive) == "function" then
        local ok, active = pcall(self.getIsAIActive, self)
        if ok and active == true then
            Policy.stats.aiActiveCalls =
                Policy.stats.aiActiveCalls + 1
        end
    end

    return allowed
end

local function patchClass(name, classTable)
    if type(classTable) ~= "table"
        or type(classTable.getAllowTireTracks) ~= "function" then
        return false, "class/method unavailable"
    end

    if Policy.patched[name] ~= nil then
        return true, "already patched"
    end

    Policy.patched[name] = {
        classTable = classTable,
        original = classTable.getAllowTireTracks
    }
    classTable.getAllowTireTracks = Policy.getAllowTireTracks
    Policy.stats.classesPatched = Policy.stats.classesPatched + 1
    return true, nil
end

function Policy.install()
    Policy.stats.installAttempts = Policy.stats.installAttempts + 1
    if not enabled() then return false, "AI visual tire tracks disabled" end

    local patched = 0
    local ok1 = patchClass("AIImplement", AIImplement)
    if ok1 then patched = patched + 1 end

    local ok2 = patchClass("AIJobVehicle", AIJobVehicle)
    if ok2 then patched = patched + 1 end

    if patched == 0 then
        return false, "no AI tire-track specialization available"
    end
    return true, nil
end

function Policy.getDiagnostics()
    local out = {}
    for k,v in pairs(Policy.stats or {}) do out[k]=v end
    out.enabled = enabled()
    out.aiImplementPatched = Policy.patched.AIImplement ~= nil
    out.aiJobVehiclePatched = Policy.patched.AIJobVehicle ~= nil
    return out
end

Policy.install()
return Policy
