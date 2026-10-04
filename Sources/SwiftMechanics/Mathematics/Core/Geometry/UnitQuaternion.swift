public struct UnitQuaternion: Equatable, Sendable, RotationIntegrating {
    public let w: Double
    public let x: Double
    public let y: Double
    public let z: Double

    public static let identity = UnitQuaternion(validatedW: 1, x: 0, y: 0, z: 0)

    public init(w: Double, x: Double, y: Double, z: Double) throws(CoreError) {
        guard w.isFinite, x.isFinite, y.isFinite, z.isFinite else { throw .nonFiniteInput }
        let scale = max(abs(w), max(abs(x), max(abs(y), abs(z))))
        guard scale > 0 else { throw .degenerateQuaternion }
        let sw = w / scale, sx = x / scale, sy = y / scale, sz = z / scale
        let norm = ScalarMath.norm(ScalarMath.norm(sw, sx), ScalarMath.norm(sy, sz))
        self.init(validatedW: sw / norm, x: sx / norm, y: sy / norm, z: sz / norm)
    }

    /// Restores already-unit components without changing their floating-point bits.
    public init(unitW w: Double, x: Double, y: Double, z: Double) throws(CoreError) {
        guard w.isFinite, x.isFinite, y.isFinite, z.isFinite else { throw .nonFiniteInput }
        let squaredNorm = w * w + x * x + y * y + z * z
        guard squaredNorm.isFinite, abs(squaredNorm - 1) <= 16 * Double.ulpOfOne else {
            throw .nonUnitQuaternion
        }
        self.init(validatedW: w, x: x, y: y, z: z)
    }

    // Constants, normalized components, conjugation and sign reversal preserve unit length.
    internal init(validatedW w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    public init(axis: Vector3, angle: Double) throws(CoreError) {
        guard angle.isFinite else { throw .nonFiniteInput }
        let unit = try axis.normalized()
        let half = angle / 2
        let sine = ScalarMath.sine(half)
        try self.init(w: ScalarMath.cosine(half), x: unit.x * sine, y: unit.y * sine, z: unit.z * sine)
    }

    public init(rotationVector vector: Vector3) throws(CoreError) {
        let angle = try vector.magnitude()
        if angle == 0 { self = .identity }
        else { try self.init(axis: vector, angle: angle) }
    }

    public init(matrix: Matrix3, tolerance: NumericalTolerance) throws(CoreError) {
        let gram = try matrix.transposed().multiplied(by: matrix).subtracting(.identity)
        let determinant = try matrix.determinant()
        guard determinant > 0,
              try tolerance.contains(error: gram.maximumMagnitude, scale: 1),
              try tolerance.contains(error: determinant - 1, scale: 1) else { throw .nonRigidMatrix }
        let trace = matrix.m00 + matrix.m11 + matrix.m22
        if trace > 0 {
            let s = 2 * (trace + 1).squareRoot()
            try self.init(w: s / 4, x: (matrix.m21 - matrix.m12) / s,
                          y: (matrix.m02 - matrix.m20) / s, z: (matrix.m10 - matrix.m01) / s)
        } else if matrix.m00 > matrix.m11 && matrix.m00 > matrix.m22 {
            let s = 2 * (1 + matrix.m00 - matrix.m11 - matrix.m22).squareRoot()
            try self.init(w: (matrix.m21 - matrix.m12) / s, x: s / 4,
                          y: (matrix.m01 + matrix.m10) / s, z: (matrix.m02 + matrix.m20) / s)
        } else if matrix.m11 > matrix.m22 {
            let s = 2 * (1 + matrix.m11 - matrix.m00 - matrix.m22).squareRoot()
            try self.init(w: (matrix.m02 - matrix.m20) / s, x: (matrix.m01 + matrix.m10) / s,
                          y: s / 4, z: (matrix.m12 + matrix.m21) / s)
        } else {
            let s = 2 * (1 + matrix.m22 - matrix.m00 - matrix.m11).squareRoot()
            try self.init(w: (matrix.m10 - matrix.m01) / s, x: (matrix.m02 + matrix.m20) / s,
                          y: (matrix.m12 + matrix.m21) / s, z: s / 4)
        }
    }

    public func conjugated() -> UnitQuaternion {
        UnitQuaternion(validatedW: w, x: -x, y: -y, z: -z)
    }

    public func negated() -> UnitQuaternion {
        UnitQuaternion(validatedW: -w, x: -x, y: -y, z: -z)
    }

    public func multiplied(by other: UnitQuaternion) throws(CoreError) -> UnitQuaternion {
        try UnitQuaternion(
            w: w * other.w - x * other.x - y * other.y - z * other.z,
            x: w * other.x + x * other.w + y * other.z - z * other.y,
            y: w * other.y - x * other.z + y * other.w + z * other.x,
            z: w * other.z + x * other.y - y * other.x + z * other.w
        )
    }

    public func matrix() throws(CoreError) -> Matrix3 {
        try Matrix3(
            1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
            2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
            2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)
        )
    }

    public func rotating(_ vector: Vector3) throws(CoreError) -> Vector3 {
        try matrix().applying(to: vector)
    }

    public func rotationVector() throws(CoreError) -> Vector3 {
        let reverse = w < 0 || (w == 0 && (x < 0 || (x == 0 && (y < 0 || (y == 0 && z < 0)))))
        let q = reverse ? negated() : self
        let sine = ScalarMath.norm(ScalarMath.norm(q.x, q.y), q.z)
        if sine == 0 { return .zero }
        let angle = 2 * ScalarMath.angle(y: sine, x: q.w)
        return try .result((q.x / sine) * angle, (q.y / sine) * angle, (q.z / sine) * angle)
    }

    public func integratingBodyAngularVelocity(_ velocity: Vector3, timeStep: Double) throws(CoreError) -> UnitQuaternion {
        guard timeStep.isFinite, timeStep >= 0 else { throw .invalidTimeStep }
        return try multiplied(by: UnitQuaternion(rotationVector: velocity.scaled(by: timeStep)))
    }

    public func integratingWorldAngularVelocity(_ velocity: Vector3, timeStep: Double) throws(CoreError) -> UnitQuaternion {
        guard timeStep.isFinite, timeStep >= 0 else { throw .invalidTimeStep }
        return try UnitQuaternion(rotationVector: velocity.scaled(by: timeStep)).multiplied(by: self)
    }

    public func bodyRate(for velocity: Vector3) throws(CoreError) -> QuaternionRate {
        try QuaternionRate(
            w: -0.5 * (x * velocity.x + y * velocity.y + z * velocity.z),
            x: 0.5 * (w * velocity.x + y * velocity.z - z * velocity.y),
            y: 0.5 * (w * velocity.y + z * velocity.x - x * velocity.z),
            z: 0.5 * (w * velocity.z + x * velocity.y - y * velocity.x)
        )
    }
}
