import SwiftMechanics

/// Original admitted CAD, freshly compiled mechanics and strict physical/catalog authority.
@available(macOS 15, *)
public final class CADGearRuntimeContext: Sendable {
    public let binding: CADGearPairBinding
    public let equations: NonlinearMechanismEquation
    public let continuation: IntegrationContinuationProvider
    public let contributors: CADGearRuntimeContributors
    public let configuration: RuntimeConfiguration
    public let checkpoints: NonlinearMechanismCheckpointHandler
    public let initialRecords: [RuntimeContributorState]
    public let runtime: CADGearRuntimePolicy
    public var model: CompiledMechanicalModel { binding.model }
    public var initialPhysical: KinematicState { binding.state.state }
    init(admission: _CADGearRuntimeAdmission) {
        binding = admission.binding; equations = admission.equations
        continuation = admission.continuation; contributors = admission.contributors
        configuration = admission.configuration; checkpoints = admission.checkpoints
        initialRecords = admission.initialRecords; runtime = admission.runtime
    }
}
