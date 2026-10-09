RealismExtensionsConfig = {
    version = "0.0.1.0",
    -- Explicitly NOT the production main release profile.
    releaseChannel = "experimental-terrain-pto",
    diagnostics = {
        -- development: causal runtime telemetry enabled for active research.
        -- stabilization: retain cheap health/perf telemetry, reduce research noise.
        -- minimal: errors/startup identity only.
        profile = "development",
        verbose = true,
        windowMs = 5000,
        causalWindows = true,
        writerAttribution = true,
        expensiveGeometry = false,
        performanceTiming = true
    },
    ptoHud = {
        enabled = true,
        -- Pixel-space layout relative to the vanilla speed-gauge centre.
        -- RMS uses the same anchor for its dashboard additions, so this stays
        -- independent from RMS internals while fitting the same cluster.
        offsetXPx = -53,
        offsetYPx = -11,
        iconWidthPx = 30,
        iconHeightPx = 18.75,
        modeTextSizePx = 9,
        modeTextGapPx = 5,

        -- Advisory presentation only: no PTO physics or vehicle control is
        -- changed when this threshold is exceeded.
        transportWarningKph = 25,
        warningBlinkIntervalMs = 600
    },
    modules = {
        PTOControl = true,
        TerrainDeformation = true,
        TerrainRecovery = true,
        -- EXPERIMENTAL v1. Pure bearing-pressure gate for RE persistent ruts;
        -- toggle false to compare original R6 behavior on the same backup save.
        TerrainPlasticYield = true,
        TerrainMaintenance = true,
        SoilMassTransport = false,
        NativeTireTrackProbe = true,
        AIVisualTireTracks = true,
        VisualTrackCapture = true
    }
}
