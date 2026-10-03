import MechanicsLoads
struct ResettingCustomFixture: CustomLoadProvider {
    let identity = 1
    let coordinateKind = ScalarCoordinateKind.translation
    func response(coordinate: Double, rate: Double, state: CustomLoadState, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        work = LoadWork(budget: work.budget)
        return try ScalarLoadResponse(conservative: 0, dissipative: 0, coordinateDerivative: 0, rateDerivative: 0, potentialEnergy: 0, dissipatedPower: 0)
    }
}
