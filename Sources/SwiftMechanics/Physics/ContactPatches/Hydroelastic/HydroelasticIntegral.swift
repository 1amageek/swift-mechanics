internal struct HydroelasticIntegral: Sendable {
    var area=0.0, pressure=0.0
    var force=Vector3.zero, moment=Vector3.zero
    var surfacePowerFirst=0.0, surfacePowerSecond=0.0
    var geometryResidual=0.0, pressureDifference=0.0
}
