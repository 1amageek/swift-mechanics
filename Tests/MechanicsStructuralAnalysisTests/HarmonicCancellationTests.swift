import Testing
import MechanicsCore
import MechanicsNumerics
import MechanicsStructuralAnalysis
struct HarmonicCancellationTests {
    @Test func realCompletedLinearSolveCannotPublishAfterCancellation() throws {
        guard #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) else { Issue.record("The cancellation fixture requires Mutex availability.");return }
        let owner=HarmonicCancellationOwner(),pencil=try StructuralFixtures.pencil(StructuralFixtures.beam(elements:1,massDamping:4),fixed:[0,1,3])
        let policy=try StructuralPolicy(maximumCoordinates:256,maximumMetadataBytes:10000,energyScale:100,timeScale:1,spectralTolerance:1e-13,
            positiveMassThreshold:1e-14,originalResidualTolerance:1e-6,zeroEigenvalueThreshold:1e-6,isCancelled:{owner.cancelled()})
        let service:any HarmonicAnalyzing=ReferenceHarmonicAnalyzer(solver:HarmonicCancellingSolver(owner:owner))
        let excitation=HarmonicPhysicsTests.excitation(1,omega:3),tolerance=try HarmonicPhysicsTests.tolerance();var w=try StructuralFixtures.work()
        do throws(StructuralError) { _=try service.response(pencil,expectedBinding:pencil.binding,excitation:excitation,linearTolerance:tolerance,policy:policy,work:&w);Issue.record("Cancelled solve published") }
        catch { if case .cancelled = error {} else { Issue.record("Wrong failure") } }
        #expect(owner.cancelled());#expect(w.operations>0)
    }
}
