import SwiftMechanics
@available(macOS 15.0, *)
public struct ModalReductionQualificationCases: ModalReductionQualifying, Sendable {
    public init() {}
    public func run(_ selected: ModalReductionQualificationCase) throws(ModalReductionQualificationError) {
        switch selected {
        case .constitutiveReconstruction: try constitutiveReconstruction()
        case .locationAndSource: try locationAndSource()
        case .originalForceEnergyPower: try originalForceEnergyPower()
        case .finiteDomainAndLegacy: try finiteDomainAndLegacy()
        case .workAndCallLimits: try workAndCallLimits()
        case .cooperativeCancellation: try cooperativeCancellation()
        }
    }
    private typealias F = ModalReductionQualificationFixtures
    private func constitutiveReconstruction() throws(ModalReductionQualificationError) {
        let state=try F.state(F.prepared()),result=try F.query(state),field=result.sample.field
        try F.matrix(field.deformationGradient,[1,0.2,0,0,1,0,0,0,1],"Original current F")
        try F.matrix(F.material { () throws(MaterialError) in try field.response.greenStrain.matrix() },[0,0.1,0,0.1,0.02,0,0,0,0],"Finite Green strain")
        try F.matrix(F.material { () throws(MaterialError) in try field.response.secondPiolaStress.matrix() },[0.2,0.6,0,0.6,0.32,0,0,0,0.2],"Current material second Piola")
        try F.matrix(field.response.firstPiolaStress,[0.32,0.664,0,0.6,0.32,0,0,0,0.2],"Current material first Piola")
        try F.matrix(field.response.cauchyStress,[0.4528,0.664,0,0.664,0.32,0,0,0,0.2],"Actual current Cauchy")
        try F.require(abs(field.response.firstPiolaStress.m01-0.6)>0.06 && field.response.firstPiolaStress.m00>0.3,"Frozen infinitesimal tangent cannot certify actual stress")
        try F.near(field.response.energyDensity,0.0632,"Independent reference energy density")
        try F.require(result.sample.snapshot.constitutiveWork.calls==1,"Actual one-cell material evaluate ledger")
        do throws(ModalReductionQualificationError) {
            _=try F.prepared(operatingShear:0.1)
            throw ModalReductionQualificationError.assertion("Original non-dyadic operating pencil must not be silently accepted")
        } catch {
            switch error {
            case .modal(.structural(.nonsymmetric)): break
            default: throw error
            }
        }
        let operating=try F.prepared(operatingShear:0.125),increment=try F.state(operating,shear:0.075)
        let shifted=try F.query(increment)
        try F.matrix(shifted.sample.field.deformationGradient,[1,0.2,0,0,1,0,0,0,1],"Actual operating positions plus modal increments")
        try F.matrix(shifted.sample.stress,[0.32,0.664,0,0.6,0.32,0,0,0,0.2],"Current law independent of frozen operating tangent")
    }
    private func locationAndSource() throws(ModalReductionQualificationError) {
        let model=try F.prepared(),state=try F.state(model),a=try F.query(state),b=try F.query(state,location:F.location([0,0,1,0]))
        try F.near(a.sample.referencePosition,F.vector(0.25,0.25,0.25),"Original centroid location")
        try F.near(a.sample.currentPosition,F.vector(0.30,0.25,0.25),"Current material centroid")
        try F.near(a.sample.velocity,F.vector(0.075,0,0),"Current material velocity")
        try F.near(b.sample.currentPosition,F.vector(0.2,1,0),"Selected original node location")
        try F.matrix(b.sample.stress,F.entries(a.sample.stress),"Constant F stress location invariance")
        try F.require(a.state.model.pencil.binding==model.pencil.binding && a.sample.location.cell==50 && a.sample.location.meshRevision==7,"Modal and material binding retained")
        let source=a.sample.snapshot.source.mesh.mesh,field=a.sample.field
        try F.require(source.source==model.pencil.binding.provenance && source.frame==model.pencil.binding.frame && source.revision==7,"Mesh source frame and revision retained")
        try F.require(field.material.identifier==source.materials[0].identifier && field.material.source==source.materials[0].source && field.cell.source==source.cells[0].source,"Original material and cell provenance")
        try F.require(a.sample.snapshot.state.nodeIdentifiers==[10,11,12,13] && a.sample.snapshot.timeSeconds==0.5 && a.sample.snapshot.geometryRevision==4 && a.sample.stressMeasure == .firstPiola && a.sample.projection == .elementConstant,"Explicit layout time epoch measure and projection")
        try F.require(a.sample.snapshot.source !== b.sample.snapshot.source,"Independent query owners do not infer accepted history")
        let foreign=try F.prepared(revision:8);let reducer:any ModalReducing=ReferenceModalReducer();let policy=try F.fieldPolicy(),location=try F.location()
        var work=try F.work(),calls=try F.calls()
        try F.expect({ if case .staleBinding=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:foreign.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&calls,work:&work) }
        try F.require(calls.calls==0,"Stale binding precedes material call")
        for bad in [try F.location(revision:8),try F.location(cell:999),try F.location([0.2,0.2,0.2,0.2])] {
            var local=try F.work(),ledger=try F.calls()
            try F.expect({ if case .field(.invalidLocation)=$0 {true} else {false} }) { () throws(ModalReductionError) in
                _=try reducer.tetrahedralStress(state,expectedBinding:model.pencil.binding,location:bad,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&ledger,work:&local) }
            try F.require(ledger.calls==1 && local.operations>935,"Late location refusal preserves actual spent material/numerical work")
        }
    }
    private func originalForceEnergyPower() throws(ModalReductionQualificationError) {
        let result=try F.query(F.state(F.prepared())),snapshot=result.sample.snapshot
        let expected=try [F.vector(-0.984/6,-0.92/6,-0.2/6),F.vector(0.32/6,0.6/6,0),F.vector(0.664/6,0.32/6,0),F.vector(0,0,0.2/6)]
        var rx=0.0,ry=0.0,rz=0.0,mx=0.0,my=0.0,mz=0.0,power=0.0
        for i in 0..<4 {
            let f=snapshot.internalForces[i],x=snapshot.state.positions[i],v=snapshot.state.velocities[i]
            try F.near(f,expected[i],"Original nodal positive energy gradient")
            rx+=f.x;ry+=f.y;rz+=f.z;mx+=x.y*f.z-x.z*f.y;my+=x.z*f.x-x.x*f.z;mz+=x.x*f.y-x.y*f.x
            power+=f.x*v.x+f.y*v.y+f.z*v.z
        }
        try F.near(rx,0,"Original force x");try F.near(ry,0,"Original force y");try F.near(rz,0,"Original force z")
        try F.near(mx,0,"Original world moment x");try F.near(my,0,"Original world moment y");try F.near(mz,0,"Original world moment z")
        try F.near(snapshot.storedEnergy,0.0632/6,"Original reference-volume energy")
        try F.near(power,0.0332,"Original nodal physical power");try F.near(snapshot.internalPower,0.0332,"Original constitutive P:Fdot power")
        // Independent derivative of psi(gamma)=1.5*gamma^2+2*gamma^4.
        let gamma=0.2,analyticDerivative=(3*gamma+8*gamma*gamma*gamma)/6
        try F.near(snapshot.internalForces[2].x,analyticDerivative,"Independent physical virtual-work derivative")
        try F.near(snapshot.internalForces[2].x*0.7,(0.664/6)*0.7,"Independent original-coordinate virtual work")
    }
    private func finiteDomainAndLegacy() throws(ModalReductionQualificationError) {
        let model=try F.prepared(),state=try F.state(model),reducer:any ModalReducing=ReferenceModalReducer()
        var legacy=try F.flexible { () throws(FlexibleError) in try ConstitutiveCallWork(maximumCalls:13) },work=try F.work()
        try F.expect({ if case .unsupportedSource=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,cellIdentifier:50,constitutiveWork:&legacy,work:&work) }
        try F.require(legacy.calls==0 && work.operations==0,"Legacy ledger contract never silently substituted")
        var displacement=[Double](repeating:0,count:12);let velocity=displacement;displacement[3] = -2
        let inverted=try F.projected(model,displacement),v=try F.projected(model,velocity)
        var inversionWork=try F.work()
        try F.expect({ if case .material(.outsideDomain(measure:"volumeRatio",value:let value,limit:0.2))=$0 { value<0.2 } else { false } }) { () throws(ModalReductionError) in
            _=try reducer.initialState(model,coordinates:inverted,velocities:v,time:0.5,work:&inversionWork) }
        displacement=[Double](repeating:0,count:12);displacement[6]=1
        let strained=try F.projected(model,displacement);var strainWork=try F.work()
        try F.expect({ if case .material(.outsideDomain(measure:"strainNorm",value:let value,limit:0.5))=$0 {value>0.5} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.initialState(model,coordinates:strained,velocities:v,time:0.5,work:&strainWork) }
        let policy=try F.fieldPolicy(minimumVolume:1),location=try F.location();var fieldWork=try F.work(),calls=try F.calls()
        try F.expect({ if case .field(.invertedCell(50))=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&calls,work:&fieldWork) }
        try F.require(calls.calls==0 && fieldWork.operations>935,"Field physical-volume admission precedes material call")
        var invalidWork=try F.work()
        try F.expect({ if case .invalidInput=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.initialState(model,coordinates:[Double](repeating:.nan,count:6),velocities:v,time:0.5,work:&invalidWork) }
    }
    private func workAndCallLimits() throws(ModalReductionQualificationError) {
        let state=try F.state(F.prepared()),location=try F.location(),policy=try F.fieldPolicy(),reducer:any ModalReducing=ReferenceModalReducer()
        var work=try F.work(),calls=try F.calls()
        let result=try F.modal { () throws(ModalReductionError) in try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&calls,work:&work) }
        // Literal source-derived charges: outer935, field evaluate1963, sample864;
        // simultaneous model/nodal1234 plus field826. No guessed law arithmetic.
        try F.require(work.operations==3762 && work.peakScalarStorage==2060 && calls.calls==1,"Exact real numerical/material work")
        try F.require(result.numericalWork==work && result.sample.numericalWork.operations==2827,"Caller aggregate and real supplier work retained")
        var noCalls=try F.calls(0),failed=try F.work()
        try F.expect({ if case .field(.constitutiveCallLimit)=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&noCalls,work:&failed) }
        try F.require(noCalls.calls==0 && failed.operations==1734,"Pre-call limit preserves original charged outer work")
        var storage=try F.work(storage:2059),storageCalls=try F.calls()
        try F.expect({ if case .field(.numerical(.resourceLimit(resource:.scalarStorage,limit:825)))=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&storageCalls,work:&storage) }
        try F.require(storageCalls.calls==0 && storage.operations==935 && storage.peakScalarStorage==1234,"Simultaneous storage gate before material")
        var bounded=try F.work(operations:3761),boundedCalls=try F.calls()
        try F.expect({ if case .field(.numerical(.resourceLimit(resource:.arithmeticOperations,limit:2826)))=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&boundedCalls,work:&bounded) }
        try F.require(boundedCalls.calls==1 && bounded.operations==3698,"Late original operation rejection preserves work prefix")
    }
    private func cooperativeCancellation() throws(ModalReductionQualificationError) {
        let state=try F.state(F.prepared()),location=try F.location(),reducer:any ModalReducing=ReferenceModalReducer()
        let early=ModalReductionCancellationCounter(cancellationCheckpoint:1),earlyPolicy=try F.fieldPolicy(cancelled:{early.check()})
        var earlyWork=try F.work(),earlyCalls=try F.calls()
        try F.expect({ if case .field(.cancelled)=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:earlyPolicy,constitutiveWork:&earlyCalls,work:&earlyWork) }
        try F.require(early.checkpoints==1 && earlyCalls.calls==0 && earlyWork.operations==935,"Early supplier cancellation preserves actual reconstruction work")
        let baseline=ModalReductionCancellationCounter(),policy=try F.fieldPolicy(cancelled:{baseline.check()})
        _=try F.query(state,policy:policy);let checkpoints=baseline.checkpoints
        try F.require(checkpoints>1,"Actual field and publication checkpoints")
        let late=ModalReductionCancellationCounter(cancellationCheckpoint:checkpoints),latePolicy=try F.fieldPolicy(cancelled:{late.check()})
        var lateWork=try F.work(),lateCalls=try F.calls()
        try F.expect({ if case .field(.cancelled)=$0 {true} else {false} }) { () throws(ModalReductionError) in
            _=try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:latePolicy,constitutiveWork:&lateCalls,work:&lateWork) }
        try F.require(late.checkpoints==checkpoints && lateCalls.calls==1 && lateWork.operations==3762,"Cancellation at final publication preserves real work and no output")
    }
    public func awaitedTaskCancellation() async throws(ModalReductionQualificationError) {
        let state=try F.state(F.prepared()),location=try F.location(),policy=try F.fieldPolicy()
        let task=Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            var work=try F.work(),calls=try F.calls();let reducer:any ModalReducing=ReferenceModalReducer()
            try F.expect({ if case .cancelled=$0 {true} else {false} }) { () throws(ModalReductionError) in
                _=try reducer.tetrahedralStress(state,expectedBinding:state.model.pencil.binding,location:location,geometryRevision:4,fieldPolicy:policy,constitutiveWork:&calls,work:&work) }
            try F.require(work.operations==0 && calls.calls==0,"Actual Task cancellation before reconstruction/material work")
        }
        do { try await task.value } catch let error as ModalReductionQualificationError { throw error }
        catch { throw .assertion("Unexpected Native Task failure") }
    }
}
