internal struct FrictionalImpulseSource: Sendable {
    let input: FrictionalImpulseInput
    let snapshot: KinematicSnapshot
    let first: PointJacobian
    let second: PointJacobian
    let firstLocal: Vector3
    let secondLocal: Vector3
    let rows: [Double]
    let before: [Double]
    let drift: [Double]
    let reserved: Int

    @inline(never)
    static func prepare(_ input: FrictionalImpulseInput, policy: FrictionalImpulsePolicy,
                        work: inout NumericalWork) throws(FrictionalImpulseFailure) -> Self {
        let a=FrictionalImpulseArithmetic.self, h=policy.hybrid, n=input.tree.layout.velocityCount, b=input.tree.bodies.count
        try a.check(policy)
        let maximumPositions=try a.product(7,b), maximumAnchors=try a.product(2,b)
        guard n <= h.maximumVelocities, n == h.impulseScales.count, n == policy.mass.coordinateScales.count,
              b <= h.maximumBodies, input.inertias.count == b, input.collision.proxies.count <= h.maximumColliders,
              input.state.q.count == input.tree.layout.positionCount, input.state.v.count == n,
              input.state.acceleration.count == n, input.state.q.count <= maximumPositions,
              input.state.prescribedAnchors.count <= maximumAnchors else { throw FrictionalImpulseFailure(.capacityExceeded) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar or zero-velocity source requests reach this entry point.
        // A planar tangent law or immobile impact policy needs original physical acceptance before success.
        guard n > 0, input.tree.bodies.allSatisfy({$0.dimension == .spatial}) else { throw FrictionalImpulseFailure(.unsupportedDomain) }
        guard input.state.revision == input.tree.revision, input.expectedCollisionRevision == input.collision.revision,
              input.basis.frame.id == input.tree.worldFrame, input.basis.frame.revision == input.tree.revision else {
            throw FrictionalImpulseFailure(.staleSource)
        }
        let c=input.contact, proxies=input.collision.proxies
        guard proxies.indices.contains(c.firstProxyIndex), proxies.indices.contains(c.secondProxyIndex),
              c.firstProxyIndex != c.secondProxyIndex else { throw FrictionalImpulseFailure(.invalidInput) }
        let firstProxy=proxies[c.firstProxyIndex], secondProxy=proxies[c.secondProxyIndex], witness=c.witness
        for body in input.tree.bodies {
            guard body.id.key.utf8.count <= h.maximumIdentifierBytes, body.frame.key.utf8.count <= h.maximumIdentifierBytes else { throw FrictionalImpulseFailure(.capacityExceeded) }
        }
        guard input.tree.worldFrame.key.utf8.count <= h.maximumIdentifierBytes else { throw FrictionalImpulseFailure(.capacityExceeded) }
        for joint in input.tree.joints {
            for id in [joint.id,joint.parentAnchor.frame,joint.childAnchor.frame] {
                guard id.key.utf8.count <= h.maximumIdentifierBytes else { throw FrictionalImpulseFailure(.capacityExceeded) }
            }
        }
        for anchor in input.state.prescribedAnchors {
            guard anchor.frame.key.utf8.count <= h.maximumIdentifierBytes else { throw FrictionalImpulseFailure(.capacityExceeded) }
        }
        for proxy in [firstProxy,secondProxy] {
            for id in [proxy.geometry.bodyID,proxy.geometry.colliderID,proxy.geometry.frameID] {
                guard id.key.utf8.count <= h.maximumIdentifierBytes else { throw FrictionalImpulseFailure(.capacityExceeded) }
            }
            guard proxy.geometry.frameID == input.tree.worldFrame, proxy.geometry.frameRevision == input.tree.revision else { throw FrictionalImpulseFailure(.frameMismatch) }
        }
        guard firstProxy.geometry.bodyID != secondProxy.geometry.bodyID,
              witness.pair.first == firstProxy.geometry, witness.pair.second == secondProxy.geometry,
              firstProxy.filter.enabled, secondProxy.filter.enabled, !firstProxy.filter.isTrigger, !secondProxy.filter.isTrigger,
              firstProxy.filter.layerBits & secondProxy.filter.maskBits != 0,
              secondProxy.filter.layerBits & firstProxy.filter.maskBits != 0 else { throw FrictionalImpulseFailure(.invalidWitness) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Approximate, degenerate or nonanalytic witnesses are callable here.
        // Their impact geometry/law uncertainty must be implemented and physically accepted before success.
        guard witness.degeneracy == .regular, witness.approximationError == 0,
              firstProxy.geometry.approximationError == 0, secondProxy.geometry.approximationError == 0,
              firstProxy.geometry.resolution == .analytic, secondProxy.geometry.resolution == .analytic else { throw FrictionalImpulseFailure(.unsupportedDomain) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Continuous elastic friction/cohesion/rolling selections reach this hard-law input.
        // A published conversion/history-dependent impulse law is required before those selections can succeed.
        guard case .separateImpact=c.law.lossPolicy, c.law.parameters.friction == .none,
              c.law.parameters.cohesion == .none, c.law.parameters.resistance.rollingCoefficient == 0,
              c.law.parameters.resistance.spinningCoefficient == 0 else { throw FrictionalImpulseFailure(.unsupportedDomain) }
        // Both snapshots, dense physical sources, point arrays and all jump scratch coexist at acceptance.
        let bn=try a.product(b,n), nn=try a.product(n,n)
        let reserved=try a.sum(try a.product(24,bn),try a.sum(try a.product(4,nn),try a.sum(try a.product(1024,b),try a.sum(try a.product(64,n),256))))
        try a.storage(reserved,&work)
        // Original evaluator owns no numerical ledger. Charge its bounded tree/subspace traversal before calling it.
        try a.charge(a.sum(try a.product(8192,b),try a.product(1024,bn)),&work)
        let snapshot=try a.source { try TreeKinematicsEvaluator().evaluate(input.tree,state:input.state,policy:policy.joints) }
        try a.check(policy)
        for body in snapshot.bodies {
            let columns=try a.source { try snapshot.geometricColumns(body:body.body) }
            let hasMotion=columns.contains { $0.angular != .zero || $0.linear != .zero }
            if hasMotion {
                let angular=try a.core { () throws(CoreError) in try body.prescribedDriftVelocity.angular.magnitude() }
                let linear=try a.core { () throws(CoreError) in try body.prescribedDriftVelocity.linear.magnitude() }
                // FIXME(INCOMPLETE_IMPLEMENTATION): Moving dynamic charts reach this body admission.
                // General boundary momentum transfer must be implemented before nonzero dynamic drift succeeds.
                guard angular <= policy.admission.angularVelocityTolerance.absolute,
                      linear <= policy.admission.linearVelocityTolerance.absolute else { throw FrictionalImpulseFailure(.unsupportedDomain) }
            }
        }
        try a.charge(a.sum(1024,try a.product(512,n)),&work)
        let firstBody=try a.source { try snapshot.body(firstProxy.geometry.bodyID) }, secondBody=try a.source { try snapshot.body(secondProxy.geometry.bodyID) }
        guard abs(witness.separation) <= h.lengthTolerance,
              witness.originalBalanceResidual.isFinite, witness.originalBalanceResidual >= 0,
              witness.originalBalanceResidual <= h.lengthTolerance,
              try a.core({ () throws(CoreError) in try witness.pointB.subtracting(witness.pointA).subtracting(witness.normal.scaled(by:witness.separation)).magnitude() }) <= h.lengthTolerance,
              try a.core({ () throws(CoreError) in try witness.normal.subtracting(input.basis.normal).magnitude() }) <= h.normalTolerance,
              try a.samePose(witness.poseA,firstProxy.pose,policy:h), try a.samePose(witness.poseB,secondProxy.pose,policy:h),
              try a.samePose(a.core { () throws(CoreError) in try firstBody.motion.pose.composed(with:c.firstColliderToBody) },firstProxy.pose,policy:h),
              try a.samePose(a.core { () throws(CoreError) in try secondBody.motion.pose.composed(with:c.secondColliderToBody) },secondProxy.pose,policy:h) else { throw FrictionalImpulseFailure(.stalePose) }
        let firstLocal=try a.core { () throws(CoreError) in try firstBody.motion.pose.inverted().transforming(point:witness.pointA) }
        let secondLocal=try a.core { () throws(CoreError) in try secondBody.motion.pose.inverted().transforming(point:witness.pointB) }
        let calculator=KinematicJacobianCalculator()
        let first=try a.source { try calculator.point(body:firstBody.body,bodyLocalPoint:firstLocal,snapshot:snapshot) }
        let second=try a.source { try calculator.point(body:secondBody.body,bodyLocalPoint:secondLocal,snapshot:snapshot) }
        let firstMotion=try a.source { try calculator.pointMotion(body:first.body,bodyLocalPoint:firstLocal,snapshot:snapshot) }
        let secondMotion=try a.source { try calculator.pointMotion(body:second.body,bodyLocalPoint:secondLocal,snapshot:snapshot) }
        guard first.columns.count == n, second.columns.count == n else { throw FrictionalImpulseFailure(.invalidShape) }
        guard try a.core({ () throws(CoreError) in try firstMotion.position.subtracting(witness.pointA).magnitude() }) <= h.lengthTolerance,
              try a.core({ () throws(CoreError) in try secondMotion.position.subtracting(witness.pointB).magnitude() }) <= h.lengthTolerance else { throw FrictionalImpulseFailure(.stalePose) }
        var rows=[Double](repeating:0,count:try a.product(3,n))
        for i in 0..<n {
            let column=try a.components(a.core { () throws(CoreError) in try second.columns[i].subtracting(first.columns[i]) },basis:input.basis)
            for j in 0..<3 { rows[j*n+i]=column[j] }
        }
        let before=try a.components(a.core { () throws(CoreError) in try secondMotion.velocity.subtracting(firstMotion.velocity) },basis:input.basis)
        let drift=try a.components(a.core { () throws(CoreError) in try second.prescribedDriftVelocity.subtracting(first.prescribedDriftVelocity) },basis:input.basis)
        for row in 0..<3 {
            var expected=drift[row]
            for i in 0..<n { expected=try a.finite(expected+rows[row*n+i]*input.state.v[i]) }
            guard abs(try a.finite(expected-before[row])) <= h.speedTolerance else { throw FrictionalImpulseFailure(.velocityRejected(value:abs(expected-before[row]),threshold:h.speedTolerance)) }
        }
        return Self(input:input,snapshot:snapshot,first:first,second:second,firstLocal:firstLocal,secondLocal:secondLocal,rows:rows,before:before,drift:drift,reserved:reserved)
    }

    @inline(never)
    func assemble(snapshot: KinematicSnapshot, velocity: [Double], policy: FrictionalImpulsePolicy,
                  loadWork: inout LoadWork, work: inout NumericalWork) throws(FrictionalImpulseFailure) -> PhysicalRigidDynamicsSystem {
        try FrictionalImpulseArithmetic.check(policy)
        do throws(DynamicsError) {
            let source=try RigidDynamicsInput(snapshot:snapshot,velocity:velocity,inertias:input.inertias,gravity:nil)
            return try RigidEquationKernel().assemble(PhysicalRigidDynamicsInput(spatial:source),admission:policy.admission,loadWork:&loadWork,work:&work)
        } catch { throw FrictionalImpulseFailure(.dynamics(error),failedSupplierWorkUnavailable:error.failedSupplierWorkUnavailable) }
    }
}
