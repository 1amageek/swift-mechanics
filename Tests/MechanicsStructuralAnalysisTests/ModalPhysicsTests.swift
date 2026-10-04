@testable import SwiftMechanics
import Testing
struct ModalPhysicsTests {
    @Test func cantileverBeamRefinesToIndependentEulerBernoulliFrequency() throws {
        let service:any ModalAnalyzing=ReferenceModalAnalyzer();var errors:[Double]=[]
        for elements in [2,4,8] {
            let beam=try StructuralFixtures.beam(elements:elements),pencil=try StructuralFixtures.pencil(beam)
            var w=try StructuralFixtures.work();let result=try service.modes(pencil,expectedBinding:pencil.binding,policy:StructuralFixtures.policy(),work:&w)
            let beta=1.875104068711961,exact=beta*beta*beta*beta*beam.youngModulus*beam.beam.secondMoment/(beam.beam.density*beam.beam.area*16)
            errors.append(abs(result.eigenvalues[0]/exact-1));#expect(result.classifications.allSatisfy{$0 == .oscillatory})
            #expect(result.maximumOriginalResidual<1e-6);#expect(result.maximumMassOrthogonalityError<1e-6)
        }
        #expect(errors[1]<errors[0]);#expect(errors[2]<errors[1]);#expect(errors[2]<1e-5)
    }
    @Test func freeBeamHasTwoRealRigidModesAndPrestressCanDestabilize() throws {
        let beam=try StructuralFixtures.beam(),free=try StructuralFixtures.pencil(beam,fixed:[])
        var w=try StructuralFixtures.work();let service:any ModalAnalyzing=ReferenceModalAnalyzer()
        let modes=try service.modes(free,expectedBinding:free.binding,policy:StructuralFixtures.policy(),work:&w)
        #expect(modes.classifications.filter{$0 == .neutral}.count==2)
        let pi=3.141592653589793,load=1.2*pi*pi*beam.youngModulus*beam.beam.secondMoment/4
        let compressed=try StructuralFixtures.pencil(beam,fixed:[0,beam.coordinateCount-2],load:load)
        var other=try StructuralFixtures.work();let unstable=try service.modes(compressed,expectedBinding:compressed.binding,policy:StructuralFixtures.policy(),work:&other)
        #expect(unstable.classifications[0] == .unstable);#expect(unstable.eigenvalues[0]<0)
    }
    @Test func originalResidualRejectsPrematureDiagonalAcceptanceAndBudgetExhaustion() throws {
        let pencil=try StructuralFixtures.pencil(StructuralFixtures.beam()),service:any ModalAnalyzing=ReferenceModalAnalyzer()
        var loose=try StructuralFixtures.work()
        #expect(throws:StructuralError.self) { try service.modes(pencil,expectedBinding:pencil.binding,policy:StructuralFixtures.policy(spectral:2,residual:1e-12),work:&loose) }
        var exhausted=try StructuralFixtures.work(iterations:0)
        let policy=try StructuralFixtures.policy()
        do throws(StructuralError) { _=try service.modes(pencil,expectedBinding:pencil.binding,policy:policy,work:&exhausted);Issue.record("Iteration exhaustion published modes") }
        catch { if case .nonConvergence = error {} else { Issue.record("Wrong failure") } }
    }
    @Test func invalidMassStaleBindingAndCancellationAreFailures() throws {
        let pencil=try StructuralFixtures.pencil(StructuralFixtures.beam()),service:any ModalAnalyzing=ReferenceModalAnalyzer()
        let bad=StructuralPencil(binding:pencil.binding,mass:[Double](repeating:0,count:pencil.mass.count),stiffness:pencil.stiffness,damping:pencil.damping)
        var w=try StructuralFixtures.work()
        let policy=try StructuralFixtures.policy()
        do throws(StructuralError) { _=try service.modes(bad,expectedBinding:bad.binding,policy:policy,work:&w);Issue.record("Zero mass accepted") } catch { if case .nonPositiveMass = error {} else { Issue.record("Wrong failure") } }
        let b=pencil.binding,stale=StructuralBinding(identity:b.identity,revision:2,frame:b.frame,source:b.source,provenance:b.provenance,sourceCoordinateIDs:b.sourceCoordinateIDs,reductionBasis:b.reductionBasis,beam:b.beam,equilibriumModel:b.equilibriumModel,operatingParameter:b.operatingParameter,branchIdentity:b.branchIdentity,retainedCoordinates:b.retainedCoordinates,dimensions:b.dimensions,coordinateScales:b.coordinateScales,operatingTime:b.operatingTime,operatingCoordinates:b.operatingCoordinates)
        #expect(throws:StructuralError.self) { try service.modes(pencil,expectedBinding:stale,policy:StructuralFixtures.policy(),work:&w) }
        #expect(throws:StructuralError.self) { try service.modes(pencil,expectedBinding:pencil.binding,policy:StructuralFixtures.policy(cancelled:true),work:&w) }
    }
}
