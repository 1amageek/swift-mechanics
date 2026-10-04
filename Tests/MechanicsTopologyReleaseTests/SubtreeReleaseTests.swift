import SwiftMechanics
import Testing

@Suite struct SubtreeReleaseTests {
    private func near(_ a:Vector3,_ b:Vector3) throws { #expect(try a.subtracting(b).magnitude() < 1e-7) }
    /// Independent COM-based sum, without the dynamics kernel or generalized coordinates.
    private func conserved(_ model:CompiledMechanicalModel,_ snapshot:KinematicSnapshot) throws -> (Double,Vector3,Vector3) {
        var energy=0.0,linear=Vector3.zero,angular=Vector3.zero
        for body in snapshot.bodies {
            let record=try #require(model.descriptor.bodies.first(where: { $0.id == body.body }))
            guard case .spatial(let spatial)=record else { throw TopologyReleaseFailure.unsupportedDomain }
            let properties=try #require(spatial.inertia).properties,m=body.motion
            let r=try m.pose.rotation.rotating(properties.centerOfMass)
            let position=try m.pose.translation.adding(r)
            let velocity=try m.velocity.linear.adding(m.velocity.angular.cross(r))
            let momentum=try velocity.scaled(by:properties.mass)
            let spinBody=try properties.inertiaAtCenter.applying(to:m.pose.rotation.conjugated().rotating(m.velocity.angular))
            let spin=try m.pose.rotation.rotating(spinBody)
            linear=try linear.adding(momentum);angular=try angular.adding(spin.adding(position.cross(momentum)))
            energy += try 0.5*(properties.mass*velocity.dot(velocity)+m.velocity.angular.dot(spin))
        }
        return (energy,linear,angular)
    }
    @Test func movingDeepParentAndAnchorsPreserveEveryBodyAndInternalJoint() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),rule=try TopologyFixtures.catalog(model).rules[0]
        let release=try TopologyFixtures.release(model,rule:rule)
        #expect(release.releasedBodies == [try TopologyFixtures.id(.body,"B"),try TopologyFixtures.id(.body,"C")])
        let connector=try #require(release.target.descriptor.joints.first(where: { $0.record.id == rule.connector }))
        #expect(connector.record.parentBody == model.descriptor.root)
        let target=try release.target.evaluate(release.target.makeState(release.incomingPhysical))
        for before in release.sourceSnapshot.bodies {
            let after=try target.body(before.body)
            try near(before.motion.pose.translation,after.motion.pose.translation)
            try near(before.motion.pose.rotation.rotationVector(),after.motion.pose.rotation.rotationVector())
            try near(before.motion.velocity.linear,after.motion.velocity.linear)
            try near(before.motion.velocity.angular,after.motion.velocity.angular)
            try near(before.motion.acceleration.linear,after.motion.acceleration.linear)
            try near(before.motion.acceleration.angular,after.motion.acceleration.angular)
        }
        for mapping in release.mappings {
            #expect(model.descriptor.joints.first(where: { $0.record.id == mapping.joint }) == release.target.descriptor.joints.first(where: { $0.record.id == mapping.joint }))
            for i in 0..<mapping.source.positions.count { #expect(release.source.state.q[mapping.source.positions.start+i].bitPattern == release.incomingPhysical.q[mapping.target.positions.start+i].bitPattern) }
            for i in 0..<mapping.source.velocities.count { #expect(release.source.state.v[mapping.source.velocities.start+i].bitPattern == release.incomingPhysical.v[mapping.target.velocities.start+i].bitPattern) }
        }
        let a=try conserved(model,release.sourceSnapshot),b=try conserved(release.target,target)
        #expect(abs(a.0-b.0) < 1e-7);try near(a.1,b.1);try near(a.2,b.2)
        #expect(abs(a.0-release.sourceEnergy.kineticEnergy) < 1e-7)
        try near(a.1,release.sourceEnergy.linearMomentum);try near(a.2,release.sourceEnergy.angularMomentum)
    }
    @Test func floatingRootRawPrefixSurvivesAndPostCutForceIsActuallyResolved() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(floating:true),rule=try TopologyFixtures.catalog(model).rules[0]
        let release=try TopologyFixtures.release(model,rule:rule)
        #expect(release.target.descriptor.rootBase == .spatialFloating)
        #expect(release.target.descriptor.rootAuthority == model.descriptor.rootAuthority)
        #expect(release.incomingPhysical.q.prefix(7).map(\.bitPattern) == model.descriptor.initialState.q.prefix(7).map(\.bitPattern))
        #expect(release.incomingPhysical.v.prefix(6).map(\.bitPattern) == model.descriptor.initialState.v.prefix(6).map(\.bitPattern))
        #expect(release.incomingPhysical.acceleration.prefix(6).map(\.bitPattern) == model.descriptor.initialState.acceleration.prefix(6).map(\.bitPattern))
        let target=try release.target.evaluate(release.target.makeState(release.incomingPhysical))
        for body in release.sourceSnapshot.bodies {
            let after=try target.body(body.body);try near(body.motion.pose.translation,after.motion.pose.translation)
            try near(body.motion.velocity.linear,after.motion.velocity.linear);try near(body.motion.velocity.angular,after.motion.velocity.angular)
        }
        let prepared=try TopologyFixtures.reconcile(release),system=prepared.system,n=system.velocityCount
        #expect(prepared.physical.acceleration != release.incomingPhysical.acceleration)
        for row in 0..<n {
            var inertial=system.inertialBias[row]
            for column in 0..<n { inertial += system.massMatrix[row*n+column]*prepared.physical.acceleration[column] }
            #expect(abs(inertial-(try system.forces.total(at:row))-prepared.drive[row]) < 1e-7)
        }
    }
    @Test func cancelledCutProducesNoAdmittedValue() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),rule=try TopologyFixtures.catalog(model).rules[0]
        var w=try TopologyFixtures.work(),d=try TopologyFixtures.work()
        #expect(throws:TopologyReleaseFailure.self) {
            try ReferenceSubtreeReleaseBuilder().release(model:model,state:model.makeState(model.descriptor.initialState),joint:rule.joint,
                connector:rule.connector,parentAnchor:rule.parentAnchor,childAnchor:rule.childAnchor,policy:TopologyFixtures.policy(cancelled:true),
                admission:TopologyFixtures.admission(),work:&w,dynamicsWork:&d)
        }
    }
    @Test func resettingRequiredSolverReportsUnknownCostAndPublishesNothing() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { return }
        let model=try TopologyFixtures.model(),(session,history,_)=try TopologyFixtures.session(model)
        let initial=session.snapshot(),release=try TopologyFixtures.release(model,rule:history.catalog.rules[0])
        var w=try TopologyFixtures.work(),l=LoadWork(budget:try LoadBudget(maximumWork:100000,maximumScalars:100000))
        let admission=try TopologyFixtures.admission(),policy=try TopologyFixtures.dynamics(release.target.tree.layout.velocityCount)
        do throws(TopologyReleaseFailure) {
            _=try ReferenceSubtreeAccelerationPreparer(solver:ResettingTopologySolver()).prepare(release,gravity:nil,bodyWrenches:[],generalizedForces:[],
                drive:[Double](repeating:0,count:release.target.tree.layout.velocityCount),admission:admission,
                policy:policy,work:&w,loadWork:&l)
            Issue.record("Reset ledger admitted a target acceleration.")
        } catch { #expect(error.failedSupplierWorkUnavailable) }
        #expect(w.operations > 0)
        #expect(session.snapshot() == initial)
        do throws(TopologyReleaseFailure) {
            _=try ReferenceSubtreeAccelerationPreparer(solver:ResettingTopologySolver(reset:false)).prepare(release,gravity:nil,bodyWrenches:[],generalizedForces:[],
                drive:[Double](repeating:0,count:release.target.tree.layout.velocityCount),admission:admission,policy:policy,work:&w,loadWork:&l)
            Issue.record("A supplier changed the declared original drive.")
        } catch { if case .originalAcceptance = error {} else { Issue.record("Wrong-drive rejection lost the original-acceptance failure.") } }
        #expect(session.snapshot() == initial)
    }
}
