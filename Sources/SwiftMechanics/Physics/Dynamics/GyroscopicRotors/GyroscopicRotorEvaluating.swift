public protocol GyroscopicRotorEvaluating: Sendable {
    func evaluate(rotor: GyroscopicRotor, axis: Vector3, carrierSpeed: Vector3, carrierAcceleration: Vector3,
                  spinSpeed: Double, spinAcceleration: Double, work: inout LoadWork) throws(LoadError) -> GyroscopicRotorResponse
}
