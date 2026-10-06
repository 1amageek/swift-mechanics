import SwiftMechanics

public struct AttachmentsQualificationCases: AttachmentsQualifying {
    private typealias F = AttachmentsQualificationFixtures
    public init() {}
    public func run(_ selected: AttachmentsQualificationCase) throws(AttachmentsQualificationError) {
        switch selected {
        case .floatingTangentVelocity:try physical(.floating)
        case .sphericalTangentVelocity:try physical(.spherical)
        case .prescribedDerivative:try physical(.prescribed)
        case .originalVirtualWork:try originalVirtualWork()
        case .identityAndPhysicalRefusals:try refusals()
        case .resourcesAndCancellation:
            if #available(macOS 15.0, *) { try resources() }
            else { throw .mutexUnavailable }
        }
    }
    private func rows(_ i: F.Input, _ q: RigidMaterialAttachmentQuery, _ mode: F.Mode) throws(AttachmentsQualificationError) {
        let rigidColumns:[[Double]],bias:[Double],drift:[Double]
        switch mode {
        case .floating:rigidColumns=[[-1,0,0,0,0,0],[0,-1,0,0,0,-1],[0,0,-1,0,1,0]];bias=[9,0,0];drift=[0,0,0]
        case .spherical:rigidColumns=[[0,0,0],[0,0,-1],[0,1,0]];bias=[9,0,0];drift=[0,0,0]
        case .prescribed:rigidColumns=[[-1],[0],[0]];bias=[21,-30,0];drift=[-4,-9,0]
        }
        let count=i.rigid.state.v.count,weights=[0.2,0.5,0.3,0.0]
        try F.require(q.rows.count==3 && q.rigidVelocityCount==count,"Actual constraint velocity layout")
        try F.require(q.rigidSource === i.rigid && q.materialSnapshot.surface === i.material.surface,"Original immutable source owners")
        let retained=q.materialSnapshot.state,original=i.material.state
        try F.require(retained.frame==original.frame && retained.meshRevision==original.meshRevision && retained.nodeIdentifiers==original.nodeIdentifiers && retained.positions==original.positions && retained.velocities==original.velocities,"Original nodal snapshot values retained")
        try F.require(q.materialSnapshot.geometryRevision==i.material.geometryRevision && q.materialSnapshot.timeSeconds==i.material.timeSeconds,"Original value snapshot epoch and time retained")
        for r in 0..<3 {
            let row=q.rows[r]
            try F.near(row.gap,0,"Original gap m");try F.near(row.rate,0,"Original rate m/s")
            try F.near(row.accelerationBias,bias[r],"Original point centripetal/prescribed bias m/s squared")
            try F.near(row.prescribedRate,drift[r],"Original affine prescribed rate")
            try F.require(row.columns.count==count+12,"Combined row layout")
            for c in 0..<count { try F.near(row.columns[c],rigidColumns[r][c],"Independent rigid point column") }
            for n in 0..<4 { for axis in 0..<3 { try F.near(row.columns[count+3*n+axis],axis==r ? weights[n] : 0,"Original barycentric Cartesian column") } }
        }
        try F.require(i.material.surface.mesh.mesh.source.revision==7 && i.material.geometryRevision==4 && i.material.timeSeconds==0.5,
            "Exact source revision and geometry epoch/time")
        try F.require(i.material.state.nodeIdentifiers==[10,11,12,13] && i.material.state.frame==i.rigid.snapshot.tree.worldFrame,"Original nodal and common world frame")
        let expectedPolicy=try F.jointPolicy()
        try F.require(i.rigid.state.revision==7 && i.rigid.state.time==0.5 && i.rigid.evaluationPolicy==expectedPolicy,"Generating state and evaluation policy retained")
    }
    private func physical(_ mode: F.Mode) throws(AttachmentsQualificationError) {
        let i=try F.input(mode),q=try F.query(i),p=try F.forces(i,q)
        try rows(i,q,mode)
        let expectedEfforts:[Double]
        switch mode {
        case .floating:
            expectedEfforts=[-2,3,-4,0,4,3]
            try F.require(i.rigid.snapshot.coordinateRate.count==7 && i.rigid.state.v==[9,6,0,0,0,3],"Actual floating qdot7 differs from exact v6")
            try F.require(i.rigid.snapshot.coordinateRate==[9,6,0,0,0,0,1.5],"Original floating quaternion derivative retained")
        case .spherical:
            expectedEfforts=[0,4,3]
            try F.require(i.rigid.snapshot.coordinateRate.count==4 && i.rigid.state.v==[0,0,3],"Actual spherical qdot4 differs from exact v3")
            try F.require(i.rigid.snapshot.coordinateRate==[0,0,0,1.5],"Original spherical quaternion derivative retained")
        case .prescribed:
            expectedEfforts=[-2]
            try F.require(i.rigid.snapshot.coordinateRate==[5] && i.rigid.state.v==[5],"Actual prismatic v and original qdot")
        }
        try F.require(p.generalizedEfforts.count==expectedEfforts.count && p.nodalForces.count==4 && p.rigidLoads.count==1,"Original loads layout")
        for c in expectedEfforts.indices { try F.near(p.generalizedEfforts[c],expectedEfforts[c],"Independent conjugate effort") }
        let expectedForces=try [F.v(0.4,-0.6,0.8),F.v(1,-1.5,2),F.v(0.6,-0.9,1.2),F.v(0,0,0)]
        var resultant=Vector3.zero,moment=Vector3.zero,nodalPower=0.0,generalizedPower=0.0
        for n in 0..<4 {
            try F.near(p.nodalForces[n],expectedForces[n],"Original node force N")
            resultant=try F.add(resultant,p.nodalForces[n]);moment=try F.add(moment,F.cross(i.material.state.positions[n],p.nodalForces[n]))
            nodalPower+=F.dot(p.nodalForces[n],i.material.state.velocities[n])
        }
        let load=p.rigidLoads[0]
        try F.near(load.wrench.force,F.v(-2,3,-4),"Equal opposite rigid force")
        try F.near(load.wrench.torque,F.v(0,4,3),"Independent rigid body-origin moment N m")
        try F.near(load.pointWorld,F.v(3,0,0),"Actual material/rigid point world location")
        try F.require(load.body==i.attachment.rigidBody && load.bodyFrame==i.attachment.rigidFrame && load.referenceFrame==i.material.state.frame,
            "Exact body/frame ownership")
        resultant=try F.add(resultant,load.wrench.force)
        // Transport the body-origin wrench to the world origin independently.
        moment=try F.add(moment,F.add(load.wrench.torque,F.cross(F.v(2,0,0),load.wrench.force)))
        try F.near(resultant,.zero,"Independent action reaction N");try F.near(moment,.zero,"Independent original world moment N m")
        for c in expectedEfforts.indices { generalizedPower+=p.generalizedEfforts[c]*i.rigid.state.v[c] }
        let expectedPrescribed=mode == .prescribed ? 19.0 : 0.0
        try F.near(p.nodalPower,-9,"Actual nodal power W");try F.near(nodalPower,-9,"Independent original nodal power W")
        try F.near(p.rigidPower,9,"Actual rigid power W");try F.near(load.physicalPower,9,"Per-interface physical power W")
        try F.near(p.prescribedRigidPower,expectedPrescribed,"Actual prescribed rigid power W")
        try F.near(load.prescribedPower,expectedPrescribed,"Per-interface prescribed power W")
        try F.near(generalizedPower,9-expectedPrescribed,"Independent generalized v effort power W")
        try F.near(nodalPower+generalizedPower+expectedPrescribed,0,"Reciprocal physical power")
        try F.near(p.multiplierPower,0,"Original multiplier rate power")
        try F.require(p.query === q && p.multipliers==[2,-3,4] && p.numericalWork.operations>0,"Original proposal query/load/work retained")
        try F.require(p.forceResidual<=1e-8 && p.momentResidual<=1e-8 && p.powerResidual<=1e-8,"Per-interface accepted residuals")
    }
    private func originalVirtualWork() throws(AttachmentsQualificationError) {
        let nodeVirtual=try [F.v(0.1,-0.2,0.3),F.v(0.4,0.2,-0.1),F.v(-0.3,0.7,0.5),F.v(4,-2,3)]
        for mode in [F.Mode.floating,.spherical,.prescribed] {
            let i=try F.input(mode),q=try F.query(i),p=try F.forces(i,q)
            let tangent:[Double],pointVirtual:Vector3,expected:Double
            switch mode {
            case .floating:tangent=[-0.2,0.4,0.1,0.3,-0.5,0.7];pointVirtual=try F.v(-0.2,1.1,0.6);expected=1.39
            case .spherical:tangent=[0.3,-0.5,0.7];pointVirtual=try F.v(0,0.7,0.5);expected=0.19
            case .prescribed:tangent=[-0.2];pointVirtual=try F.v(-0.2,0,0);expected=0.49
            }
            var virtualWork=0.0,rowWork=0.0
            for c in tangent.indices { virtualWork+=p.generalizedEfforts[c]*tangent[c] }
            for n in 0..<4 { virtualWork+=F.dot(p.nodalForces[n],nodeVirtual[n]) }
            for r in q.rows.indices {
                var projected=0.0
                for c in tangent.indices { projected+=q.rows[r].columns[c]*tangent[c] }
                for n in 0..<4 {
                    let start=tangent.count+3*n,cols=q.rows[r].columns,w=nodeVirtual[n]
                    projected+=cols[start]*w.x+cols[start+1]*w.y+cols[start+2]*w.z
                }
                rowWork+=p.multipliers[r]*projected
            }
            let pointMaterial=try F.v(0.13,0.27,0.16),difference=try F.v(pointMaterial.x-pointVirtual.x,pointMaterial.y-pointVirtual.y,pointMaterial.z-pointVirtual.z)
            try F.near(F.dot(F.v(2,-3,4),difference),expected,"Independent original material minus rigid virtual displacement")
            try F.near(virtualWork,expected,"Generalized/nodal virtual work");try F.near(rowWork,expected,"Original constraint transpose virtual work")
        }
    }
    private func refusals() throws(AttachmentsQualificationError) {
        let i=try F.input(.floating),q=try F.query(i),service:any RigidMaterialAttachmentComputing=TetrahedralPointAttachments()
        let reissued=try F.build { try AttachmentRigidSource(tree:i.rigid.snapshot.tree,state:i.rigid.state,policy:i.rigid.evaluationPolicy) }
        var work=try F.work()
        try F.expect(.staleSource) { () throws(AttachmentError) in _=try service.forces(q,multipliers:[2,-3,4],currentRigid:reissued,currentMaterial:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&work) }
        let other=try F.snapshot(F.surface(),mode:.floating),epoch=try F.snapshot(i.material.surface,mode:.floating,revision:5)
        for changed in [other,epoch] {
            var w=try F.work()
            try F.expect(changed.surface === i.material.surface ? .staleGeometry : .staleSite) { () throws(AttachmentError) in _=try service.forces(q,multipliers:[2,-3,4],currentRigid:i.rigid,currentMaterial:changed,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
        }
        let badBoundary=try F.attachment(i.rigid,site:i.attachment.site,owner:"other"),badRevision=try F.attachment(i.rigid,site:i.attachment.site,revision:8)
        let badFrame=try F.attachment(i.rigid,site:i.attachment.site,frame:F.id(.frame,"other-frame"))
        let orientation=try F.attachment(i.rigid,site:i.attachment.site,dofs:.materialOrientation)
        for (a,wanted) in [(badBoundary,AttachmentError.boundaryOwnershipMismatch),(badRevision,.staleSource),(badFrame,.frameMismatch),(orientation,.unsupportedOrientation)] {
            var w=try F.work()
            try F.expect(wanted) { () throws(AttachmentError) in _=try service.query([a],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
        }
        let lateTime=try F.snapshot(i.material.surface,mode:.floating,time:0.6)
        var timed=try F.work()
        try F.expect(.timeMismatch) { () throws(AttachmentError) in _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:lateTime,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&timed) }
        for existing in [[[Double](repeating:0,count:18)],[q.rows[0].columns]] {
            var w=try F.work()
            try F.expect(existing[0]==q.rows[0].columns ? .overconstrained : .rankDeficient) { () throws(AttachmentError) in _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:existing,rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
        }
        var duplicate=try F.work()
        try F.expect(.duplicateAttachment) { () throws(AttachmentError) in _=try service.query([i.attachment,i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&duplicate) }
        let duplicateDirection=try F.attachment(i.rigid,site:i.attachment.site,dofs:.pointTranslation(directions:[.unitX,.unitX]))
        var rank=try F.work()
        try F.expect(.overconstrained) { () throws(AttachmentError) in _=try service.query([duplicateDirection],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&rank) }
        for multipliers in [[Double.nan,0,0],[1,2]] {
            var w=try F.work()
            try F.expect(multipliers.count==3 ? .nonFinite : .invalidInput) { () throws(AttachmentError) in _=try service.forces(q,multipliers:multipliers,currentRigid:i.rigid,currentMaterial:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
        }
        for revision in [7,8] {
            let state=try F.build { try KinematicState(revision:UInt64(revision),time:0.5,q:i.rigid.state.q,v:revision==7 ? [] : i.rigid.state.v,acceleration:i.rigid.state.acceleration) }
            try F.expect(revision==7 ? .joint(.invalidCoordinateCount) : .joint(.stateRevisionMismatch)) { () throws(AttachmentError) in _=try AttachmentRigidSource(tree:i.rigid.snapshot.tree,state:state,policy:i.rigid.evaluationPolicy) }
        }
        let prescribed=try F.rigid(.prescribed)
        guard let originalAnchor=prescribed.state.prescribedAnchors.first else { throw .assertion("Original prescribed anchor") }
        let missingDerivative=try F.build { try KinematicState(revision:7,time:0.5,q:prescribed.state.q,v:prescribed.state.v,acceleration:prescribed.state.acceleration) }
        try F.expect(.joint(.missingDerivativeData(originalAnchor.frame))) { () throws(AttachmentError) in
            _=try AttachmentRigidSource(tree:prescribed.snapshot.tree,state:missingDerivative,policy:prescribed.evaluationPolicy)
        }
        // The selected X constraint is satisfied, but shifted force lines produce a free couple.
        let shifted=try F.snapshot(i.material.surface,mode:.floating,shift:F.v(0,1,0))
        let partial=try F.attachment(i.rigid,site:i.attachment.site,dofs:.pointTranslation(directions:[.unitX]))
        var partialWork=try F.work()
        let partialQuery=try F.build { try service.query([partial],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:shifted,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&partialWork) }
        try F.near(partialQuery.rows[0].gap,0,"Selected translation constraint alone has zero gap")
        try F.expect(.physicalResidual) { () throws(AttachmentError) in _=try service.forces(partialQuery,multipliers:[2],currentRigid:i.rigid,currentMaterial:shifted,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&partialWork) }
    }
    @available(macOS 15.0, *)
    private func resources() throws(AttachmentsQualificationError) {
        let i=try F.input(.floating),q=try F.query(i),p=try F.forces(i,q),service:any RigidMaterialAttachmentComputing=TetrahedralPointAttachments()
        let required=q.numericalWork.operations,storage=q.numericalWork.peakScalarStorage
        try F.require(required>0 && storage>=744,"Real row and supplier work charged")
        for mode in 0..<2 {
            var w=try F.work(storage:mode==0 ? storage-1 : storage,operations:mode==1 ? required-1 : required)
            try F.expect(.numerical(.resourceLimit(resource:mode==0 ? .scalarStorage : .arithmeticOperations,limit:mode==0 ? storage-1 : required-1))) { () throws(AttachmentError) in
                _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w)
            }
        }
        var exact=try F.work(storage:storage,operations:required)
        _=try F.build { try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&exact) }
        try F.require(exact.operations==required && exact.peakScalarStorage==storage,"Exact original query budget boundary")
        let forceStorage=p.numericalWork.peakScalarStorage,forceOperations=p.numericalWork.operations
        var forceExact=try F.work(storage:forceStorage,operations:forceOperations)
        _=try F.build { try service.forces(q,multipliers:[2,-3,4],currentRigid:i.rigid,currentMaterial:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&forceExact) }
        try F.require(forceExact.operations==forceOperations,"Exact original force mapping work")
        for restricted in [try F.policy(6,rows:2),try F.policy(6,bytes:1),try F.policy(6,scaleCount:17)] {
            var w=try F.work()
            try F.expect(restricted.rankColumnScales.count==17 ? .staleLayout : .capacityExceeded) { () throws(AttachmentError) in _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:restricted,surfacePolicy:i.surfacePolicy,work:&w) }
        }
        let observe=AttachmentsCancellationCounter(),countPolicy=try F.policy(6,cancelled:{observe.check()})
        var counted=try F.work()
        _=try F.build { try service.forces(q,multipliers:[2,-3,4],currentRigid:i.rigid,currentMaterial:i.material,policy:countPolicy,surfacePolicy:i.surfacePolicy,work:&counted) }
        let late=AttachmentsCancellationCounter(cancelAt:observe.count),latePolicy=try F.policy(6,cancelled:{late.check()})
        var lateWork=try F.work()
        try F.expect(.cancelled) { () throws(AttachmentError) in _=try service.forces(q,multipliers:[2,-3,4],currentRigid:i.rigid,currentMaterial:i.material,policy:latePolicy,surfacePolicy:i.surfacePolicy,work:&lateWork) }
        try F.require(late.count==observe.count && lateWork.operations==counted.operations,"Late cancellation after physical acceptance and before publication")
        let earlyPolicy=try F.policy(6,cancelled:{true}),surfaceCancel=try F.surfacePolicy(cancelled:{true})
        var early=try F.work()
        try F.expect(.cancelled) { () throws(AttachmentError) in _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:earlyPolicy,surfacePolicy:i.surfacePolicy,work:&early) }
        try F.require(early.operations==0 && early.peakScalarStorage==0,"Early cancellation before owned work")
        var supplier=try F.work()
        try F.expect(.surface(.cancelled)) { () throws(AttachmentError) in _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:surfaceCancel,work:&supplier) }
        try F.require(supplier.operations>0,"Original supplier cancellation retains owned spent ledger")
    }
    public func taskCancellationEntry() throws(AttachmentsQualificationError) -> @Sendable () throws(AttachmentsQualificationError) -> Void {
        let i=try F.input(.floating)
        return { () throws(AttachmentsQualificationError) in
            let service:any RigidMaterialAttachmentComputing=TetrahedralPointAttachments();var w=try F.work()
            try F.expect(.cancelled) { () throws(AttachmentError) in _=try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
            try F.require(w.operations==0 && w.peakScalarStorage==0,"Actual awaited Task cancellation before query work")
        }
    }
}
