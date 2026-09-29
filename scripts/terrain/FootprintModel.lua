RealismExtensionsFootprintModel = RealismExtensionsFootprintModel or {}
local Model = RealismExtensionsFootprintModel

Model.VERSION = 1

Model.DEFAULTS = {
    -- UMN agricultural-compaction guidance reports radial tire ground pressure
    -- roughly 1-2 psi above correct inflation pressure. 10 kPa ~= 1.45 psi.
    radialCasingAllowancePa = 10000,

    -- MR's existing geometry approximation remains only as a degraded fallback
    -- when no authoritative tire-pressure state is available.
    legacyGeometryAreaFactor = 0.53,

    minimumPressurePa = 20000
}

local function validNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function validPositive(value)
    return validNumber(value) and value > 0
end

local function clamp(value, lo, hi)
    return math.max(lo, math.min(hi, value))
end

local function mergeOptions(options)
    local result = {}
    for key, value in pairs(Model.DEFAULTS) do
        result[key] = value
    end
    for key, value in pairs(options or {}) do
        result[key] = value
    end
    return result
end

local function unavailable(reason, kind)
    return {
        available = false,
        reason = reason,
        kind = kind
    }
end

local function pressureDriven(context, options, width, radius, loadN)
    local inflationBar = tonumber(context.tirePressureBar)
    if not validPositive(inflationBar) then
        return nil
    end

    local inflationPa = inflationBar * 100000
    local casingAllowancePa = math.max(
        0,
        tonumber(options.radialCasingAllowancePa) or 0
    )

    local targetPressurePa = math.max(
        tonumber(options.minimumPressurePa) or 1,
        inflationPa + casingAllowancePa
    )

    local targetAreaM2 = loadN / targetPressurePa
    local maxLengthM = 2 * radius
    local targetLengthM = targetAreaM2 / width

    -- A contact patch cannot be longer than the tire diameter. If the
    -- pressure/load state requests more support area than the geometry can
    -- provide, preserve geometry and report the resulting higher pressure.
    local geometryLimited = targetLengthM > maxLengthM
    local lengthM = math.min(targetLengthM, maxLengthM)
    local areaM2 = width * lengthM

    if not validPositive(areaM2) then
        return nil
    end

    local pressurePa = loadN / areaM2

    return {
        available = true,
        kind = "PNEUMATIC",
        model = "PRESSURE_DRIVEN",
        confidence = context.wheelLoadMeasured == true and "HIGH" or "MEDIUM",

        supportWidthM = width,
        footprintLengthM = lengthM,
        contactAreaM2 = areaM2,

        inflationPressureBar = inflationBar,
        targetGroundPressurePa = targetPressurePa,
        groundPressurePa = pressurePa,

        geometryLimited = geometryLimited,
        loadMeasured = context.wheelLoadMeasured == true
    }
end

local function geometryFallback(context, options, width, radius, loadN)
    local factor = tonumber(options.legacyGeometryAreaFactor)
        or Model.DEFAULTS.legacyGeometryAreaFactor

    local areaM2 = width * radius * math.max(0.01, factor)
    local maxAreaM2 = width * (2 * radius)
    areaM2 = math.min(areaM2, maxAreaM2)

    if not validPositive(areaM2) then
        return nil
    end

    return {
        available = true,
        kind = "PNEUMATIC",
        model = "GEOMETRY_FALLBACK",
        confidence = "LOW",

        supportWidthM = width,
        footprintLengthM = areaM2 / width,
        contactAreaM2 = areaM2,

        inflationPressureBar = nil,
        targetGroundPressurePa = nil,
        groundPressurePa = loadN / areaM2,

        geometryLimited = false,
        loadMeasured = context.wheelLoadMeasured == true
    }
end

function Model.compute(context, options)
    if type(context) ~= "table" then
        return unavailable("wheel context unavailable")
    end

    if context.grounded ~= true then
        return unavailable("wheel is not grounded")
    end

    local width = tonumber(context.supportWidthM or context.tireWidthM)
    local radius = tonumber(context.structuralRadiusM)
    local loadN = tonumber(context.wheelLoadN)

    if not validPositive(width) then
        return unavailable("support width unavailable")
    end
    if not validPositive(radius) then
        return unavailable("structural radius unavailable")
    end
    if not validPositive(loadN) then
        return unavailable("wheel load unavailable")
    end

    if context.isCrawler == true then
        -- Do not fake a track by multiplying a tire area. A crawler needs a
        -- grouped track geometry/load model so bogie/roller pressure peaks can
        -- be represented separately from nominal average pressure.
        return unavailable("crawler support-group geometry not implemented", "CRAWLER")
    end

    options = mergeOptions(options)

    local result = pressureDriven(context, options, width, radius, loadN)
    if result == nil then
        result = geometryFallback(context, options, width, radius, loadN)
    end

    if result == nil then
        return unavailable("could not resolve footprint")
    end

    result.structuralRadiusM = radius
    result.wheelLoadN = loadN
    result.baseTireWidthM = tonumber(context.baseTireWidthM)
    result.sinkDepthM = tonumber(context.sinkDepthM)
    result.physicalGroundWetness = tonumber(context.physicalGroundWetness)

    -- This model intentionally does not fold wetness or sink into contact area.
    -- They are deformation-response inputs, not substitutes for tire support
    -- geometry. A later soil-contact layer may broaden the deformation brush.
    return result
end
