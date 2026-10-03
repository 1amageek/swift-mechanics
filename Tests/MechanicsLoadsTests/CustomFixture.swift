import MechanicsLoads
struct CustomFixture: CustomLoadProvider {
    let identity = 1
    let coordinateKind = ScalarCoordinateKind.translation
    let failure: Bool
    let badDerivative: Bool
    let noEnergy: Bool
    let badEnergy: Bool
    init(failure: Bool = false, badDerivative: Bool = false, noEnergy: Bool = false, badEnergy: Bool = false) {
        self.failure = failure; self.badDerivative = badDerivative; self.noEnergy = noEnergy; self.badEnergy = badEnergy
    }
    func response(coordinate q: Double, rate v: Double, state: CustomLoadState, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.charge(2)
        if failure { throw .providerFailure(7) }
        return try ScalarLoadResponse(conservative: -q*q*q, dissipative: -2*v, active: state.values[0],
            coordinateDerivative: badDerivative ? 100 : -3*q*q, rateDerivative: -2,
            potentialEnergy: noEnergy ? nil : (badEnergy ? 0 : q*q*q*q/4), dissipatedPower: 2*v*v)
    }
}
