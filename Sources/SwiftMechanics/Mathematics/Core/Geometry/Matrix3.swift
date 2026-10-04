public struct Matrix3: Equatable, Sendable, Matrix3Operating {
    public let m00: Double
    public let m01: Double
    public let m02: Double
    public let m10: Double
    public let m11: Double
    public let m12: Double
    public let m20: Double
    public let m21: Double
    public let m22: Double

    public static let identity = Matrix3(validated: (1, 0, 0, 0, 1, 0, 0, 0, 1))
    public static let zero = Matrix3(validated: (0, 0, 0, 0, 0, 0, 0, 0, 0))
    public init(_ m00: Double, _ m01: Double, _ m02: Double, _ m10: Double, _ m11: Double, _ m12: Double, _ m20: Double, _ m21: Double, _ m22: Double) throws(CoreError) {
        guard m00.isFinite, m01.isFinite, m02.isFinite, m10.isFinite, m11.isFinite, m12.isFinite, m20.isFinite, m21.isFinite, m22.isFinite else { throw .nonFiniteInput }
        self.m00 = m00
        self.m01 = m01
        self.m02 = m02
        self.m10 = m10
        self.m11 = m11
        self.m12 = m12
        self.m20 = m20
        self.m21 = m21
        self.m22 = m22
    }

    // Constants and already finite fields/results enter this initializer.
    internal init(validated values: (Double, Double, Double, Double, Double, Double, Double, Double, Double)) {
        self.m00 = values.0
        self.m01 = values.1
        self.m02 = values.2
        self.m10 = values.3
        self.m11 = values.4
        self.m12 = values.5
        self.m20 = values.6
        self.m21 = values.7
        self.m22 = values.8
    }

    internal static func result(_ m00: Double, _ m01: Double, _ m02: Double, _ m10: Double, _ m11: Double, _ m12: Double, _ m20: Double, _ m21: Double, _ m22: Double) throws(CoreError) -> Matrix3 {
        guard m00.isFinite, m01.isFinite, m02.isFinite, m10.isFinite, m11.isFinite, m12.isFinite, m20.isFinite, m21.isFinite, m22.isFinite else { throw .nonFiniteResult }
        return Matrix3(validated: (m00, m01, m02, m10, m11, m12, m20, m21, m22))
    }

    public func element(row: Int, column: Int) throws(CoreError) -> Double {
        switch (row, column) {
        case (0, 0): return m00
        case (0, 1): return m01
        case (0, 2): return m02
        case (1, 0): return m10
        case (1, 1): return m11
        case (1, 2): return m12
        case (2, 0): return m20
        case (2, 1): return m21
        case (2, 2): return m22
        default: throw .invalidIndex
        }
    }

    public var maximumMagnitude: Double {
        max(abs(m00), max(abs(m01), max(abs(m02), max(abs(m10), max(abs(m11), max(abs(m12), max(abs(m20), max(abs(m21), abs(m22)))))))))    }

    public func transposed() -> Matrix3 {
        Matrix3(validated: (m00, m10, m20, m01, m11, m21, m02, m12, m22))
    }

    public func applying(to vector: Vector3) throws(CoreError) -> Vector3 {
        try .result(
            m00 * vector.x + m01 * vector.y + m02 * vector.z,
            m10 * vector.x + m11 * vector.y + m12 * vector.z,
            m20 * vector.x + m21 * vector.y + m22 * vector.z
        )
    }

    public func adding(_ other: Matrix3) throws(CoreError) -> Matrix3 {
        try Matrix3.result(m00 + other.m00, m01 + other.m01, m02 + other.m02, m10 + other.m10, m11 + other.m11, m12 + other.m12, m20 + other.m20, m21 + other.m21, m22 + other.m22)
    }

    public func subtracting(_ other: Matrix3) throws(CoreError) -> Matrix3 {
        try Matrix3.result(m00 - other.m00, m01 - other.m01, m02 - other.m02, m10 - other.m10, m11 - other.m11, m12 - other.m12, m20 - other.m20, m21 - other.m21, m22 - other.m22)
    }

    public func scaled(by scalar: Double) throws(CoreError) -> Matrix3 {
        guard scalar.isFinite else { throw .nonFiniteInput }
        return try Matrix3.result(m00 * scalar, m01 * scalar, m02 * scalar, m10 * scalar, m11 * scalar, m12 * scalar, m20 * scalar, m21 * scalar, m22 * scalar)
    }

    public func multiplied(by other: Matrix3) throws(CoreError) -> Matrix3 {
        try Matrix3.result(
            m00 * other.m00 + m01 * other.m10 + m02 * other.m20,
            m00 * other.m01 + m01 * other.m11 + m02 * other.m21,
            m00 * other.m02 + m01 * other.m12 + m02 * other.m22,
            m10 * other.m00 + m11 * other.m10 + m12 * other.m20,
            m10 * other.m01 + m11 * other.m11 + m12 * other.m21,
            m10 * other.m02 + m11 * other.m12 + m12 * other.m22,
            m20 * other.m00 + m21 * other.m10 + m22 * other.m20,
            m20 * other.m01 + m21 * other.m11 + m22 * other.m21,
            m20 * other.m02 + m21 * other.m12 + m22 * other.m22
        )
    }

    public func determinant() throws(CoreError) -> Double {
        let value = m00 * (m11 * m22 - m12 * m21)
            - m01 * (m10 * m22 - m12 * m20)
            + m02 * (m10 * m21 - m11 * m20)
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }

    public func inverted(relativeTolerance: Double) throws(CoreError) -> Matrix3 {
        guard relativeTolerance.isFinite, relativeTolerance >= 0 else { throw .invalidTolerance }
        let scale = maximumMagnitude
        guard scale > 0 else { throw .singularMatrix }
        let a = try Matrix3.result(m00 / scale, m01 / scale, m02 / scale,
                            m10 / scale, m11 / scale, m12 / scale,
                            m20 / scale, m21 / scale, m22 / scale)
        let det = try a.determinant()
        guard abs(det) > relativeTolerance else { throw .singularMatrix }
        let result = try Matrix3.result(
            (a.m11 * a.m22 - a.m12 * a.m21) / det / scale,
            (a.m02 * a.m21 - a.m01 * a.m22) / det / scale,
            (a.m01 * a.m12 - a.m02 * a.m11) / det / scale,
            (a.m12 * a.m20 - a.m10 * a.m22) / det / scale,
            (a.m00 * a.m22 - a.m02 * a.m20) / det / scale,
            (a.m02 * a.m10 - a.m00 * a.m12) / det / scale,
            (a.m10 * a.m21 - a.m11 * a.m20) / det / scale,
            (a.m01 * a.m20 - a.m00 * a.m21) / det / scale,
            (a.m00 * a.m11 - a.m01 * a.m10) / det / scale
        )
        return result
    }
}
