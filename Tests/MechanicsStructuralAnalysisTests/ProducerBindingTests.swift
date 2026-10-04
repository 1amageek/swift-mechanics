@testable import SwiftMechanics
import Testing
struct ProducerBindingTests {
    @Test func realStressFreeTet4HasSixRigidModesAndIdentifiedBinding() throws {
        let mesh=try StructuralFlexibleFixture.mesh(),state=try StructuralFlexibleFixture.state(mesh)
        var w=try StructuralFixtures.work(),calls=try ConstitutiveCallWork(maximumCalls:1000)
        let builder:any StructuralModelBuilding=ReferenceStructuralModelBuilder()
        let pencil=try builder.flexible(mesh,state:state,fixedCoordinates:[],coordinateScale:1,assembler:TotalLagrangianTetrahedra(),constitutiveWork:&calls,policy:StructuralFixtures.policy(),work:&w)
        let service:any ModalAnalyzing=ReferenceModalAnalyzer();let result=try service.modes(pencil,expectedBinding:pencil.binding,policy:StructuralFixtures.policy(),work:&w)
        #expect(result.classifications.filter{$0 == .neutral}.count==6);#expect(result.classifications.filter{$0 == .oscillatory}.count==6)
        #expect(pencil.binding.frame==mesh.mesh.frame);#expect(pencil.binding.revision==mesh.mesh.revision);#expect(calls.calls==13)
    }
    @Test func actualCompiledRigidEquilibriumLinearizationFeedsModalPencil() throws {
        let model=try StructuralEquilibriumFixture.springs(),point=try StructuralEquilibriumFixture.solve(model)
        let compiled=try StructuralEquilibriumFixture.compiled(),dynamics=try StructuralEquilibriumFixture.dynamics(compiled,q:point.position)
        let reduction=EquilibriumReduction(freeCoordinates:1,basis:[1],damping:[4],outputRows:1,outputMap:[1],outputDimensions:[.length])
        var supplier=try StructuralEquilibriumFixture.work();let linearizer:any EquilibriumLinearizing=ReferenceEquilibriumLinearizer()
        let linearization=try linearizer.linearize(point,compiled:compiled,dynamics:dynamics,reduction:reduction,policy:StructuralEquilibriumFixture.linearPolicy(),work:&supplier)
        var w=try StructuralFixtures.work();let builder:any StructuralModelBuilding=ReferenceStructuralModelBuilder()
        let pencil=try builder.equilibrium(linearization,expectedModel:compiled.stamp,policy:StructuralFixtures.policy(),work:&w)
        let service:any ModalAnalyzing=ReferenceModalAnalyzer();let result=try service.modes(pencil,expectedBinding:pencil.binding,policy:StructuralFixtures.policy(),work:&w)
        #expect(StructuralFixtures.close(result.eigenvalues[0],50,1e-8));#expect(StructuralFixtures.close(result.modes[0]*result.modes[0]*2,1,1e-8))
        #expect(pencil.binding.source == .equilibriumReduction);#expect(pencil.binding.operatingCoordinates==point.position)
        #expect(throws:StructuralError.self) { try builder.equilibrium(linearization,expectedModel:ModelStamp(identity:compiled.stamp.identity,revision:2),policy:StructuralFixtures.policy(),work:&w) }
    }
    @Test func staleMeshFrameBoundaryAndPhysicalLoadEnvelopeFail() throws {
        let mesh=try StructuralFlexibleFixture.mesh(),state=try StructuralFlexibleFixture.state(mesh)
        let wrong=NodalState(frame:state.frame,meshRevision:2,nodeIdentifiers:state.nodeIdentifiers,positions:state.positions,velocities:state.velocities)
        let builder:any StructuralModelBuilding=ReferenceStructuralModelBuilder();var w=try StructuralFixtures.work(),calls=try ConstitutiveCallWork(maximumCalls:1000)
        #expect(throws:StructuralError.self) { try builder.flexible(mesh,state:wrong,fixedCoordinates:[],coordinateScale:1,assembler:TotalLagrangianTetrahedra(),constitutiveWork:&calls,policy:StructuralFixtures.policy(),work:&w) }
        let beam=try StructuralFixtures.beam()
        #expect(throws:StructuralError.self) { try builder.beam(beam,fixedCoordinates:[0,0],compressiveLoad:0,expectedRevision:1,policy:StructuralFixtures.policy(),work:&w) }
        #expect(throws:StructuralError.self) { try builder.beam(beam,fixedCoordinates:[0,1],compressiveLoad:beam.youngModulus*beam.beam.area,expectedRevision:1,policy:StructuralFixtures.policy(),work:&w) }
    }
}
