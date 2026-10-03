import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsFlexible
import MechanicsContactPatches
import Testing
@Suite(.timeLimit(.minutes(1)))
struct PatchFailureTests {
    @Test func missingAndUnsupportedRepresentationSelectionsFailExplicitly() throws {
        let mesh=try PatchFixtures.mesh(), good=try PatchFixtures.body(mesh), plane=try PatchFixtures.plane(mesh.mesh.frame)
        for mode in 0..<3 {
            var work=try PatchFixtures.work(), workspace=PatchWorkspace()
            let body=mode == 0 ? try PatchFixtures.body(mesh,missing:true) : good
            let rigid: PatchRepresentation=mode == 1 ? .compliantBody(good) : (mode == 2 ? .unsupportedRigidSurface : .rigidPlane(plane))
            do { _=try TetrahedralPressurePatchIntegrator().integrate(body,against:rigid,origin:.zero,policy:PatchFixtures.policy(),workspace:&workspace,work:&work); Issue.record("Expected representation failure.") }
            catch let error as PatchError { switch error { case .missingPressureField: #expect(mode == 0); case .unsupportedPair: #expect(mode != 0); default: Issue.record("Wrong failure: \(error)") } }
        }
    }
    @Test func stalePressurePlaneAndFrameMaterialSourceMismatchAreRejected() throws {
        let mesh=try PatchFixtures.mesh(), body=try PatchFixtures.body(mesh), field=try #require(body.field)
        for mode in 0..<5 {
            let changed=NodalPressureField(frame:field.frame,meshRevision:field.meshRevision,revision:mode == 0 ? 99 : field.revision,nodeIdentifiers:field.nodeIdentifiers,
                materialIdentifiers:mode == 3 ? [try EntityID(kind:.material,key:"other")] : field.materialIdentifiers,pressurePascals:field.pressurePascals,
                source:mode == 4 ? try SourceProvenance(source:"stale source",revision:1) : field.source)
            let b=PressureBody(body:body.body,mesh:mesh,state:body.state,field:changed)
            let frame=mode == 2 ? try EntityID(kind:.frame,key:"different") : mesh.mesh.frame
            let plane=try PatchFixtures.plane(frame,revision:mode == 1 ? 99 : 4)
            var work=try PatchFixtures.work(), workspace=PatchWorkspace()
            do { _=try TetrahedralPressurePatchIntegrator().integrate(b,against:.rigidPlane(plane),origin:.zero,policy:PatchFixtures.policy(),workspace:&workspace,work:&work); Issue.record("Expected stale/incompatible failure.") }
            catch let error as PatchError { switch error { case .staleRepresentation: #expect(mode == 0 || mode == 1 || mode == 4); case .frameMismatch: #expect(mode == 2); case .incompatibleMaterial: #expect(mode == 3); default: Issue.record("Wrong failure: \(error)") } }
        }
    }
    @Test func currentInversionPlaneVertexAndInvalidPressureFailBeforePublication() throws {
        let mesh=try PatchFixtures.mesh(), body=try PatchFixtures.body(mesh), field=try #require(body.field)
        for mode in 0..<3 {
            let bad=NodalPressureField(frame:field.frame,meshRevision:field.meshRevision,revision:field.revision,nodeIdentifiers:field.nodeIdentifiers,materialIdentifiers:field.materialIdentifiers,
                pressurePascals:[-1,5,6,7],source:field.source)
            let b=mode == 0 ? try PatchFixtures.body(mesh,inverted:true) : (mode == 2 ? PressureBody(body:body.body,mesh:mesh,state:body.state,field:bad) : body)
            let plane=try PatchFixtures.plane(mesh.mesh.frame,point:mode == 1 ? .zero : Vector3(0,0,0.2))
            var work=try PatchFixtures.work(), workspace=PatchWorkspace()
            do { _=try TetrahedralPressurePatchIntegrator().integrate(b,against:.rigidPlane(plane),origin:.zero,policy:PatchFixtures.policy(),workspace:&workspace,work:&work); Issue.record("Expected current-domain failure.") }
            catch let error as PatchError { switch error { case .invertedCell: #expect(mode == 0); case .degenerateCut: #expect(mode == 1); case .invalidInput: #expect(mode == 2); default: Issue.record("Wrong failure: \(error)") } }
        }
    }
    @Test func capacityStorageArithmeticLongMetadataAndCancellationBoundExecution() throws {
        let mesh=try PatchFixtures.mesh(), body=try PatchFixtures.body(mesh)
        // The same operation budget admits the ordinary fixture, isolating long-key exhaustion.
        var baselineWork=try PatchFixtures.work(operations:10_000), baselineWorkspace=PatchWorkspace()
        _=try TetrahedralPressurePatchIntegrator().integrate(body,against:.rigidPlane(PatchFixtures.plane(mesh.mesh.frame)),origin:.zero,policy:PatchFixtures.policy(),workspace:&baselineWorkspace,work:&baselineWork)
        for mode in 0..<5 {
            var work=try PatchFixtures.work(storage:mode == 1 ? 1 : 100_000,operations:mode == 2 ? 1 : (mode == 3 ? 10_000 : 1_000_000)), workspace=PatchWorkspace()
            let frame=mode == 3 ? try EntityID(kind:.frame,key:String(repeating:"a",count:10_000)) : mesh.mesh.frame
            let plane=try PatchFixtures.plane(frame)
            do { _=try TetrahedralPressurePatchIntegrator().integrate(body,against:.rigidPlane(plane),origin:.zero,policy:PatchFixtures.policy(maximumTriangles:mode == 0 ? 1 : 40,cancelled:{mode == 4}),workspace:&workspace,work:&work); Issue.record("Expected capacity/resource/cancel failure.") }
            catch let error as PatchError { switch error { case .capacityExceeded: #expect(mode == 0); case .numerical: #expect(mode == 1 || mode == 2 || mode == 3); case .cancelled: #expect(mode == 4); default: Issue.record("Wrong failure: \(error)") } }
        }
    }
}
