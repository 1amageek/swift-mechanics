/// Lossless retirement metadata, independent of the legacy zero-load continuation signature.
internal struct SleepTopologySourceSignature {
    private var bytes:[UInt8]=[]
    private let maximum:Int
    private mutating func word(_ value:UInt64,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        guard maximum >= bytes.count,maximum-bytes.count >= 8 else { throw .capacityExceeded }
        try SleepTopologyLawMapping.charge(8,&work)
        for shift in stride(from:0,to:64,by:8) { bytes.append(UInt8(truncatingIfNeeded:value >> shift)) }
    }
    private mutating func scalar(_ value:Double,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        guard value.isFinite else { throw .unsupportedDomain };try word(value.bitPattern,&work)
    }
    private mutating func text(_ value:String,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        try word(UInt64(value.utf8.count),&work)
        guard value.utf8.count <= maximum-bytes.count else { throw .capacityExceeded }
        try SleepTopologyLawMapping.charge(value.utf8.count,&work);bytes.append(contentsOf:value.utf8)
    }
    private mutating func vector(_ value:Vector3,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        for v in [value.x,value.y,value.z] { try scalar(v,&work) }
    }
    private mutating func pose(_ value:RigidTransform,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        try vector(value.translation,&work)
        for v in [value.rotation.w,value.rotation.x,value.rotation.y,value.rotation.z] { try scalar(v,&work) }
    }
    private mutating func capability(_ value:LinearCapability,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        try word(value.precision == .float32 ? 0 : 1,&work);try word(value.backend == .referenceCPU ? 0 : 1,&work)
        switch value.algorithm {
        case .partialPivotLU:try word(0,&work);case .cholesky:try word(1,&work)
        case .conjugateGradient:try word(2,&work);case .treeElimination:try word(3,&work)
        }
    }
    private mutating func tolerance(_ value:LinearTolerance<Double>,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        for v in [value.absoluteResidual,value.relativeResidual,value.pivotThreshold] { try scalar(v,&work) }
    }
    private mutating func constraintPolicy(_ value:ConstraintSolvePolicy,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        try word(UInt64(value.diagonalMetric.count),&work);for v in value.diagonalMetric { try scalar(v,&work) }
        for v in [value.energyScale,value.rankRelativeTolerance,value.originalResidualTolerance,value.maximumCorrection] { try scalar(v,&work) }
        try word(value.rankPolicy == .allowRedundancy ? 0 : 1,&work)
        try word(UInt64(value.evaluation.maximumCoordinates),&work);try word(UInt64(value.evaluation.maximumRows),&work);try word(value.evaluation.expectedLayoutRevision,&work)
        try capability(value.linearCapability,&work);try tolerance(value.linearTolerance,&work)
        let n=value.nonlinear
        try capability(n.capability,&work);try tolerance(n.tolerance,&work)
        switch n.strategy {
        case .newton:try word(0,&work)
        case .lineSearch(let a,let b,let c):try word(1,&work);for v in [a,b,c] { try scalar(v,&work) }
        case .trustRegion(let a,let b,let c,let d,let e,let f,let g,let h):try word(2,&work);for v in [a,b,c,d,e,f,g,h] { try scalar(v,&work) }
        }
        for v in [n.referenceScale,n.minimumDirectionNorm,n.derivativeProbeDistance,n.derivativeAbsoluteTolerance,n.derivativeRelativeTolerance] { try scalar(v,&work) }
        try word(UInt64(n.maximumFactorEntries),&work);try word(n.estimateCondition ? 1 : 0,&work)
        for v in [n.budget.scalarStorage,n.budget.arithmeticOperations,n.budget.iterations] { try word(UInt64(v),&work) }
    }
    @available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
    @inline(never)
    static func encode(owner:CheckpointedMechanismSleep,source:RuntimeAcceptedState,history:MechanismSleepHistory,
                       maximum:Int,work:inout NumericalWork) throws(SleepTopologyFailureReason) -> [UInt8] {
        guard maximum > 0 else { throw .capacityExceeded }
        do throws(NumericalError) { try work.requireStorage(try NumericalWork.sum(maximum/8,1)) } catch { throw .numerical(error) }
        var data=SleepTopologySourceSignature(maximum:maximum)
        try data.text("sleep-topology-source-law-v1",&work);try data.text(owner.descriptor.identity,&work);try data.text(owner.descriptor.chart,&work)
        let model=owner.model,compiler=model.policy,joint=compiler.jointPolicy
        try data.text(model.stamp.identity,&work);try data.word(model.stamp.revision,&work)
        try data.text(model.descriptor.root.key,&work);try data.text(model.tree.worldFrame.key,&work)
        for v in [joint.quaternionTolerance.absolute,joint.quaternionTolerance.relative,joint.chartRankRelative,joint.characteristicLengthMeters,
                  compiler.translationTolerance.absolute,compiler.translationTolerance.relative,compiler.rotationTolerance.absolute,compiler.rotationTolerance.relative,
                  compiler.inertiaPolicy.symmetry.absolute,compiler.inertiaPolicy.symmetry.relative,compiler.inertiaPolicy.physicalityRelative] { try data.scalar(v,&work) }
        try data.word(UInt64(model.tree.bodies.count),&work)
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let actual)=record,let inertia=actual.inertia else { throw .unsupportedDomain }
            try data.text(body.id.key,&work);try data.text(body.frame.key,&work);try data.pose(body.referencePose,&work)
            switch actual.mode { case .dynamic:try data.word(0,&work);case .static:try data.word(1,&work);case .prescribedKinematic:throw .unsupportedDomain }
            let p=inertia.properties,m=p.inertiaAtCenter
            try data.scalar(p.mass,&work);try data.vector(p.centerOfMass,&work)
            for v in [m.m00,m.m01,m.m02,m.m10,m.m11,m.m12,m.m20,m.m21,m.m22] { try data.scalar(v,&work) }
        }
        try data.word(UInt64(model.tree.joints.count),&work)
        for item in model.tree.joints {
            guard let record=model.descriptor.joints.first(where:{$0.record.id == item.id}),record.authority == .dynamicState,
                  let range=model.tree.layout.joints.first(where:{$0.joint == item.id}),
                  item.manifold.kind == .prismatic || item.manifold.kind == .revolute else { throw .unsupportedDomain }
            for text in [item.id.key,item.parentBody.key,item.childBody.key] { try data.text(text,&work) }
            for anchor in [item.parentAnchor,item.childAnchor] {
                guard case .fixed(let pose)=anchor.placement else { throw .unsupportedDomain }
                try data.text(anchor.frame.key,&work);try data.pose(pose,&work)
            }
            try data.word(item.manifold.kind == .prismatic ? 0 : 1,&work)
            for v in [range.positions.start,range.positions.count,range.velocities.start,range.velocities.count,item.manifold.orderedAxes.count] { try data.word(UInt64(v),&work) }
            for axis in item.manifold.orderedAxes { try data.vector(axis.direction,&work);try data.scalar(axis.pitchMetersPerRadian,&work) }
        }
        let constraints=owner.constraints,layout=constraints.layout
        try data.word(layout.revision,&work);try data.scalar(layout.timeScale,&work)
        try data.word(UInt64(layout.coordinateIDs.count),&work)
        for i in layout.coordinateIDs.indices {
            try data.word(layout.coordinateIDs[i],&work)
            let dimension=layout.dimensions[i]
            for exponent in [dimension.length,dimension.mass,dimension.time,dimension.angle,dimension.electricCurrent,dimension.temperature,dimension.amount,dimension.luminousIntensity] { try data.word(UInt64(bitPattern:Int64(exponent)),&work) }
            for value in [layout.scales[i],constraints.minimumPosition[i],constraints.maximumPosition[i]] { try data.scalar(value,&work) }
        }
        try data.scalar(constraints.minimumTime,&work);try data.scalar(constraints.maximumTime,&work)
        try data.word(UInt64(constraints.rows.count),&work)
        for row in constraints.rows {
            try data.word(row.id,&work)
            for value in [row.constant,row.timeLinear,row.timeQuadratic] { try data.scalar(value,&work) }
            for values in [row.linear,row.hessian,row.mixedTime] {
                try data.word(UInt64(values.count),&work);for value in values { try data.scalar(value,&work) }
            }
        }
        try data.word(UInt64(history.drive.count),&work);for v in history.drive { try data.scalar(v,&work) }
        let policy=owner.solvePolicy,dynamics=policy.dynamics
        try data.word(UInt64(policy.maximumCoordinates),&work);try data.word(UInt64(policy.maximumRows),&work);try data.scalar(policy.originalTolerance,&work)
        try data.capability(dynamics.capability,&work);try data.tolerance(dynamics.linearTolerance,&work)
        try data.word(UInt64(dynamics.coordinateScales.count),&work);for v in dynamics.coordinateScales { try data.scalar(v,&work) }
        try data.scalar(dynamics.energyScale,&work);try data.scalar(dynamics.timeScale,&work);try data.constraintPolicy(policy.constraints,&work)
        for v in [owner.admission.capacity.maximumBodies,owner.admission.capacity.maximumVelocities,owner.admission.capacity.maximumBodyWrenches,owner.admission.capacity.maximumGeneralizedContributions] { try data.word(UInt64(v),&work) }
        for v in [owner.admission.angularVelocityTolerance.absolute,owner.admission.angularVelocityTolerance.relative,owner.admission.linearVelocityTolerance.absolute,owner.admission.linearVelocityTolerance.relative,
                  owner.policy.thresholds.kineticEnergyThreshold,owner.policy.thresholds.normalizedVelocityThreshold,owner.policy.minimumRestDuration] { try data.scalar(v,&work) }
        try data.word(UInt64(source.checkpoint.contributors.count),&work)
        for record in source.checkpoint.contributors {
            try data.text(record.id,&work);try data.word(UInt64(record.category.rawValue),&work);try data.word(record.version,&work)
            try data.word(UInt64(record.bytes.count),&work)
            guard record.bytes.count <= maximum-data.bytes.count else { throw .capacityExceeded }
            try SleepTopologyLawMapping.charge(record.bytes.count,&work);data.bytes.append(contentsOf:record.bytes)
        }
        return data.bytes
    }
}
