import SwiftMechanics
import Testing
import Synchronization
@Suite(.timeLimit(.minutes(1)))
struct FlexibleFailureTests {
    @Test func restCellsIdentityConnectivityAndQualityFailures() throws {
        let service: any TetrahedralMeshValidating = TetrahedralMeshValidator(), admission = try FlexibleFixtures.admission()
        var work = try FlexibleFixtures.work()
        #expect(throws:FlexibleError.invalidReferenceCell(element:50)) { try service.validate(FlexibleFixtures.raw(indexes:[0,2,1,3]),admission:admission,work:&work) }
        #expect(throws:FlexibleError.invalidReferenceCell(element:50)) { try service.validate(FlexibleFixtures.raw(positions:[.zero,.unitX,.unitY,try Vector3(1,1,0)]),admission:admission,work:&work) }
        #expect(throws:FlexibleError.invalidConnectivity) { try service.validate(FlexibleFixtures.raw(indexes:[0,1,2,9]),admission:admission,work:&work) }
        #expect(throws:FlexibleError.invalidConnectivity) { try service.validate(FlexibleFixtures.raw(indexes:[0,1,2,2]),admission:admission,work:&work) }
        #expect(throws:FlexibleError.unusedNode) { try service.validate(FlexibleFixtures.raw(extraNode:true),admission:admission,work:&work) }
        let raw = try FlexibleFixtures.raw()
        let missing = try TetrahedralMesh(frame:raw.frame,revision:1,source:raw.source,nodes:raw.nodes,cells:raw.cells,materials:[try FlexibleMaterial(identifier:EntityID(kind:.material,key:"other"),source:raw.materials[0].source,law:raw.materials[0].law,referenceDensity:6,massDampingRate:0)])
        #expect(throws:FlexibleError.missingMaterial) { try service.validate(missing,admission:admission,work:&work) }
        let duplicate = try TetrahedralMesh(frame:raw.frame,revision:1,source:raw.source,nodes:raw.nodes,cells:raw.cells+raw.cells,materials:raw.materials)
        #expect(throws:FlexibleError.invalidIdentity) { try service.validate(duplicate,admission:admission,work:&work) }
        var nodes = raw.nodes; nodes[1] = FlexibleNode(identifier:nodes[0].identifier,referencePosition:.unitX)
        #expect(throws:FlexibleError.invalidIdentity) { try service.validate(TetrahedralMesh(frame:raw.frame,revision:1,source:raw.source,nodes:nodes,cells:raw.cells,materials:raw.materials),admission:admission,work:&work) }
    }
    @Test func currentInversionDomainAndLayoutFailures() throws {
        let mesh = try FlexibleFixtures.mesh(), service: any TetrahedralAssembling = TotalLagrangianTetrahedra()
        var work = try FlexibleFixtures.work(), calls = try ConstitutiveCallWork(maximumCalls:100)
        let inverted = try FlexibleFixtures.state(mesh,f:Matrix3(-1,0,0,0,1,0,0,0,1))
        #expect(throws:FlexibleError.material(.outsideDomain(measure:"volumeRatio",value:-1,limit:0.2))) { try service.assemble(mesh,state:inverted,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        #expect(calls.calls == 1)
        let state = try FlexibleFixtures.state(mesh)
        #expect(throws:FlexibleError.layoutMismatch) { try service.assemble(mesh,state:NodalState(frame:mesh.mesh.frame,meshRevision:2,nodeIdentifiers:state.nodeIdentifiers,positions:state.positions,velocities:state.velocities),massForm:.consistent,constitutiveWork:&calls,work:&work) }
        let otherFrame = try EntityID(kind:.frame,key:"different-frame")
        #expect(throws:FlexibleError.layoutMismatch) { try service.assemble(mesh,state:NodalState(frame:otherFrame,meshRevision:1,nodeIdentifiers:state.nodeIdentifiers,positions:state.positions,velocities:state.velocities),massForm:.consistent,constitutiveWork:&calls,work:&work) }
        var ids = state.nodeIdentifiers; ids.swapAt(0,1)
        #expect(throws:FlexibleError.layoutMismatch) { try service.assemble(mesh,state:NodalState(frame:mesh.mesh.frame,meshRevision:1,nodeIdentifiers:ids,positions:state.positions,velocities:state.velocities),massForm:.consistent,constitutiveWork:&calls,work:&work) }
        let large = try FlexibleFixtures.state(mesh,f:Matrix3(4,0,0,0,1,0,0,0,1))
        #expect(throws:FlexibleError.self) { try service.assemble(mesh,state:large,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        #expect(state.positions == mesh.mesh.nodes.map { $0.referencePosition })
    }
    @available(macOS 15.0, *)
    @Test func numericalConstitutiveCapacityAndCancellationBoundaries() throws {
        let raw = try FlexibleFixtures.raw(), admission = try FlexibleFixtures.admission(), validator: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        var none = try FlexibleFixtures.work(operations:0)
        #expect(throws:FlexibleError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0))) { try validator.validate(raw,admission:admission,work:&none) }
        var storage = try FlexibleFixtures.work(storage:29)
        #expect(throws:FlexibleError.numerical(.resourceLimit(resource:.scalarStorage,limit:29))) { try validator.validate(raw,admission:admission,work:&storage) }
        var w = try FlexibleFixtures.work()
        #expect(throws:FlexibleError.capacityExceeded) { try validator.validate(raw,admission:FlexibleFixtures.admission(maximumNodes:3),work:&w) }
        #expect(throws:FlexibleError.cancelled) { try validator.validate(raw,admission:FlexibleFixtures.admission(cancelled:true),work:&w) }
        let mesh = try FlexibleFixtures.mesh(), state = try FlexibleFixtures.state(mesh)
        let service: any TetrahedralAssembling = TotalLagrangianTetrahedra()
        var calls = try ConstitutiveCallWork(maximumCalls:12)
        #expect(throws:FlexibleError.constitutiveCallLimit(limit:12)) { try service.assemble(mesh,state:state,massForm:.consistent,constitutiveWork:&calls,work:&w) }
        #expect(calls.calls == 12)
        var small = try FlexibleFixtures.work(storage:481), enough = try ConstitutiveCallWork(maximumCalls:13)
        #expect(throws:FlexibleError.numerical(.resourceLimit(resource:.scalarStorage,limit:481))) { try service.assemble(mesh,state:state,massForm:.consistent,constitutiveWork:&enough,work:&small) }
        #expect(enough.calls == 0)
        var exact = try FlexibleFixtures.work(storage:482)
        let result = try service.assemble(mesh,state:state,massForm:.consistent,constitutiveWork:&enough,work:&exact)
        #expect(result.numericalWork.peakScalarStorage == 482 && enough.calls == 13)
        let cancelled: any TetrahedralAssembling = TotalLagrangianTetrahedra(isCancelled:{true})
        #expect(throws:FlexibleError.cancelled) { try cancelled.assemble(mesh,state:state,massForm:.consistent,constitutiveWork:&enough,work:&w) }
        let checkpoints = Mutex(0)
        let lateCancel: any TetrahedralAssembling = TotalLagrangianTetrahedra(isCancelled:{
            checkpoints.withLock { count in count += 1; return count == 49 }
        })
        var finalCalls = try ConstitutiveCallWork(maximumCalls:13), finalWork = try FlexibleFixtures.work()
        #expect(throws:FlexibleError.cancelled) { try lateCancel.assemble(mesh,state:state,massForm:.consistent,constitutiveWork:&finalCalls,work:&finalWork) }
        #expect(finalCalls.calls == 13 && finalWork.operations > 0)
    }
    @Test func longMaterialKeysExhaustBeforeUnboundedComparison() throws {
        let raw = try FlexibleFixtures.raw(), original = raw.materials[0], prefix = String(repeating:"a",count:10000)
        let assigned = try EntityID(kind:.material,key:prefix+"assigned")
        let other = try EntityID(kind:.material,key:prefix+"other")
        let material = try FlexibleMaterial(identifier:other,source:original.source,law:original.law,referenceDensity:6,massDampingRate:0)
        let cell = try TetrahedronCell(identifier:50,nodes:[0,1,2,3],material:assigned,source:raw.cells[0].source)
        let lookup = try TetrahedralMesh(frame:raw.frame,revision:1,source:raw.source,nodes:raw.nodes,cells:[cell],materials:[material])
        let validator: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        let admission = try FlexibleFixtures.admission()
        var limited = try FlexibleFixtures.work(operations:200)
        #expect(throws:FlexibleError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:200))) {
            try validator.validate(lookup,admission:admission,work:&limited)
        }
        #expect(limited.operations <= 200 && limited.operations >= 198)
        let second = try FlexibleMaterial(identifier:assigned,source:original.source,law:original.law,referenceDensity:6,massDampingRate:0)
        let duplicates = try TetrahedralMesh(frame:raw.frame,revision:1,source:raw.source,nodes:raw.nodes,cells:[cell],materials:[material,second])
        var duplicateWork = try FlexibleFixtures.work(operations:200)
        #expect(throws:FlexibleError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:200))) {
            try validator.validate(duplicates,admission:admission,work:&duplicateWork)
        }
    }
    @Test func refinementIdentityAndCapacityRemainTransactional() throws {
        let mesh = try FlexibleFixtures.mesh(), validator: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        var work = try FlexibleFixtures.work()
        #expect(throws:FlexibleError.layoutMismatch) { try validator.refine(mesh,revision:1,newNodeIdentifiers:[100],newCellIdentifiers:[1,2,3,4],admission:FlexibleFixtures.admission(),work:&work) }
        #expect(throws:FlexibleError.invalidIdentity) { try validator.refine(mesh,revision:2,newNodeIdentifiers:[10],newCellIdentifiers:[1,2,3,4],admission:FlexibleFixtures.admission(),work:&work) }
        #expect(throws:FlexibleError.capacityExceeded) { try validator.refine(mesh,revision:2,newNodeIdentifiers:[100],newCellIdentifiers:[1,2,3,4],admission:FlexibleFixtures.admission(maximumNodes:4),work:&work) }
        #expect(mesh.mesh.nodes.count == 4 && mesh.mesh.cells.count == 1)
    }
}
