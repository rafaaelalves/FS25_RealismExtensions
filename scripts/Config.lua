RealismExtensionsConfig = {
    version = "0.0.1.0",
    diagnostics = {
        verbose = false,
        -- One message per meaningful PTO worker decision/transition.
        ptoWorkerEvents = true,
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
        rpmTextSizePx = 8,
        rpmTextGapPx = 3,
        rpmSmoothingMs = 350,

        -- Advisory presentation only: no PTO physics or vehicle control is
        -- changed when this threshold is exceeded.
        transportWarningKph = 25,
        warningBlinkIntervalMs = 600
    },
    modules = {
        TerrainDeformation = false,
        PTOControl = true
    }
}
