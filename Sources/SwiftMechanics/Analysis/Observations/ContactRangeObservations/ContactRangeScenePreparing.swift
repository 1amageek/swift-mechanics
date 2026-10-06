public protocol ContactRangeScenePreparing: Sendable {
    func prepare(model: CompiledMechanicalModel, state: CompiledKinematicState,
                 colliders: [ObservationColliderBinding], revision: UInt64,
                 policy: ContactRangeObservationPolicy, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> ContactRangeScene
}
