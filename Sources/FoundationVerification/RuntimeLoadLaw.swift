import MechanicsLoads

struct RuntimeLoadLaw: CustomLoadProvider {
    let identity = 1
    let coordinateKind = ScalarCoordinateKind.translation

    func response(coordinate: Double, rate: Double, state: CustomLoadState,
                  work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.charge(1)
        return try ScalarLoadResponse(conservative: -2 * coordinate, dissipative: -3 * rate,
            coordinateDerivative: -2, rateDerivative: -3, potentialEnergy: coordinate * coordinate,
            dissipatedPower: 3 * rate * rate)
    }
}
