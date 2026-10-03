internal struct PlanarPredictor: Sendable {
    let u:[Double]
    let v:[Double]
    let rateU:[Double]
    let rateV:[Double]
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
