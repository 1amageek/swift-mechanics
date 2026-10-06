import SwiftMechanics

public struct FieldOutputsQualificationCases: FieldOutputsQualifying {
    private typealias F=FieldOutputsQualificationFixtures
    public init() {}
    public func run(_ selected: FieldOutputsQualificationCase) throws(FieldOutputsQualificationError) {
        switch selected {
        case .affineShearAndSampling:try affineShearAndSampling()
        case .volumetricAndAssembly:try volumetricAndAssembly()
        case .rotationWithinDomain:try rotationWithinDomain()
        case .averagingAndMaterials:try averagingAndMaterials()
        case .sourceAndLocationRefusals:try sourceAndLocationRefusals()
        case .resourcesAndCancellation:try resourcesAndCancellation()
        }
    }
    private func affineShearAndSampling() throws(FieldOutputsQualificationError) {
        let source=try F.source(),state=try F.state(source,f:F.shear()),snapshot=try F.evaluate(source,state)
        let cell=snapshot.cells[0],p=try F.shearP()
        try F.near(cell.deformationGradient,F.shear(),"Original current affine F")
        try F.near(cell.response.firstPiolaStress,p,"Original first Piola Pa")
        try F.near(F.material { () throws(MaterialError) in try cell.response.greenStrain.matrix() },F.shearE(),"Original Green strain dimensionless")
        try F.near(F.material { () throws(MaterialError) in try cell.response.secondPiolaStress.matrix() },F.shearS(),"Original second Piola Pa")
        try F.near(cell.response.cauchyStress,F.shearCauchy(),"Original Cauchy Pa")
        try F.near(cell.referenceVolume,1.0/6,"Original reference volume m3");try F.near(cell.currentVolume,1.0/6,"Actual current volume m3")
        try F.near(cell.response.energyDensity,79.0/1250,"Original reference energy density")
        try F.physical(snapshot,p:p,energy:79.0/7500,power:319.0/7500)
        let interior=try F.sample(snapshot,F.location([0.4,0.1,0.2,0.3]))
        try F.near(interior.referencePosition,F.vector(0.1,0.2,0.3),"Material location in original reference frame")
        try F.near(interior.currentPosition,F.vector(2.14,-0.8,0.8),"Actual affine current location meters")
        try F.near(interior.displacement,F.vector(2.04,-1,0.5),"Actual material displacement meters")
        try F.near(interior.velocity,F.vector(1.07,-2.01,0.56),"Actual affine material velocity m/s")
        for measure in [FieldStressMeasure.firstPiola,.secondPiola,.cauchy] {
            let a=try F.sample(snapshot,F.location([1,0,0,0]),measure:measure)
            let b=try F.sample(snapshot,F.location([0,0,1,0]),measure:measure)
            let expected: Matrix3
            switch measure { case .firstPiola:expected=p;case .secondPiola:expected=try F.shearS();case .cauchy:expected=try F.shearCauchy();default:throw .assertion("Fixture measure") }
            try F.near(a.stress,expected,"Element-constant selected measure");try F.near(b.stress,expected,"Location invariant selected measure")
            try F.require(a.projection == .elementConstant && a.stressMeasure == measure && a.snapshot === snapshot && a.field.cell.identifier==50,"Original measure/projection/cell owner")
        }
        try F.require(snapshot.source === source && snapshot.timeSeconds==0.5 && snapshot.geometryRevision==4,"Original source/time/geometry owner")
        try F.require(snapshot.state.frame == source.mesh.mesh.frame && snapshot.state.meshRevision==7 && source.mesh.mesh.source.source=="qualified-field-mesh","Original frame/revision/source")
        try F.require(cell.cell.source == source.mesh.mesh.cells[0].source && cell.material.source == source.mesh.mesh.materials[0].source && cell.material.law.nonlinearModulus==0,"Original cell/material/domain authority")
        try F.near(cell.material.law.domain.maximumStrainNorm,0.5,"Declared small Green-strain norm domain")
        let h=try F.rate(),base=try F.shear(),delta=1e-3
        var energies: [Double]=[]
        for t in [-2*delta,-delta,delta,2*delta] {
            let a=F.entries(base),b=F.entries(h)
            var entries: [Double]=[]
            for i in 0..<9 { entries.append(a[i]+t*b[i]) }
            let trial=try F.evaluate(source,F.state(source,f:F.matrix(entries)))
            energies.append(trial.storedEnergy)
        }
        let derivative=(energies[0]-8*energies[1]+8*energies[2]-energies[3])/(12*delta)
        try F.near(derivative,319.0/7500,"Independent energy derivative equals positive internal power",tolerance:1e-8)
    }
    private func volumetricAndAssembly() throws(FieldOutputsQualificationError) {
        let source=try F.source(),state=try F.state(source,f:F.volumetric()),snapshot=try F.evaluate(source,state),cell=snapshot.cells[0]
        let p=try F.volumetric(2079.0/500)
        try F.near(cell.volumeRatio,1331.0/1000,"Original volumetric J")
        try F.near(cell.currentVolume,1331.0/6000,"Original current volume")
        try F.near(F.material { () throws(MaterialError) in try cell.response.greenStrain.matrix() },F.volumetric(21.0/200),"Original volumetric Green strain")
        try F.near(F.material { () throws(MaterialError) in try cell.response.secondPiolaStress.matrix() },F.volumetric(189.0/50),"Original volumetric second Piola")
        try F.near(cell.response.firstPiolaStress,p,"Original volumetric first Piola")
        try F.near(cell.response.cauchyStress,F.volumetric(189.0/55),"Original volumetric Cauchy")
        try F.near(cell.response.energyDensity,11907.0/20000,"Original volumetric energy density")
        try F.physical(snapshot,p:p,energy:3969.0/40000,power:693.0/4000)
        let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator(),policy=try F.policy(),expected=try F.positiveForces(p)
        for form in [FlexibleMassForm.consistent,.rowSumLumped] {
            var work=try F.work(),calls=try F.flexible { () throws(FlexibleError) in try ConstitutiveCallWork(maximumCalls:13) }
            let diagnostics=try F.field { () throws(FieldOutputError) in try evaluator.assemblyDiagnostics(snapshot,massForm:form,policy:policy,work:&work,constitutiveWork:&calls) }
            try F.require(diagnostics.snapshot === snapshot && calls.calls==13 && snapshot.constitutiveWork.calls==1,"Actual separate field evaluate/assembler tangent ledgers")
            try F.near(diagnostics.assembly.storedEnergy,3969.0/40000,"Actual assembler original energy")
            for i in 0..<4 {
                let force=try F.vector(diagnostics.assembly.internalForce[3*i],diagnostics.assembly.internalForce[3*i+1],diagnostics.assembly.internalForce[3*i+2])
                try F.near(force,expected[i],"Actual assembler original nodal force")
            }
            try F.require(diagnostics.maximumNodalForceResidual<=1e-9 && diagnostics.energyResidual<=1e-9 && diagnostics.resultantForceResidual<=1e-9 && diagnostics.resultantMomentResidual<=1e-9,"Actual assembler original diagnostics")
            try F.require(diagnostics.assembly.massForm==form && diagnostics.assembly.frame==state.frame && diagnostics.assembly.nodeIdentifiers==state.nodeIdentifiers,"Actual assembler units/layout retained")
            try F.near(diagnostics.assembly.totalReferenceMass,1,"Actual selected SI reference mass")
        }
    }
    private func rotationWithinDomain() throws(FieldOutputsQualificationError) {
        let source=try F.source(),r=try F.rotation(),pure=try F.evaluate(source,F.state(source,f:r,rate:.zero))
        try F.near(pure.cells[0].response.energyDensity,0,"Rigid rotation within declared domain has zero energy")
        try F.near(pure.cells[0].response.firstPiolaStress,.zero,"Rigid rotation zero stress")
        try F.physical(pure,p:.zero,energy:0,power:0)
        let f=try F.rotateSpatial(F.shear()),h=try F.rotateSpatial(F.rate()),state=try F.state(source,f:f,rate:h)
        let snapshot=try F.evaluate(source,state),cell=snapshot.cells[0]
        try F.near(F.material { () throws(MaterialError) in try cell.response.greenStrain.matrix() },F.shearE(),"Rotation preserves declared Green strain")
        try F.near(F.material { () throws(MaterialError) in try cell.response.secondPiolaStress.matrix() },F.shearS(),"Material second Piola under allowed rotation")
        let p=try F.rotateSpatial(F.shearP())
        try F.near(cell.response.firstPiolaStress,p,"Spatial first Piola rotation")
        try F.near(cell.response.cauchyStress,F.rotateBoth(F.shearCauchy()),"Spatial Cauchy rotation")
        try F.physical(snapshot,p:p,energy:79.0/7500,power:319.0/7500)
        try F.require(cell.material.law.nonlinearModulus==0 && cell.material.law.domain.maximumStrainNorm==0.5,"No nonlinear/out-of-domain rotation claim")
    }
    private func averagingAndMaterials() throws(FieldOutputsQualificationError) {
        let source=try F.source(mixed:true),state=try F.state(source,f:F.shear()),snapshot=try F.evaluate(source,state)
        try F.require(snapshot.cells.count==2 && snapshot.constitutiveWork.calls==2,"Two real assigned material calls")
        let a=try F.sample(snapshot,F.location([0.25,0.25,0.25,0.25],cell:50)),b=try F.sample(snapshot,F.location([0.25,0.25,0.25,0.25],cell:60))
        try F.near(a.stress,F.shearP(),"First material discontinuous stress")
        try F.near(b.stress,F.volumetric(2079.0/250),"Second actual material discontinuous stress")
        try F.require(a.field.material.identifier != b.field.material.identifier && a.field.material.source != b.field.material.source,"Original distinct material sources")
        let p=try F.shearP(),e=try F.shearE(),s=F.entries(p),strain=F.entries(e),otherP=2079.0/250,otherE=21.0/200
        let exactEnergy=79.0/7500+3969.0/10000
        for weighting in [FieldAveragingPolicy.Weighting.referenceVolume,.currentVolume] {
            let average=try F.average(snapshot,weighting:weighting),ratio=weighting == .referenceVolume ? 2.0 : 2.662
            var stress: [Double]=[],green: [Double]=[]
            for i in 0..<9 {
                let diagonal=i==0 || i==4 || i==8
                stress.append((s[i]+ratio*(diagonal ? otherP : 0))/(1+ratio))
                green.append((strain[i]+ratio*(diagonal ? otherE : 0))/(1+ratio))
            }
            try F.near(average.stress,F.matrix(stress),"Explicit volume reporting stress weights")
            try F.near(average.greenStrain,F.matrix(green),"Explicit volume reporting strain weights")
            try F.near(average.centroidDisplacement,F.vector(2.05,-1+ratio*0.025/(1+ratio),0.5+ratio*0.025/(1+ratio)),"Explicit centroid displacement weights")
            try F.near(average.referenceEnergyDensity,(79.0/1250+ratio*11907.0/10000)/(1+ratio),"Reported reference density weighting")
            try F.near(average.selectedStoredEnergy,exactEnergy,"Exact stored energy sum distinct from current-weighted density")
            try F.near(average.totalWeight,(1+ratio)/6,"Declared total volume weight")
            try F.require(average.snapshot === snapshot && average.selectedCells==[50,60] && average.averaging.materialMixing == .explicitBlend && average.averaging.weighting == weighting,"Selected original averaging authority")
        }
        try F.near(snapshot.storedEnergy,exactEnergy,"Original multi-cell stored energy")
    }
    private func sourceAndLocationRefusals() throws(FieldOutputsQualificationError) {
        let source=try F.source(),state=try F.state(source,f:F.shear()),snapshot=try F.evaluate(source,state),policy=try F.policy()
        let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator()
        func refused(_ input: Tet4FieldSource,_ state: NodalState,_ failure: F.Failure,time: Double = 0.5,revision: UInt64 = 4,previous: Tet4FieldSnapshot? = nil,policy supplied: FieldOutputPolicy? = nil) throws(FieldOutputsQualificationError) {
            var work=try F.work(),calls=try F.calls(input.mesh.mesh.cells.count)
            try F.expect(failure) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:input,state:state,timeSeconds:time,geometryRevision:revision,previous:previous,policy:supplied ?? policy,work:&work,constitutiveWork:&calls) }
        }
        try refused(Tet4FieldSource(mesh:source.mesh),state,.source,previous:snapshot)
        try refused(source,state,.geometry,time:0.4,previous:snapshot)
        try refused(source,state,.geometry,revision:3,previous:snapshot)
        try refused(source,F.state(source,f:F.shear(0.3)),.geometry,previous:snapshot)
        try refused(source,F.state(source,f:F.shear(),rate:.zero),.geometry,previous:snapshot)
        let continued=try F.evaluate(source,state,previous:snapshot,time:0.6,revision:4)
        try F.require(continued.source === source && continued.timeSeconds==0.6,"Same source and unchanged state may retain geometry revision")
        try refused(source,F.changed(state,frame:F.identity(.frame,"other")),.frame)
        try refused(source,F.changed(state,revision:99),.layout)
        try refused(source,F.changed(state,ids:[11,10,12,13]),.layout)
        try refused(source,F.changed(state,positions:Array(state.positions.prefix(3))),.layout)
        try refused(source,state,.invalid,time:.nan)
        try refused(source,state,.invalid,time:-0.1)
        try refused(source,F.state(source,f:F.volumetric(-1)),.inverted)
        try refused(source,F.state(source,f:F.shear(2)),.strainDomain)
        try refused(source,F.state(source,f:F.volumetric(0.4)),.volumeDomain,policy:F.policy(minimumJ:0.01))
        for weights in [[1.0,0,0],[1.1,0,0,-0.1],[Double.nan,0,0,1]] {
            try F.expect(.location) { () throws(FieldOutputError) in _=try Tet4FieldLocation(meshRevision:7,cell:50,barycentric:weights) }
        }
        for location in [try F.location([0.2,0.2,0.2,0.2]),try F.location([1,0,0,0],cell:999),try F.location([1,0,0,0],revision:99)] {
            var work=try F.work()
            try F.expect(.location) { () throws(FieldOutputError) in _=try evaluator.sample(snapshot,location:location,measure:.firstPiola,projection:.elementConstant,policy:policy,work:&work) }
        }
        let location=try F.location([1,0,0,0])
        for mode in 0..<2 {
            var work=try F.work()
            try F.expect(mode==0 ? .stress : .projection) { () throws(FieldOutputError) in _=try evaluator.sample(snapshot,location:location,measure:mode==0 ? .logarithmic : .firstPiola,projection:mode==1 ? .nodalSmoothing : .elementConstant,policy:policy,work:&work) }
        }
        let mixedSource=try F.source(mixed:true),mixed=try F.evaluate(mixedSource,F.state(mixedSource,f:F.shear()))
        for mode in 0..<4 {
            var work=try F.work()
            let selected: [UInt64]=mode==0 ? [50,50] : mode==1 ? [50,999] : mode==2 ? [] : [50,60]
            let wanted: F.Failure=mode==0 ? .duplicate : mode==1 ? .location : mode==2 ? .capacity : .mixed
            try F.expect(wanted) { () throws(FieldOutputError) in _=try evaluator.average(mixed,selectedCells:selected,measure:.firstPiola,projection:.elementConstant,
                averaging:FieldAveragingPolicy(weighting:.referenceVolume,materialMixing:.requireSameMaterial),policy:policy,work:&work) }
        }
    }
    private func resourcesAndCancellation() throws(FieldOutputsQualificationError) {
        let source=try F.source(),state=try F.state(source,f:F.shear()),snapshot=try F.evaluate(source,state),policy=try F.policy()
        let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator(),required=snapshot.numericalWork.operations
        for mode in 0..<3 {
            var work=try F.work(storage:mode==0 ? 825 : 826,operations:mode==1 ? required-1 : required),calls=try F.calls(mode==2 ? 0 : 1)
            let failure: F.Failure=mode==0 ? .storage(825) : mode==1 ? .operations(required-1) : .callLimit
            try F.expect(failure) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:policy,work:&work,constitutiveWork:&calls) }
            if mode==2 { try F.require(calls.calls==0 && work.operations>0,"Call refusal before actual material work") }
        }
        var exact=try F.work(storage:826,operations:required),exactCalls=try F.calls()
        _=try F.field { () throws(FieldOutputError) in try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:policy,work:&exact,constitutiveWork:&exactCalls) }
        try F.require(exact.operations==required && exact.peakScalarStorage==826 && exactCalls.calls==1,"Exact numerical/material/storage boundary")
        for restricted in [try F.policy(nodes:3),try F.policy(cells:1,materials:1,scalars:825),try F.policy(bytes:1)] {
            var work=try F.work(),calls=try F.calls()
            try F.expect(.capacity) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:restricted,work:&work,constitutiveWork:&calls) }
        }
        var failedDomainWork=try F.work(),failedDomainCalls=try F.calls()
        let excessive=try F.state(source,f:F.shear(2))
        try F.expect(.strainDomain) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:source,state:excessive,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:policy,work:&failedDomainWork,constitutiveWork:&failedDomainCalls) }
        try F.require(failedDomainCalls.calls==1 && failedDomainWork.operations>0,"Original material-domain failure preserves real spent call")
        var assemblyWork=try F.work(),assemblyCalls=try F.flexible { () throws(FlexibleError) in try ConstitutiveCallWork(maximumCalls:12) }
        try F.expect(.supplierCalls(12)) { () throws(FieldOutputError) in _=try evaluator.assemblyDiagnostics(snapshot,massForm:.consistent,policy:policy,work:&assemblyWork,constitutiveWork:&assemblyCalls) }
        try F.require(assemblyCalls.calls==12 && assemblyWork.operations>0,"Original assembler call refusal and spent supplier work")
        var shortAssembly=try F.work(storage:1307),enoughCalls=try F.flexible { () throws(FlexibleError) in try ConstitutiveCallWork(maximumCalls:13) }
        try F.expect(.storage(1307)) { () throws(FieldOutputError) in _=try evaluator.assemblyDiagnostics(snapshot,massForm:.consistent,policy:policy,work:&shortAssembly,constitutiveWork:&enoughCalls) }
        try F.require(enoughCalls.calls==0,"Combined storage preflight precedes real assembler")
        let counter=FieldOutputsCancellationCounter(),countPolicy=try F.policy(cancelled:{counter.check()})
        var counted=try F.work(),countedCalls=try F.calls()
        _=try F.field { () throws(FieldOutputError) in try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:countPolicy,work:&counted,constitutiveWork:&countedCalls) }
        let late=FieldOutputsCancellationCounter(cancelAt:counter.count),latePolicy=try F.policy(cancelled:{late.check()})
        var cancelled=try F.work(),cancelledCalls=try F.calls()
        try F.expect(.cancelled) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:latePolicy,work:&cancelled,constitutiveWork:&cancelledCalls) }
        try F.require(late.count==counter.count && cancelled.operations==counted.operations && cancelledCalls.calls==1,"Late cancellation after original field/material work before snapshot publication")
        let immediate=try F.policy(cancelled:{true})
        var early=try F.work(),earlyCalls=try F.calls()
        try F.expect(.cancelled) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:immediate,work:&early,constitutiveWork:&earlyCalls) }
        try F.require(early.operations==0 && early.peakScalarStorage==0 && earlyCalls.calls==0,"Early cancel before allocation/supplier call")
        try F.expect(.invalid) { () throws(FieldOutputError) in _=try FieldConstitutiveWork(maximumCalls:-1) }
    }
    public func taskCancellationEntry() throws(FieldOutputsQualificationError) -> @Sendable () throws(FieldOutputsQualificationError) -> Void {
        let source=try F.source(),state=try F.state(source,f:F.shear()),policy=try F.policy()
        return { () throws(FieldOutputsQualificationError) in
            let evaluator: any Tet4FieldComputing=TetrahedralFieldEvaluator()
            var work=try F.work(),calls=try F.calls()
            try F.expect(.cancelled) { () throws(FieldOutputError) in _=try evaluator.evaluate(source:source,state:state,timeSeconds:0.5,geometryRevision:4,previous:nil,policy:policy,work:&work,constitutiveWork:&calls) }
            try F.require(work.operations==0 && calls.calls==0 && work.peakScalarStorage==0,"Actual Task cancellation before field publication/work")
        }
    }
}
