/// Original normalized three-dimensional C2 kernel with support radius 2h.
public struct WendlandC2Kernel: Sendable {
    public init() {}
    public func value(displacement: Vector3, smoothingLength h: Double) throws(ParticleFlowError) -> Double {
        guard h.isFinite, h > 0 else { throw .invalidInput }
        let r = try ParticleFlowMath.norm(displacement)
        let q = try ParticleFlowMath.finite(r / h)
        guard q < 2 else { return 0 }
        let a = try ParticleFlowMath.finite(21 / (16 * Double.pi * h * h * h))
        guard a > 0 else { throw .nonFiniteArithmetic }
        let s = 1 - q / 2
        return try ParticleFlowMath.finite(a * s * s * s * s * (2 * q + 1))
    }
    public func gradient(displacement: Vector3, smoothingLength h: Double) throws(ParticleFlowError) -> Vector3 {
        guard h.isFinite, h > 0 else { throw .invalidInput }
        let r = try ParticleFlowMath.norm(displacement), q = try ParticleFlowMath.finite(r / h)
        guard q < 2 else { return .zero }
        let a = try ParticleFlowMath.finite(21 / (16 * Double.pi * h * h * h))
        guard a > 0 else { throw .nonFiniteArithmetic }
        let s = 1 - q / 2, coefficient = try ParticleFlowMath.finite(-5 * a / (h * h) * s * s * s)
        return try ParticleFlowMath.scale(displacement, coefficient)
    }
}
