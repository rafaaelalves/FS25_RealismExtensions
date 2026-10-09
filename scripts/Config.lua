RealismExtensionsConfig = {
    version = "0.0.1.0",
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
    modules = {
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
