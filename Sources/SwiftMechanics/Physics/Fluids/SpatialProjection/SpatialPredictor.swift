internal struct SpatialPredictor: Sendable {
    let velocity:[[Double]]
    let rate:[[Double]]
    let kinetic:Double
    let viscousPower:Double
    let donorPower:Double
    let divergencePower:Double
    let sourcePower:Double
    let injection:Double
    let advectiveFactor:Double
    let viscousFactor:Double
    let courantFactor:Double
}
