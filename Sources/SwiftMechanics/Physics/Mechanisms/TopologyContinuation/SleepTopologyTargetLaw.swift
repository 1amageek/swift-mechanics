@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal enum SleepTopologyTargetLaw {
    static func same(_ a:[Double],_ b:[Double]) -> Bool { a.count == b.count && zip(a,b).allSatisfy {$0.bitPattern == $1.bitPattern} }
    static func same(_ a:KinematicState,_ b:KinematicState) -> Bool {
        a.revision == b.revision && a.time.bitPattern == b.time.bitPattern && same(a.q,b.q) && same(a.v,b.v)
            && same(a.acceleration,b.acceleration) && a.prescribedAnchors == b.prescribedAnchors
    }
    static func same(_ a:ConstraintCoordinateLayout,_ b:ConstraintCoordinateLayout) -> Bool {
        a.revision == b.revision && a.coordinateIDs == b.coordinateIDs && a.dimensions == b.dimensions
            && same(a.scales,b.scales) && a.timeScale.bitPattern == b.timeScale.bitPattern
    }
    static func same(_ a:QuadraticConstraint,_ b:QuadraticConstraint) -> Bool {
        a.id == b.id && a.constant.bitPattern == b.constant.bitPattern && same(a.linear,b.linear)
            && same(a.hessian,b.hessian) && same(a.mixedTime,b.mixedTime)
            && a.timeLinear.bitPattern == b.timeLinear.bitPattern && a.timeQuadratic.bitPattern == b.timeQuadratic.bitPattern
    }
    @inline(never)
    static func validate(_ retirement:PreparedSleepTopologyRetirement,transition:NonlinearReconciledSubtreeRelease,
                         equations:NonlinearMechanismEquation,work:inout NumericalWork) throws(TopologyReleaseFailure) {
        let release=transition.release,physical=transition.physical
        guard retirement.release === release,transition.descriptor == equations.descriptor,
              physical.revision == release.target.stamp.revision,physical.time.bitPattern == release.incomingPhysical.time.bitPattern,
              same(physical.q,release.incomingPhysical.q),same(physical.v,release.incomingPhysical.v),
              physical.prescribedAnchors == release.incomingPhysical.prescribedAnchors,
              same(equations.drive,retirement.targetDrive),same(equations.velocityLayout,retirement.targetVelocityLayout),
              transition.motion.temporalMeaning == .accelerationForce,transition.motion.basis == release.target.tree.layout,
              transition.motion.frame == release.target.tree.worldFrame,transition.motion.time.bitPattern == physical.time.bitPattern,
              same(transition.motion.sourceVelocity,physical.v),same(transition.motion.values,physical.acceleration) else { throw .originalAcceptance }
        do throws(RuntimeFailure) { try equations.validate(model:release.target) } catch { throw .runtime(error) }
        let original=retirement.targetConstraints,current=equations.constraints,p=original.layout.scales.count
        guard same(original.layout,current.layout),same(original.minimumPosition,current.minimumPosition),same(original.maximumPosition,current.maximumPosition),
              original.minimumTime.bitPattern == current.minimumTime.bitPattern,original.maximumTime.bitPattern == current.maximumTime.bitPattern,
              current.rows.count == original.rows.count+1,
              transition.motion.rowIDs == original.rows.map({ $0.id }),
              let connector=release.target.tree.layout.joints.first(where:{$0.joint == release.connector}),connector.positions.count == 7 else { throw .originalAcceptance }
        for row in original.rows {
            try TopologyArithmetic.charge(try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(8,try NumericalWork.sum(row.hessian.count,try NumericalWork.product(2,p))) },&work)
            guard let matched=current.rows.first(where:{$0.id == row.id}),same(row,matched) else { throw .originalAcceptance }
        }
        guard let norm=current.rows.first(where:{$0.id == UInt64.max}),!original.rows.contains(where:{$0.id == norm.id}),
              norm.constant == -1,norm.timeLinear == 0,norm.timeQuadratic == 0,
              norm.linear.count == p,norm.linear.allSatisfy({$0 == 0}),norm.mixedTime.count == p,norm.mixedTime.allSatisfy({$0 == 0}) else { throw .originalAcceptance }
        let square=try TopologyArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(p,p) }
        guard norm.hessian.count == square else { throw .originalAcceptance }
        let start=connector.positions.start+3
        for i in 0..<p { for j in 0..<p {
            try TopologyArithmetic.charge(4,&work)
            let expected=i == j && i >= start && i < start+4 ? 2*current.layout.scales[i]*current.layout.scales[i] : 0
            guard norm.hessian[i*p+j].bitPattern == expected.bitPattern else { throw .originalAcceptance }
        } }
    }
}
