RealismExtensionsDiagnostics = {
    PREFIX = "[RealismExtensions]"
}

function RealismExtensionsDiagnostics.info(message)
    Logging.info("%s %s", RealismExtensionsDiagnostics.PREFIX, tostring(message))
end

function RealismExtensionsDiagnostics.warn(message)
    Logging.warning("%s %s", RealismExtensionsDiagnostics.PREFIX, tostring(message))
end

function RealismExtensionsDiagnostics.verbose(message)
    if RealismExtensionsConfig ~= nil
        and RealismExtensionsConfig.diagnostics ~= nil
        and RealismExtensionsConfig.diagnostics.verbose == true then
        RealismExtensionsDiagnostics.info(message)
    end
end
