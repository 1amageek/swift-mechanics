import MechanicsCore
public final class SurfaceContactStep: Sendable {
    public let source: SurfaceContactState
    public let snapshot: DeformingSurfaceSnapshot
    public let endpointTime: Double
    public let nodalForces: [Vector3]
    public let contacts: [SurfaceForceTrial]
    internal init(source: SurfaceContactState, snapshot: DeformingSurfaceSnapshot, endpointTime: Double, forces: [Vector3], contacts: [SurfaceForceTrial]) {
        self.source=source; self.snapshot=snapshot; self.endpointTime=endpointTime; nodalForces=forces; self.contacts=contacts
    }
}
