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
        SoilMassTransport = false,
        NativeTireTrackProbe = true
    }
}
