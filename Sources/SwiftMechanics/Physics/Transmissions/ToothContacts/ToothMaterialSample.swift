internal final class ToothMaterialSample: Sendable {
    let rigid: ToothRigidResult
    let observations: [MaterialToothContactSample]
    let histories: [ContactHistory]
    let normal: Double
    let tangent: Double
    let cohesion: Double
    let normalPower: Double
    let resistancePower: Double
    let tangentLoss: Double
    var stored: Double { normal+tangent+cohesion }
    init(rigid: ToothRigidResult, observations: [MaterialToothContactSample], histories: [ContactHistory],
         normal: Double, tangent: Double, cohesion: Double, normalPower: Double, resistancePower: Double, tangentLoss: Double) {
        self.rigid=rigid; self.observations=observations; self.histories=histories
        self.normal=normal; self.tangent=tangent; self.cohesion=cohesion
        self.normalPower=normalPower; self.resistancePower=resistancePower; self.tangentLoss=tangentLoss
    }
}
