
public protocol ObservationSourcePreparing: Sendable {
    func prepare(model: CompiledMechanicalModel, state: CompiledKinematicState, solved: ConstrainedMotion?,
                 policy: ObservationPolicy, work: inout NumericalWork) throws(ObservationError) -> ObservationSource
}
