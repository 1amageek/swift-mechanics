internal enum ConstrainedImpactSourceBinding {
    @inline(never)
    static func validate(_ value: RigidDynamicsSystem, input: RigidDynamicsInput,
                         work: inout NumericalWork) throws(ConstrainedImpactError) {
        let a = input.snapshot, b = value.input.snapshot, n = input.velocity.count
        guard value.velocityCount == n, value.massMatrix.count == (try ConstrainedImpactArithmetic.product(n,n)),
              b.bodies.count == a.bodies.count, b.frames.count == a.frames.count, b.joints.count == a.joints.count,
              b.tree.bodies.count == a.tree.bodies.count, b.tree.joints.count == a.tree.joints.count,
              value.input.velocity.count == n, value.input.inertias.count == input.inertias.count else {
            throw ConstrainedImpactError(.sourceMismatch)
        }
        let count = try ConstrainedImpactArithmetic.sum(try ConstrainedImpactArithmetic.product(64,a.bodies.count),
            try ConstrainedImpactArithmetic.sum(try ConstrainedImpactArithmetic.product(64,a.frames.count),
                try ConstrainedImpactArithmetic.sum(try ConstrainedImpactArithmetic.product(128,a.joints.count),
                    try ConstrainedImpactArithmetic.product(8,try ConstrainedImpactArithmetic.product(n,a.bodies.count)))))
        try ConstrainedImpactArithmetic.charge(count,&work)
        guard a.time.bitPattern == b.time.bitPattern, a.tree.revision == b.tree.revision,
              a.tree.worldFrame == b.tree.worldFrame, a.tree.rootBase == b.tree.rootBase,
              a.tree.layout == b.tree.layout, a.tree.bodies == b.tree.bodies, a.tree.joints == b.tree.joints,
              a.bodies == b.bodies, a.frames == b.frames, a.joints == b.joints, a.coordinateRate == b.coordinateRate,
              input.velocity == value.input.velocity, input.inertias == value.input.inertias,
              value.input.bodyWrenches.isEmpty, value.input.generalizedForces.isEmpty else { throw ConstrainedImpactError(.sourceMismatch) }
        guard case .none = value.input.gravity else { throw ConstrainedImpactError(.sourceMismatch) }
        for body in a.bodies {
            do {
                guard try a.geometricColumns(body:body.body) == b.geometricColumns(body:body.body) else {
                    throw ConstrainedImpactError(.sourceMismatch)
                }
            } catch let error as ConstrainedImpactError { throw error }
            catch { throw ConstrainedImpactError(.sourceMismatch) }
        }
    }
}
