RealismExtensionsConfig = {
    version = "0.0.1.0",
    -- Explicitly NOT the production main release profile.
    releaseChannel = "experimental-terrain-pto",
    diagnostics = {
        -- development: causal runtime telemetry enabled for active research.
        -- stabilization: retain cheap health/perf telemetry, reduce research noise.
        -- minimal: errors/startup identity only.
        profile = "stabilization",
        -- Full historical research trace remains opt-in via verbose=true.
        verbose = false,
        ptoWorkerEvents = true,
        windowMs = 60000,
        causalWindows = true,
        writerAttribution = true,
        -- Bounded per-operation causal samples (12 TARGET, 18 rut max).
        targetOutcomeSamples = false,
        rutCausalSamples = false,
        expensiveGeometry = false,
        performanceTiming = false
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
        showEstimatedRpm = true,
        showUnlinkedPowerHint = true,
        rpmTextSizePx = 8,
        rpmTextGapPx = 3,
        rpmSmoothingMs = 350,

        -- Advisory presentation only: no PTO physics or vehicle control is
        -- changed when this threshold is exceeded.
        transportWarningKph = 25,
        warningBlinkIntervalMs = 600
    },
    modules = {
        PTOControl = true,
        TerrainDeformation = true,
        -- Experimental causal geometry ownership: native callbacks before mechanical debt commit.
        -- NOT production-ready until journal save/restore and recovery are validated.
        TerrainGeometryJournal = true,
        -- The experimental branch actively exercises causal restoration.
        -- Production main remains protected; only use this on a copied save.
        TerrainCausalRecovery = true,
        TerrainRecovery = true,
        -- Experimental correction: refuse unsupported terrain reference planes.
        -- Turn OFF to reproduce the pre-fix annular estimator in A/B tests.
        TerrainRecoveryReferenceV2 = true,
        -- EXPERIMENTAL v1. Pure bearing-pressure gate for RE persistent ruts;
        -- toggle false to compare original R6 behavior on the same backup save.
        TerrainPlasticYield = true,
        -- Isolate the legacy R1 maintenance writer during causal v1 trial.
        TerrainMaintenance = false,
        -- Verified RE-owned native journal repair on NPC fields (1 period)
        -- and municipal dirt/gravel (2 periods), never legacy annular TARGET.
        TerrainCausalMaintenance = true,
        SoilMassTransport = false,
        NativeTireTrackProbe = true,
        AIVisualTireTracks = true,
        VisualTrackCapture = true
    }
}
