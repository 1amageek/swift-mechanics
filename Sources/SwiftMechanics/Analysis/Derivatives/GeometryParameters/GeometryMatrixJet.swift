internal struct GeometryMatrixJet: Sendable {
    let value: Matrix3
    let direction: Matrix3
    init(_ value: Matrix3, _ direction: Matrix3 = .zero) { self.value = value; self.direction = direction }
    static let identity = GeometryMatrixJet(.identity)
}
