import MechanicsCore
internal struct DifferentialVector: Sendable {
    let value: Vector3
    let direction: Vector3
    init(_ value: Vector3, _ direction: Vector3 = .zero) { self.value=value; self.direction=direction }
    static let zero = DifferentialVector(.zero)
}
