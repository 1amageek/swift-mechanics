/// Full physical source with genuine known-root motion rows and retained original geometry.
public final class PrescribedRootConstraint: Sendable {
    public let system: PhysicalRigidDynamicsSystem
    public let geometry: VelocityConstraintSample
    public let base: PrescribedBaseMotionSample
    public let sample: VelocityConstraintSample
    public let knownCoordinates: [Int]
    public let dynamicCoordinates: [Int]
    public init(system:PhysicalRigidDynamicsSystem,geometry:VelocityConstraintSample,base:PrescribedBaseMotionSample,
                rowIDs:[UInt64],policy:MechanismSolvePolicy,work:inout NumericalWork) throws(MechanismError) {
        try MechanismArithmetic.check(policy)
        let snapshot=system.input.snapshot,n=system.velocityCount,k=snapshot.tree.rootBase.velocityCount,m=geometry.rowIDs.count
        guard k > 0,n <= policy.maximumCoordinates,m <= policy.maximumRows,rowIDs.count == k,
              m <= policy.maximumRows-k,base.layout == snapshot.tree.rootBase,base.time.bitPattern == snapshot.time.bitPattern,
              base.worldFrame == snapshot.tree.worldFrame,base.frame == snapshot.tree.bodies.first?.frame,
              base.q.count == snapshot.tree.rootBase.positionCount,base.v.count == k,base.a.count == k,
              geometry.layout.scales.count == n,geometry.layout.coordinateIDs.count == n,
              geometry.layout.revision == snapshot.tree.revision,geometry.layout.scales == policy.dynamics.coordinateScales,
              geometry.layout.timeScale == policy.dynamics.timeScale else { throw .staleBinding }
        let entries=try MechanismArithmetic.numerical { () throws(NumericalError) -> Int in try NumericalWork.product(m,n) }
        guard geometry.rows.count == entries,geometry.drift.count == m,geometry.accelerationBias.count == m else { throw .invalidShape }
        try MechanismArithmetic.numerical { () throws(NumericalError) -> Void in
            try work.requireStorage(try NumericalWork.sum(system.scalarStorage,try NumericalWork.sum(try NumericalWork.product(n,m+k),try NumericalWork.product(16,n+m+k))))
        }
        try MechanismArithmetic.charge(try MechanismArithmetic.numerical { () throws(NumericalError) -> Int in
            try NumericalWork.sum(try NumericalWork.product(m+k,m+k),try NumericalWork.sum(entries,try NumericalWork.product(512,k+1)))
        },&work)
        for i in rowIDs.indices { guard !rowIDs[..<i].contains(rowIDs[i]),!geometry.rowIDs.contains(rowIDs[i]) else { throw .invalidInput } }
        for i in geometry.rowIDs.indices { guard !geometry.rowIDs[..<i].contains(geometry.rowIDs[i]) else { throw .invalidInput } }
        guard geometry.rows.allSatisfy({$0.isFinite}),geometry.drift.allSatisfy({$0.isFinite}),geometry.accelerationBias.allSatisfy({$0.isFinite}) else { throw .invalidInput }
        for i in 0..<k { guard base.v[i].bitPattern == system.input.velocity[i].bitPattern else { throw .staleBinding } }
        try Self.validateSource(snapshot,base:base)
        var rows=[Double](repeating:0,count:(m+k)*n),drift=[Double](repeating:0,count:m+k),bias=drift
        let t=geometry.layout.timeScale,s=geometry.layout.scales
        for i in 0..<k {
            rows[i*n+i]=1
            drift[i]=try MechanismArithmetic.finite(-base.v[i]*t/s[i])
            bias[i]=try MechanismArithmetic.finite(-base.a[i]*t*t/s[i])
        }
        for i in geometry.rows.indices { rows[k*n+i]=geometry.rows[i] }
        for i in 0..<m { drift[k+i]=geometry.drift[i];bias[k+i]=geometry.accelerationBias[i] }
        self.system=system;self.geometry=geometry;self.base=base
        sample=VelocityConstraintSample(layout:geometry.layout,rowIDs:rowIDs+geometry.rowIDs,rows:rows,drift:drift,accelerationBias:bias,isIntegrable:geometry.isIntegrable)
        knownCoordinates=Array(0..<k);dynamicCoordinates=Array(k..<n)
        try MechanismArithmetic.check(policy)
    }
    @inline(never)
    private static func validateSource(_ snapshot:KinematicSnapshot,base:PrescribedBaseMotionSample) throws(MechanismError) {
        guard let root=snapshot.bodies.first else { throw .staleBinding }
        let expected:JointKinematics
        do {
            let manifold=try JointManifold(base.layout == .spatialFloating ? .sixDOF : .planar(firstTranslationAxis:.unitX,secondTranslationAxis:.unitY))
            // Sealed law rotations satisfy the public raw-unit 16-ulp bound. The root chart has structural full rank.
            let policy=try JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:16*Double.ulpOfOne,relative:0),
                chartRankRelative:0,characteristicLengthMeters:1)
            expected=try JointMotionEvaluator().evaluate(manifold,q:base.q[...],v:base.v[...],acceleration:base.a[...],policy:policy)
        } catch { throw .invalidInput }
        guard root.motion == expected.frameMotion,snapshot.coordinateRate.count >= expected.coordinateRate.count,
              snapshot.coordinateRate.prefix(expected.coordinateRate.count).elementsEqual(expected.coordinateRate) else { throw .staleBinding }
    }

    public func geometricReaction(_ motion:ConstrainedMotion,work:inout NumericalWork) throws(MechanismError) -> [Double] {
        let n=system.velocityCount,k=knownCoordinates.count,m=geometry.rowIDs.count
        guard motion.rowIDs == sample.rowIDs,motion.rowMultipliers.count == m+k,motion.time.bitPattern == base.time.bitPattern,
              motion.sourceVelocity == system.input.velocity,motion.basis == system.input.snapshot.tree.layout,
              motion.frame == system.input.snapshot.tree.worldFrame,
              motion.layout.coordinateIDs == sample.layout.coordinateIDs,motion.layout.dimensions == sample.layout.dimensions,
              motion.layout.scales == sample.layout.scales,motion.layout.timeScale == sample.layout.timeScale,
              motion.layout.revision == sample.layout.revision else { throw .staleBinding }
        try MechanismArithmetic.charge(try MechanismArithmetic.numerical { () throws(NumericalError) -> Int in
            try NumericalWork.product(512,try NumericalWork.product(system.input.snapshot.tree.bodies.count,n+1))
        },&work)
        try Self.validateMotionSource(motion.sourceSnapshot,expected:system.input.snapshot)
        try MechanismArithmetic.numerical { () throws(NumericalError) -> Void in try work.requireStorage(try NumericalWork.sum(system.scalarStorage,n)) }
        var result=[Double](repeating:0,count:n)
        for row in 0..<m { for i in 0..<n {
            try MechanismArithmetic.charge(4,&work)
            result[i]=try MechanismArithmetic.finite(result[i]+geometry.rows[row*n+i]*motion.rowMultipliers[k+row]/geometry.layout.scales[i])
        } }
        return result
    }
    @inline(never)
    private static func validateMotionSource(_ actual:KinematicSnapshot,expected:KinematicSnapshot) throws(MechanismError) {
        let a=actual.tree,e=expected.tree
        guard actual.time.bitPattern == expected.time.bitPattern,a.layout == e.layout,a.revision == e.revision,
              a.rootBase == e.rootBase,a.worldFrame == e.worldFrame,a.frameCount == e.frameCount,
              a.bodies == e.bodies,a.joints == e.joints,actual.bodies == expected.bodies,
              actual.frames == expected.frames,actual.joints == expected.joints,
              actual.coordinateRate == expected.coordinateRate else { throw .staleBinding }
        for body in e.bodies {
            do throws(JointError) {
                guard try actual.geometricColumns(body:body.id).elementsEqual(expected.geometricColumns(body:body.id)) else { throw .invalidJointGeometry }
            } catch { throw .staleBinding }
        }
    }

}
