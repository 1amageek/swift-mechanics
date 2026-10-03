import MechanicsCore
internal struct DifferentialMatrix: Sendable {
    let value: Matrix3
    let direction: Matrix3
    init(_ value: Matrix3, _ direction: Matrix3 = .zero) { self.value=value; self.direction=direction }
    static let identity = DifferentialMatrix(.identity)
}
