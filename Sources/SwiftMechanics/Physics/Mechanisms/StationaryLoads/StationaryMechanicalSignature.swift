internal enum StationaryMechanicalSignature {
    static func bytes(model:CompiledMechanicalModel,policy:MechanismSolvePolicy,admission:DynamicsAdmission,drive:[Double],maximum:Int) throws(StationaryLoadError) -> [UInt8] {
        var data=StationaryCanonicalBytes(maximum:maximum)
        try data.text("loaded-spatial-scalar-law-v1");try data.text(model.stamp.identity);try data.word(model.stamp.revision)
        try data.text(model.tree.worldFrame.key);try data.text(model.descriptor.root.key)
        let jointPolicy=model.policy.jointPolicy
        for value in [jointPolicy.quaternionTolerance.absolute,jointPolicy.quaternionTolerance.relative,jointPolicy.chartRankRelative,jointPolicy.characteristicLengthMeters] { try data.scalar(value) }
        try data.word(UInt64(model.tree.bodies.count))
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let actual)=record,let inertia=actual.inertia else { throw .unsupportedDomain }
            try data.text(body.id.key);try data.text(body.frame.key);try data.pose(body.referencePose)
            switch actual.mode { case .dynamic:try data.word(0);case .static:try data.word(1);case .prescribedKinematic:try data.word(2) }
            let properties=inertia.properties
            try data.scalar(properties.mass);try data.vector(properties.centerOfMass);try data.matrix(properties.inertiaAtCenter)
        }
        try data.word(UInt64(model.tree.joints.count))
        for joint in model.tree.joints {
            try data.text(joint.id.key);try data.text(joint.parentBody.key);try data.text(joint.childBody.key)
            for anchor in [joint.parentAnchor,joint.childAnchor] {
                guard case .fixed(let pose)=anchor.placement else { throw .unsupportedDomain }
                try data.text(anchor.frame.key);try data.pose(pose)
            }
            guard joint.manifold.kind == .revolute || joint.manifold.kind == .prismatic else { throw .unsupportedDomain }
            try data.word(joint.manifold.kind == .revolute ? 0 : 1);try data.word(UInt64(joint.manifold.orderedAxes.count))
            for axis in joint.manifold.orderedAxes { try data.vector(axis.direction);try data.scalar(axis.pitchMetersPerRadian) }
        }
        try data.word(UInt64(drive.count));for value in drive { try data.scalar(value) }
        try data.word(UInt64(policy.maximumCoordinates));try data.word(UInt64(policy.maximumRows));try data.scalar(policy.originalTolerance)
        let dynamics=policy.dynamics,constraints=policy.constraints
        try capability(dynamics.capability,data:&data);try tolerance(dynamics.linearTolerance,data:&data)
        try data.word(UInt64(dynamics.coordinateScales.count))
        for value in dynamics.coordinateScales { try data.scalar(value) };try data.scalar(dynamics.energyScale);try data.scalar(dynamics.timeScale)
        try data.word(UInt64(constraints.diagonalMetric.count))
        for value in constraints.diagonalMetric { try data.scalar(value) }
        for value in [constraints.energyScale,constraints.rankRelativeTolerance,constraints.originalResidualTolerance,constraints.maximumCorrection] { try data.scalar(value) }
        switch constraints.rankPolicy { case .allowRedundancy:try data.word(0);case .requireIndependentRows:try data.word(1) }
        try data.word(UInt64(constraints.evaluation.maximumCoordinates));try data.word(UInt64(constraints.evaluation.maximumRows));try data.word(constraints.evaluation.expectedLayoutRevision)
        try capability(constraints.linearCapability,data:&data);try tolerance(constraints.linearTolerance,data:&data)
        let nonlinear=constraints.nonlinear
        try capability(nonlinear.capability,data:&data);try tolerance(nonlinear.tolerance,data:&data)
        switch nonlinear.strategy {
        case .newton:try data.word(0)
        case .lineSearch(let a,let b,let c):try data.word(1);for value in [a,b,c] { try data.scalar(value) }
        case .trustRegion(let a,let b,let c,let d,let e,let f,let g,let h):try data.word(2);for value in [a,b,c,d,e,f,g,h] { try data.scalar(value) }
        }
        for value in [nonlinear.referenceScale,nonlinear.minimumDirectionNorm,nonlinear.derivativeProbeDistance,nonlinear.derivativeAbsoluteTolerance,nonlinear.derivativeRelativeTolerance] { try data.scalar(value) }
        try data.word(UInt64(nonlinear.maximumFactorEntries));try data.word(nonlinear.estimateCondition ? 1 : 0)
        try data.word(UInt64(nonlinear.budget.scalarStorage));try data.word(UInt64(nonlinear.budget.arithmeticOperations));try data.word(UInt64(nonlinear.budget.iterations))
        for value in [admission.capacity.maximumBodies,admission.capacity.maximumVelocities,admission.capacity.maximumBodyWrenches,admission.capacity.maximumGeneralizedContributions] { try data.word(UInt64(value)) }
        for value in [admission.angularVelocityTolerance.absolute,admission.angularVelocityTolerance.relative,admission.linearVelocityTolerance.absolute,admission.linearVelocityTolerance.relative] { try data.scalar(value) }
        return data.bytes
    }
    private static func tolerance(_ tolerance:LinearTolerance<Double>,data:inout StationaryCanonicalBytes) throws(StationaryLoadError) {
        try data.scalar(tolerance.absoluteResidual);try data.scalar(tolerance.relativeResidual);try data.scalar(tolerance.pivotThreshold)
    }
    private static func capability(_ capability:LinearCapability,data:inout StationaryCanonicalBytes) throws(StationaryLoadError) {
        try data.word(capability.precision == .float32 ? 0 : 1);try data.word(capability.backend == .referenceCPU ? 0 : 1)
        switch capability.algorithm { case .partialPivotLU:try data.word(0);case .cholesky:try data.word(1);case .conjugateGradient:try data.word(2);case .treeElimination:try data.word(3) }
    }
}
