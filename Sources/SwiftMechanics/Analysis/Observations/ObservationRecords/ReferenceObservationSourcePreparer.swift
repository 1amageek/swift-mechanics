
public struct ReferenceObservationSourcePreparer: ObservationSourcePreparing {
    public init() {}
    @inline(never)
    public func prepare(model: CompiledMechanicalModel, state: CompiledKinematicState, solved: ConstrainedMotion? = nil,
                        policy: ObservationPolicy, work: inout NumericalWork) throws(ObservationError) -> ObservationSource {
        try ObservationArithmetic.check(policy)
        guard model.tree.bodies.count <= policy.maximumBodies,model.tree.layout.positionCount <= policy.maximumCoordinates,
              model.tree.layout.velocityCount <= policy.maximumCoordinates,state.state.q.count <= policy.maximumCoordinates,
              state.state.v.count <= policy.maximumCoordinates,state.state.acceleration.count <= policy.maximumCoordinates else { throw .capacityExceeded }
        let anchorBound=try ObservationArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(2,model.tree.bodies.count) }
        guard state.state.prescribedAnchors.count <= anchorBound else { throw .capacityExceeded }
        if let solved {
            guard solved.rowIDs.count <= policy.maximumReactionRows,solved.rowMultipliers.count <= policy.maximumReactionRows,
                  solved.values.count <= policy.maximumCoordinates,solved.generalizedReaction.count <= policy.maximumCoordinates,
                  solved.sourceVelocity.count <= policy.maximumCoordinates,solved.sourceSnapshot.bodies.count <= policy.maximumBodies else { throw .capacityExceeded }
        }
        try ObservationArithmetic.metadata([model.stamp.identity,state.stamp.identity,model.tree.worldFrame.key],policy:policy,work:&work)
        for anchor in state.state.prescribedAnchors { try ObservationArithmetic.metadata([anchor.frame.key],policy:policy,work:&work) }
        for body in model.tree.bodies { try ObservationArithmetic.metadata([body.id.key,body.frame.key],policy:policy,work:&work) }
        for joint in model.tree.joints { try ObservationArithmetic.metadata([joint.id.key,joint.parentAnchor.frame.key,joint.childAnchor.frame.key],policy:policy,work:&work) }
        try ObservationArithmetic.numerical { () throws(NumericalError) in
            try work.requireStorage(try NumericalWork.product(6,try NumericalWork.product(model.tree.bodies.count,model.tree.layout.velocityCount)))
            try work.chargeOperations(1)
        }
        let snapshot: KinematicSnapshot
        do throws(CompilationFailure) { snapshot=try model.evaluate(state) } catch { throw .compilation(error) }
        try ObservationArithmetic.check(policy)
        guard let solved else { return ObservationSource(model:model,state:state,snapshot:snapshot,authority:.suppliedState) }
        guard case .accelerationForce=solved.temporalMeaning,solved.values.count == state.state.v.count,
              solved.values.allSatisfy({$0.isFinite}) else { throw .missingAcceleration }
        try ObservationArithmetic.bind(solved,snapshot:snapshot,velocity:state.state.v,policy:policy,work:&work)
        let physical: KinematicState
        do { physical=try KinematicState(revision:state.state.revision,time:state.state.time,q:state.state.q,v:state.state.v,
            acceleration:solved.values,prescribedAnchors:state.state.prescribedAnchors) } catch { throw .missingAcceleration }
        try ObservationArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(2) }
        let validated:CompiledKinematicState,result:KinematicSnapshot
        do throws(CompilationFailure) {
            validated=try model.makeState(physical)
            result=try model.evaluate(validated)
        } catch { throw .compilation(error) }
        try ObservationArithmetic.check(policy)
        return ObservationSource(model:model,state:validated,snapshot:result,authority:.constraintSolved)
    }
}
