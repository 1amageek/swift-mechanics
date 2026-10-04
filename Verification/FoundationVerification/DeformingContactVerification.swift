import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyDeformingContact() throws {
        let snapshot=try deformingProbeSnapshot(),policy=try deformingProbePolicy()
        var work=NumericalWork(budget:try NumericalBudget(scalarStorage:100000,arithmeticOperations:10000000,iterations:0))
        let query: any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries()
        let witness=try query.selfContact(snapshot,first:SurfaceFeatureID(cell:101,oppositeNode:1),vertex:0,
            second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:policy,work:&work)
        try require(abs(witness.separation+0.01)<1e-10)
        let pair=try deformingProbePair()
        var laws=ContactWork(budget:try ContactBudget(operations:1000000,scalarStorage:1000,records:10))
        let service: any SurfaceContactTransacting=ValueSurfaceContactTransactions()
        let binding=SurfaceContactBinding(key:"self",witness:witness,pair:pair,currentObstacle:nil)
        let accepted=try service.initialState(snapshot,bindings:[binding],policy:policy,work:&work,lawWork:&laws)
        let step=try service.trial(accepted,snapshot:snapshot,bindings:[binding],timeStep:0.001,policy:policy,
            lawPolicy:ContactAcceptancePolicy(absoluteEnergyTolerance:1e-10,absolutePowerTolerance:1e-10,
                relativeTolerance:1e-11,referenceEnergy:1,referencePower:1,coneTolerance:1e-11),work:&work,lawWork:&laws)
        let result=step.contacts[0]
        try require(result.response.trialHistory.identity.firstBody == result.response.trialHistory.identity.secondBody)
        try require(abs(result.response.forceOnB.x-1)<1e-9 && abs(result.response.forceOnB.z-10)<1e-9)
        try require(abs(result.mappedPower+1)<1e-9 && result.forceResidual<1e-8 && result.momentResidual<1e-8)
        try require(try service.reject(step,from:accepted) === accepted)
        let next=try service.accept(step,from:accepted)
        try require(accepted.histories[0].sequence == 0 && next.histories[0].sequence == 1 && next.acceptedTime == 0.001)
        var rejected=false
        do throws(DeformingContactError) {
            _=try TetrahedralBoundaryUpdater().point(witness.first,in:snapshot,policy:deformingProbePolicy(cells:1),work:&work)
        } catch {
            if case .capacityExceeded=error { rejected=true } else { throw error }
        }
        try require(rejected)
    }

    @inline(never) private static func deformingProbeSnapshot() throws -> DeformingSurfaceSnapshot {
        let frame=try EntityID(kind:.frame,key:"deforming-world"),source=try SourceProvenance(source:"physical self-contact solid",revision:1)
        let material=try FlexibleMaterial(identifier:EntityID(kind:.material,key:"deforming-solid"),source:source,
            law:PolynomialHyperelasticity(elasticity:IsotropicElasticity(bulkModulus:1000,shearModulus:400),
                nonlinearModulus:0,domain:StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.1)),referenceDensity:1,massDampingRate:0)
        let points:[Vector3]=[.zero,.unitX,.unitY,.unitZ,try Vector3(0.2,0.2,0.01),try Vector3(0.3,0.2,0.01),
            try Vector3(0.2,0.3,0.01),try Vector3(0.2,0.2,0.11)]
        let nodes=points.enumerated().map { FlexibleNode(identifier:UInt64(10+$0.offset),referencePosition:$0.element) }
        let cells=[try TetrahedronCell(identifier:100,nodes:[0,1,2,3],material:material.identifier,source:source),
            try TetrahedronCell(identifier:101,nodes:[4,5,6,7],material:material.identifier,source:source)]
        let raw=try TetrahedralMesh(frame:frame,revision:1,source:source,nodes:nodes,cells:cells,materials:[material])
        var work=NumericalWork(budget:try NumericalBudget(scalarStorage:100000,arithmeticOperations:10000000,iterations:0))
        let mesh=try TetrahedralMeshValidator().validate(raw,
            admission:MeshAdmission(maximumNodes:8,maximumCells:2,maximumMaterials:1,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12),work:&work)
        let updater: any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater(),policy=try deformingProbePolicy()
        let surface=try updater.extract(mesh,body:ModelReference(id:EntityID(kind:.body,key:"deforming-body"),revision:1),policy:policy,work:&work)
        var velocities=[Vector3](repeating:.zero,count:8);velocities[4] = .unitX
        let state=NodalState(frame:frame,meshRevision:1,nodeIdentifiers:nodes.map { $0.identifier },positions:points,velocities:velocities)
        return try updater.update(surface,state:state,geometryRevision:1,time:0,previous:nil,policy:policy,work:&work)
    }

    private static func deformingProbePolicy(cells: Int=2) throws(DeformingContactError) -> DeformingContactPolicy {
        try DeformingContactPolicy(maximumNodes:8,maximumCells:cells,maximumFaces:8,maximumContacts:1,maximumIdentifierBytes:100,
            minimumVolume:1e-12,minimumDoubleArea:1e-10,lengthTolerance:1e-9,barycentricInterior:1e-7,
            forceTolerance:1e-7,momentTolerance:1e-7,powerTolerance:1e-7,rotationTolerance:1e-10)
    }

    @inline(never) private static func deformingProbePair() throws -> ContactLawPair {
        let material=try ContactMaterial(reference:ModelReference(id:EntityID(kind:.material,key:"deforming-contact"),revision:1),
            youngModulus:1e6,poissonsRatio:0.25,linearStiffness:2000,normalDamping:0,huntCrossleyAlpha:0,
            friction:.elasticCoulomb(ContactFrictionParameters(staticFirst:0.8,staticSecond:0.8,dynamicFirst:0.4,dynamicSecond:0.4,
                tangentialStiffness:2000,transitionSpeed:0.1)),
            resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none)
        var work=ContactWork(budget:try ContactBudget(operations:100000,scalarStorage:1000,records:1))
        let pairing: any ContactMaterialPairing=SeriesContactPairing()
        return try pairing.combine(first:material,second:material,selection:.linear(maximumPenetration:0.2,maximumNormalSpeed:100),
            lossPolicy:.compliantDampingOnly,resistanceRadius:1,override:nil,work:&work)
    }
}
