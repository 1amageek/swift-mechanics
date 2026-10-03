public protocol Matrix3Operating: Sendable {
    func applying(to vector: Vector3) throws(CoreError) -> Vector3
    func determinant() throws(CoreError) -> Double
    func inverted(relativeTolerance: Double) throws(CoreError) -> Matrix3
}
