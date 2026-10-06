/// A fixed reference basis; construction explicitly orthogonalizes two tangents.
public struct ShellBasis: Equatable, Sendable {
    public let origin: Vector3
    public let firstTangent: Vector3
    public let secondTangent: Vector3
    public let normal: Vector3

    public init(origin: Vector3, firstDirection: Vector3, secondDirection: Vector3) throws(ShellError) {
        let first = try ShellArithmetic.core { () throws(CoreError) in try firstDirection.normalized() }
        let second = try ShellArithmetic.core { () throws(CoreError) in try secondDirection.normalized() }
        let cross = try ShellArithmetic.core { () throws(CoreError) in try first.cross(second) }
        // Nearly parallel inputs do not define a reliable plane orientation.
        let magnitude = try ShellArithmetic.core { () throws(CoreError) in try cross.magnitude() }
        guard magnitude > 64 * Double.ulpOfOne else { throw .degenerateGeometry }
        let normal = try ShellArithmetic.core { () throws(CoreError) in try cross.normalized() }
        self.origin = origin
        firstTangent = first
        secondTangent = try ShellArithmetic.core { () throws(CoreError) in try normal.cross(first).normalized() }
        self.normal = normal
    }

    public func referencePosition(x: Double, y: Double) throws(ShellError) -> Vector3 {
        guard x.isFinite, y.isFinite else { throw .invalidParameter(name: "referenceCoordinates") }
        do { return try origin.adding(firstTangent.scaled(by: x)).adding(secondTangent.scaled(by: y)) }
        catch { throw .core(error) }
    }
}
