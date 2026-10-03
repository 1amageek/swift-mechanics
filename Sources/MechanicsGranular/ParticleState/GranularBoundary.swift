import MechanicsCore
import MechanicsModel
import MechanicsCollision
public struct GranularBoundary: Sendable {
    public let proxy: CollisionProxy
    public let body: ModelReference, material: ModelReference
    public let velocityAtOrigin: Vector3, angularVelocity: Vector3
    public init(proxy: CollisionProxy, body: ModelReference, material: ModelReference,
        velocityAtOrigin: Vector3 = .zero, angularVelocity: Vector3 = .zero, normalVelocityTolerance: Double, angularAlignmentTolerance: Double) throws(GranularError) {
        guard normalVelocityTolerance.isFinite, normalVelocityTolerance >= 0, angularAlignmentTolerance.isFinite, angularAlignmentTolerance >= 0, body.id.kind == .body, material.id.kind == .material,
             proxy.geometry.margin == 0, proxy.geometry.approximationError == 0, proxy.geometry.resolution == .analytic else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Finite-mass/moving-normal rigid boundaries and other shapes are deferred.
        // Current evolution uses a prescribed half-space invariant under tangent translation/normal-axis spin.
        guard case .halfSpace=proxy.geometry.shape else { throw .unsupportedDomain }
        let n=try GranularArithmetic.core { () throws(CoreError) in try proxy.pose.rotation.rotating(.unitZ) }
        guard abs(try GranularArithmetic.dot(n,velocityAtOrigin)) <= normalVelocityTolerance,
            try GranularArithmetic.norm(GranularArithmetic.cross(n,angularVelocity)) <= angularAlignmentTolerance else { throw .unsupportedDomain }
        self.proxy=proxy; self.body=body; self.material=material; self.velocityAtOrigin=velocityAtOrigin; self.angularVelocity=angularVelocity
    }
}
