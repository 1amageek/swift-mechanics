/// Lossless bounded metadata for the explicit quadratic original-source constructor.
internal struct NonlinearPhysicalSignature {
    private var value="nonlinear-original-physical-v1"
    private let maximum:Int
    private mutating func word(_ number:UInt64) throws(MechanismError) {
        let field=":"+String(number,radix:16)
        guard maximum >= value.utf8.count,field.utf8.count <= maximum-value.utf8.count else { throw .capacityExceeded }
        value.append(field)
    }
    private mutating func scalar(_ number:Double) throws(MechanismError) {
        guard number.isFinite else { throw .invalidInput };try word(number.bitPattern)
    }
    private mutating func text(_ text:String) throws(MechanismError) {
        let count=text.utf8.count
        try word(UInt64(count))
        guard maximum >= value.utf8.count,count <= (maximum-value.utf8.count)/2 else { throw .capacityExceeded }
        for byte in text.utf8 {
            if byte < 16 { value.append("0") }
            value.append(String(byte,radix:16))
        }
    }
    private mutating func vector(_ v:Vector3) throws(MechanismError) { try scalar(v.x);try scalar(v.y);try scalar(v.z) }
    private mutating func pose(_ p:RigidTransform) throws(MechanismError) {
        try vector(p.translation);for v in [p.rotation.w,p.rotation.x,p.rotation.y,p.rotation.z] { try scalar(v) }
    }
    private mutating func authority(_ a:CoordinateAuthority) throws(MechanismError) {
        switch a { case .fixed:try word(0);case .dynamicState:try word(1);case .prescribedMotion:throw .unsupportedChart }
    }
    private mutating func capability(_ c:LinearCapability) throws(MechanismError) {
        try word(c.precision == .float32 ? 0 : 1);try word(c.backend == .referenceCPU ? 0 : 1)
        switch c.algorithm { case .partialPivotLU:try word(0);case .cholesky:try word(1);case .conjugateGradient:try word(2);case .treeElimination:try word(3) }
    }
    private mutating func tolerance(_ t:LinearTolerance<Double>) throws(MechanismError) {
        try scalar(t.absoluteResidual);try scalar(t.relativeResidual);try scalar(t.pivotThreshold)
    }
    private mutating func constraints(_ p:ConstraintSolvePolicy) throws(MechanismError) {
        try word(UInt64(p.diagonalMetric.count));for v in p.diagonalMetric { try scalar(v) }
        for v in [p.energyScale,p.rankRelativeTolerance,p.originalResidualTolerance,p.maximumCorrection] { try scalar(v) }
        try word(p.rankPolicy == .allowRedundancy ? 0 : 1)
        try word(UInt64(p.evaluation.maximumCoordinates));try word(UInt64(p.evaluation.maximumRows));try word(p.evaluation.expectedLayoutRevision)
        try capability(p.linearCapability);try tolerance(p.linearTolerance)
        let n=p.nonlinear
        try capability(n.capability);try tolerance(n.tolerance)
        switch n.strategy {
        case .newton:try word(0)
        case .lineSearch(let a,let b,let c):try word(1);for v in [a,b,c] { try scalar(v) }
        case .trustRegion(let a,let b,let c,let d,let e,let f,let g,let h):try word(2);for v in [a,b,c,d,e,f,g,h] { try scalar(v) }
        }
        for v in [n.referenceScale,n.minimumDirectionNorm,n.derivativeProbeDistance,n.derivativeAbsoluteTolerance,n.derivativeRelativeTolerance] { try scalar(v) }
        try word(UInt64(n.maximumFactorEntries));try word(n.estimateCondition ? 1 : 0)
        for v in [n.budget.scalarStorage,n.budget.arithmeticOperations,n.budget.iterations] { try word(UInt64(v)) }
    }
    @available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
    static func signature(model:CompiledMechanicalModel,policy:MechanismSolvePolicy,projection:NonlinearMechanismProjectionPolicy,
                          admission:DynamicsAdmission,drive:[Double],quadraticChart:String,maximum:Int) throws(MechanismError) -> String {
        var data=NonlinearPhysicalSignature(maximum:maximum)
        guard maximum >= data.value.utf8.count,model.tree.rootBase == .fixed else { throw .capacityExceeded }
        try data.text(quadraticChart);try data.text(model.stamp.identity);try data.word(model.stamp.revision)
        try data.text(model.tree.worldFrame.key);try data.text(model.descriptor.root.key);try data.word(0);try data.authority(model.descriptor.rootAuthority)
        try data.word(UInt64(model.tree.layout.positionCount));try data.word(UInt64(model.tree.layout.velocityCount))
        let compiler=model.policy,joint=compiler.jointPolicy
        for v in [joint.quaternionTolerance.absolute,joint.quaternionTolerance.relative,joint.chartRankRelative,joint.characteristicLengthMeters,
                  compiler.translationTolerance.absolute,compiler.translationTolerance.relative,compiler.rotationTolerance.absolute,compiler.rotationTolerance.relative,
                  compiler.inertiaPolicy.symmetry.absolute,compiler.inertiaPolicy.symmetry.relative,compiler.inertiaPolicy.physicalityRelative] { try data.scalar(v) }
        try data.word(UInt64(model.tree.bodies.count))
        for body in model.tree.bodies {
            guard let record=model.descriptor.bodies.first(where:{$0.id == body.id}),case .spatial(let actual)=record,let inertia=actual.inertia else { throw .unsupportedChart }
            try data.text(body.id.key);try data.text(body.frame.key);try data.pose(body.referencePose)
            switch actual.mode { case .dynamic:try data.word(0);case .static:try data.word(1);case .prescribedKinematic:throw .unsupportedChart }
            let p=inertia.properties
            try data.scalar(p.mass);try data.vector(p.centerOfMass)
            let m=p.inertiaAtCenter
            for v in [m.m00,m.m01,m.m02,m.m10,m.m11,m.m12,m.m20,m.m21,m.m22] { try data.scalar(v) }
        }
        try data.word(UInt64(model.tree.joints.count))
        for joint in model.tree.joints {
            guard let record=model.descriptor.joints.first(where:{$0.record.id == joint.id}),let range=model.tree.layout.joints.first(where:{$0.joint == joint.id}) else { throw .staleBinding }
            try data.text(joint.id.key);try data.text(joint.parentBody.key);try data.text(joint.childBody.key);try data.authority(record.authority)
            for anchor in [joint.parentAnchor,joint.childAnchor] {
                guard case .fixed(let pose)=anchor.placement else { throw .unsupportedChart }
                try data.text(anchor.frame.key);try data.pose(pose)
            }
            switch joint.manifold.kind {
            case .fixed:try data.word(0);case .revolute:try data.word(1);case .prismatic:try data.word(2);case .spherical:try data.word(3)
            case .universal:try data.word(4);case .cylindrical:try data.word(5);case .planar:try data.word(6);case .screw:try data.word(7)
            case .sixDOF:try data.word(8);case .custom:try data.word(9)
            }
            for v in [range.positions.start,range.positions.count,range.velocities.start,range.velocities.count,joint.manifold.orderedAxes.count] { try data.word(UInt64(v)) }
            for axis in joint.manifold.orderedAxes {
                switch axis.kind { case .prismatic:try data.word(0);case .revolute:try data.word(1);case .screw:try data.word(2) }
                try data.vector(axis.direction);try data.scalar(axis.pitchMetersPerRadian)
            }
        }
        try data.word(UInt64(drive.count));for v in drive { try data.scalar(v) }
        try data.word(UInt64(policy.maximumCoordinates));try data.word(UInt64(policy.maximumRows));try data.scalar(policy.originalTolerance)
        try data.capability(policy.dynamics.capability);try data.tolerance(policy.dynamics.linearTolerance)
        for v in policy.dynamics.coordinateScales { try data.scalar(v) };try data.scalar(policy.dynamics.energyScale);try data.scalar(policy.dynamics.timeScale)
        try data.constraints(policy.constraints);try data.constraints(projection.position)
        try data.word(UInt64(projection.maximumIterations));try data.scalar(projection.maximumCorrection)
        for v in [admission.capacity.maximumBodies,admission.capacity.maximumVelocities,admission.capacity.maximumBodyWrenches,admission.capacity.maximumGeneralizedContributions] { try data.word(UInt64(v)) }
        for v in [admission.angularVelocityTolerance.absolute,admission.angularVelocityTolerance.relative,admission.linearVelocityTolerance.absolute,admission.linearVelocityTolerance.relative] { try data.scalar(v) }
        return data.value
    }
}
