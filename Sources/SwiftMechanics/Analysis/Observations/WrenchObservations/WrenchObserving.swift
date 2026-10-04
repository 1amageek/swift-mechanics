
public protocol WrenchObserving: Sendable {
    /// Mounted evidence is verified against the exact original source/mount before expressing the supplied path.
    func physical(source:ObservationSource,mount:ObservationMount,input:IdentifiedPhysicalWrench,options:WrenchObservationOptions,
                  gravity:ObservationGravity?,policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> PhysicalWrenchObservation
    /// This is a source-bound scalar generalized component, not an inferred six-axis bearing wrench.
    func axialReaction(source:ObservationSource,mount:ObservationMount,joint:EntityID,motion:ConstrainedMotion,
                       temporal:IdentifiedPhysicalWrench.TemporalMeaning,sign:WrenchObservationOptions.Sign,
                       policy:ObservationPolicy,work:inout NumericalWork) throws(ObservationError) -> AxialReactionObservation
    func bearingReaction() throws(ObservationError) -> Never
}
