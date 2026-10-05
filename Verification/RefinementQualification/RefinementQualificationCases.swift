import SwiftMechanics

public struct RefinementQualificationCases: RefinementQualifying {
    private typealias F=RefinementQualificationFixtures
    public init() {}
    public func run(_ selected: RefinementQualificationCase) throws(RefinementQualificationError) {
        switch selected {
        case .topologyAndBoundary:try topologyAndBoundary()
        case .diagonalGeometry:try diagonalGeometry()
        case .sharedAndDisconnected:try sharedAndDisconnected()
        case .stateAndConcentratedLoads:try stateAndConcentratedLoads()
        case .originalRefusals:try originalRefusals()
        case .resourcesAndCancellation:try resourcesAndCancellation()
        }
    }
    private func topologyAndBoundary() throws(RefinementQualificationError) {
        let source=try F.source(),layout=try F.layout(source),result=try F.refine(layout)
        try F.require(layout.edges.count==6 && layout.faces.count==4 && layout.boundaryFaces.count==4,"Original single-cell incidence")
        try topology(result,boundaryFaces:16)
        try state(result,rigid:false)
        try F.require(result.cells[0].diagonalMidpoints==[4,9],"Explicit lexicographic octahedron diagonal")
        try F.require(result.refined.mesh.mesh.nodes.count==10 && result.refined.mesh.mesh.cells.count==8,"Actual red 1-to-8 topology")
        let expectedPairs=[[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
        try edgeIdentity(result,expected:expectedPairs)
        try F.near(result.refined.mesh.referenceCells.reduce(0) { $0+$1.volume },1.0/6,"Original total reference volume")
    }
    private func diagonalGeometry() throws(RefinementQualificationError) {
        let variants=try [F.vector(0.3,-0.2,1),F.vector(-0.3,0.2,1),F.vector(0.3,0.2,1)]
        let expected=[[4,9],[5,8],[6,7]]
        for i in variants.indices {
            let source=try F.source(apex:variants[i]),layout=try F.layout(source)
            let shortest=try F.refine(layout,diagonal:.shortestReferenceDiagonal)
            try F.require(shortest.cells[0].diagonalMidpoints==expected[i],"Actual independently shortest reference diagonal")
            try topology(shortest,boundaryFaces:16)
            let lexicographic=try F.refine(layout,diagonal:.lexicographicOppositeEdges)
            try F.require(lexicographic.cells[0].diagonalMidpoints==[4,9],"Declared lexicographic diagonal differs from geometry selection")
            try topology(lexicographic,boundaryFaces:16)
        }
        let symmetric=try F.refine(F.layout(F.source()),diagonal:.shortestReferenceDiagonal)
        try F.require(symmetric.cells[0].diagonalMidpoints==[4,9],"Exact equal-length diagonal tie uses original-ID lexicographic order")
    }
    private func sharedAndDisconnected() throws(RefinementQualificationError) {
        let sharedSource=try F.source(.sharedFace),sharedLayout=try F.layout(sharedSource),shared=try F.refine(sharedLayout)
        try F.require(sharedLayout.edges.count==9 && sharedLayout.faces.count==8 && sharedLayout.boundaryFaces.count==6,"Original two-cell shared face admitted")
        try F.require(shared.refined.mesh.mesh.nodes.count==14 && shared.refined.mesh.mesh.cells.count==16,"Shared global midpoint count")
        try edgeIdentity(shared,expected:[[0,1],[0,2],[0,3],[0,4],[1,2],[1,3],[1,4],[2,3],[2,4]])
        try topology(shared,boundaryFaces:24,materialInterfaces:4)
        let interface=shared.faces.filter { !$0.original.isBoundary }
        try F.require(interface.count==2 && interface.allSatisfy { $0.children.count==4 && $0.boundaryGroup==nil },"Original material interface has exactly four children per side")
        for face in interface[0].children {
            let key=face.nodes.sorted()
            try F.require(interface[1].children.filter { $0.nodes.sorted()==key }.count==1,"Both original parents retain identical midpoint material-face triangles")
        }
        try state(shared,rigid:false)
        let separateSource=try F.source(.disconnected),separateLayout=try F.layout(separateSource),separate=try F.refine(separateLayout)
        try F.require(separateLayout.edges.count==12 && separateLayout.boundaryFaces.count==8 && separate.refined.mesh.mesh.nodes.count==20,"Disconnected physical cells retain independent topology")
        try topology(separate,boundaryFaces:32)
        try state(separate,rigid:false)
        try F.near(separate.refined.mesh.referenceCells.reduce(0) { $0+$1.volume },1.0/3,"Disconnected exact total reference volume")
    }
    private func stateAndConcentratedLoads() throws(RefinementQualificationError) {
        let source=try F.source(),result=try F.refine(F.layout(source)),forces=try F.forces(source)
        try state(result,rigid:false)
        try F.require(result.loadPolicy == .retainConcentratedOriginalNodes && result.originalLoads.source === source,"Explicit concentrated-force ownership")
        try F.require(result.momentReferencePosition==source.state.positions[0],"Declared original current first-node moment origin")
        let q=try [F.vector(0.2,-0.1,0.3),F.vector(-0.4,0.5,0.7),F.vector(0.9,-0.6,0.1),F.vector(-0.2,0.8,-0.5)]
        var virtual: [Vector3]=[],dual=[Vector3](repeating:.zero,count:4)
        for row in result.prolongation {
            var value=try F.scale(q[row.firstOriginalNode],row.firstWeight)
            if let second=row.secondOriginalNode { value=try F.add(value,F.scale(q[second],row.secondWeight)) }
            virtual.append(value)
            dual[row.firstOriginalNode]=try F.add(dual[row.firstOriginalNode],F.scale(result.loads[row.refinedNode],row.firstWeight))
            if let second=row.secondOriginalNode { dual[second]=try F.add(dual[second],F.scale(result.loads[row.refinedNode],row.secondWeight)) }
        }
        var resultant=Vector3.zero,moment=Vector3.zero,worldMoment=Vector3.zero,power=0.0,virtualWork=0.0,originalWork=0.0
        for i in result.loads.indices {
            if i<4 { try F.require(result.loads[i]==forces[i],"Exact original concentrated covector retained") }
            else { try F.require(result.loads[i] == .zero,"Explicit injection-dual midpoint force zero") }
            resultant=try F.add(resultant,result.loads[i])
            moment=try F.add(moment,F.cross(F.subtract(result.refined.state.positions[i],result.momentReferencePosition),result.loads[i]))
            worldMoment=try F.add(worldMoment,F.cross(result.refined.state.positions[i],result.loads[i]))
            power+=F.dot(result.loads[i],result.refined.state.velocities[i]);virtualWork+=F.dot(result.loads[i],virtual[i])
        }
        for i in 0..<4 { try F.near(dual[i],forces[i],"Independent P transpose L equals original covector");originalWork+=F.dot(forces[i],q[i]) }
        try F.near(resultant,F.vector(2,2,3),"Original resultant force N")
        try F.near(moment,F.vector(4,1,0.75),"Original current-body moment Nm")
        try F.near(worldMoment,F.vector(0,-4,6.75),"Original world-origin moment Nm")
        try F.near(power,4.3,"Original physical nodal power W");try F.near(virtualWork,3.4,"Arbitrary original virtual work")
        try F.near(originalWork,3.4,"Independent old nodal virtual work")
        try F.require(result.dualResidual<=1e-10 && result.forceResidual<=1e-10 && result.momentResidual<=1e-10 && result.powerResidual<=1e-10,"Accepted original dual/physical residuals")
        let arbitrary=try F.source(source,state:F.changed(source.state,velocities:q)),arbitraryResult=try F.refine(F.layout(arbitrary))
        try F.near(arbitraryResult.refined.state.velocities[4],F.midpoint(q[0],q[1]),"Arbitrary old nodal velocity prolongation")
        var arbitraryPower=0.0
        for i in arbitraryResult.loads.indices { arbitraryPower+=F.dot(arbitraryResult.loads[i],arbitraryResult.refined.state.velocities[i]) }
        try F.near(arbitraryPower,3.4,"Physical source accepts arbitrary old nodal velocity and retains original power")
        let rigid=try F.refine(F.layout(F.source(rigid:true)))
        try topology(rigid,boundaryFaces:16);try state(rigid,rigid:true)
    }
    private func edgeIdentity(_ result: Tet4RefinementResult,expected: [[Int]]) throws(RefinementQualificationError) {
        let old=result.layout.source.mesh.mesh,new=result.refined.mesh.mesh
        try F.require(result.layout.edges.count==expected.count,"Independent edge count")
        for i in expected.indices {
            let a=expected[i][0],b=expected[i][1],edge=result.layout.edges[i],node=old.nodes.count+i
            try F.require(edge.lowerNode==a && edge.upperNode==b && edge.lowerIdentifier==old.nodes[a].identifier && edge.upperIdentifier==old.nodes[b].identifier,"Original lexicographic global-ID edge pair")
            try F.require(new.nodes[node].identifier==1000+UInt64(i),"Declared deterministic midpoint ID range")
            try F.near(new.nodes[node].referencePosition,F.midpoint(old.nodes[a].referencePosition,old.nodes[b].referencePosition),"Actual original edge midpoint")
            let row=result.prolongation[node]
            try F.require(row.refinedNode==node && row.firstOriginalNode==a && row.secondOriginalNode==b && row.firstWeight==0.5 && row.secondWeight==0.5,"Actual original prolongation row")
        }
    }
    private func state(_ result: Tet4RefinementResult,rigid: Bool) throws(RefinementQualificationError) {
        let source=result.layout.source,refined=result.refined,old=source.mesh.mesh,new=refined.mesh.mesh
        try F.require(result.prolongation.count==new.nodes.count,"Explicit full prolongation")
        for i in old.nodes.indices {
            try F.require(new.nodes[i]==old.nodes[i] && refined.state.positions[i]==source.state.positions[i] && refined.state.velocities[i]==source.state.velocities[i],"Original node/layout/value retention")
            let row=result.prolongation[i]
            try F.require(row.refinedNode==i && row.firstOriginalNode==i && row.secondOriginalNode==nil && row.firstWeight==1 && row.secondWeight==0,"Original identity prolongation row")
        }
        for i in new.nodes.indices {
            try F.near(refined.state.positions[i],F.position(new.nodes[i].referencePosition,rigid:rigid),"Actual affine or rigid material position")
            try F.near(refined.state.velocities[i],F.velocity(new.nodes[i].referencePosition,rigid:rigid),"Actual affine or rigid material velocity")
            try F.require(refined.state.nodeIdentifiers[i]==new.nodes[i].identifier,"New state and actual mesh node layout")
        }
        for i in result.layout.edges.indices { try F.require(new.nodes[old.nodes.count+i].boundaryGroup==result.boundaryAssignments.midpointGroups[i],"Supplied midpoint group including explicit nil") }
    }
    private func topology(_ result: Tet4RefinementResult,boundaryFaces: Int,materialInterfaces: Int = 0) throws(RefinementQualificationError) {
        let source=result.layout.source,old=source.mesh.mesh,new=result.refined.mesh.mesh
        try F.require(result.refined.timeSeconds==0.5 && result.refined.geometryRevision==5 && new.revision==8 && result.refined.state.meshRevision==8,"Original time and strict revision/epoch advance")
        try F.require(new.frame==old.frame && new.source==old.source && result.refined.state.frame==old.frame && result.layout.source === source,"Original immutable frame/source owner")
        try F.require(new.materials.count==old.materials.count,"Original material assignment count")
        for i in old.materials.indices {
            let a=old.materials[i],b=new.materials[i]
            try F.require(a.identifier==b.identifier && a.source==b.source && a.referenceDensity==b.referenceDensity && a.massDampingRate==b.massDampingRate && a.law==b.law,"Original material/source/physical parameters retained")
        }
        let reference=new.nodes.map { $0.referencePosition },current=result.refined.state.positions
        for (i,cell) in new.cells.enumerated() {
            let parent=old.cells[i/8],prepared=result.refined.mesh.referenceCells[i],v=try F.volume(reference,cell.nodes),cv=try F.volume(current,cell.nodes)
            let parentV=source.mesh.referenceCells[i/8].volume,parentCurrent=try F.volume(source.state.positions,parent.nodes)
            try F.require(cell.identifier==2000+UInt64(i) && cell.parentIdentifier==parent.identifier && cell.material==parent.material && cell.source==parent.source,"Actual deterministic child/source/material parent ledger")
            try F.require(v>0 && cv>0,"Independent positive reference/current child orientation")
            try F.near(v,parentV/8,"Independent exact reference child volume");try F.near(cv,parentCurrent/8,"Independent exact current child volume")
            try F.near(prepared.volume,v,"Actual supplier reference volume")
            let gradients=[prepared.gradient0,prepared.gradient1,prepared.gradient2,prepared.gradient3]
            try F.near(F.add(F.add(gradients[0],gradients[1]),F.add(gradients[2],gradients[3])),.zero,"Actual supplier partition gradient")
            for a in 1..<4 { for b in 1..<4 {
                try F.near(F.dot(gradients[a],F.subtract(reference[cell.nodes[b]],reference[cell.nodes[0]])),a==b ? 1 : 0,"Actual supplier inverse-gradient quality")
            } }
        }
        for (i,mapping) in result.cells.enumerated() {
            try F.require(mapping.originalCell.identifier==old.cells[i].identifier && mapping.children==(0..<8).map { UInt64(2000+8*i+$0) },"Original cell children ledger")
            try F.near(mapping.refinedReferenceVolume,source.mesh.referenceCells[i].volume,"Original reference partition ledger")
            try F.near(mapping.refinedCurrentVolume,F.volume(source.state.positions,old.cells[i].nodes),"Original current partition ledger")
        }
        var incidence: [[Int]:[(cell:Int,nodes:[Int])]]=[:]
        for (i,cell) in new.cells.enumerated() {
            for omitted in 0..<4 {
                var nodes=cell.nodes.enumerated().filter { $0.offset != omitted }.map { $0.element }
                if omitted%2==1 { nodes.swapAt(1,2) }
                let vector=try F.area(reference,nodes),toward=try F.subtract(reference[cell.nodes[omitted]],reference[nodes[0]])
                try F.require(F.dot(vector,toward)<0,"Independent outward face orientation")
                incidence[nodes.sorted(),default:[]].append((i,nodes))
            }
        }
        var boundaryCount=0,interfaceCount=0
        for faces in incidence.values {
            try F.require(faces.count==1 || faces.count==2,"Actual conforming child incidence without hanging/nonmanifold faces")
            if faces.count==1 { boundaryCount+=1 }
            else {
                try F.near(F.add(F.area(reference,faces[0].nodes),F.area(reference,faces[1].nodes)),.zero,"Original reciprocal oriented interior faces")
                if new.cells[faces[0].cell].material != new.cells[faces[1].cell].material { interfaceCount+=1 }
            }
        }
        try F.require(boundaryCount==boundaryFaces && interfaceCount==materialInterfaces,"Independent boundary/material interface topology counts")
        try F.require(result.faces.count==result.layout.faces.count && result.boundaryAssignments.layout === result.layout,"Actual original-face assignment owner")
        let originalReference=old.nodes.map { $0.referencePosition }
        for subdivision in result.faces {
            let original=try F.area(originalReference,subdivision.original.nodes),quarter=try F.scale(original,0.25)
            var sum=Vector3.zero
            try F.require(subdivision.children.count==4 && subdivision.boundaryAssignmentOwner=="caller-boundary-decisions","Four actual children and supplied boundary authority")
            for child in subdivision.children {
                let vector=try F.area(reference,child.nodes);try F.near(vector,quarter,"Independent quarter outward area vector")
                try F.require(child.isBoundary==subdivision.original.isBoundary,"Original boundary versus interior face ledger")
                sum=try F.add(sum,vector)
            }
            try F.near(sum,original,"Independent original face area-vector partition")
            if subdivision.original.isBoundary {
                guard let index=result.layout.boundaryFaces.firstIndex(where: { $0.cell==subdivision.original.cell && $0.oppositeNode==subdivision.original.oppositeNode }) else { throw .assertion("Missing original boundary face") }
                try F.require(subdivision.boundaryGroup==result.boundaryAssignments.originalFaceGroups[index],"Exact caller supplied face group including nil")
            }
        }
    }
    private func originalRefusals() throws(RefinementQualificationError) {
        let source=try F.source(),layout=try F.layout(source),groups=try F.groups(layout),loads=try F.loads(source),policy=try F.policy(),admission=try F.admission()
        let producer: any Tet4RedRefining=ConformingTet4RedRefiner()
        func layoutRefused(_ input: Tet4RefinementSource,_ wanted: F.Failure) throws(RefinementQualificationError) {
            var work=try F.work();try F.expect(wanted) { () throws(RefinementError) in _=try producer.layout(source:input,policy:policy,work:&work) }
        }
        func refused(_ wanted: F.Failure,revision: UInt64 = 8,epoch: UInt64 = 5,ids: RefinementIdentifierAllocation = RefinementIdentifierAllocation(firstMidpointNode:1000,firstChildCell:2000),boundary: RefinementBoundaryMapping? = nil,loads supplied: ConcentratedRefinementLoads? = nil,loadPolicy: RefinementLoadPolicy = .retainConcentratedOriginalNodes,policy suppliedPolicy: RefinementPolicy? = nil,admission suppliedAdmission: MeshAdmission? = nil) throws(RefinementQualificationError) {
            var work=try F.work();try F.expect(wanted) { () throws(RefinementError) in _=try producer.refine(layout,meshRevision:revision,geometryRevision:epoch,identifiers:ids,diagonal:.lexicographicOppositeEdges,boundary:boundary ?? .explicitGroups(groups),loads:supplied ?? loads,loadPolicy:loadPolicy,policy:suppliedPolicy ?? policy,admission:suppliedAdmission ?? admission,work:&work) }
        }
        try refused(.revision,revision:7);try refused(.revision,epoch:4)
        let other=try F.source(source,state:source.state),otherGroups=try F.groups(F.layout(source))
        try refused(.source,loads:F.loads(other));try refused(.source,boundary:.explicitGroups(otherGroups))
        try refused(.collision,ids:RefinementIdentifierAllocation(firstMidpointNode:10,firstChildCell:2000))
        try refused(.collision,ids:RefinementIdentifierAllocation(firstMidpointNode:1000,firstChildCell:50))
        try refused(.overflow,ids:RefinementIdentifierAllocation(firstMidpointNode:UInt64.max-2,firstChildCell:2000))
        try refused(.overflow,ids:RefinementIdentifierAllocation(firstMidpointNode:1000,firstChildCell:UInt64.max-3))
        try refused(.policy,policy:F.policy(conformity:1e-8))
        try refused(.boundary,boundary:.inferConstraints)
        try refused(.load,loadPolicy:.distributedTraction);try refused(.load,loadPolicy:.redistributeNodalLoads)
        try refused(.supplierQuality,admission:F.admission(minimum:0.03))
        try layoutRefused(F.source(source,state:F.changed(source.state,frame:F.identity(.frame,"other"))),.frame)
        try layoutRefused(F.source(source,state:F.changed(source.state,revision:99)),.layout)
        try layoutRefused(F.source(source,state:F.changed(source.state,ids:[20,10,30,40])),.layout)
        try layoutRefused(F.source(source,state:F.changed(source.state,velocities:Array(source.state.velocities.prefix(3)))),.layout)
        var inverted=source.state.positions;inverted.swapAt(1,2)
        try layoutRefused(F.source(source,state:F.changed(source.state,positions:inverted)),.physical)
        for geometry in [F.Geometry.overlap,.coincident,.hanging] { try layoutRefused(F.source(geometry),.nonconforming) }
        try layoutRefused(F.source(.nonmanifold),.topology)
        for time in [-1.0,Double.nan] { try F.expect(.invalid) { () throws(RefinementError) in _=try Tet4RefinementSource(mesh:source.mesh,state:source.state,timeSeconds:time,geometryRevision:4) } }
        try F.expect(.assignment) { () throws(RefinementError) in _=try RefinementBoundaryAssignments(layout:layout,owner:"",midpointGroups:groups.midpointGroups,originalFaceGroups:groups.originalFaceGroups) }
        try F.expect(.assignment) { () throws(RefinementError) in _=try RefinementBoundaryAssignments(layout:layout,owner:"caller",midpointGroups:[],originalFaceGroups:groups.originalFaceGroups) }
        try F.expect(.layout) { () throws(RefinementError) in _=try ConcentratedRefinementLoads(source:source,forces:[.zero]) }
        try F.expect(.invalid) { () throws(RefinementError) in _=try RefinementPolicy(maximumNodes:0,maximumCells:32,maximumMaterials:4,maximumEdges:32,maximumFaces:128,
            maximumIdentifierBytes:256,maximumScalars:200_000,conformityTolerance:1e-10,barycentricTolerance:1e-10,volumeTolerance:1e-10,areaTolerance:1e-10,
            minimumCurrentVolume:1e-12,forceTolerance:1e-10,momentTolerance:1e-10,powerTolerance:1e-10) }
    }
    private func resourcesAndCancellation() throws(RefinementQualificationError) {
        let source=try F.source(),layout=try F.layout(source),result=try F.refine(layout),groups=try F.groups(layout),loads=try F.loads(source),policy=try F.policy(),admission=try F.admission()
        let producer: any Tet4RedRefining=ConformingTet4RedRefiner(),ids=RefinementIdentifierAllocation(firstMidpointNode:1000,firstChildCell:2000)
        try F.require(layout.numericalWork.peakScalarStorage==826 && result.numericalWork.peakScalarStorage==5914,"Independent original layout/refinement storage reserve formulas")
        for mode in 0..<2 {
            var work=try F.work(storage:mode==0 ? 825 : 826,operations:mode==1 ? layout.numericalWork.operations-1 : layout.numericalWork.operations)
            try F.expect(mode==0 ? .storage(825) : .operations(layout.numericalWork.operations-1)) { () throws(RefinementError) in _=try producer.layout(source:source,policy:policy,work:&work) }
        }
        for mode in 0..<2 {
            var work=try F.work(storage:mode==0 ? 5913 : 5914,operations:mode==1 ? result.numericalWork.operations-1 : result.numericalWork.operations)
            try F.expect(mode==0 ? .storage(5913) : .operations(result.numericalWork.operations-1)) { () throws(RefinementError) in _=try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:ids,diagonal:.lexicographicOppositeEdges,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:policy,admission:admission,work:&work) }
        }
        var exact=try F.work(storage:5914,operations:result.numericalWork.operations)
        _=try F.refinement { () throws(RefinementError) in try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:ids,diagonal:.lexicographicOppositeEdges,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:policy,admission:admission,work:&exact) }
        try F.require(exact.operations==result.numericalWork.operations && exact.peakScalarStorage==5914,"Exact original numerical boundary")
        for restricted in [try F.policy(nodes:9),try F.policy(cells:7),try F.policy(faces:31),try F.policy(scalars:5913),try F.policy(bytes:1)] {
            var work=try F.work();try F.expect(.capacity) { () throws(RefinementError) in _=try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:ids,diagonal:.lexicographicOppositeEdges,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:restricted,admission:admission,work:&work) }
        }
        let tooFewEdges=try F.policy(edges:5);var edgeWork=try F.work()
        try F.expect(.capacity) { () throws(RefinementError) in _=try producer.layout(source:source,policy:tooFewEdges,work:&edgeWork) }
        let counter=RefinementCancellationCounter(),countPolicy=try F.policy(cancelled:{counter.check()})
        var measured=try F.work()
        _=try F.refinement { () throws(RefinementError) in try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:ids,diagonal:.lexicographicOppositeEdges,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:countPolicy,admission:admission,work:&measured) }
        let late=RefinementCancellationCounter(cancelAt:counter.count),latePolicy=try F.policy(cancelled:{late.check()});var lateWork=try F.work()
        try F.expect(.cancelled) { () throws(RefinementError) in _=try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:ids,diagonal:.lexicographicOppositeEdges,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:latePolicy,admission:admission,work:&lateWork) }
        try F.require(late.count==counter.count && lateWork.operations==measured.operations && lateWork.peakScalarStorage==measured.peakScalarStorage,"Late cancellation after original generated geometry/load work before proposal publication")
        let immediate=try F.policy(cancelled:{true});var early=try F.work()
        try F.expect(.cancelled) { () throws(RefinementError) in _=try producer.layout(source:source,policy:immediate,work:&early) }
        try F.require(early.operations==0 && early.peakScalarStorage==0,"Early cancellation before layout allocation")
    }
    public func taskCancellationEntry() throws(RefinementQualificationError) -> @Sendable () throws(RefinementQualificationError) -> Void {
        let source=try F.source(),layout=try F.layout(source),groups=try F.groups(layout),loads=try F.loads(source),policy=try F.policy(),admission=try F.admission()
        return { () throws(RefinementQualificationError) in
            let producer: any Tet4RedRefining=ConformingTet4RedRefiner();var work=try F.work()
            try F.expect(.cancelled) { () throws(RefinementError) in _=try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:RefinementIdentifierAllocation(firstMidpointNode:1000,firstChildCell:2000),diagonal:.lexicographicOppositeEdges,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:policy,admission:admission,work:&work) }
            try F.require(work.operations==0 && work.peakScalarStorage==0,"Actual Task cancellation before refinement work/publication")
        }
    }
}
