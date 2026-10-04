
/// Symmetric material-frame tensor; xy, yz and xz are tensor shear components.
public struct SymmetricTensor: Equatable, Sendable {
    public let xx: Double
    public let yy: Double
    public let zz: Double
    public let xy: Double
    public let yz: Double
    public let xz: Double

    public static let zero = SymmetricTensor(validated: (0, 0, 0, 0, 0, 0))

    public init(xx: Double, yy: Double, zz: Double, xy: Double = 0, yz: Double = 0, xz: Double = 0) throws(MaterialError) {
        guard xx.isFinite, yy.isFinite, zz.isFinite, xy.isFinite, yz.isFinite, xz.isFinite else {
            throw .invalidParameter(name: "symmetricTensor.nonFinite")
        }
        self.init(validated: (xx, yy, zz, xy, yz, xz))
    }

    private init(validated value: (Double, Double, Double, Double, Double, Double)) {
        xx = value.0; yy = value.1; zz = value.2
        xy = value.3; yz = value.4; xz = value.5
    }

    private static func result(_ xx: Double, _ yy: Double, _ zz: Double, _ xy: Double, _ yz: Double, _ xz: Double) throws(MaterialError) -> Self {
        guard xx.isFinite, yy.isFinite, zz.isFinite, xy.isFinite, yz.isFinite, xz.isFinite else {
            throw .nonFiniteResult(operation: "tensorArithmetic")
        }
        return Self(validated: (xx, yy, zz, xy, yz, xz))
    }

    public func trace() throws(MaterialError) -> Double {
        try materialFinite(xx + yy + zz, operation: "tensorTrace")
    }

    public func contracted(with other: Self) throws(MaterialError) -> Double {
        try materialFinite(xx * other.xx + yy * other.yy + zz * other.zz + 2 * (xy * other.xy + yz * other.yz + xz * other.xz), operation: "tensorContraction")
    }

    public func norm() throws(MaterialError) -> Double {
        // Scaling avoids underflow/overflow of squared finite components.
        let scale = max(abs(xx), abs(yy), abs(zz), abs(xy), abs(yz), abs(xz))
        if scale == 0 { return 0 }
        let scaled = Self(validated: (xx / scale, yy / scale, zz / scale, xy / scale, yz / scale, xz / scale))
        return try materialFinite(scale * (try scaled.contracted(with: scaled)).squareRoot(), operation: "tensorNorm")
    }

    public func adding(_ other: Self) throws(MaterialError) -> Self {
        try .result(xx + other.xx, yy + other.yy, zz + other.zz, xy + other.xy, yz + other.yz, xz + other.xz)
    }

    public func subtracting(_ other: Self) throws(MaterialError) -> Self {
        try .result(xx - other.xx, yy - other.yy, zz - other.zz, xy - other.xy, yz - other.yz, xz - other.xz)
    }

    public func scaled(by value: Double) throws(MaterialError) -> Self {
        guard value.isFinite else { throw .invalidParameter(name: "tensorScale") }
        return try .result(xx * value, yy * value, zz * value, xy * value, yz * value, xz * value)
    }

    public func deviator() throws(MaterialError) -> Self {
        let mean = try trace() / 3
        return try .result(xx - mean, yy - mean, zz - mean, xy, yz, xz)
    }

    public static func isotropic(_ value: Double) throws(MaterialError) -> Self {
        try .result(value, value, value, 0, 0, 0)
    }

    public func matrix() throws(MaterialError) -> Matrix3 {
        try materialCore { () throws(CoreError) in try Matrix3(xx, xy, xz, xy, yy, yz, xz, yz, zz) }
    }

    internal static func symmetricPart(_ matrix: Matrix3) throws(MaterialError) -> Self {
        try .result(matrix.m00, matrix.m11, matrix.m22,
                    matrix.m01 / 2 + matrix.m10 / 2,
                    matrix.m12 / 2 + matrix.m21 / 2,
                    matrix.m02 / 2 + matrix.m20 / 2)
    }
}
