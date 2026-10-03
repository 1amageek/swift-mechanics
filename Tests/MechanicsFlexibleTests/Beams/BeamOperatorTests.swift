import Testing
import MechanicsCore
import MechanicsModel
import MechanicsMaterials
import MechanicsNumerics
import MechanicsFlexible
struct BeamOperatorTests {
    static func beam(elements: Int = 1) throws -> UniformBeam {
        try UniformBeam(identity:"beam",revision:1,frame:EntityID(kind:.frame,key:"world-beam"),source:SourceProvenance(source:"calibrated elastic beam",revision:1),
            length:2,area:0.01,secondMoment:1e-5,maximumFiberDistance:0.05,density:1000,elasticity:IsotropicElasticity(bulkModulus:1e7,shearModulus:4e6),elements:elements,
            massDamping:2,stiffnessDamping:0.01,maximumSlope:0.01,maximumLinearStrain:0.01)
    }
    static func work(_ storage: Int = 100000) throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:1000000,iterations:0)) }
    static func quadratic(_ a:[Double],_ x:[Double]) -> Double { var value=0.0;for i in x.indices { for j in x.indices { value+=x[i]*a[i*x.count+j]*x[j] } };return value }
    @Test func exactIntegratedHermiteEnergiesAndMass() throws {
        var w=try Self.work();let service:any BeamAssembling=HermiteBeamAssembler()
        let a=try service.assemble(Self.beam(),admission:BeamAdmission(maximumElements:10,maximumMetadataBytes:1000,isCancelled:{false}),work:&w)
         #expect(abs(a.youngModulus-9*1e7*4e6/(3*1e7+4e6))<1e-8)
        let curvature=0.002,l=a.beam.length,q=[0.0,0,0.5*curvature*l*l,curvature*l]
        #expect(abs(0.5*Self.quadratic(a.elasticStiffness,q)-0.5*a.youngModulus*a.beam.secondMoment*l*curvature*curvature)<1e-12)
        #expect(abs(Self.quadratic(a.mass,[1,0,1,0])-a.beam.density*a.beam.area*l)<1e-12)
        #expect(abs(Self.quadratic(a.geometricStiffness,[0,1,l,1])-l)<1e-12)
        for i in a.damping.indices { #expect(a.damping[i]==a.beam.massDamping*a.mass[i]+a.beam.stiffnessDamping*a.elasticStiffness[i]) }
    }
    @Test func sharedNodeAssemblyPreservesQuadraticFieldEnergy() throws {
        var w=try Self.work();let a=try HermiteBeamAssembler().assemble(Self.beam(elements:4),admission:BeamAdmission(maximumElements:4,maximumMetadataBytes:1000,isCancelled:{false}),work:&w)
        var q=[Double](repeating:0,count:a.coordinateCount);let curvature=0.002
        for node in 0...a.beam.elements { let x=a.beam.length*Double(node)/Double(a.beam.elements);q[2*node]=0.5*curvature*x*x;q[2*node+1]=curvature*x }
        #expect(abs(Self.quadratic(a.elasticStiffness,q)-a.youngModulus*a.beam.secondMoment*a.beam.length*curvature*curvature)<1e-10)
    }
    @Test func invalidGeometryAndUnrepresentableMaterialScaleFail() throws {
        #expect(throws:BeamError.invalidInput) { try UniformBeam(identity:"invalid",revision:1,frame:EntityID(kind:.frame,key:"world"),source:SourceProvenance(source:"test",revision:1),length:0,area:1,secondMoment:1,maximumFiberDistance:1,density:1,elasticity:IsotropicElasticity(bulkModulus:1,shearModulus:1),elements:1,massDamping:0,stiffnessDamping:0,maximumSlope:0.01,maximumLinearStrain:0.01) }
        let huge=try UniformBeam(identity:"overflow",revision:1,frame:EntityID(kind:.frame,key:"world"),source:SourceProvenance(source:"test",revision:1),length:Double.leastNonzeroMagnitude,area:1,secondMoment:1,maximumFiberDistance:1,density:1,elasticity:IsotropicElasticity(bulkModulus:1e7,shearModulus:4e6),elements:1,massDamping:0,stiffnessDamping:0,maximumSlope:0.01,maximumLinearStrain:0.01)
        var w=try Self.work();#expect(throws:BeamError.nonFiniteResult) { try HermiteBeamAssembler().assemble(huge,admission:BeamAdmission(maximumElements:1,maximumMetadataBytes:1000,isCancelled:{false}),work:&w) }
    }
    @Test func storageElementAndCancellationLimitsFail() throws {
        let service:any BeamAssembling=HermiteBeamAssembler();var small=try Self.work(1)
        #expect(throws:BeamError.self) { try service.assemble(Self.beam(),admission:BeamAdmission(maximumElements:1,maximumMetadataBytes:1000,isCancelled:{false}),work:&small) }
        var w=try Self.work()
        #expect(throws:BeamError.capacityExceeded) { try service.assemble(Self.beam(elements:2),admission:BeamAdmission(maximumElements:1,maximumMetadataBytes:1000,isCancelled:{false}),work:&w) }
        #expect(throws:BeamError.cancelled) { try service.assemble(Self.beam(),admission:BeamAdmission(maximumElements:1,maximumMetadataBytes:1000,isCancelled:{true}),work:&w) }
    }
}
