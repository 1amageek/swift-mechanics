import MechanicsFlexible
public struct DeformingSurfaceSnapshot: Sendable {
    public let surface: MaterialSurface
    public let state: NodalState
    public let geometryRevision: UInt64
    public let timeSeconds: Double
    internal init(surface: MaterialSurface, state: NodalState, geometryRevision: UInt64, time: Double) {
        self.surface=surface; self.state=state; self.geometryRevision=geometryRevision; timeSeconds=time
    }
}
