/// Public actual-tree retraction; the supplied external chart is validated without normalization.
public enum ManifoldRetraction {
    @inline(never)
    public static func retract(_ system:GeometricConstraintSystem,state:KinematicState,dimensionlessTangent:[Double],
                               policy:ConstraintEvaluationPolicy,work:inout NumericalWork) throws(GeometricConstraintError) -> KinematicState {
        _=try CompiledGeometricConfigurationValidator().snapshot(system,state:state,policy:policy,work:&work)
        let tree=system.model.tree,n=state.v.count
        guard dimensionlessTangent.count == n,dimensionlessTangent.allSatisfy({$0.isFinite}) else { throw .invalidShape }
        try ManifoldArithmetic.charge(try ManifoldArithmetic.numeric { () throws(NumericalError) -> Int in try NumericalWork.product(512,n+1) },&work)
        var velocity=[Double](repeating:0,count:n),q=state.q
        for i in 0..<n { velocity[i]=try ManifoldArithmetic.finite(dimensionlessTangent[i]*system.layout.scales[i]) }
        let integrator=JointMotionEvaluator()
        func apply(_ manifold:JointManifold,positions:Range<Int>,velocities:Range<Int>) throws(GeometricConstraintError) {
            let result:[Double]
            do { result=try integrator.integrating(manifold,q:q[positions],v:velocity[velocities],timeStep:1,policy:system.model.policy.jointPolicy) }
            catch { throw .invalidChart }
            guard result.count == positions.count else { throw .invalidShape }
            for (index,value) in zip(positions,result) { q[index]=value }
        }
        switch tree.rootBase {
        case .fixed: break
        case .planarFloating:
            let manifold=try ManifoldArithmetic.geometry { try JointManifold(.planar(firstTranslationAxis:.unitX,secondTranslationAxis:.unitY)) }
            try apply(manifold,positions:0..<3,velocities:0..<3)
        case .spatialFloating:
            let manifold=try ManifoldArithmetic.geometry { try JointManifold(.sixDOF) };try apply(manifold,positions:0..<7,velocities:0..<6)
        }
        for entry in tree.layout.joints {
            guard let joint=tree.joints.first(where:{$0.id == entry.joint}) else { throw .staleSource }
            try apply(joint.manifold,positions:entry.positions.range,velocities:entry.velocities.range)
        }
        let result=try ManifoldArithmetic.geometry { try KinematicState(revision:state.revision,time:state.time,q:q,v:state.v,acceleration:state.acceleration,prescribedAnchors:state.prescribedAnchors) }
        _=try CompiledGeometricConfigurationValidator().snapshot(system,state:result,policy:policy,work:&work);try ManifoldArithmetic.check(policy);return result
    }
}
