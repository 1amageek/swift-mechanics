import SwiftMechanics
import Testing

@Suite("Hybrid hard normal impulses")
struct HybridImpulseTests {
    @Test func analyticMomentumRestitutionAndEnergy() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let input=try HybridFixtures.input(), source=input.physical.state, result=try HybridFixtures.solve(input)
        #expect(result.eventIDs == [10]); #expect(abs(result.normalImpulses[0]-9) < 1e-9)
        #expect(abs(result.velocity[0]-1.5) < 1e-9); #expect(abs(result.kineticEnergyBefore-9) < 1e-9)
        #expect(abs(result.kineticEnergyAfter-2.25) < 1e-9); #expect(abs(result.predictedEnergyLoss-6.75) < 1e-9)
        #expect(result.normalizedMomentumResidual < 1e-9); #expect(result.lawResidual < 1e-9); #expect(result.energyResidual < 1e-9)
        #expect(input.physical.state == source)
    }
    @Test func simultaneousIndependentRowsHaveCanonicalOrder() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let input=try HybridFixtures.input(two:true), result=try HybridFixtures.solve(input)
        #expect(result.eventIDs == [10,20]); #expect(abs(result.velocity[0]-1.5) < 1e-9)
        #expect(abs(result.velocity[1]-1) < 1e-9); #expect(result.normalImpulses.allSatisfy({ abs($0-9) < 1e-9 }))
        #expect(abs(result.predictedEnergyLoss-11.25) < 1e-8)
    }
    @Test func coupledModesFailInsteadOfDroppingOffDiagonalTerms() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        do { _=try HybridFixtures.solve(HybridFixtures.input(duplicate:true)); Issue.record("Expected coupled-mode rejection.") }
        catch HybridError.coupledModes {} catch { throw error }
    }
    @Test func staleGeometryAndCancellationFailBeforeJump() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let input=try HybridFixtures.input()
        let stale=HardImpactInput(model:input.model,physical:input.physical,inertias:input.inertias,collision:input.collision,expectedCollisionRevision:2,contacts:input.contacts)
        do { _=try HybridFixtures.solve(stale); Issue.record("Expected stale geometry.") } catch HybridError.staleGeometry {} catch { throw error }
        let token=HybridCancellation(); token.cancel()
        do { _=try HybridFixtures.solve(input,cancellation:token); Issue.record("Expected cancellation.") } catch HybridError.cancelled {} catch { throw error }
    }
    @Test func thresholdRestitutionUsesActualSelectedLaw() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        let input=try HybridFixtures.input(e:0)
        let result=try HybridFixtures.solve(input)
        #expect(abs(result.velocity[0]) < 1e-9); #expect(abs(result.normalImpulses[0]-6) < 1e-9)
        #expect(abs(result.predictedEnergyLoss-9) < 1e-9)
    }
    @Test func exhaustedPhysicalWorkFails() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else { Issue.record("Hybrid Runtime OS baseline unavailable."); return }
        do { _=try HybridFixtures.solve(HybridFixtures.input(),operations:0); Issue.record("Expected supplier budget failure.") }
        catch HybridError.dynamics {} catch HybridError.numerical {} catch { throw error }
    }
}
