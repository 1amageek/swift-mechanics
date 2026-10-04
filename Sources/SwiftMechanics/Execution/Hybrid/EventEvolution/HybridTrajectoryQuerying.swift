
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public protocol HybridTrajectoryQuerying: Sendable {
    var model: CompiledMechanicalModel { get }
    var equations: any SmoothODEEquations { get }
    var continuation: IntegrationContinuationProvider { get }
    func query(from source: RuntimeCheckpoint, to time: Double, cancellation: HybridCancellation) throws(HybridError) -> HybridTrajectoryResult
}
