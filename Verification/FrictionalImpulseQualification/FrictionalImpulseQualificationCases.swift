import SwiftMechanics

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct FrictionalImpulseQualificationCases: FrictionalImpulseQualifying {
    private typealias F = FrictionalImpulseQualificationFixtures
    public init() {}
    public func run(_ selected: FrictionalImpulseQualificationCase) throws {
        switch selected {
        case .sticking: try sticking()
        case .sliding: try sliding()
        case .lawsAndScaling: try lawsAndScaling()
        case .prescribedWall: try prescribedWall()
        case .refusals: try refusals()
        case .resourcesAndCancellation: try resourcesAndCancellation()
        }
    }
    public func solve(_ input: FrictionalImpulseInput, policy: FrictionalImpulsePolicy) throws -> FrictionalImpulseResult {
        var work = try F.numerical(), loads = try F.loads(), contacts = try F.contacts()
        let solver: any FrictionalImpulseSolving = ReferenceFrictionalImpulseSolver()
        return try solver.solve(input, policy: policy, work: &work, loadWork: &loads, contactWork: &contacts)
    }
    private func state(_ r: FrictionalImpulseResult, expected: [Double]) throws {
        try F.require(r.stateAfter.v.count == expected.count, "Actual original velocity layout")
        for i in expected.indices { try F.near(r.stateAfter.v[i], expected[i], "Literal post velocity " + String(i)) }
        try F.require(r.stateAfter.q == r.input.state.q && r.stateAfter.time == r.input.state.time &&
            r.stateAfter.revision == r.input.state.revision && r.stateAfter.prescribedAnchors == r.input.state.prescribedAnchors,
            "Original position/time/revision/prescribed anchor retention")
        try F.require(r.stateAfter.acceleration.allSatisfy { $0 == 0 }, "Explicit instantaneous-jump acceleration reset")
        let ball = try r.snapshotAfter.body(F.id(.body, "ball"))
        try F.vector(ball.motion.pose.translation, 0, 0, 1, "Actual post snapshot original position")
        try F.vector(ball.motion.velocity.linear, expected[0], expected[1], expected[2], "Actual reconstructed linear motion")
        try F.vector(ball.motion.velocity.angular, expected[3], expected[4], expected[5], "Actual reconstructed angular motion")
        try F.require(r.firstImpulse.body == r.input.collision.proxies[0].geometry.bodyID &&
            r.secondImpulse.body == r.input.collision.proxies[1].geometry.bodyID && r.firstImpulse.frame == r.input.tree.worldFrame &&
            r.secondImpulse.frame == r.input.tree.worldFrame && r.input.contact.eventID == 41, "Original impulse body/frame/event authority")
        try F.vector(r.firstImpulse.point, 0, 0, 0, "Original first contact point")
        try F.vector(r.secondImpulse.point, 0, 0, 0, "Original second contact point")
        try F.vector(r.firstImpulse.impulse.adding(r.secondImpulse.impulse), 0, 0, 0, "Original physical action/reaction")
        let orbital = try Vector3(0, 0, 1).cross(r.secondImpulse.impulse)
        try F.vector(r.secondOriginImpulse.torque.adding(orbital), 0, 0, 0, "Original world-origin angular impulse balance")
        try F.vector(r.firstOriginImpulse.torque, 0, 0, 0, "Original plane-origin angular impulse")
        try F.require(r.diagnostics.momentumResidual <= 1e-8 && r.diagnostics.velocityResidual <= 1e-8 &&
            r.diagnostics.coulombResidual <= 1e-8 && r.diagnostics.workResidual <= 1e-8 && r.diagnostics.energyResidual <= 1e-8,
            "Original physical/law acceptance residuals")
    }
    private func energy(_ r: FrictionalImpulseResult, before: Double, after: Double, normal: Double, tangent: Double,
                        generalized: Double, contact: Double, wall: Double = 0) throws {
        try F.near(r.energyBefore.kineticEnergy, before, "Independent original kinetic energy")
        try F.near(r.energyAfter.kineticEnergy, after, "Independent post kinetic energy")
        try F.near(r.diagnostics.normalLossJoules, normal, "Independent normal restitution loss")
        try F.near(r.diagnostics.tangentLossJoules, tangent, "Independent tangent maximum-dissipation loss")
        try F.near(r.diagnostics.generalizedImpulseWorkJoules, generalized, "Independent generalized midpoint impulse work")
        try F.near(r.diagnostics.contactImpulseWorkJoules, contact, "Independent contact impulse work")
        try F.near(r.diagnostics.prescribedWallWorkJoules, wall, "Independent prescribed boundary work")
        try F.near(after - before + normal + tangent - wall, 0, "Independent kinetic/loss/wall energy identity")
    }
    private func isotropic(_ r: FrictionalImpulseResult) throws {
        let expected = [0.5, 0, 0, 0, 1.5, 0, 0, 0, 1.5]
        try F.require(r.diagnostics.delassus.count == 9, "Original full Delassus matrix")
        for i in expected.indices { try F.near(r.diagnostics.delassus[i], expected[i], "Independent inverse mass entry") }
    }
    private func sticking() throws {
        let r = try solve(F.input(), policy: F.policy())
        try F.require(r.regime == .sticking, "Strict interior Coulomb regime")
        try isotropic(r); try F.vector(r.impulse, 6, -4.0/3, 0, "Independent sticking impulse components")
        try F.vector(r.relativeVelocityBefore, -2, 2, 0, "Original pre point velocity")
        try F.vector(r.relativeVelocityAfter, 1, 0, 0, "Actual zero post tangent speed")
        try F.vector(r.secondImpulse.impulse, -4.0/3, 0, 6, "Original world sphere impulse Ns")
        try F.vector(r.secondOriginImpulse.torque, 0, 4.0/3, 0, "Independent body-origin angular impulse Nms")
        try F.near(r.diagnostics.tangentMultiplier, 0, "Sticking multiplier")
        try state(r, expected: [4.0/3, 0, 1, 0, 4.0/3, 0])
        try energy(r, before: 8, after: 11.0/3, normal: 3, tangent: 4.0/3, generalized: -13.0/3, contact: -13.0/3)
    }
    private func sliding() throws {
        let r = try solve(F.input(), policy: F.policy(mu: 1.0/6))
        try F.require(r.regime == .sliding, "Coulomb disc boundary regime")
        try isotropic(r); try F.vector(r.impulse, 6, -1, 0, "Independent sliding impulse")
        try F.vector(r.relativeVelocityAfter, 1, 0.5, 0, "Original post tangent speed")
        try F.near(r.diagnostics.tangentMultiplier, 0.5, "Independent KKT multiplier")
        try state(r, expected: [1.5, 0, 1, 0, 1, 0])
        try energy(r, before: 8, after: 15.0/4, normal: 3, tangent: 5.0/4, generalized: -17.0/4, contact: -17.0/4)
        let anisotropic = try solve(F.input(vx: 53.0/35, vy: 10.0/7, ix: 2, iy: 1, ixy: 0.5, iz: 2), policy: F.policy(mu: 1.0/6))
        try F.require(anisotropic.regime == .sliding, "Non-diagonal anisotropic tangent SPD regime")
        let w = [0.5, 0, 0, 0, 23.0/14, 2.0/7, 0, 2.0/7, 15.0/14]
        for i in w.indices { try F.near(anisotropic.diagnostics.delassus[i], w[i], "Original anisotropic inverse inertia") }
        try F.vector(anisotropic.impulse, 6, -3.0/5, -4.0/5, "Manufactured independent anisotropic impulse")
        try F.vector(anisotropic.relativeVelocityAfter, 1, 3.0/10, 2.0/5, "Independent returned-row velocity")
        try F.near(anisotropic.diagnostics.tangentMultiplier, 0.5, "Independent anisotropic shift")
        try F.vector(anisotropic.secondOriginImpulse.torque, -4.0/5, 3.0/5, 0, "Original anisotropic angular impulse")
        try state(anisotropic, expected: [17.0/14, 36.0/35, 1, -22.0/35, 32.0/35, 0])
        try energy(anisotropic, before: 10209.0/1225, after: 3977.0/980, normal: 3, tangent: 893.0/700,
            generalized: -2993.0/700, contact: -2993.0/700)
    }
    private func lawsAndScaling() throws {
        for (e, threshold, effective) in [(0.0, 0.0, 0.0), (1.0, 0.0, 1.0), (1.0, 3.0, 0.0), (1.0, 2.0, 1.0)] {
            let r = try solve(F.input(e: e, threshold: threshold), policy: F.policy(mu: 0))
            try F.require(r.regime == .frictionless, "Explicit frictionless coefficient")
            try F.vector(r.impulse, 4*(1+effective), 0, 0, "Threshold restitution impulse")
            try F.vector(r.relativeVelocityAfter, 2*effective, 2, 0, "Actual threshold rebound")
            try state(r, expected: [2, 0, 2*effective, 0, 0, 0])
            let loss = 4*(1-effective*effective)
            try energy(r, before: 8, after: 4+4*effective*effective, normal: loss, tangent: 0, generalized: -loss, contact: -loss)
        }
        let zero = try solve(F.input(vx: 0), policy: F.policy())
        try F.require(zero.regime == .sticking, "Zero tangent strictly interior")
        try F.vector(zero.impulse, 6, 0, 0, "Zero tangent impulse")
        try energy(zero, before: 4, after: 1, normal: 3, tangent: 0, generalized: -3, contact: -3)
        let rotated = try solve(F.input(basisRotation: UnitQuaternion(axis: .unitZ, angle: .pi/2)), policy: F.policy())
        try F.vector(rotated.impulse, 6, 0, 4.0/3, "Explicit rotated tangent basis components")
        try F.vector(rotated.secondImpulse.impulse, -4.0/3, 0, 6, "Basis-independent physical impulse")
        try state(rotated, expected: [4.0/3, 0, 1, 0, 4.0/3, 0])
        let scaled = try solve(F.input(), policy: F.policy(mu: 1.0/6, massScale: 2, velocityScale: 3))
        try F.vector(scaled.impulse, 6, -1, 0, "Physical SI impulse unchanged by declared normalization")
        try F.near(scaled.diagnostics.tangentMultiplier, 1, "Declared dimensionless scaled multiplier")
        try state(scaled, expected: [1.5, 0, 1, 0, 1, 0])
        try energy(scaled, before: 8, after: 15.0/4, normal: 3, tangent: 5.0/4, generalized: -17.0/4, contact: -17.0/4)
    }
    private func prescribedWall() throws {
        let r = try solve(F.input(wallSpeed: 1), policy: F.policy())
        try F.require(r.regime == .sticking, "Independent prescribed-wall sticking")
        try F.vector(r.impulse, 6, -2.0/3, 0, "Actual relative incoming wall impulse")
        try F.vector(r.relativeVelocityBefore, -2, 1, 0, "Original prescribed drift included")
        try F.vector(r.relativeVelocityAfter, 1, 0, 0, "Original wall-relative post velocity")
        try state(r, expected: [5.0/3, 0, 1, 0, 2.0/3, 0])
        try F.vector(r.snapshotAfter.body(F.id(.body, "wall")).motion.velocity.linear, 1, 0, 0, "Prescribed wall retained")
        try energy(r, before: 17.0/2, after: 9.0/2, normal: 3, tangent: 1.0/3, generalized: -4, contact: -10.0/3, wall: -2.0/3)
    }
    private func refused(_ input: FrictionalImpulseInput, policy: FrictionalImpulsePolicy,
                         matches: (FrictionalImpulseCause) -> Bool) throws {
        do { _ = try solve(input, policy: policy) }
        catch let error as FrictionalImpulseFailure {
            try F.require(matches(error.cause), "Unexpected original refusal: " + String(describing: error.cause)); return
        }
        throw FrictionalImpulseQualificationError.assertion("Expected typed original refusal")
    }
    private func replacing(_ input: FrictionalImpulseInput, collisionRevision: UInt64? = nil, basis: ContactBasis? = nil,
                           contact: ImpulseContactBinding? = nil) -> FrictionalImpulseInput {
        FrictionalImpulseInput(tree: input.tree, state: input.state, inertias: input.inertias, collision: input.collision,
            expectedCollisionRevision: collisionRevision ?? input.expectedCollisionRevision, contact: contact ?? input.contact, basis: basis ?? input.basis)
    }
    private func refusals() throws {
        try refused(F.input(vz: 1), policy: F.policy()) { if case .nonapproaching = $0 { return true }; return false }
        try refused(F.input(), policy: F.policy(mu: 2.0/9)) { if case .ambiguousBoundary = $0 { return true }; return false }
        try refused(F.input(comX: 0.2), policy: F.policy()) { if case .coupledNormalTangent = $0 { return true }; return false }
        try refused(F.input(normalOnly: true), policy: F.policy(coordinates: 1)) { if case .singularTangent = $0 { return true }; return false }
        try refused(F.input(compliant: true), policy: F.policy()) { if case .unsupportedDomain = $0 { return true }; return false }
        let input = try F.input()
        try refused(replacing(input, collisionRevision: 8), policy: F.policy()) { if case .staleSource = $0 { return true }; return false }
        let wrongBasis = try ContactBasis(frame: ModelReference(id: F.id(.frame, "other"), revision: 7), contactToQuery: .identity)
        try refused(replacing(input, basis: wrongBasis), policy: F.policy()) { if case .staleSource = $0 { return true }; return false }
        let rotatedNormal = try ContactBasis(frame: input.basis.frame, contactToQuery: UnitQuaternion(axis: .unitX, angle: .pi/2))
        try refused(replacing(input, basis: rotatedNormal), policy: F.policy()) { if case .stalePose = $0 { return true }; return false }
        let wrongContact = ImpulseContactBinding(eventID: 41, witness: input.contact.witness, firstProxyIndex: 0, secondProxyIndex: 1,
            firstColliderToBody: .identity, secondColliderToBody: RigidTransform(rotation: .identity, translation: try Vector3(1, 0, 0)), law: input.contact.law)
        try refused(replacing(input, contact: wrongContact), policy: F.policy()) { if case .stalePose = $0 { return true }; return false }
        try refused(input, policy: F.policy(coordinates: 5)) { if case .capacityExceeded = $0 { return true }; return false }
        try refused(input, policy: F.policy(bodies: 1)) { if case .capacityExceeded = $0 { return true }; return false }
        try refused(input, policy: F.policy(identifiers: 1)) { if case .capacityExceeded = $0 { return true }; return false }
        try refused(input, policy: F.policy(mu: 1e-12, bracket: 1)) { if case .nonconvergence = $0 { return true }; return false }
        try refused(input, policy: F.policy(mu: 1.0/6, bisection: 1)) { if case .nonconvergence = $0 { return true }; return false }
        do { _ = try F.policy(mu: -1) }
        catch let error as FrictionalImpulseFailure { try F.require({ if case .invalidInput = error.cause { return true }; return false }(), "Negative coefficient policy") ; return }
        throw FrictionalImpulseQualificationError.assertion("Negative friction coefficient must fail")
    }
    private func resourcesAndCancellation() throws {
        let input = try F.input(), solver: any FrictionalImpulseSolving = ReferenceFrictionalImpulseSolver()
        var loads = try F.loads(), contacts = try F.contacts(), storage = try F.numerical(storage: 3119)
        do { _ = try solver.solve(input, policy: F.policy(), work: &storage, loadWork: &loads, contactWork: &contacts); throw FrictionalImpulseQualificationError.assertion("Expected typed storage refusal") }
        catch let error as FrictionalImpulseFailure {
            try F.require({ if case .numerical(.resourceLimit(resource: .scalarStorage, limit: 3119)) = error.cause { return true }; return false }(), "Independent initial source storage refusal")
        }
        try F.require(storage.operations == 0 && storage.peakScalarStorage == 0, "Storage refusal preserves zero prefix")
        var operations = try F.numerical(operations: 28671)
        do { _ = try solver.solve(input, policy: F.policy(), work: &operations, loadWork: &loads, contactWork: &contacts); throw FrictionalImpulseQualificationError.assertion("Expected typed operations refusal") }
        catch let error as FrictionalImpulseFailure {
            try F.require({ if case .numerical(.resourceLimit(resource: .arithmeticOperations, limit: 28671)) = error.cause { return true }; return false }(), "Independent conservative original tree work refusal")
        }
        try F.require(operations.operations == 0 && operations.peakScalarStorage == 3120, "Refused operation charge retains earlier accepted reserve")
        var contact = try F.contacts(operations: 0), numerical = try F.numerical()
        do { _ = try solver.solve(input, policy: F.policy(), work: &numerical, loadWork: &loads, contactWork: &contact); throw FrictionalImpulseQualificationError.assertion("Expected typed contact supplier refusal") }
        catch let error as FrictionalImpulseFailure {
            try F.require({ if case .contact(.resourceLimit(resource: .operations, limit: 0)) = error.cause { return true }; return false }(), "Actual restitution supplier budget refusal")
        }
        try F.require(numerical.operations > 32768 && contact.operations == 0, "Known original mass work retained without invented contact work")
        let counter = FrictionalImpulseCancellationCounter()
        let measured = try solve(input, policy: F.policy(cancelled: { counter.check() }))
        let late = FrictionalImpulseCancellationCounter(cancelAt: counter.count)
        var lateWork = try F.numerical(), lateLoads = try F.loads(), lateContacts = try F.contacts()
        do { _ = try solver.solve(input, policy: F.policy(cancelled: { late.check() }), work: &lateWork, loadWork: &lateLoads, contactWork: &lateContacts); throw FrictionalImpulseQualificationError.assertion("Expected typed late cancellation refusal") }
        catch let error as FrictionalImpulseFailure {
            try F.require({ if case .cancelled = error.cause { return true }; return false }(), "Actual late cancellation")
        }
        try F.require(late.count == counter.count && lateWork.operations == measured.diagnostics.numericalWork.operations &&
            lateWork.peakScalarStorage == measured.diagnostics.numericalWork.peakScalarStorage, "Late cancel before publication retains full known physical acceptance work")
        var early = try F.numerical()
        do { _ = try solver.solve(input, policy: F.policy(cancelled: { true }), work: &early, loadWork: &loads, contactWork: &contacts); throw FrictionalImpulseQualificationError.assertion("Expected typed early cancellation refusal") }
        catch let error as FrictionalImpulseFailure {
            try F.require({ if case .cancelled = error.cause { return true }; return false }(), "Early policy cancellation")
        }
        try F.require(early.operations == 0 && early.peakScalarStorage == 0, "Early cancellation consumes no numerical work")
    }
    public func actualTaskCancellation(_ input: FrictionalImpulseInput) throws {
        let solver: any FrictionalImpulseSolving = ReferenceFrictionalImpulseSolver()
        var work = try F.numerical(), loads = try F.loads(), contact = try F.contacts()
        do { _ = try solver.solve(input, policy: F.policy(), work: &work, loadWork: &loads, contactWork: &contact) }
        catch let error as FrictionalImpulseFailure {
            try F.require({ if case .cancelled = error.cause { return true }; return false }(), "Actual Task cancellation")
            try F.require(work.operations == 0 && work.peakScalarStorage == 0, "Task cancellation zero known numerical prefix"); return
        }
        throw FrictionalImpulseQualificationError.assertion("Cancelled Task must refuse")
    }
}
