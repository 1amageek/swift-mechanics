internal enum ToothRetraction {
    @inline(never)
    static func apply(model: ToothContactModel, source: KinematicState, acceleration: [Double], timeStep: Double,
                      policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> KinematicState {
        try ToothArithmetic.check(policy); try work.charge(1024)
        let velocity=try [ToothArithmetic.value(source.v[0]+timeStep*acceleration[0]),
                          ToothArithmetic.value(source.v[1]+timeStep*acceleration[1])]
        var positions=source.q
        let evaluator: any JointMotionEvaluating=JointMotionEvaluator()
        for (index,joint) in model.tree.joints.enumerated() {
            let layout=model.tree.layout.joints[index]
            let integrated: [Double]
            do { integrated=try evaluator.integrating(joint.manifold,q:source.q[layout.positions.start..<layout.positions.end],
                v:velocity[layout.velocities.start..<layout.velocities.end],timeStep:timeStep,policy:model.jointPolicy) }
            catch let e as JointError { throw .joint(e) }
            catch let e as CoreError { throw .core(e) }
            catch { throw .unexpectedKinematicsFailure }
            guard integrated.count == layout.positions.count else { throw .invalidSupplierOutput }
            positions[layout.positions.start]=integrated[0]
        }
        do { return try KinematicState(revision:model.tree.revision,time:source.time+timeStep,q:positions,v:velocity,acceleration:acceleration) }
        catch { throw .joint(error) }
    }
}
