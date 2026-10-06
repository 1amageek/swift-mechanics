
public final class ObservationSource: Sendable {
    public let model: CompiledMechanicalModel
    public let state: CompiledKinematicState
    public let snapshot: KinematicSnapshot
    public let accelerationAuthority: ObservationHeader.AccelerationAuthority
    internal init(model: CompiledMechanicalModel, state: CompiledKinematicState, snapshot: KinematicSnapshot,
                  authority: ObservationHeader.AccelerationAuthority) {
        self.model=model;self.state=state;self.snapshot=snapshot;accelerationAuthority=authority
    }
}
