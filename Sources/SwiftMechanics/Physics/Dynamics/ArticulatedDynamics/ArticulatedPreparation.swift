internal enum ArticulatedPreparation {
    @inline(never)
    static func make(_ input: RigidDynamicsInput, rhs: [Double], operation: ArticulatedDynamicsOperation,
                     policy: ArticulatedDynamicsPolicy, loadWork: inout LoadWork,
                     work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> ArticulatedWorkspace {
        let tree = input.snapshot.tree, bodies = tree.bodies.count, n = tree.layout.velocityCount, limits = policy.admission.capacity
        try ArticulatedArithmetic.check(policy)
        guard bodies <= limits.maximumBodies, n <= limits.maximumVelocities,
              input.bodyWrenches.count <= limits.maximumBodyWrenches,
              input.generalizedForces.count <= limits.maximumGeneralizedContributions else { throw ArticulatedDynamicsFailure(.capacityExceeded) }
        try ArticulatedArithmetic.charge(bodies,&work)
        // FIXME(INCOMPLETE_IMPLEMENTATION): This spatial scalar-joint recursion has no planar,
        // floating-root, multi-DOF or V0 implementation. These public query domains fail until
        // their original tangent/inertia elimination and independent physical evidence exist.
        guard n > 0, tree.rootBase == .fixed, tree.bodies.allSatisfy({$0.dimension == .spatial}),
              tree.layout.positionCount == n else { throw ArticulatedDynamicsFailure(.unsupportedDomain) }
        guard bodies > 0, tree.joints.count == bodies-1, input.snapshot.bodies.count == bodies,
              input.snapshot.joints.count == tree.joints.count, tree.layout.joints.count == tree.joints.count,
              input.inertias.count == bodies, input.velocity.count == n, rhs.count == n,
              policy.coordinateScales.count == n else { throw ArticulatedDynamicsFailure(.invalidShape) }
        let storage = try ArticulatedArithmetic.sum(try ArticulatedArithmetic.product(110,bodies),
            try ArticulatedArithmetic.sum(try ArticulatedArithmetic.product(8,n),256))
        try ArticulatedArithmetic.storage(storage,&work)
        try ArticulatedArithmetic.charge(try ArticulatedArithmetic.product(4,n),&work)
        guard rhs.allSatisfy({$0.isFinite}), input.velocity.allSatisfy({$0.isFinite}) else { throw ArticulatedDynamicsFailure(.invalidInput) }
        if let gravity = input.gravity {
            guard gravity.frame == tree.worldFrame else { throw ArticulatedDynamicsFailure(.frameMismatch) }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Nonuniform gravity requires distributed second-
            // moment torque/potential. The current COM load path refuses it until those original
            // physical contributions and independent recursion evidence are implemented.
            guard gravity.gradient == .zero else { throw ArticulatedDynamicsFailure(.unsupportedDomain) }
        }
        var workspace = ArticulatedWorkspace(bodies:bodies,velocities:n)
        workspace.generalizedEffort = rhs
        var nextCoordinate = 0
        for i in tree.bodies.indices {
            // Conservative bounded charge covers the fixed-size source/frame/vector work;
            // articulated matrix arithmetic is charged separately at its actual loop boundary.
            try ArticulatedArithmetic.check(policy); try ArticulatedArithmetic.charge(1024,&work)
            let body = input.snapshot.bodies[i], inertia = input.inertias[i]
            guard inertia.body == tree.bodies[i].id, body.body == inertia.body,
                  inertia.frame == tree.bodies[i].frame, body.bodyFrame == inertia.frame,
                  body.worldFrame == tree.worldFrame else { throw ArticulatedDynamicsFailure(.sourceMismatch) }
            let properties = inertia.properties
            let rotation = try ArticulatedArithmetic.core { () throws(CoreError) in try body.motion.pose.rotation.matrix() }
            let offset = try ArticulatedArithmetic.core { () throws(CoreError) in try rotation.applying(to:properties.centerOfMass) }
            let tensor = try ArticulatedArithmetic.core { () throws(CoreError) in try rotation.multiplied(by:properties.inertiaAtCenter).multiplied(by:rotation.transposed()) }
            let matrix = try ArticulatedMatrix6.inertia(mass:properties.mass,offset:offset,tensor:tensor,work:&work)
            for entry in 0..<36 { workspace.inertia[i*36+entry] = matrix[entry] }
            if i == 0 {
                guard try ArticulatedArithmetic.close(body.motion.velocity.angular,.zero,tolerance:policy.admission.angularVelocityTolerance),
                      try ArticulatedArithmetic.close(body.motion.velocity.linear,.zero,tolerance:policy.admission.linearVelocityTolerance) else {
                    throw ArticulatedDynamicsFailure(.velocityMismatch)
                }
            } else {
                let joint = tree.joints[i-1], layout = tree.layout.joints[i-1], frames = input.snapshot.joints[i-1]
                let parentIndex: Int
                do { parentIndex = try tree.bodyIndex(joint.parentBody) } catch { throw ArticulatedDynamicsFailure(.joints(error)) }
                guard parentIndex < i, joint.childBody == body.body, layout.joint == joint.id, frames.joint == joint.id,
                      frames.parentAnchor.frame == joint.parentAnchor.frame, frames.childAnchor.frame == joint.childAnchor.frame,
                      frames.parentAnchor.referenceFrame == tree.worldFrame, frames.childAnchor.referenceFrame == tree.worldFrame,
                      layout.velocities.start == nextCoordinate, layout.positions.start == nextCoordinate else {
                    throw ArticulatedDynamicsFailure(.invalidTopology)
                }
                workspace.parents[i] = parentIndex
                // FIXME(INCOMPLETE_IMPLEMENTATION): Prescribed anchors and multi-axis joints
                // do not enter this scalar ABA path. Their moving-transform and block pivot
                // contracts must be implemented and independently checked before success.
                for anchor in [joint.parentAnchor,joint.childAnchor] {
                    if case .prescribed = anchor.placement { throw ArticulatedDynamicsFailure(.unsupportedDomain) }
                }
                switch joint.manifold.kind {
                case .fixed: guard layout.velocities.count == 0 else { throw ArticulatedDynamicsFailure(.invalidShape) }
                case .revolute, .prismatic, .screw:
                    guard layout.velocities.count == 1 else { throw ArticulatedDynamicsFailure(.invalidShape) }
                default: throw ArticulatedDynamicsFailure(.unsupportedDomain)
                }
                guard layout.positions.count == layout.velocities.count, frames.relative.subspace.columns.count == layout.velocities.count else {
                    throw ArticulatedDynamicsFailure(.invalidShape)
                }
                nextCoordinate = layout.velocities.end
                let parent = input.snapshot.bodies[parentIndex]
                let displacement = try ArticulatedArithmetic.core { () throws(CoreError) in try body.motion.pose.translation.subtracting(parent.motion.pose.translation) }
                let transform = ArticulatedMatrix6.transport(offset:displacement)
                for entry in 0..<36 { workspace.transport[i*36+entry] = transform[entry] }
                var subspace = SpatialMotion(angular:.zero,linear:.zero)
                if layout.velocities.count == 1 {
                    workspace.coordinates[i] = layout.velocities.start
                    let local = frames.relative.subspace.columns[0]
                    subspace = try ArticulatedArithmetic.core { () throws(CoreError) in
                        let angular = try frames.parentAnchor.motion.pose.rotation.rotating(local.angular)
                        let childOffset = try body.motion.pose.translation.subtracting(frames.childAnchor.motion.pose.translation)
                        let linear = try frames.parentAnchor.motion.pose.rotation.rotating(local.linear).adding(angular.cross(childOffset))
                        return SpatialMotion(angular:angular,linear:linear)
                    }
                }
                let columns = ArticulatedArithmetic.vector(subspace)
                for row in 0..<6 { workspace.subspace[i*6+row] = columns[row] }
                let parentVelocity = parent.motion.velocity
                let speed = layout.velocities.count == 1 ? input.velocity[layout.velocities.start] : 0
                let velocity = try ArticulatedArithmetic.core { () throws(CoreError) in
                    SpatialMotion(angular:try parentVelocity.angular.adding(subspace.angular.scaled(by:speed)),
                        linear:try parentVelocity.linear.adding(parentVelocity.angular.cross(displacement)).adding(subspace.linear.scaled(by:speed)))
                }
                guard try ArticulatedArithmetic.close(velocity.angular,body.motion.velocity.angular,tolerance:policy.admission.angularVelocityTolerance),
                      try ArticulatedArithmetic.close(velocity.linear,body.motion.velocity.linear,tolerance:policy.admission.linearVelocityTolerance) else {
                    throw ArticulatedDynamicsFailure(.velocityMismatch)
                }
                if case .forward = operation {
                    let bias = try ArticulatedArithmetic.core { () throws(CoreError) in
                        SpatialMotion(angular:try body.accelerationBias.angular.subtracting(parent.accelerationBias.angular),
                            linear:try body.accelerationBias.linear.subtracting(parent.accelerationBias.linear.adding(parent.accelerationBias.angular.cross(displacement))))
                    }
                    let values = ArticulatedArithmetic.vector(bias)
                    for row in 0..<6 { workspace.bias[i*6+row] = values[row] }
                }
            }
            if case .forward = operation {
                let velocityWrench = try ArticulatedArithmetic.core { () throws(CoreError) in
                    let omega = body.motion.velocity.angular
                    let force = try omega.cross(omega.cross(offset)).scaled(by:properties.mass)
                    let torque = try omega.cross(tensor.applying(to:omega)).adding(offset.cross(force))
                    return SpatialWrench(torque:torque,force:force)
                }
                let values = ArticulatedArithmetic.vector(velocityWrench)
                for row in 0..<6 { workspace.forceBias[i*6+row] = values[row] }
                if let field = input.gravity {
                    let com = try ArticulatedArithmetic.core { () throws(CoreError) in try body.motion.pose.translation.adding(offset) }
                    let gravity: GravityResponse
                    do { gravity = try GravityEvaluator().point(field,body:body.body,sample:GravitySample(point:com,mass:properties.mass),work:&loadWork) }
                    catch { throw ArticulatedDynamicsFailure(.loads(error)) }
                    try ArticulatedArithmetic.charge(20,&work)
                    let wrench = try ArticulatedArithmetic.core { () throws(CoreError) in SpatialWrench(torque:try offset.cross(gravity.load.forces.conservative),force:gravity.load.forces.conservative) }
                    try subtract(wrench,bodyIndex:i,workspace:&workspace,work:&work)
                }
            }
        }
        guard nextCoordinate == n else { throw ArticulatedDynamicsFailure(.invalidShape) }
        try loads(input,operation:operation,workspace:&workspace,policy:policy,work:&work)
        return workspace
    }
    private static func subtract(_ wrench: SpatialWrench, bodyIndex: Int, workspace: inout ArticulatedWorkspace,
                                 work: inout NumericalWork) throws(ArticulatedDynamicsFailure) {
        let values = ArticulatedArithmetic.vector(wrench)
        for row in 0..<6 { try ArticulatedArithmetic.charge(1,&work); workspace.forceBias[bodyIndex*6+row] = try ArticulatedArithmetic.finite(workspace.forceBias[bodyIndex*6+row]-values[row]) }
    }
    private static func loads(_ input: RigidDynamicsInput, operation: ArticulatedDynamicsOperation,
                              workspace: inout ArticulatedWorkspace, policy: ArticulatedDynamicsPolicy,
                              work: inout NumericalWork) throws(ArticulatedDynamicsFailure) {
        for load in input.bodyWrenches {
            try ArticulatedArithmetic.check(policy); try ArticulatedArithmetic.charge(256,&work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): Known reaction-channel loads do not certify
            // constrained/contact articulated motion. This query refuses those channels until
            // an original constrained authority supplies compatible recursive equations.
            if load.channel == .constraint || load.channel == .contact { throw ArticulatedDynamicsFailure(.unsupportedDomain) }
            let index: Int
            do { index = try input.snapshot.tree.bodyIndex(load.body) } catch { throw ArticulatedDynamicsFailure(.joints(error)) }
            let body = input.snapshot.bodies[index], wrench: SpatialWrench
            if load.frame == body.worldFrame {
                wrench = try ArticulatedArithmetic.core { () throws(CoreError) in
                    SpatialWrench(torque:try load.wrench.torque.adding(load.referencePoint.subtracting(body.motion.pose.translation).cross(load.wrench.force)),force:load.wrench.force)
                }
            } else if load.frame == body.bodyFrame {
                wrench = try ArticulatedArithmetic.core { () throws(CoreError) in
                    let force = try body.motion.pose.rotation.rotating(load.wrench.force)
                    let offset = try body.motion.pose.rotation.rotating(load.referencePoint)
                    return SpatialWrench(torque:try body.motion.pose.rotation.rotating(load.wrench.torque).adding(offset.cross(force)),force:force)
                }
            } else { throw ArticulatedDynamicsFailure(.frameMismatch) }
            if case .forward = operation { try subtract(wrench,bodyIndex:index,workspace:&workspace,work:&work) }
        }
        for load in input.generalizedForces {
            try ArticulatedArithmetic.check(policy)
            // FIXME(INCOMPLETE_IMPLEMENTATION): Generalized reaction labels cannot admit a
            // constrained/contact topology; this query requires an original compatible physical
            // authority before any such load can participate in recursive success.
            if load.channel == .constraint || load.channel == .contact { throw ArticulatedDynamicsFailure(.unsupportedDomain) }
            guard load.values.count == workspace.generalizedEffort.count else { throw ArticulatedDynamicsFailure(.invalidShape) }
            for i in load.values.indices {
                try ArticulatedArithmetic.charge(2,&work)
                guard load.values[i].isFinite else { throw ArticulatedDynamicsFailure(.invalidInput) }
                if case .forward = operation { workspace.generalizedEffort[i] = try ArticulatedArithmetic.finite(workspace.generalizedEffort[i]+load.values[i]) }
            }
        }
    }
}
