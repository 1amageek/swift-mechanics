import SwiftMechanics

extension FoundationVerification {
    @inline(never) static func verifyStructuralAnalysis() throws {
        let policy=try StructuralPolicy(maximumCoordinates:32,maximumMetadataBytes:1000,energyScale:100,timeScale:1,
            spectralTolerance:1e-13,positiveMassThreshold:1e-14,originalResidualTolerance:1e-6,zeroEigenvalueThreshold:1e-6,isCancelled:{false})
        let beam=try structuralProbeBeam(elements:4),builder: any StructuralModelBuilding=ReferenceStructuralModelBuilder()
        var work=try structuralProbeWork()
        let pencil=try builder.beam(beam,fixedCoordinates:[0,1],compressiveLoad:0,expectedRevision:1,policy:policy,work:&work)
        let modal: any ModalAnalyzing=ReferenceModalAnalyzer()
        let modes=try modal.modes(pencil,expectedBinding:pencil.binding,policy:policy,work:&work)
        let beta=1.875104068711961,exact=beta*beta*beta*beta*beam.youngModulus*beam.beam.secondMoment/160
        try require(abs(modes.eigenvalues[0]/exact-1)<1e-4 && modes.maximumOriginalResidual<1e-6)
        let buckling: any BucklingAnalyzing=ReferenceBucklingAnalyzer()
        let critical=try buckling.beam(beam,fixedCoordinates:[0,beam.coordinateCount-2],expectedRevision:1,policy:policy,work:&work)
        let euler=Double.pi*Double.pi*beam.youngModulus*beam.beam.secondMoment/4
        try require(abs(critical.criticalLoad/euler-1)<1e-3 && critical.maximumOriginalResidual<1e-6)
        let truss=try NonlinearTruss(identity:"structural-truss",revision:1,frame:beam.beam.frame,source:beam.beam.source,
            halfSpan:1,initialHeight:0.5,axialRigidity:1000,maximumAbsoluteEngineeringStrain:0.2)
        let limit=try buckling.criticalTruss(truss,lowerHeight:0,upperHeight:0.5,positionTolerance:1e-10,expectedRevision:1,policy:policy,work:&work)
        try require(abs(limit.point.height-0.2778800910751648)<1e-8 && abs(limit.point.downwardLoad-38.383739817434744)<1e-7)
        try verifyStructuralHarmonic(policy)
        var rejected=false
        do throws(StructuralError) { _=try buckling.nonlinearBeam(beam,policy:policy,work:&work) }
        catch { if case .unsupportedDomain=error { rejected=true } else { throw error } }
        try require(rejected)
    }

    @inline(never) private static func verifyStructuralHarmonic(_ policy: StructuralPolicy) throws {
        let beam=try structuralProbeBeam(elements:1,damping:4)
        var work=try structuralProbeWork()
        let pencil=try ReferenceStructuralModelBuilder().beam(beam,fixedCoordinates:[0,1,3],compressiveLoad:0,
            expectedRevision:1,policy:policy,work:&work)
        let excitation=HarmonicExcitation(identity:"physical-harmonic-force",angularFrequency:3,maximumAngularFrequency:100,
            maximumNormalizedAmplitude:1,realEffort:[1],imaginaryEffort:[0],outputMap:[1],outputDimensions:[.length])
        let service: any HarmonicAnalyzing=ReferenceHarmonicAnalyzer()
        let response=try service.response(pencil,expectedBinding:pencil.binding,excitation:excitation,
            linearTolerance:LinearTolerance<Double>(absoluteResidual:1e-11,relativeResidual:1e-10,pivotThreshold:1e-14),policy:policy,work:&work)
        let k=12*beam.youngModulus*beam.beam.secondMoment/8,m=156*beam.beam.density*beam.beam.area*2/420
        let real=k-9*m,imaginary=12*m,denominator=real*real+imaginary*imaginary
        try require(abs(response.coordinates[0].real-real/denominator)<1e-10 && abs(response.coordinates[0].imaginary+imaginary/denominator)<1e-10)
        try require(response.maximumOriginalResidual<1e-8)
    }

    @inline(never) private static func structuralProbeBeam(elements: Int,damping: Double=0) throws -> BeamAssembly {
        let beam=try UniformBeam(identity:"structural-beam",revision:1,frame:EntityID(kind:.frame,key:"structural-frame"),
            source:SourceProvenance(source:"calibrated linear beam",revision:1),length:2,area:0.01,secondMoment:1e-5,
            maximumFiberDistance:0.05,density:1000,elasticity:IsotropicElasticity(bulkModulus:1e7,shearModulus:4e6),elements:elements,
            massDamping:damping,stiffnessDamping:0,maximumSlope:0.01,maximumLinearStrain:0.01)
        var work=try structuralProbeWork()
        let service: any BeamAssembling=HermiteBeamAssembler()
        return try service.assemble(beam,admission:BeamAdmission(maximumElements:8,maximumMetadataBytes:1000,isCancelled:{false}),work:&work)
    }
    private static func structuralProbeWork() throws -> NumericalWork {
        NumericalWork(budget:try NumericalBudget(scalarStorage:2000000,arithmeticOperations:100000000,iterations:100000))
    }
}
