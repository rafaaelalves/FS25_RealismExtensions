RealismExtensionsPTOProfiles = RealismExtensionsPTOProfiles or {}
local Profiles = RealismExtensionsPTOProfiles
local Model = RealismExtensionsPTOModel

Profiles.VERSION = 1

-- Evidence-only catalog. Unknown tractors deliberately fall back to their
-- native GIANTS 540 ratio instead of guessing 1000/Economy capability from HP.
Profiles.TRACTORS = {
    {
        id = "fiat_180_90",
        tokens = { "180-90", "180_90", "18090" },
        modes = {
            [Model.MODE.RPM_540] = {},
            [Model.MODE.RPM_1000] = {}
        }
    }
}

-- Only requirements that FS25 data cannot represent reliably belong here.
-- Ordinary implements continue to use their native powerConsumer.ptoRpm.
Profiles.IMPLEMENTS = {
    {
        id = "heizohack_hm10_500",
        tokens = { "hm10500", "hm10-500", "hm10_500", "hm 10-500" },
        shaftRpm = 1000
    }
}

local function lower(v)
    return string.lower(tostring(v or ""))
end

local function basename(path)
    path = lower(path):gsub("\\", "/")
    return path:match("([^/]+)$") or path
end

local function identityBlob(object)
    if object == nil then return "" end

    local parts = {
        lower(object.configFileName),
        lower(object.configFileNameClean),
        lower(object.typeName)
    }

    if type(object.getName) == "function" then
        local ok, value = pcall(object.getName, object)
        if ok then parts[#parts + 1] = lower(value) end
    end

    if type(object.getFullName) == "function" then
        local ok, value = pcall(object.getFullName, object)
        if ok then parts[#parts + 1] = lower(value) end
    end

    parts[#parts + 1] = basename(object.configFileName)
    return table.concat(parts, " ")
end

local function matches(entry, blob)
    for _, token in ipairs(entry.tokens or {}) do
        token = lower(token)
        if token ~= "" and string.find(blob, token, 1, true) ~= nil then
            return true
        end
    end
    return false
end

function Profiles.findTractor(object)
    local blob = identityBlob(object)
    for _, entry in ipairs(Profiles.TRACTORS) do
        if matches(entry, blob) then return entry end
    end
    return nil
end

function Profiles.findImplement(object)
    local blob = identityBlob(object)
    for _, entry in ipairs(Profiles.IMPLEMENTS) do
        if matches(entry, blob) then return entry end
    end
    return nil
end

function Profiles.getIdentityBlob(object)
    return identityBlob(object)
end

return Profiles
