public struct TreeReactionRecovery: TreeReactionRecovering {
    private let equations: any RigidEquationComputing
    private let gravity: any GravityEvaluating
    public init(equations: any RigidEquationComputing = RigidEquationKernel(),
                gravity: any GravityEvaluating = GravityEvaluator()) {
        self.equations = equations; self.gravity = gravity
    }

    public func recover(_ system: RigidDynamicsSystem, acceleration: [Double], topology: TreeReactionTopology,
                        outputFrame: EntityID, policy: TreeReactionPolicy,
                        loadWork: inout LoadWork, work: inout NumericalWork) throws(ReactionPathError) -> TreeReactionReport {
        try check(policy)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Unrepresented loops, mesh paths and multiple-bearing splits have no physical allocation contract. This public recovery path must fail until their identified loads and independent equilibrium evidence exist.
        guard topology == .completeTree else { throw .unrepresentedConnections }
        let input = system.input, snapshot = input.snapshot, tree = snapshot.tree
        let count = snapshot.bodies.count, n = system.velocityCount
        guard count <= policy.maximumBodies, tree.joints.count <= policy.maximumJoints,
              input.bodyWrenches.count <= policy.maximumBodyLoads else { throw .capacityExceeded }
        guard acceleration.count == n, policy.generalizedForceScales.count == n else { throw .invalidShape }
        guard acceleration.allSatisfy({ $0.isFinite }) else { throw .invalidInput }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Nonzero generalized loads do not identify a unique per-body six-axis load. The current original body-balance path refuses them until a physically identified allocation is supplied as body wrenches.
        guard input.generalizedForces.allSatisfy({ $0.values.allSatisfy({ $0 == 0 }) }) else { throw .nonuniqueGeneralizedAllocation }
        let outputPose: RigidTransform
        do { outputPose = try snapshot.frame(outputFrame).motion.pose } catch { throw .joints(error) }
        try numerical { () throws(NumericalError) in
            let bodyStorage = try NumericalWork.product(64, count)
            let edgeStorage = try NumericalWork.product(32, tree.joints.count)
            let coordinateStorage = try NumericalWork.product(8, n)
            let local = try NumericalWork.sum(128, NumericalWork.sum(bodyStorage, NumericalWork.sum(edgeStorage, coordinateStorage)))
            try work.requireStorage(NumericalWork.sum(system.scalarStorage, local))
        }
        let zero = SpatialWrench(torque: .zero, force: .zero)
        var net = [SpatialWrench](repeating: zero, count: count)
        var parent = [Int](repeating: -1, count: count)
        var generalized = [Double](repeating: 0, count: n)
        var generalizedMagnitude = [Double](repeating: 0, count: n)
        for joint in tree.joints {
            try charge(2, &work); try check(policy)
            let child = try bodyIndex(tree, joint.childBody), ancestor = try bodyIndex(tree, joint.parentBody)
            guard child > ancestor, parent[child] == -1 else { throw .invalidSupplierEvidence }
            parent[child] = ancestor
        }
        for i in 0..<count {
            try check(policy); try charge(128, &work)
            let state = snapshot.bodies[i], point = state.motion.pose.translation
            let before = work
            let evidence: BodyWrenchEvidence
            do { evidence = try equations.inertialWrench(system, body: state.body, acceleration: acceleration,
                                                        referencePointWorld: point, work: &work) }
            catch {
                try validateLedger(before, &work)
                throw .dynamics(error)
            }
            try validateLedger(before, &work)
            guard evidence.body == state.body, evidence.frame == tree.worldFrame,
                  evidence.referencePoint == point else { throw .invalidSupplierEvidence }
            net[i] = try shifted(evidence.wrench, from: point, to: .zero)
            if let field = input.gravity {
                let com = try core { () throws(CoreError) in try state.motion.pose.transforming(point: input.inertias[i].properties.centerOfMass) }
                // Record callback admission in caller-owned state before handing a positive prefix
                // to the supplier. It remains known even if the supplier resets its local ledger.
                do { try loadWork.charge(1) } catch { throw .loads(error) }
                let beforeLoad = loadWork
                var supplierLoadWork = loadWork
                let response: GravityResponse
                do { response = try gravity.point(field, body: state.body,
                    sample: GravitySample(point: com, mass: input.inertias[i].properties.mass), work: &supplierLoadWork) }
                catch {
                    try mergeLoadLedger(beforeLoad, supplier: supplierLoadWork, into: &loadWork)
                    throw .loads(error)
                }
                try mergeLoadLedger(beforeLoad, supplier: supplierLoadWork, into: &loadWork)
                guard response.load.body == state.body, response.load.frame == tree.worldFrame,
                      response.load.point == com else { throw .invalidSupplierEvidence }
                let weight: SpatialWrench
                do { weight = try response.load.wrench(about: .zero) } catch { throw .loads(error) }
                net[i] = try subtract(net[i], weight)
            }
        }
        for load in input.bodyWrenches {
            try check(policy); try charge(128, &work)
            let i = try bodyIndex(tree, load.body), state = snapshot.bodies[i]
            let wrench: SpatialWrench, point: Vector3
            if load.frame == tree.worldFrame { wrench = load.wrench; point = load.referencePoint }
            else if load.frame == state.bodyFrame {
                wrench = try core { () throws(CoreError) in
                    SpatialWrench(torque: try state.motion.pose.rotation.rotating(load.wrench.torque),
                                  force: try state.motion.pose.rotation.rotating(load.wrench.force))
                }
                point = try core { () throws(CoreError) in try state.motion.pose.transforming(point: load.referencePoint) }
            } else { throw .invalidSupplierEvidence }
            net[i] = try subtract(net[i], shifted(wrench, from: point, to: .zero))
        }
        // The original virtual-work residual is recomputed from original per-body Newton/Euler products.
        // It is independent of the assembled mass matrix and cannot be hidden in an arbitrary joint wrench.
        for i in 0..<count {
            try check(policy); try charge(64, &work)
            let bodyNet = try shifted(net[i], from: .zero, to: snapshot.bodies[i].motion.pose.translation)
            let columns: ArraySlice<SpatialMotion>
            do { columns = try snapshot.geometricColumns(body: snapshot.bodies[i].body) } catch { throw .joints(error) }
            for (k, column) in columns.enumerated() {
                try check(policy); try charge(32, &work)
                let value = try core { () throws(CoreError) in try bodyNet.power(against: column) }
                let sum = generalized[k] + value, magnitude = generalizedMagnitude[k] + abs(value)
                guard sum.isFinite, magnitude.isFinite else { throw .invalidInput }
                generalized[k] = sum; generalizedMagnitude[k] = magnitude
            }
        }
        var maximum = 0.0
        for k in 0..<n {
            try check(policy); try charge(4, &work)
            let value = generalized[k] / policy.generalizedForceScales[k]
            let magnitude = generalizedMagnitude[k] / policy.generalizedForceScales[k]
            guard try core({ () throws(CoreError) in try policy.generalizedTolerance.contains(error: value, scale: magnitude) }) else {
                throw .originalGeneralizedResidual(index: k, scaledValue: value)
            }
            maximum = max(maximum, abs(value))
        }
        var subtree = net
        if count > 1 {
            for i in stride(from: count - 1, through: 1, by: -1) {
                try check(policy); try charge(12, &work)
                guard parent[i] >= 0 else { throw .invalidSupplierEvidence }
                subtree[parent[i]] = try add(subtree[parent[i]], subtree[i])
            }
        }
        var balance = subtree
        for i in 1..<count { try check(policy); try charge(12, &work); balance[parent[i]] = try subtract(balance[parent[i]], subtree[i]) }
        for i in 0..<count {
            try check(policy); try charge(24, &work)
            guard try agrees(balance[i].force, net[i].force, policy.forceTolerance),
                  try agrees(balance[i].torque, net[i].torque, policy.torqueTolerance) else {
                throw .originalBodyBalance(body: snapshot.bodies[i].body)
            }
        }
        var results: [JointReactionWrench] = []
        results.reserveCapacity(tree.joints.count)
        for joint in tree.joints {
            try check(policy); try charge(384, &work)
            let index = try bodyIndex(tree, joint.childBody)
            let anchor: FrameKinematics
            do { anchor = try snapshot.frame(joint.childAnchor.frame) } catch { throw .joints(error) }
            let point = anchor.motion.pose.translation
            let wrench = try converted(subtree[index], referenceWorld: point, outputPose: outputPose)
            let pointInFrame = try core { () throws(CoreError) in try outputPose.inverted().transforming(point: point) }
            results.append(JointReactionWrench(joint: joint.id, parentBody: joint.parentBody, childBody: joint.childBody,
                frame: outputFrame, referencePoint: pointInFrame, referencePointWorld: point,
                parentOnChild: wrench, childOnParent: try negated(wrench), timeSeconds: snapshot.time, revision: tree.revision))
        }
        let support: RootSupportWrench?
        try charge(384, &work)
        if tree.rootBase == .fixed {
            let point = snapshot.bodies[0].motion.pose.translation
            let wrench = try converted(subtree[0], referenceWorld: point, outputPose: outputPose)
            support = RootSupportWrench(rootBody: snapshot.bodies[0].body, frame: outputFrame,
                referencePoint: try core { () throws(CoreError) in try outputPose.inverted().transforming(point: point) },
                referencePointWorld: point, supportOnRoot: wrench, rootOnSupport: try negated(wrench),
                timeSeconds: snapshot.time, revision: tree.revision)
        } else {
            guard try agrees(subtree[0].force, .zero, policy.forceTolerance),
                  try agrees(subtree[0].torque, .zero, policy.torqueTolerance) else { throw .originalBodyBalance(body: snapshot.bodies[0].body) }
            support = nil
        }
        try check(policy)
        return TreeReactionReport(joints: results, support: support, maximumScaledOriginalGeneralizedResidual: maximum,
                                  numericalWork: work, loadWork: loadWork, topologyAssumption: topology)
    }

    private func converted(_ worldOrigin: SpatialWrench, referenceWorld: Vector3, outputPose: RigidTransform) throws(ReactionPathError) -> SpatialWrench {
        let value = try shifted(worldOrigin, from: .zero, to: referenceWorld)
        return try core { () throws(CoreError) in
            let inverse = outputPose.rotation.conjugated()
            return SpatialWrench(torque: try inverse.rotating(value.torque), force: try inverse.rotating(value.force))
        }
    }
    private func shifted(_ value: SpatialWrench, from: Vector3, to: Vector3) throws(ReactionPathError) -> SpatialWrench {
        try core { () throws(CoreError) in SpatialWrench(torque: try value.torque.adding(from.subtracting(to).cross(value.force)), force: value.force) }
    }
    private func add(_ a: SpatialWrench, _ b: SpatialWrench) throws(ReactionPathError) -> SpatialWrench {
        try core { () throws(CoreError) in SpatialWrench(torque: try a.torque.adding(b.torque), force: try a.force.adding(b.force)) }
    }
    private func subtract(_ a: SpatialWrench, _ b: SpatialWrench) throws(ReactionPathError) -> SpatialWrench {
        try core { () throws(CoreError) in SpatialWrench(torque: try a.torque.subtracting(b.torque), force: try a.force.subtracting(b.force)) }
    }
    private func negated(_ value: SpatialWrench) throws(ReactionPathError) -> SpatialWrench {
        try core { () throws(CoreError) in SpatialWrench(torque: try value.torque.scaled(by: -1), force: try value.force.scaled(by: -1)) }
    }
    private func agrees(_ a: Vector3, _ b: Vector3, _ tolerance: NumericalTolerance) throws(ReactionPathError) -> Bool {
        try core { () throws(CoreError) in
            let x = try tolerance.contains(error: a.x - b.x, scale: max(abs(a.x), abs(b.x)))
            let y = try tolerance.contains(error: a.y - b.y, scale: max(abs(a.y), abs(b.y)))
            let z = try tolerance.contains(error: a.z - b.z, scale: max(abs(a.z), abs(b.z)))
            return x && y && z
        }
    }
    private func validateLedger(_ before: NumericalWork, _ after: inout NumericalWork) throws(ReactionPathError) {
        guard before.budget == after.budget, after.operations >= before.operations,
              after.iterations >= before.iterations, after.peakScalarStorage >= before.peakScalarStorage else {
            after = before; throw .supplierLedgerReplaced
        }
    }
    private func mergeLoadLedger(_ before: LoadWork, supplier: LoadWork, into output: inout LoadWork) throws(ReactionPathError) {
        guard before.budget.maximumWork == supplier.budget.maximumWork, before.budget.maximumScalars == supplier.budget.maximumScalars,
              supplier.consumed >= before.consumed, supplier.peakScalars >= before.peakScalars else {
            throw .supplierLedgerReplaced
        }
        // Preserve the caller's cancellation closure even if a supplier replaces a budget with equal limits.
        do { try output.charge(supplier.consumed - before.consumed); try output.reserve(scalars: supplier.peakScalars) }
        catch { throw .loads(error) }
    }
    private func bodyIndex(_ tree: KinematicTree, _ body: EntityID) throws(ReactionPathError) -> Int {
        do { return try tree.bodyIndex(body) } catch { throw .joints(error) }
    }
    private func check(_ policy: TreeReactionPolicy) throws(ReactionPathError) {
        guard !policy.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
    private func charge(_ count: Int, _ work: inout NumericalWork) throws(ReactionPathError) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    private func numerical<T>(_ body: () throws(NumericalError) -> T) throws(ReactionPathError) -> T {
        do { return try body() } catch { throw .numerical(error) }
    }
    private func core<T>(_ body: () throws(CoreError) -> T) throws(ReactionPathError) -> T {
        do { return try body() } catch { throw .core(error) }
    }
}
