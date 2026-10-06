import SwiftMechanics

public struct HexahedraQualificationCases: HexahedraQualifying {
    private typealias F=HexahedraQualificationFixtures
    private typealias E=HexahedraQualificationError
    public init() {}
    public func run(_ selected: HexahedraQualificationCase) throws(HexahedraQualificationError) {
        switch selected {
        case .affinePatchAndTangent: try affine()
        case .nonAffineEnergyGradient: try differential()
        case .finiteObjectivityAndRigidModes: try objectivity()
        case .massAndMaterialAssignments: try mass()
        case .geometryAndBindingRefusals: try refusals()
        case .resourcesAndCancellation:
            if #available(macOS 15.0, *) { try resources() } else { throw .mutexUnavailable }
        }
    }
    private func affine() throws(E) {
        let mesh=try F.mesh(),reference=try F.validate(mesh),state=try F.state(mesh),a=try F.assemble(reference,state)
        try F.near(a.storedEnergy,0.08844310125,"Original literal finite energy")
        try F.near(a.totalReferenceVolume,1,"Original unit volume");try F.near(a.totalReferenceMass,6,"Original density mass")
        let p=[1.8581871,1.05,1.05]
        var direction=[Double](repeating:0,count:24),velocities: [Vector3]=[]
        for i in 0..<8 {
            let b=F.bits[i]
            direction[3*i]=0.2*Double(b[0]);direction[3*i+1] = -0.1*Double(b[1]);direction[3*i+2]=0.05*Double(b[2])
            velocities.append(try F.vector(direction[3*i],direction[3*i+1],direction[3*i+2]))
            for axis in 0..<3 {
                try F.near(a.internalForce[3*i+axis],F.sign(i,axis)*p[axis]/4,"Original nodal force")
                for j in 0..<8 { for otherAxis in 0..<3 {
                    try F.near(a.tangent[(3*i+axis)*24+3*j+otherAxis],F.tangent(i,axis,j,otherAxis),"Independent analytic prestressed tangent")
                } }
            }
        }
        let action=F.action(a.tangent,direction),dp=[3.7238854,0.98618,2.05691]
        for i in 0..<8 { for axis in 0..<3 { try F.near(action[3*i+axis],F.sign(i,axis)*dp[axis]/4,"Original analytic affine dP action") } }
        let power=try F.assemble(reference,F.changed(state,velocities:velocities))
        try F.physical(power,power:0.31913742)
        try F.require(a.nodeIdentifiers==state.nodeIdentifiers && a.coordinateCount==24,"Original node coordinate layout")
        try F.require(a.frame==mesh.frame && a.source==mesh.source && a.meshIdentifier==71 && a.meshRevision==7,"Original reference source/frame binding")
        try F.require(a.state.revision==9 && a.state.source==state.source && a.state.positions==state.positions && a.state.velocities==state.velocities,"Original current source and state retained")
        try F.require(a.reference.mesh.nodes==mesh.nodes && a.reference.mesh.cells==mesh.cells,"Original cell source and boundary metadata retained")
        for i in mesh.materials.indices {
            let actual=a.reference.mesh.materials[i],expected=mesh.materials[i]
            try F.require(actual.identifier==expected.identifier && actual.source==expected.source && actual.law==expected.law && actual.referenceDensity==expected.referenceDensity,"Original material assignment retained")
        }
        try F.require(a.forceDimension == .force && a.massDimension == .mass && a.energyDimension == .energy,"Original SI dimensions")
        try F.require(a.tangentDimension==PhysicalDimension(mass:1,time: -2) && a.dampingDimension==PhysicalDimension(mass:1,time: -1)
            && a.powerDimension==PhysicalDimension(length:2,mass:1,time: -3),"Original tangent/damping/power dimensions")
        try F.require(a.constitutiveWork.calls==200 && reference.scalarStorage==336,"Actual constitutive call/cache contracts")
    }
    private func differential() throws(E) {
        let mesh=try F.mesh(),reference=try F.validate(mesh),original=try F.state(mesh)
        var displacement=[Double](repeating:0,count:24),direction=displacement
        for i in 0..<24 {
            displacement[i]=Double((7*i+3)%11-5)*0.002
            direction[i]=Double((5*i+1)%13-6)*0.03
        }
        let state=try F.perturb(original,displacement,1),a=try F.assemble(reference,state)
        let plus=try F.assemble(reference,F.perturb(state,direction,1e-6)),minus=try F.assemble(reference,F.perturb(state,direction, -1e-6))
        let action=F.action(a.tangent,direction)
        var energyRate=0.0
        for i in 0..<24 {
            energyRate+=a.internalForce[i]*direction[i]
            try F.near((plus.internalForce[i]-minus.internalForce[i])/2e-6,action[i],"Original non-affine energy Hessian action",tolerance:2e-6)
            for j in 0..<24 { try F.near(a.tangent[i*24+j],a.tangent[j*24+i],"Original Hessian symmetry") }
        }
        try F.near((plus.storedEnergy-minus.storedEnergy)/2e-6,energyRate,"Original positive energy-gradient convention",tolerance:2e-6)
        var velocities: [Vector3]=[]
        for i in 0..<8 { velocities.append(try F.vector(direction[3*i],direction[3*i+1],direction[3*i+2])) }
        let physical=try F.assemble(reference,F.changed(state,velocities:velocities))
        try F.physical(physical,power:energyRate)
    }
    private func objectivity() throws(E) {
        let mesh=try F.mesh(),reference=try F.validate(mesh),base=try F.assemble(reference,F.state(mesh))
        let rotated=try F.assemble(reference,F.state(mesh,rotated:true))
        try F.near(rotated.storedEnergy,base.storedEnergy,"Finite superposed rotation energy")
        let index=[1,0,2],sign=[-1.0,1.0,1.0]
        for i in 0..<8 { for axis in 0..<3 {
            try F.near(rotated.internalForce[3*i+axis],sign[axis]*base.internalForce[3*i+index[axis]],"Finite rotated nodal force")
            for j in 0..<8 { for b in 0..<3 {
                try F.near(rotated.tangent[(3*i+axis)*24+3*j+b],sign[axis]*sign[b]*base.tangent[(3*i+index[axis])*24+3*j+index[b]],"Finite rotated spatial tangent")
            } }
        } }
        let rigid=try F.assemble(reference,F.state(mesh,stretch:1,rotated:true))
        try F.near(rigid.storedEnergy,0,"Pure finite rotation strain energy",tolerance:1e-20)
        for force in rigid.internalForce { try F.near(force,0,"Pure finite rotation force") }
        let rest=try F.assemble(reference,F.state(mesh,stretch:1))
        for mode in 0..<6 {
            var d=[Double](repeating:0,count:24)
            for i in 0..<8 {
                let x=mesh.nodes[i].referencePosition
                if mode<3 { d[3*i+mode]=1 }
                else if mode==3 { d[3*i+1] = -x.z;d[3*i+2]=x.y }
                else if mode==4 { d[3*i]=x.z;d[3*i+2] = -x.x }
                else { d[3*i] = -x.y;d[3*i+1]=x.x }
            }
            for value in F.action(rest.tangent,d) { try F.near(value,0,"Six original stress-free rigid modes") }
        }
    }
    private func mass() throws(E) {
        let mesh=try F.mesh(),reference=try F.validate(mesh),state=try F.state(mesh)
        let consistent=try F.assemble(reference,state),lumped=try F.assemble(reference,state,mass:.rowSumLumped)
        for i in 0..<8 { for axis in 0..<3 {
            var row=0.0
            for j in 0..<8 { for b in 0..<3 {
                let expected=axis==b ? 6*F.zeroMoment(i,j,0)*F.zeroMoment(i,j,1)*F.zeroMoment(i,j,2) : 0
                let entry=(3*i+axis)*24+3*j+b
                try F.near(consistent.mass[entry],expected,"Exact separable consistent mass")
                try F.near(consistent.damping[entry],0.25*expected,"Original mass damping")
                try F.near(lumped.mass[entry],i==j && axis==b ? 0.75 : 0,"Original exact row lump")
                row+=consistent.mass[entry]
            } }
            try F.near(row,0.75,"Original row mass conservation")
            try F.near(consistent.dampingForce[3*i+axis],F.bits[i][axis]==1 ? 0.125 : 0.0625,"Exact consistent damping force")
            try F.near(lumped.dampingForce[3*i+axis],Double(F.bits[i][axis])*0.1875,"Exact lumped damping force")
        } }
        try F.near(consistent.dissipatedPower,1.5,"Exact consistent damping integral")
        try F.near(lumped.dissipatedPower,2.25,"Exact lumped damping integral")
        for a in [consistent,lumped] {
            var matrixPower=0.0
            for i in 0..<24 { matrixPower+=a.dampingForce[i]*F.component(state.velocities[i/3],i%3) }
            try F.near(a.dissipatedPower,matrixPower,"Original damping quadratic power")
        }
        let two=try F.mesh(two:true),twoRef=try F.validate(two),mixed=try F.assemble(twoRef,F.state(two))
        try F.near(mixed.totalReferenceVolume,2,"Disconnected original volumes")
        try F.near(mixed.totalReferenceMass,18,"Assigned density mass")
        try F.near(mixed.storedEnergy,3*0.08844310125,"Assigned independent material energy")
        try F.near(mixed.dissipatedPower,7.5,"Assigned damping integral")
        let mixedLump=try F.assemble(twoRef,F.state(two),mass:.rowSumLumped)
        try F.near(mixedLump.dissipatedPower,11.25,"Assigned lumped damping integral")
        for i in 0..<48 {
            let scale=i<24 ? 1.0 : 2.0
            try F.near(mixed.internalForce[i],scale*consistent.internalForce[i%24],"Assigned material force")
            for j in 0..<48 {
                let same=i/24==j/24,entry=i*48+j,original=(i%24)*24+j%24
                try F.near(mixed.mass[entry],same ? scale*consistent.mass[original] : 0,"Disconnected exact mass blocks")
                try F.near(mixed.tangent[entry],same ? scale*consistent.tangent[original] : 0,"Assigned tangent blocks")
                try F.near(mixed.damping[entry],same ? scale*scale*consistent.damping[original] : 0,"Assigned damping blocks")
            }
        }
        try F.physical(mixed,power:3*(1.8581871+2.1))
        let warped=try F.mesh(warp:0.2,warpY:0.1,warpZ:0.1),warpedRef=try F.validate(warped)
        let warpedState=try F.state(warped,stretch:1),w=try F.assemble(warpedRef,warpedState),wl=try F.assemble(warpedRef,warpedState,mass:.rowSumLumped)
        try F.near(w.totalReferenceVolume,1.1,"Exact warped original volume")
        try F.near(w.totalReferenceMass,6.6,"Exact warped reference mass");try F.near(w.storedEnergy,0,"Warped reference rest energy")
        for f in w.internalForce { try F.near(f,0,"Warped reference rest force") }
        for i in 0..<8 { for axis in 0..<3 {
            var exactRow=0.0
            for j in 0..<8 {
                let z0=F.zeroMoment(i,j,0),z1=F.zeroMoment(i,j,1),z2=F.zeroMoment(i,j,2)
                let x0=F.firstMoment(i,j,0),x1=F.firstMoment(i,j,1),x2=F.firstMoment(i,j,2)
                let expected=6*(z0*z1*z2+0.2*z0*x1*x2+0.1*x0*z1*x2+0.1*x0*x1*z2)
                exactRow+=expected
                for b in 0..<3 { try F.near(w.mass[(3*i+axis)*24+3*j+b],axis==b ? expected : 0,"Exact warped separable mass") }
            }
            try F.near(wl.mass[(3*i+axis)*24+3*i+axis],exactRow,"Exact warped row-sum mass")
        } }
    }
    private func refusals() throws(E) {
        let mesh=try F.mesh(),reference=try F.validate(mesh),state=try F.state(mesh)
        let badReference=try F.mesh(warp: -1.3)
        let validator: any HexahedralMeshValidating=HexahedralMeshValidator()
        let assembler: any HexahedralAssembling=TotalLagrangianHexahedra()
        let policy=try F.policy()
        var work=try F.work(),calls=try F.calls()
        try F.expect(.referenceJacobianNotCertified(cell:50)) { () throws(HexahedralError) in _=try validator.validate(badReference,admission:policy,work:&work) }
        let badCurrent=try F.state(badReference,stretch:1)
        let originalCurrent=F.changed(state,positions:badCurrent.positions)
        try F.expect(.currentJacobianNotCertified(cell:50)) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:originalCurrent,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        try F.require(calls.calls==0,"Whole-cube current refusal precedes actual material call")
        let conservative=try F.policy(floor:0.02,margin:0.9)
        try F.expect(.referenceJacobianNotCertified(cell:50)) { () throws(HexahedralError) in _=try validator.validate(mesh,admission:conservative,work:&work) }
        let frame=try F.identity(.frame,"different-world"),origin=try F.provenance("changed-reference",7)
        var ids=state.nodeIdentifiers;ids[0]+=1
        let states=[F.changed(state,identifier:72),F.changed(state,revision:8),F.changed(state,frame:frame),F.changed(state,source:origin),F.changed(state,ids:ids),F.changed(state,positions:[]),F.changed(state,velocities:[])]
        for bad in states {
            try F.expect(.layoutMismatch) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:bad,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        }
        let narrow=try F.policy(nodes:7)
        try F.expect(.capacityExceeded) { () throws(HexahedralError) in _=try validator.validate(mesh,admission:narrow,work:&work) }
        var nodes=mesh.nodes;nodes[1]=FlexibleNode(identifier:nodes[0].identifier,referencePosition:nodes[1].referencePosition)
        let duplicate=try F.changed(mesh,nodes:nodes)
        try F.expect(.invalidIdentity) { () throws(HexahedralError) in _=try validator.validate(duplicate,admission:policy,work:&work) }
        nodes=mesh.nodes;nodes.append(FlexibleNode(identifier:1000,referencePosition:.zero))
        let unused=try F.changed(mesh,nodes:nodes)
        try F.expect(.unusedNode) { () throws(HexahedralError) in _=try validator.validate(unused,admission:policy,work:&work) }
        let cellSource=mesh.cells[0].source,material=mesh.cells[0].material
        let duplicateCell=try F.hex { () throws(HexahedralError) in try HexahedronCell(identifier:51,nodes:[0,1,2,3,4,5,6,7],material:material,source:cellSource) }
        let duplicateMesh=try F.changed(mesh,cells:[mesh.cells[0],duplicateCell])
        try F.expect(.duplicateCell) { () throws(HexahedralError) in _=try validator.validate(duplicateMesh,admission:policy,work:&work) }
        let invalid=try F.hex { () throws(HexahedralError) in try HexahedronCell(identifier:50,nodes:[0,1,2,3,4,5,6,6],material:material,source:cellSource) }
        let invalidMesh=try F.changed(mesh,cells:[invalid])
        try F.expect(.invalidConnectivity) { () throws(HexahedralError) in _=try validator.validate(invalidMesh,admission:policy,work:&work) }
        let unknown=try F.identity(.material,"missing")
        let missing=try F.hex { () throws(HexahedralError) in try HexahedronCell(identifier:50,nodes:[0,1,2,3,4,5,6,7],material:unknown,source:cellSource) }
        let missingMesh=try F.changed(mesh,cells:[missing])
        try F.expect(.missingMaterial) { () throws(HexahedralError) in _=try validator.validate(missingMesh,admission:policy,work:&work) }
        let compression=try F.state(mesh,stretch:0.1),strain=try F.state(mesh,stretch:3)
        calls=try F.calls();work=try F.work()
        try F.domain("volumeRatio",limit:0.2) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:compression,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        try F.require(calls.calls==1,"Original volume domain producer work retained")
        calls=try F.calls();work=try F.work()
        try F.domain("strainNorm",limit:2) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:strain,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        try F.require(calls.calls==1,"Original strain domain producer work retained")
        try F.expect(.invalidParameter) { () throws(HexahedralError) in _=try HexahedralAdmission(maximumNodes:8,maximumCells:1,maximumMaterials:1,minimumReferenceDeterminant:.nan,minimumCurrentDeterminant:1e-12,certificateRelativeMargin:0,inverseRelativeTolerance:1e-12) }
    }
    @available(macOS 15.0, *)
    private func resources() throws(E) {
        let mesh=try F.mesh(),state=try F.state(mesh),policy=try F.policy()
        let validator: any HexahedralMeshValidating=HexahedralMeshValidator()
        var successWork=try F.work(storage:472)
        let reference=try F.hex { () throws(HexahedralError) in try validator.validate(mesh,admission:policy,work:&successWork) }
        try F.require(successWork.peakScalarStorage==472,"Exact original reference storage boundary")
        var work=try F.work(storage:471)
        try F.expect(.numerical(.resourceLimit(resource:.scalarStorage,limit:471))) { () throws(HexahedralError) in _=try validator.validate(mesh,admission:policy,work:&work) }
        work=try F.work(operations:successWork.operations-1)
        try F.expect(.numerical(.resourceLimit(resource:.arithmeticOperations,limit:successWork.operations-1))) { () throws(HexahedralError) in _=try validator.validate(mesh,admission:policy,work:&work) }
        let assembler: any HexahedralAssembling=TotalLagrangianHexahedra()
        successWork=try F.work(storage:2240)
        var calls=try F.calls(200)
        _=try F.hex { () throws(HexahedralError) in try assembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&calls,work:&successWork) }
        try F.require(successWork.peakScalarStorage==2240 && calls.calls==200,"Exact assembly storage/call boundary")
        work=try F.work(storage:2239);calls=try F.calls()
        try F.expect(.numerical(.resourceLimit(resource:.scalarStorage,limit:2239))) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        try F.require(calls.calls==0,"Capacity refusal before constitutive work")
        work=try F.work(operations:successWork.operations-1)
        try F.expect(.numerical(.resourceLimit(resource:.arithmeticOperations,limit:successWork.operations-1))) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        work=try F.work();calls=try F.calls(199)
        try F.expect(.constitutiveCallLimit(limit:199)) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        try F.require(calls.calls==199,"Actual admitted calls retained at refusal")
        let observed=HexahedraCancellationCounter(),observedAssembler: any HexahedralAssembling=TotalLagrangianHexahedra(isCancelled:{observed.check()})
        work=try F.work();calls=try F.calls(200)
        let prior=try F.hex { () throws(HexahedralError) in try observedAssembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&calls,work:&work) }
        let last=HexahedraCancellationCounter(cancelAt:observed.count),cancelledAssembler: any HexahedralAssembling=TotalLagrangianHexahedra(isCancelled:{last.check()})
        var cancelledWork=try F.work(),cancelledCalls=try F.calls(200)
        try F.expect(.cancelled) { () throws(HexahedralError) in _=try cancelledAssembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&cancelledCalls,work:&cancelledWork) }
        try F.require(last.count==observed.count && cancelledCalls.calls==200 && cancelledWork==work,"Late publication cancellation preserves complete charged work")
        try F.require(prior.state.positions==state.positions && prior.internalForce.count==24,"Prior immutable result survives cancellation")
        let early: any HexahedralAssembling=TotalLagrangianHexahedra(isCancelled:{true})
        cancelledWork=try F.work();cancelledCalls=try F.calls()
        try F.expect(.cancelled) { () throws(HexahedralError) in _=try early.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&cancelledCalls,work:&cancelledWork) }
        try F.require(cancelledCalls.calls==0 && cancelledWork.operations==0 && cancelledWork.peakScalarStorage==0,"Early cancellation precedes work/allocation")
        let validationObserved=HexahedraCancellationCounter(),validationPolicy=try F.policy(cancelled:{validationObserved.check()})
        work=try F.work()
        _=try F.hex { () throws(HexahedralError) in try validator.validate(mesh,admission:validationPolicy,work:&work) }
        let validationLast=HexahedraCancellationCounter(cancelAt:validationObserved.count),lastPolicy=try F.policy(cancelled:{validationLast.check()})
        cancelledWork=try F.work()
        try F.expect(.cancelled) { () throws(HexahedralError) in _=try validator.validate(mesh,admission:lastPolicy,work:&cancelledWork) }
        try F.require(validationLast.count==validationObserved.count && cancelledWork==work,"Late reference cache publication cancellation")
    }
    public func taskCancellationEntry() throws(HexahedraQualificationError) -> @Sendable () throws(HexahedraQualificationError) -> Void {
        let mesh=try F.mesh(),reference=try F.validate(mesh),state=try F.state(mesh)
        return {
            let assembler: any HexahedralAssembling=TotalLagrangianHexahedra()
            var work=try F.work(),calls=try F.calls()
            try F.expect(.cancelled) { () throws(HexahedralError) in _=try assembler.assemble(reference,state:state,massForm:.consistent,constitutiveWork:&calls,work:&work) }
            try F.require(work.operations==0 && work.peakScalarStorage==0 && calls.calls==0,"Actual awaited Task cancellation precedes storage and material")
        }
    }
}
