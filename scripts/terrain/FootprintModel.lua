RealismExtensionsFootprintModel = RealismExtensionsFootprintModel or {}
local Model = RealismExtensionsFootprintModel

Model.VERSION = 2

Model.DEFAULTS = {
    -- UMN agricultural-compaction guidance reports radial tire ground pressure
    -- roughly 1-2 psi above correct inflation pressure. 10 kPa ~= 1.45 psi.
    radialCasingAllowancePa = 10000,

    -- MR uses width * radius * 0.53 as its geometry pressure approximation.
    -- Keep the same degraded fallback and extend it to crawler length through
    -- MR's explicit mrTrackFx contract.
    legacyGeometryAreaFactor = 0.53,

    -- Crawler footprints are discretized only for terrain geometry. Exposure
    -- is shared across these longitudinal patches so discretization never
    -- multiplies the physical pass.
    crawlerPatchSpacingWidthFactor = 0.75,
    crawlerPatchSpacingMinM = 0.25,
    crawlerMaxLongitudinalPatches = 5,

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

local function mergeOptions(options)
    local result = {}
    for key, value in pairs(Model.DEFAULTS) do result[key] = value end
    for key, value in pairs(options or {}) do result[key] = value end
    return result
end

local function unavailable(reason, kind)
    return {
        available = false,
        reason = reason,
        kind = kind
    }
end

local function copySegments(context, totalWidth, fallbackRadius)
    local source = type(context.supportSegments) == "table"
        and context.supportSegments or nil
    local out = {}

    for _, segment in ipairs(source or {}) do
        local width = tonumber(segment.widthM)
        if validPositive(width) then
            out[#out + 1] = {
                offsetM = tonumber(segment.offsetM) or 0,
                widthM = width,
                radiusM = validPositive(tonumber(segment.radiusM))
                    and tonumber(segment.radiusM) or fallbackRadius
            }
        end
    end

    if #out == 0 then
        out[1] = {
            offsetM = 0,
            widthM = totalWidth,
            radiusM = fallbackRadius
        }
    end

    table.sort(out, function(a, b)
        if a.offsetM == b.offsetM then return a.widthM < b.widthM end
        return a.offsetM < b.offsetM
    end)
    return out
end

local function buildRoundPatches(segments, lengthM, totalAreaM2, loadN, pressurePa)
    local totalWidth = 0
    for _, segment in ipairs(segments) do totalWidth = totalWidth + segment.widthM end
    if not validPositive(totalWidth) then return nil end

    local patches = {}
    for _, segment in ipairs(segments) do
        local share = segment.widthM / totalWidth
        patches[#patches + 1] = {
            available = true,
            kind = "ROUND_WHEEL_PATCH",
            offsetM = segment.offsetM,
            supportWidthM = segment.widthM,
            footprintLengthM = lengthM,
            contactAreaM2 = totalAreaM2 * share,
            wheelLoadN = loadN * share,
            groundPressurePa = pressurePa,
            structuralRadiusM = segment.radiusM
        }
    end
    return patches
end

local function pressureDriven(context, options, width, radius, loadN, segments)
    local inflationBar = tonumber(context.tirePressureBar)
    if not validPositive(inflationBar) then return nil end

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
    local geometryLimited = targetLengthM > maxLengthM
    local lengthM = math.min(targetLengthM, maxLengthM)
    local areaM2 = width * lengthM
    if not validPositive(areaM2) then return nil end

    local pressurePa = loadN / areaM2
    return {
        available = true,
        kind = "ROUND_WHEEL",
        model = "PRESSURE_DRIVEN",
        confidence = context.wheelLoadMeasured == true and "HIGH" or "MEDIUM",

        supportWidthM = width,
        supportContactWidthM = width,
        supportSpanM = tonumber(context.supportSpanM) or width,
        supportGapWidthM = math.max(
            0,
            tonumber(context.supportGapWidthM) or 0
        ),
        supportSegmentCount = #segments,
        contactPatches = buildRoundPatches(
            segments,
            lengthM,
            areaM2,
            loadN,
            pressurePa
        ),
        footprintLengthM = lengthM,
        contactAreaM2 = areaM2,

        inflationPressureBar = inflationBar,
        targetGroundPressurePa = targetPressurePa,
        groundPressurePa = pressurePa,

        geometryLimited = geometryLimited,
        loadMeasured = context.wheelLoadMeasured == true
    }
end

local function geometryFallback(context, options, width, radius, loadN, segments)
    local factor = tonumber(options.legacyGeometryAreaFactor)
        or Model.DEFAULTS.legacyGeometryAreaFactor
    local lengthM = radius * math.max(0.01, factor)
    local areaM2 = width * lengthM
    if not validPositive(areaM2) then return nil end

    local pressurePa = loadN / areaM2
    return {
        available = true,
        kind = "ROUND_WHEEL",
        model = "GEOMETRY_FALLBACK",
        confidence = "LOW",

        supportWidthM = width,
        supportContactWidthM = width,
        supportSpanM = tonumber(context.supportSpanM) or width,
        supportGapWidthM = math.max(
            0,
            tonumber(context.supportGapWidthM) or 0
        ),
        supportSegmentCount = #segments,
        contactPatches = buildRoundPatches(
            segments,
            lengthM,
            areaM2,
            loadN,
            pressurePa
        ),
        footprintLengthM = lengthM,
        contactAreaM2 = areaM2,

        inflationPressureBar = nil,
        targetGroundPressurePa = nil,
        groundPressurePa = pressurePa,

        geometryLimited = false,
        loadMeasured = context.wheelLoadMeasured == true
    }
end

local function crawlerFootprint(context, options, width, radius, loadN)
    local factor = tonumber(options.legacyGeometryAreaFactor)
        or Model.DEFAULTS.legacyGeometryAreaFactor
    local trackFactor = tonumber(context.trackFootprintFactor)
    if not validPositive(trackFactor) then trackFactor = 3 end

    -- MoreRealistic's pressure/rolling-resistance path treats crawler support
    -- as width * (radius * mrTrackFx) * 0.53. Reusing that exact geometric
    -- contract gives RE an average support footprint without pretending to
    -- resolve bogie/idler pressure peaks that the source stack does not expose.
    local lengthM = radius * trackFactor * math.max(0.01, factor)
    local areaM2 = width * lengthM
    if not validPositive(areaM2) then
        return unavailable("crawler support area unavailable", "CRAWLER")
    end

    local pressurePa = loadN / areaM2

    local spacingTarget = math.max(
        tonumber(options.crawlerPatchSpacingMinM) or 0.25,
        width * math.max(
            0.25,
            tonumber(options.crawlerPatchSpacingWidthFactor) or 0.75
        )
    )
    local patchCount = math.max(
        1,
        math.min(
            math.max(
                1,
                math.floor(
                    tonumber(options.crawlerMaxLongitudinalPatches) or 5
                )
            ),
            math.ceil(lengthM / spacingTarget)
        )
    )
    local patchArea = areaM2 / patchCount
    local patchLoad = loadN / patchCount
    local patchStep = lengthM / patchCount
    local contactPatches = {}
    for i = 1, patchCount do
        contactPatches[#contactPatches + 1] = {
            available = true,
            kind = "CRAWLER_PATCH",
            offsetM = 0,
            longitudinalOffsetM =
                (i - (patchCount + 1) * 0.5) * patchStep,
            supportWidthM = width,
            -- Keep the complete belt contact length as the pass/exposure
            -- characteristic. physicalPatchLengthM describes only this
            -- terrain-writing discretization slice.
            footprintLengthM = lengthM,
            physicalPatchLengthM = patchStep,
            contactAreaM2 = patchArea,
            wheelLoadN = patchLoad,
            groundPressurePa = pressurePa,
            structuralRadiusM = radius,
            exposureShare = 1 / patchCount,
            continuousTrack = true
        }
    end

    return {
        available = true,
        kind = "CRAWLER",
        model = "MR_TRACK_GEOMETRY",
        confidence = context.wheelLoadMeasured == true and "HIGH" or "MEDIUM",

        supportWidthM = width,
        supportContactWidthM = width,
        supportSpanM = tonumber(context.supportSpanM) or width,
        supportGapWidthM = 0,
        supportSegmentCount = 1,
        contactPatches = contactPatches,
        longitudinalPatchCount = patchCount,
        footprintLengthM = lengthM,
        contactAreaM2 = areaM2,

        inflationPressureBar = nil,
        targetGroundPressurePa = nil,
        groundPressurePa = pressurePa,
        trackFootprintFactor = trackFactor,

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

    local width = tonumber(
        context.supportContactWidthM
            or context.supportWidthM
            or context.tireWidthM
    )
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

    options = mergeOptions(options)
    local result

    if context.isCrawler == true or context.supportKind == "CRAWLER" then
        result = crawlerFootprint(context, options, width, radius, loadN)
    else
        local segments = copySegments(context, width, radius)
        result = pressureDriven(
            context,
            options,
            width,
            radius,
            loadN,
            segments
        )
        if result == nil then
            result = geometryFallback(
                context,
                options,
                width,
                radius,
                loadN,
                segments
            )
        end
    end

    if result == nil then
        return unavailable("could not resolve footprint")
    end

    result.structuralRadiusM = radius
    result.wheelLoadN = loadN
    result.baseTireWidthM = tonumber(context.baseTireWidthM)
    result.sinkDepthM = tonumber(context.sinkDepthM)
    result.physicalGroundWetness = tonumber(context.physicalGroundWetness)

    -- Wetness/sink stay response inputs. Support topology only describes where
    -- the load is carried; it does not duplicate MR/Mud mobility physics.
    return result
end
