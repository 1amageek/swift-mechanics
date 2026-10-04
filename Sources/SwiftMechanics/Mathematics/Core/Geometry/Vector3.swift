public struct Vector3: Equatable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let z: Double

    public static let zero = Vector3(validatedX: 0, y: 0, z: 0)
    public static let unitX = Vector3(validatedX: 1, y: 0, z: 0)
    public static let unitY = Vector3(validatedX: 0, y: 1, z: 0)
    public static let unitZ = Vector3(validatedX: 0, y: 0, z: 1)

    public init(_ x: Double, _ y: Double, _ z: Double) throws(CoreError) {
        guard x.isFinite, y.isFinite, z.isFinite else { throw .nonFiniteInput }
        self.init(validatedX: x, y: y, z: z)
    }

    // Only finite, already validated values and exact constants enter this initializer.
    internal init(validatedX x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    internal static func result(_ x: Double, _ y: Double, _ z: Double) throws(CoreError) -> Vector3 {
        guard x.isFinite, y.isFinite, z.isFinite else { throw .nonFiniteResult }
        return Vector3(validatedX: x, y: y, z: z)
    }

    public func adding(_ other: Vector3) throws(CoreError) -> Vector3 {
        try .result(x + other.x, y + other.y, z + other.z)
    }

    public func subtracting(_ other: Vector3) throws(CoreError) -> Vector3 {
        try .result(x - other.x, y - other.y, z - other.z)
    }

    public func scaled(by scalar: Double) throws(CoreError) -> Vector3 {
        guard scalar.isFinite else { throw .nonFiniteInput }
        return try .result(x * scalar, y * scalar, z * scalar)
    }

    public func dot(_ other: Vector3) throws(CoreError) -> Double {
        let result = x * other.x + y * other.y + z * other.z
        guard result.isFinite else { throw .nonFiniteResult }
        return result
    }

    public func cross(_ other: Vector3) throws(CoreError) -> Vector3 {
        try .result(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }

    public func magnitude() throws(CoreError) -> Double {
        let value = ScalarMath.norm(ScalarMath.norm(x, y), z)
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }

    public func normalized() throws(CoreError) -> Vector3 {
        let scale = max(abs(x), max(abs(y), abs(z)))
        guard scale > 0 else { throw .degenerateVector }
        let sx = x / scale, sy = y / scale, sz = z / scale
        let norm = ScalarMath.norm(ScalarMath.norm(sx, sy), sz)
        return try .result(sx / norm, sy / norm, sz / norm)
    }
}
