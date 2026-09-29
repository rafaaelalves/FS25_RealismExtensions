# Providers

Provider/adaptor code belongs here only when it is genuinely a RealismExtensions concern.

The preferred architecture is for FS25_RealismCompatibility to expose normalized specialist state and for Extensions modules to consume `RealismExtensionsState`.

Do not create one-off MR/Mud/RMS/Reifen access paths inside gameplay modules.
