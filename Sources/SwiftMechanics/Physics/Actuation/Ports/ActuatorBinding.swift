public struct ActuatorBinding: Equatable, Sendable {
    public let actuator:EntityID, joint:EntityID, frame:EntityID
    public let model:ModelStamp
    public let lawRevision:UInt64, continuationKey:UInt64
    public let positionIndex:Int,velocityIndex:Int
    public let coordinate:ScalarCoordinateKind
    public let authority:CoordinateAuthority
    public let stateKind:ActuatorStateKind
    public let stateDomain:ActuatorScalarDomain
    public init(actuator:EntityID,joint:EntityID,frame:EntityID,model:ModelStamp,lawRevision:UInt64,continuationKey:UInt64,
                positionIndex:Int,velocityIndex:Int,coordinate:ScalarCoordinateKind,authority:CoordinateAuthority,stateKind:ActuatorStateKind,stateDomain:ActuatorScalarDomain) throws(ActuationError) {
        guard actuator.kind == .actuator,joint.kind == .joint,frame.kind == .frame,!model.identity.isEmpty,lawRevision > 0,
              positionIndex >= 0,velocityIndex >= 0 else { throw .invalidInput }
        self.actuator=actuator;self.joint=joint;self.frame=frame;self.model=model;self.lawRevision=lawRevision;self.continuationKey=continuationKey
        self.positionIndex=positionIndex;self.velocityIndex=velocityIndex;self.coordinate=coordinate;self.authority=authority;self.stateKind=stateKind;self.stateDomain=stateDomain
    }
    public func validate(model actual:CompiledMechanicalModel,work:inout ActuationWork) throws(ActuationError) {
        try work.metadata(model.identity);try work.metadata(actuator.key);try work.metadata(joint.key);try work.metadata(frame.key)
        guard model == actual.stamp else { throw .staleBinding };guard frame == actual.descriptor.worldFrame else { throw .frameMismatch }
        guard actual.tree.layout.joints.count <= work.budget.maximumBindings else { throw .capacityExceeded }
        for layout in actual.tree.layout.joints {
            try work.charge(1)
            if layout.joint == joint {
                // FIXME(INCOMPLETE_IMPLEMENTATION): Non-scalar charts reach binding admission here.
                // General manifold q-v differential routing must be implemented and verified before these charts can succeed.
                guard layout.positions.count == 1,layout.velocities.count == 1,layout.positions.start == positionIndex,layout.velocities.start == velocityIndex else { throw .unsupportedChart }
                for record in actual.descriptor.joints {
                    try work.charge(1)
                    if record.record.id == joint {
                        guard authority == record.authority else { throw .incompatibleAuthority }
                        let kind=record.record.manifold.kind
                        // FIXME(INCOMPLETE_IMPLEMENTATION): Other scalar/custom formulations reach this admission branch.
                        // A formulation-specific coordinate-rate and conjugate-effort contract is required before success.
                        guard (coordinate == .translation && kind == .prismatic) || (coordinate == .rotation && (kind == .revolute || kind == .screw)) else { throw .unsupportedChart }
                        return
                    }
                }
                throw .staleBinding
            }
        }
        throw .staleBinding
    }
}
