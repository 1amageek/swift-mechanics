import SwiftMechanics
import Testing

@Suite("Simultaneous constrained gear impacts")
struct ConstrainedImpactPhysicalTests {
    @Test(arguments:[0.0,1.0]) func originalGearMassMomentumLawAndEnergy(_ restitution: Double) throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(restitution:restitution), original = input.physical
        let equations = try ConstrainedImpactFixtures.constraints(input.model), prepared = try ConstrainedImpactFixtures.prepared(input,constraints:equations)
        #expect(prepared.impact.normalRows == [-1,0,1]); #expect(prepared.retainedRows == [1,1,0])
        #expect(prepared.impact.system.massMatrix == [2,0,0,0,2,0,0,0,2])
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        let solver: any ConstrainedNormalImpulseSolving = ReferenceConstrainedNormalImpulseSolver()
        let result = try solver.solve(prepared,work:&work,contactWork:&contact,cancellation:HybridCancellation())
        let p = 4*(1+restitution)/3, expected = [-p/4,p/4,-1+p/2]
        #expect(abs(result.contactImpulse-p) < 1e-9)
        #expect(abs(result.retainedImpulses[0]-p/2) < 1e-9)
        for i in 0..<3 { #expect(abs(result.velocity[i]-expected[i]) < 1e-9) }
        // Independent original generalized momentum balance; no returned residual is used as the oracle.
        for i in 0..<3 {
            let delta = 2*(result.velocity[i]-original.state.v[i])
            let applied = [-p,0,p][i]+[p/2,p/2,0][i]
            #expect(abs(delta-applied) < 1e-9)
            #expect(abs(result.retainedGeneralizedImpulse[i]-[p/2,p/2,0][i]) < 1e-9)
        }
        #expect(abs(result.velocity[0]+result.velocity[1]) < 1e-9)
        #expect(abs(-result.velocity[0]+result.velocity[2]-restitution) < 1e-9)
        let energy = result.velocity.reduce(0) { $0+$1*$1 }
        let lost = 2*(1-restitution*restitution)/3
        #expect(abs(result.effectiveInverseMass-0.75) < 1e-9)
        #expect(abs(result.kineticEnergyBefore-1) < 1e-9); #expect(abs(result.kineticEnergyAfter-energy) < 1e-9)
        #expect(abs(1-energy-lost) < 1e-9); #expect(abs(result.predictedLostEnergy-lost) < 1e-9)
        #expect(result.source === prepared); #expect(result.eventID == 41); #expect(result.time == 0.25)
        #expect(input.physical == original); #expect(result.source.retainedRowIDs == [7])
        #expect(work.operations > 0); #expect(work.iterations > 0); #expect(contact.operations > 0)
    }
    @Test func actualNormalizationRetainsTheSamePhysicalImpact() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), scales = [2.0,3.0,4.0]
        let rows = try ConstrainedImpactFixtures.constraints(input.model,scales:scales,phaseScale:5)
        let prepared = try ConstrainedImpactFixtures.prepared(input,constraints:rows,policy:ConstrainedImpactFixtures.policy(scales:scales))
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        let result = try ReferenceConstrainedNormalImpulseSolver().solve(prepared,work:&work,contactWork:&contact,cancellation:HybridCancellation())
        #expect(abs(result.contactImpulse-8.0/3) < 1e-9)
        #expect(abs(result.retainedImpulses[0]-20.0/3) < 1e-9)
        #expect(abs(result.retainedGeneralizedImpulse[0]-4.0/3) < 1e-9)
        #expect(abs(result.retainedGeneralizedImpulse[1]-4.0/3) < 1e-9)
        #expect(abs(result.velocity[0]+2.0/3) < 1e-9); #expect(abs(result.velocity[2]-1.0/3) < 1e-9)
    }
    @Test func freeImpulseThenProjectionFailsTheOriginalRestitutionOracle() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let input = try ConstrainedImpactFixtures.input(), token = HybridCancellation()
        var work = try ConstrainedImpactFixtures.numerical(), load = try ConstrainedImpactFixtures.load(token), contact = try ConstrainedImpactFixtures.contact()
        let free = try RigidHardImpactAdapter().prepare(input,policy:ConstrainedImpactFixtures.policy().impact,
            admission:ConstrainedImpactFixtures.admission(token),loadWork:&load,work:&work,cancellation:token)
        let solved = try IndependentNormalImpulseSolver().solve(free,policy:ConstrainedImpactFixtures.policy().impact,
            massPolicy:ConstrainedImpactFixtures.policy().dynamics,work:&work,contactWork:&contact,cancellation:token)
        #expect(abs(solved.normalImpulses[0]-2) < 1e-9)
        #expect(abs(solved.velocity[0]+1) < 1e-9); #expect(abs(solved.velocity[2]) < 1e-9)
        // Actual free result followed by the independent exact equal-inertia gear projection.
        let projectedA = (solved.velocity[0]-solved.velocity[1])/2
        let projectedB = -projectedA, striker = solved.velocity[2]
        #expect(abs(-projectedA+striker-0.5) < 1e-9)
        #expect(abs(projectedA*projectedA+projectedB*projectedB+striker*striker-0.5) < 1e-9)
    }
    @Test func thresholdLawUsesConstrainedIncomingEnergy() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Required runtime OS unavailable."); return }
        let prepared = try ConstrainedImpactFixtures.prepared(ConstrainedImpactFixtures.input(restitution:1,threshold:2))
        var work = try ConstrainedImpactFixtures.numerical(), contact = try ConstrainedImpactFixtures.contact()
        let result = try ReferenceConstrainedNormalImpulseSolver().solve(prepared,work:&work,contactWork:&contact,cancellation:HybridCancellation())
        #expect(abs(result.normalSpeedAfter) < 1e-9); #expect(abs(result.contactImpulse-4.0/3) < 1e-9)
        #expect(abs(result.predictedLostEnergy-2.0/3) < 1e-9)
    }
}
