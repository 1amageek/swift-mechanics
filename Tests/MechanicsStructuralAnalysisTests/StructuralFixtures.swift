@testable import SwiftMechanics
struct StructuralFixtures {
    static func work(storage:Int=2000000,operations:Int=100000000,iterations:Int=100000) throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:iterations)) }
    static func policy(spectral:Double=1e-13,residual:Double=1e-6,cancelled:Bool=false,coordinates:Int=256) throws -> StructuralPolicy {
        try StructuralPolicy(maximumCoordinates:coordinates,maximumMetadataBytes:10000,energyScale:100,timeScale:1,spectralTolerance:spectral,
            positiveMassThreshold:1e-14,originalResidualTolerance:residual,zeroEigenvalueThreshold:1e-6,isCancelled:{cancelled})
    }
    static func beam(elements:Int=4,massDamping:Double=0,stiffnessDamping:Double=0) throws -> BeamAssembly {
        let beam=try UniformBeam(identity:"structural-beam",revision:1,frame:EntityID(kind:.frame,key:"beam-frame"),source:SourceProvenance(source:"linear small-strain slender beam",revision:1),
            length:2,area:0.01,secondMoment:1e-5,maximumFiberDistance:0.05,density:1000,elasticity:IsotropicElasticity(bulkModulus:1e7,shearModulus:4e6),elements:elements,
            massDamping:massDamping,stiffnessDamping:stiffnessDamping,maximumSlope:0.01,maximumLinearStrain:0.01)
        var w=try work();let service:any BeamAssembling=HermiteBeamAssembler()
        return try service.assemble(beam,admission:BeamAdmission(maximumElements:32,maximumMetadataBytes:10000,isCancelled:{false}),work:&w)
    }
    static func pencil(_ beam:BeamAssembly,fixed:[Int]=[0,1],load:Double=0) throws -> StructuralPencil {
        var w=try work();let service:any StructuralModelBuilding=ReferenceStructuralModelBuilder()
        return try service.beam(beam,fixedCoordinates:fixed,compressiveLoad:load,expectedRevision:1,policy:policy(),work:&w)
    }
    static func truss() throws -> NonlinearTruss { try NonlinearTruss(identity:"two-bar-snap-through",revision:1,frame:EntityID(kind:.frame,key:"truss-frame"),source:SourceProvenance(source:"calibrated axial elastic bars",revision:1),halfSpan:1,initialHeight:0.5,axialRigidity:1000,maximumAbsoluteEngineeringStrain:0.2) }
    static func close(_ a:Double,_ b:Double,_ tolerance:Double=1e-6) -> Bool { abs(a-b)<=tolerance*max(1,max(abs(a),abs(b))) }
}
