RealismExtensionsCore = {}

function RealismExtensionsCore:loadMap()
    RealismExtensionsDiagnostics.info(
        "v" .. tostring(RealismExtensionsConfig.version)
        .. " foundation loaded; gameplay modules inactive"
    )
end

function RealismExtensionsCore:deleteMap()
    RealismExtensionsState.clearProvider()
end

addModEventListener(RealismExtensionsCore)
