internal enum SleepTopologyLawMapping {
    static func same(_ a:[Double],_ b:[Double]) -> Bool { a.count == b.count && zip(a,b).allSatisfy {$0.bitPattern == $1.bitPattern} }
    static func same(_ a:KinematicState,_ b:KinematicState) -> Bool {
        a.revision == b.revision && a.time.bitPattern == b.time.bitPattern && same(a.q,b.q) && same(a.v,b.v)
            && same(a.acceleration,b.acceleration) && a.prescribedAnchors == b.prescribedAnchors
    }
    static func sum(_ a:Int,_ b:Int) throws(SleepTopologyFailureReason) -> Int {
        do throws(NumericalError) { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
    static func charge(_ count:Int,_ work:inout NumericalWork) throws(SleepTopologyFailureReason) {
        do throws(NumericalError) { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    @available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
    @inline(never)
    static func validate(owner:CheckpointedMechanismSleep,authority:SleepTopologySourceAuthority,retired:[UInt64],
                         constraints:QuadraticConstraintSystem,velocity:ConstraintCoordinateLayout,work:inout NumericalWork) throws(SleepTopologyFailureReason) -> [Double] {
        let release=authority.release,p=release.target.tree.layout.positionCount,n=release.target.tree.layout.velocityCount,old=owner.constraints
        guard n <= release.target.policy.kinematicCapacity.maximumVelocities,
              p <= work.budget.scalarStorage,retired.count <= old.rows.count,!retired.isEmpty,
              constraints.rows.count == old.rows.count-retired.count,!constraints.rows.isEmpty,
              constraints.layout.coordinateIDs.count == p,velocity.coordinateIDs.count == n,
              constraints.layout.revision == release.target.stamp.revision,velocity.revision == release.target.stamp.revision,
              constraints.layout.timeScale.bitPattern == old.layout.timeScale.bitPattern,velocity.timeScale.bitPattern == old.layout.timeScale.bitPattern,
              constraints.minimumPosition.count == p,constraints.maximumPosition.count == p,
              constraints.minimumTime.bitPattern == old.minimumTime.bitPattern,constraints.maximumTime.bitPattern == old.maximumTime.bitPattern,
              let connector=release.target.tree.layout.joints.first(where:{$0.joint == release.connector}),
              connector.positions.count == 7,connector.velocities.count == 6,
              release.mappings.count == owner.model.tree.layout.joints.count-1 else { throw .invalidDisposition }
        let square:Int,storage:Int
        do throws(NumericalError) { square=try NumericalWork.product(p,p);storage=try NumericalWork.sum(try NumericalWork.product(4,p),n);try work.requireStorage(storage) }
        catch { throw .numerical(error) }
        try charge(try sum(p,n),&work)
        guard Set(retired).count == retired.count,Set(constraints.layout.coordinateIDs).count == p,Set(velocity.coordinateIDs).count == n,
              constraints.layout.scales.allSatisfy({$0.isFinite && $0 > 0}),velocity.scales.allSatisfy({$0.isFinite && $0 > 0}),
              constraints.minimumPosition.allSatisfy({$0.isFinite}),constraints.maximumPosition.allSatisfy({$0.isFinite}) else { throw .invalidDisposition }
        for i in 0..<p { guard constraints.minimumPosition[i] <= release.incomingPhysical.q[i],release.incomingPhysical.q[i] <= constraints.maximumPosition[i] else { throw .invalidDisposition } }
        for i in 0..<7 { guard constraints.layout.dimensions[connector.positions.start+i] == (i < 3 ? .length : .dimensionless) else { throw .invalidDisposition } }
        for i in 0..<6 { guard velocity.dimensions[connector.velocities.start+i] == (i < 3 ? .length : .angle) else { throw .invalidDisposition } }
        var mapping=[Int](repeating:-1,count:old.layout.scales.count),drive=[Double](repeating:0,count:n)
        for item in release.mappings {
            try charge(16,&work)
            guard item.source.positions.count == 1,item.target.positions.count == 1,item.source.velocities.count == 1,item.target.velocities.count == 1,
                  owner.model.tree.layout.joints.contains(item.source),release.target.tree.layout.joints.contains(item.target),item.source.joint == item.target.joint,
                  mapping[item.source.positions.start] == -1 else { throw .invalidDisposition }
            let i=item.source.positions.start,j=item.target.positions.start,k=item.target.velocities.start
            guard old.layout.coordinateIDs[i] == constraints.layout.coordinateIDs[j],old.layout.coordinateIDs[i] == velocity.coordinateIDs[k],
                  old.layout.scales[i].bitPattern == constraints.layout.scales[j].bitPattern,old.layout.scales[i].bitPattern == velocity.scales[k].bitPattern,
                  old.layout.dimensions[i] == constraints.layout.dimensions[j],old.layout.dimensions[i] == velocity.dimensions[k],
                  old.minimumPosition[i].bitPattern == constraints.minimumPosition[j].bitPattern,old.maximumPosition[i].bitPattern == constraints.maximumPosition[j].bitPattern else { throw .invalidDisposition }
            mapping[i]=j;drive[k]=authority.history.drive[item.source.velocities.start]
        }
        for i in mapping.indices { guard (i == authority.cut) == (mapping[i] == -1) else { throw .invalidDisposition } }
        for row in old.rows {
            try charge(1,&work)
            guard (row.linear[authority.cut] != 0) == retired.contains(row.id) else { throw .invalidDisposition }
            if retired.contains(row.id) { continue }
            guard let target=constraints.rows.first(where:{$0.id == row.id}),target.linear.count == p,target.hessian.count == square,target.mixedTime.count == p,
                  target.constant.bitPattern == row.constant.bitPattern,target.timeLinear.bitPattern == row.timeLinear.bitPattern,
                  target.timeQuadratic.bitPattern == row.timeQuadratic.bitPattern,target.hessian.allSatisfy({$0 == 0}),target.mixedTime.allSatisfy({$0 == 0}) else { throw .invalidDisposition }
            var expected=[Double](repeating:0,count:p)
            for i in mapping.indices where mapping[i] >= 0 { try charge(1,&work);expected[mapping[i]]=row.linear[i] }
            guard same(expected,target.linear) else { throw .invalidDisposition }
        }
        guard Set(constraints.rows.map({ $0.id })).count == constraints.rows.count else { throw .invalidDisposition }
        return drive
    }
}
