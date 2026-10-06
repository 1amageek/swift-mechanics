import Testing
import SwiftMechanics

@Suite internal struct IslandPhysicalTests {
    @Test func genuineCompilerPartitionAndMixedRest() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(drive:[2,2,4])
        #expect(program.islands.count == 2)
        let gear=try #require(program.islands.first(where:{$0.coordinateIDs == [10,20]}))
        let striker=try #require(program.islands.first(where:{$0.coordinateIDs == [30]}))
        #expect(gear.retainedRowIDs == [7]);#expect(striker.constraints == nil)
        for island in program.islands {
            for local in island.model.tree.layout.joints {
                let original=try #require(program.source.tree.layout.joints.first(where:{$0.joint == local.joint}))
                #expect(island.sourceCoordinateIndices[local.velocities.start] == original.velocities.start)
            }
            for body in island.model.descriptor.bodies { #expect(program.source.descriptor.bodies.contains(body)) }
        }
        var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics()
        let rest=try #require(solver.certifyRest(program:program,islandID:gear.id,physical:program.source.descriptor.initialState,thresholds:IslandFixtures.thresholds(),work:&work))
        #expect(rest.kineticEnergy == 0);#expect(rest.normalizedVelocity == 0)
        let motion=try solver.motion(program:program,islandID:gear.id,physical:program.source.descriptor.initialState,work:&work)
        #expect(motion.system.massMatrix == [2,0,0,2]);#expect(motion.acceleration == [0,0])
        #expect(motion.generalizedReaction == [-2,-2]);#expect(motion.constrained?.temporalMeaning == .accelerationForce)
        let free=try solver.motion(program:program,islandID:striker.id,physical:program.source.descriptor.initialState,work:&work)
        #expect(free.system.massMatrix == [2]);#expect(free.acceleration.count == 1 && abs(free.acceleration[0]-2) <= program.policy.mechanics.originalTolerance);#expect(free.kineticEnergy == 1)
        #expect(free.constrained == nil);#expect(work.loads.consumed > 0);#expect(work.numerical.operations > 0)
    }
    @Test func awakeOriginalForceAndWholeOracle() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(drive:[2,-2,4]);let state=try KinematicState(revision:1,time:0.5,q:[0.1,-0.1,0.25],v:[0.5,-0.5,-1],acceleration:[1,-1,2])
        var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics()
        let gear=try #require(program.islands.first(where:{$0.coordinateIDs == [10,20]}))
        let actual=try solver.motion(program:program,islandID:gear.id,physical:state,work:&work)
        #expect(actual.acceleration.count == 2 && abs(actual.acceleration[0]-1) <= program.policy.mechanics.originalTolerance && abs(actual.acceleration[1]+1) <= program.policy.mechanics.originalTolerance);#expect(actual.generalizedReaction == [0,0]);#expect(actual.kineticEnergy == 0.5)
        #expect(try solver.certifyRest(program:program,islandID:gear.id,physical:state,thresholds:IslandFixtures.thresholds(),work:&work) == nil)
        let snapshot=try program.source.evaluate(program.source.makeState(state))
        var inertias:[RigidBodyInertia]=[]
        for body in program.source.tree.bodies {
            let record=try #require(program.source.descriptor.bodies.first(where:{$0.id == body.id}))
            guard case .spatial(let spatial)=record else { Issue.record("Expected original spatial body");return }
            let inertia=try #require(spatial.inertia)
            inertias.append(try RigidBodyInertia(body:body.id,frame:body.frame,properties:inertia.properties))
        }
        var loads=try IslandFixtures.load(HybridCancellation()),nw=try IslandFixtures.numerical(),dw=try IslandFixtures.numerical(),rw=try IslandFixtures.numerical(),lw=try IslandFixtures.numerical()
        let whole=try RigidEquationKernel().assemble(RigidDynamicsInput(snapshot:snapshot,velocity:state.v,inertias:inertias,gravity:nil),admission:program.policy.admission,loadWork:&loads,work:&nw)
        let evaluation=try QuadraticConstraintEvaluator().evaluate(program.constraints,position:state.q,velocity:state.v,time:state.time,policy:program.policy.mechanics.constraints.evaluation,work:&nw)
        let original=try MassWeightedMechanismSolver().acceleration(whole,sample:VelocityConstraintSample(layout:program.constraints.layout,holonomic:evaluation),drive:program.drive,policy:program.policy.mechanics,work:&nw,dynamicsWork:&dw,rankWork:&rw,linearWork:&lw)
        #expect(original.values.count == 3 && abs(original.values[0]-1) <= program.policy.mechanics.originalTolerance && abs(original.values[1]+1) <= program.policy.mechanics.originalTolerance && abs(original.values[2]-2) <= program.policy.mechanics.originalTolerance);#expect(actual.acceleration == gear.sourceCoordinateIndices.map {original.values[$0]})
        #expect(actual.generalizedReaction == gear.sourceCoordinateIndices.map {original.generalizedReaction[$0]})
    }
    @Test func supplierFreeAssociationAndExactLocalPosition() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program(drive:[2,2,4]);var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics()
        let gear=try #require(program.islands.first(where:{$0.coordinateIDs == [10,20]}))
        let proof=try #require(solver.certifyRest(program:program,islandID:gear.id,physical:program.source.descriptor.initialState,thresholds:IslandFixtures.thresholds(),work:&work))
        let moved=try KinematicState(revision:1,time:1,q:[0,0,-1],v:[0,0,3],acceleration:[0,0,2])
        let prior=work.loads.consumed
        #expect(try solver.associateRest(certificate:proof,program:program,physical:moved,work:&work))
        #expect(work.loads.consumed == prior)
        let shifted=try KinematicState(revision:1,time:1,q:[0.1,-0.1,-1],v:[0,0,3],acceleration:[0,0,2])
        #expect(try solver.associateRest(certificate:proof,program:program,physical:shifted,work:&work) == false)
        let late=try KinematicState(revision:1,time:11,q:[0,0,0],v:[0,0,0],acceleration:[0,0,0])
        #expect(try solver.associateRest(certificate:proof,program:program,physical:late,work:&work) == false)
        let stale=try KinematicState(revision:2,time:1,q:[0,0,0],v:[0,0,0],acceleration:[0,0,0])
        do throws(StationaryIslandFailure) { _=try solver.associateRest(certificate:proof,program:program,physical:stale,work:&work);Issue.record("Stale source admitted") }
        catch { if case .sourceMismatch=error.reason {} else { Issue.record("Wrong stale failure") } }
    }
    @Test(arguments:[0,1,2,3,4]) func canonicalBindingRefusesChangedPhysicalLaw(_ variant:Int) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable.");return }
        let program=try IslandFixtures.program();var work=try IslandFixtures.work();let solver=ReferenceStationaryIslandDynamics()
        let gear=try #require(program.islands.first(where:{$0.coordinateIDs == [10,20]}))
        let proof=try #require(solver.certifyRest(program:program,islandID:gear.id,physical:program.source.descriptor.initialState,thresholds:IslandFixtures.thresholds(),work:&work))
        let other:StationaryIslandProgram
        switch variant {
        case 0:other=try IslandFixtures.program(drive:[1,0,0])
        case 1:other=try IslandFixtures.program(model:IslandFixtures.model(mass:3))
        case 2:other=try IslandFixtures.program(model:IslandFixtures.model(inertia:3))
        case 3:other=try IslandFixtures.program(policy:IslandFixtures.policy(energy:2))
        default:other=try IslandFixtures.program(model:IslandFixtures.model(anchor:4))
        }
        #expect(program.source.stamp == other.source.stamp);#expect(program.binding != other.binding)
        #expect(try solver.associateRest(certificate:proof,program:other,physical:other.source.descriptor.initialState,work:&work) == false)
        let fresh=try IslandFixtures.program()
        #expect(program.binding == fresh.binding)
        #expect(try solver.associateRest(certificate:proof,program:fresh,physical:fresh.source.descriptor.initialState,work:&work))
    }
}
