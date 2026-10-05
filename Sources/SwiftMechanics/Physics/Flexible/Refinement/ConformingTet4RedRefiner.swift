public struct ConformingTet4RedRefiner: Tet4RedRefining {
    public init() {}

    @inline(never)
    public func layout(source: Tet4RefinementSource, policy p: RefinementPolicy,
                       work: inout NumericalWork) throws(RefinementError) -> Tet4RefinementLayout {
        try admit(source,policy: p,work: &work)
        let faceCount = try RefinementArithmetic.product(4,source.mesh.mesh.cells.count)
        let edgeBound = min(p.maximumEdges,try RefinementArithmetic.product(6,source.mesh.mesh.cells.count))
        let reserve = try RefinementArithmetic.sum(source.mesh.scalarStorage,
            RefinementArithmetic.sum(512,RefinementArithmetic.sum(RefinementArithmetic.product(48,faceCount),RefinementArithmetic.product(16,edgeBound))))
        try RefinementArithmetic.storage(reserve,p,&work)
        let faces = try RefinementTopology.faces(source.mesh.mesh.cells,policy: p,work: &work)
        try RefinementTopology.conforming(source.mesh.mesh,policy: p,work: &work)
        let edges = try RefinementTopology.edges(source.mesh.mesh,policy: p,work: &work)
        var boundary: [RefinementFace] = []; boundary.reserveCapacity(faces.count)
        for face in faces {
            try RefinementArithmetic.charge(1,p,&work)
            if face.isBoundary { boundary.append(face) }
        }
        try RefinementArithmetic.check(p)
        return Tet4RefinementLayout(source: source,edges: edges,faces: faces,boundary: boundary,policy: p,work: work)
    }

    @inline(never)
    public func refine(_ layout: Tet4RefinementLayout, meshRevision: UInt64, geometryRevision: UInt64,
                       identifiers: RefinementIdentifierAllocation, diagonal: CentralOctahedronDiagonalPolicy,
                       boundary: RefinementBoundaryMapping, loads: ConcentratedRefinementLoads, loadPolicy: RefinementLoadPolicy,
                       policy p: RefinementPolicy, admission: MeshAdmission,
                       work: inout NumericalWork) throws(RefinementError) -> Tet4RefinementResult {
        let source = layout.source, mesh = source.mesh.mesh
        try admit(source,policy: p,work: &work)
        guard layout.policy.conformityTolerance == p.conformityTolerance,
              layout.policy.barycentricTolerance == p.barycentricTolerance else { throw .topologyPolicyMismatch }
        guard layout.edges.count <= p.maximumEdges, layout.faces.count <= p.maximumFaces else { throw .capacityExceeded }
        guard meshRevision > mesh.revision, geometryRevision > source.geometryRevision else { throw .staleRevision }
        guard loads.source === source else { throw .staleSource }
        let assignments = try explicitBoundary(boundary,layout: layout,policy: p,work: &work)
        try admitLoads(loadPolicy)
        let nodeCount = try RefinementArithmetic.sum(mesh.nodes.count,layout.edges.count)
        let cellCount = try RefinementArithmetic.product(8,mesh.cells.count)
        let faceCount = try RefinementArithmetic.product(4,cellCount)
        guard nodeCount <= p.maximumNodes, cellCount <= p.maximumCells, faceCount <= p.maximumFaces,
              nodeCount <= admission.maximumNodes, cellCount <= admission.maximumCells,
              mesh.materials.count <= admission.maximumMaterials else { throw .capacityExceeded }
        let reserve = try RefinementArithmetic.sum(source.mesh.scalarStorage,
            RefinementArithmetic.sum(1024,RefinementArithmetic.sum(RefinementArithmetic.product(128,nodeCount),
                RefinementArithmetic.sum(RefinementArithmetic.product(192,cellCount),RefinementArithmetic.product(64,faceCount)))))
        try RefinementArithmetic.storage(reserve,p,&work)
        try admitIdentifiers(identifiers,edges: layout.edges.count,children: cellCount,mesh: mesh,policy: p,work: &work)
        var nodes = mesh.nodes; nodes.reserveCapacity(nodeCount)
        var positions = source.state.positions; positions.reserveCapacity(nodeCount)
        var velocities = source.state.velocities; velocities.reserveCapacity(nodeCount)
        var nodeIDs = source.state.nodeIdentifiers; nodeIDs.reserveCapacity(nodeCount)
        var prolongation: [RefinementProlongationRow] = []; prolongation.reserveCapacity(nodeCount)
        for i in mesh.nodes.indices {
            try RefinementArithmetic.charge(1,p,&work)
            prolongation.append(RefinementProlongationRow(node: i,first: i,second: nil,firstWeight: 1,secondWeight: 0))
        }
        for (index,edge) in layout.edges.enumerated() {
            try RefinementArithmetic.charge(96,p,&work)
            let nodeID = try RefinementArithmetic.identifier(identifiers.firstMidpointNode,offset: index)
            let point = try RefinementArithmetic.midpoint(mesh.nodes[edge.lowerNode].referencePosition,mesh.nodes[edge.upperNode].referencePosition)
            let position = try RefinementArithmetic.midpoint(source.state.positions[edge.lowerNode],source.state.positions[edge.upperNode])
            let velocity = try RefinementArithmetic.midpoint(source.state.velocities[edge.lowerNode],source.state.velocities[edge.upperNode])
            let node = nodes.count
            nodes.append(FlexibleNode(identifier: nodeID,referencePosition: point,boundaryGroup: assignments.midpointGroups[index]))
            positions.append(position); velocities.append(velocity); nodeIDs.append(nodeID)
            prolongation.append(RefinementProlongationRow(node: node,first: edge.lowerNode,second: edge.upperNode,firstWeight: 0.5,secondWeight: 0.5))
        }
        var cells: [TetrahedronCell] = []; cells.reserveCapacity(cellCount)
        var selectedDiagonals: [[Int]] = []; selectedDiagonals.reserveCapacity(mesh.cells.count)
        for (index,parent) in mesh.cells.enumerated() {
            let midpoint = try cellMidpoints(parent,layout: layout,policy: p,work: &work)
            let selected = try selectedDiagonal(midpoint,nodes: nodes,policy: diagonal,resource: p,work: &work)
            selectedDiagonals.append(selected.diagonal)
            let v = parent.nodes, e = midpoint
            var children = [[v[0],e[0],e[1],e[2]],[v[1],e[0],e[3],e[4]],
                            [v[2],e[1],e[3],e[5]],[v[3],e[2],e[4],e[5]]]
            for i in 0..<4 { children.append([selected.diagonal[0],selected.diagonal[1],selected.ring[i],selected.ring[(i+1)%4]]) }
            for ordinal in 0..<8 {
                try RefinementArithmetic.charge(128,p,&work)
                var connectivity = children[ordinal]
                if try RefinementArithmetic.referenceVolume(nodes,connectivity) < 0 { connectivity.swapAt(2,3) }
                let id = try RefinementArithmetic.identifier(identifiers.firstChildCell,offset: try RefinementArithmetic.sum(RefinementArithmetic.product(8,index),ordinal))
                let child = try RefinementArithmetic.flexible { () throws(FlexibleError) in
                    try TetrahedronCell(identifier: id,nodes: connectivity,material: parent.material,source: parent.source,parentIdentifier: parent.identifier)
                }
                cells.append(child)
            }
        }
        let generated = try RefinementArithmetic.flexible { () throws(FlexibleError) in
            try TetrahedralMesh(frame: mesh.frame,revision: meshRevision,source: mesh.source,nodes: nodes,cells: cells,materials: mesh.materials)
        }
        let state = NodalState(frame: mesh.frame,meshRevision: meshRevision,nodeIdentifiers: nodeIDs,positions: positions,velocities: velocities)
        try RefinementArithmetic.check(p)
        let combinedAdmission = try RefinementArithmetic.flexible { () throws(FlexibleError) in
            try MeshAdmission(maximumNodes: admission.maximumNodes,maximumCells: admission.maximumCells,
                maximumMaterials: admission.maximumMaterials,minimumReferenceVolume: admission.minimumReferenceVolume,
                inverseRelativeTolerance: admission.inverseRelativeTolerance,
                isCancelled: { p.isCancelled() || admission.isCancelled() })
        }
        let supplier: any TetrahedralMeshValidating = TetrahedralMeshValidator()
        let validated = try RefinementArithmetic.flexible { () throws(FlexibleError) in try supplier.validate(generated,admission: combinedAdmission,work: &work) }
        let mappings = try cellMappings(layout,refined: validated,state: state,diagonals: selectedDiagonals,policy: p,work: &work)
        let newFaces = try RefinementTopology.faces(cells,policy: p,work: &work)
        let faces = try faceMappings(layout,refinedFaces: newFaces,refinedNodes: nodes,assignments: assignments,policy: p,work: &work)
        let loadResult = try transferLoads(loads,prolongation: prolongation,state: state,policy: p,work: &work)
        let refined = try Tet4RefinementSource(mesh: validated,state: state,timeSeconds: source.timeSeconds,geometryRevision: geometryRevision)
        try RefinementArithmetic.check(p)
        return Tet4RefinementResult(layout: layout,refined: refined,identifiers: identifiers,diagonal: diagonal,
            boundary: assignments,prolongation: prolongation,cells: mappings,faces: faces,loads: loadResult.forces,
            originalLoads: loads,dual: loadResult.dual,force: loadResult.force,moment: loadResult.moment,power: loadResult.power,
            policy: p,admission: admission,work: work)
    }

    private func admit(_ source: Tet4RefinementSource, policy p: RefinementPolicy,
                       work: inout NumericalWork) throws(RefinementError) {
        try RefinementArithmetic.check(p)
        let mesh = source.mesh.mesh, state = source.state
        guard mesh.nodes.count <= p.maximumNodes, mesh.cells.count <= p.maximumCells,
              mesh.materials.count <= p.maximumMaterials else { throw .capacityExceeded }
        let faces = try RefinementArithmetic.product(4,mesh.cells.count)
        guard faces <= p.maximumFaces else { throw .capacityExceeded }
        let reserve = try RefinementArithmetic.sum(source.mesh.scalarStorage,
            RefinementArithmetic.sum(512,RefinementArithmetic.sum(RefinementArithmetic.product(32,mesh.nodes.count),RefinementArithmetic.product(32,mesh.materials.count))))
        try RefinementArithmetic.storage(reserve,p,&work)
        try RefinementArithmetic.text(mesh.frame.key,p,&work); try RefinementArithmetic.text(state.frame.key,p,&work)
        try RefinementArithmetic.text(mesh.source.source,p,&work)
        for material in mesh.materials {
            try RefinementArithmetic.text(material.identifier.key,p,&work); try RefinementArithmetic.text(material.source.source,p,&work)
        }
        for cell in mesh.cells {
            try RefinementArithmetic.text(cell.material.key,p,&work); try RefinementArithmetic.text(cell.source.source,p,&work)
        }
        guard state.frame == mesh.frame else { throw .frameMismatch }
        guard state.meshRevision == mesh.revision, state.nodeIdentifiers.count == mesh.nodes.count,
              state.positions.count == mesh.nodes.count, state.velocities.count == mesh.nodes.count else { throw .staleLayout }
        for n in mesh.nodes.indices {
            try RefinementArithmetic.charge(1,p,&work)
            guard state.nodeIdentifiers[n] == mesh.nodes[n].identifier else { throw .staleLayout }
        }
        for cell in mesh.cells {
            try RefinementArithmetic.charge(96,p,&work)
            guard try RefinementArithmetic.volume(state.positions,cell.nodes) >= p.minimumCurrentVolume else { throw .physicalResidual }
        }
    }

    private func explicitBoundary(_ boundary: RefinementBoundaryMapping, layout: Tet4RefinementLayout,
                                  policy p: RefinementPolicy, work: inout NumericalWork) throws(RefinementError) -> RefinementBoundaryAssignments {
        switch boundary {
        case .explicitGroups(let assignments):
            guard assignments.layout === layout else { throw .staleSource }
            try RefinementArithmetic.text(assignments.owner,p,&work)
            guard assignments.midpointGroups.count == layout.edges.count,
                  assignments.originalFaceGroups.count == layout.boundaryFaces.count else { throw .invalidAssignment }
            return assignments
        // FIXME(INCOMPLETE_IMPLEMENTATION): Inferred physical constraints reach the public red-refinement operation.
        // Boundary group metadata does not define constraint DOF or authority. Explicit constraint operators,
        // interpolation/dual contracts and independent enforcement proof are required before this can succeed.
        case .inferConstraints: throw .unsupportedBoundaryMapping
        }
    }

    private func admitLoads(_ policy: RefinementLoadPolicy) throws(RefinementError) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Distributed traction and arbitrary nodal redistribution reach refinement.
        // Actual boundary integration and declared P-transpose-consistent covector mapping with original
        // force/moment/arbitrary virtual-power evidence are required before those load domains can succeed.
        guard policy == .retainConcentratedOriginalNodes else { throw .unsupportedLoadMapping }
    }

    private func admitIdentifiers(_ ids: RefinementIdentifierAllocation, edges: Int, children: Int,
                                  mesh: TetrahedralMesh, policy p: RefinementPolicy, work: inout NumericalWork) throws(RefinementError) {
        guard edges > 0, children > 0 else { throw .invalidInput }
        let lastNode = try RefinementArithmetic.identifier(ids.firstMidpointNode,offset: edges-1)
        let lastCell = try RefinementArithmetic.identifier(ids.firstChildCell,offset: children-1)
        for node in mesh.nodes {
            try RefinementArithmetic.charge(2,p,&work)
            guard node.identifier < ids.firstMidpointNode || node.identifier > lastNode else { throw .identifierCollision }
        }
        for cell in mesh.cells {
            try RefinementArithmetic.charge(2,p,&work)
            guard cell.identifier < ids.firstChildCell || cell.identifier > lastCell else { throw .identifierCollision }
        }
    }

    private func cellMidpoints(_ cell: TetrahedronCell, layout: Tet4RefinementLayout, policy p: RefinementPolicy,
                               work: inout NumericalWork) throws(RefinementError) -> [Int] {
        let pairs = [[0,1],[0,2],[0,3],[1,2],[1,3],[2,3]]
        var nodes: [Int] = []; nodes.reserveCapacity(6)
        for pair in pairs { nodes.append(try RefinementTopology.midpoint(cell.nodes[pair[0]],cell.nodes[pair[1]],layout: layout,policy: p,work: &work)) }
        return nodes
    }

    private func selectedDiagonal(_ e: [Int], nodes: [FlexibleNode], policy: CentralOctahedronDiagonalPolicy,
                                  resource p: RefinementPolicy, work: inout NumericalWork) throws(RefinementError) -> (diagonal: [Int], ring: [Int]) {
        let candidates = [[e[0],e[5]],[e[1],e[4]],[e[2],e[3]]]
        let rings = [[e[1],e[2],e[4],e[3]],[e[0],e[2],e[5],e[3]],[e[0],e[1],e[5],e[4]]]
        var selected = 0, bestLength = 0.0
        for i in 0..<3 {
            try RefinementArithmetic.charge(48,p,&work)
            let delta = try RefinementArithmetic.core { () throws(CoreError) in try nodes[candidates[i][0]].referencePosition.subtracting(nodes[candidates[i][1]].referencePosition) }
            let length = try RefinementArithmetic.core { () throws(CoreError) in try delta.magnitude() }
            let a = min(candidates[i][0],candidates[i][1]), b = max(candidates[i][0],candidates[i][1])
            let oldA = min(candidates[selected][0],candidates[selected][1]), oldB = max(candidates[selected][0],candidates[selected][1])
            let lexEarlier = a < oldA || (a == oldA && b < oldB)
            if i == 0 || (policy == .shortestReferenceDiagonal && (length < bestLength || (length == bestLength && lexEarlier))) || (policy == .lexicographicOppositeEdges && lexEarlier) {
                selected = i; bestLength = length
            }
        }
        return (candidates[selected],rings[selected])
    }

    private func cellMappings(_ layout: Tet4RefinementLayout, refined: ValidatedTetrahedralMesh, state: NodalState,
                              diagonals: [[Int]], policy p: RefinementPolicy,
                              work: inout NumericalWork) throws(RefinementError) -> [RefinementCellMapping] {
        var result: [RefinementCellMapping] = []; result.reserveCapacity(layout.source.mesh.mesh.cells.count)
        for (index,parent) in layout.source.mesh.mesh.cells.enumerated() {
            let oldReference = layout.source.mesh.referenceCells[index].volume
            try RefinementArithmetic.charge(96,p,&work)
            let oldCurrent = try RefinementArithmetic.volume(layout.source.state.positions,parent.nodes)
            var reference = 0.0, current = 0.0, children: [UInt64] = []; children.reserveCapacity(8)
            for ordinal in 0..<8 {
                try RefinementArithmetic.charge(128,p,&work)
                let child = refined.referenceCells[8*index+ordinal], currentVolume = try RefinementArithmetic.volume(state.positions,child.cell.nodes)
                try RefinementArithmetic.text(child.cell.material.key,p,&work)
                try RefinementArithmetic.text(child.cell.source.source,p,&work)
                guard child.cell.parentIdentifier == parent.identifier, child.cell.material == parent.material,
                      child.cell.source == parent.source, currentVolume >= p.minimumCurrentVolume,
                      abs(child.volume-oldReference/8) <= p.volumeTolerance,
                      abs(currentVolume-oldCurrent/8) <= p.volumeTolerance else { throw .physicalResidual }
                reference = try RefinementArithmetic.finite(reference+child.volume)
                current = try RefinementArithmetic.finite(current+currentVolume)
                children.append(child.cell.identifier)
            }
            guard abs(reference-oldReference) <= p.volumeTolerance, abs(current-oldCurrent) <= p.volumeTolerance else { throw .physicalResidual }
            result.append(RefinementCellMapping(cell: parent,children: children,diagonal: diagonals[index],
                reference: oldReference,refinedReference: reference,current: oldCurrent,refinedCurrent: current))
        }
        return result
    }

    private func faceMappings(_ layout: Tet4RefinementLayout, refinedFaces: [RefinementFace],
                              refinedNodes: [FlexibleNode], assignments: RefinementBoundaryAssignments, policy p: RefinementPolicy,
                              work: inout NumericalWork) throws(RefinementError) -> [RefinementFaceSubdivision] {
        var result: [RefinementFaceSubdivision] = []; result.reserveCapacity(layout.faces.count)
        var mappedBoundary = [Bool](repeating: false,count: refinedFaces.count)
        for face in layout.faces {
            let a = face.nodes[0], b = face.nodes[1], c = face.nodes[2]
            let ab = try RefinementTopology.midpoint(a,b,layout: layout,policy: p,work: &work)
            let bc = try RefinementTopology.midpoint(b,c,layout: layout,policy: p,work: &work)
            let ca = try RefinementTopology.midpoint(c,a,layout: layout,policy: p,work: &work)
            let expected = [[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]
            try RefinementArithmetic.charge(128,p,&work)
            let originalAreaVector = try RefinementArithmetic.faceAreaVector(layout.source.mesh.mesh.nodes,face.nodes)
            let originalArea = try RefinementArithmetic.core { () throws(CoreError) in try originalAreaVector.magnitude() }
            let quarterAreaVector = try RefinementArithmetic.core { () throws(CoreError) in try originalAreaVector.scaled(by: 0.25) }
            var areaVector = Vector3.zero, totalArea = 0.0, maximumAreaResidual = 0.0
            var children: [RefinementFace] = []; children.reserveCapacity(4)
            for triangle in expected {
                var selected: Int?
                let start = try RefinementArithmetic.product(32,face.cellIndex)
                for i in start..<(start+32) {
                    try RefinementArithmetic.charge(32,p,&work)
                    let candidate = refinedFaces[i]
                    if RefinementArithmetic.sameFace(triangle,candidate.nodes) {
                        guard selected == nil, RefinementArithmetic.sameOrientation(triangle,candidate.nodes),
                              candidate.isBoundary == face.isBoundary else { throw .invalidTopology }
                        selected = i
                    }
                }
                guard let selected else { throw .invalidTopology }
                if face.isBoundary { guard !mappedBoundary[selected] else { throw .invalidTopology }; mappedBoundary[selected] = true }
                try RefinementArithmetic.charge(128,p,&work)
                let childAreaVector = try RefinementArithmetic.faceAreaVector(refinedNodes,refinedFaces[selected].nodes)
                let childArea = try RefinementArithmetic.core { () throws(CoreError) in try childAreaVector.magnitude() }
                let areaResidual = try RefinementArithmetic.core { () throws(CoreError) in try childAreaVector.subtracting(quarterAreaVector).magnitude() }
                guard childArea > 0, try RefinementArithmetic.core({ () throws(CoreError) in try childAreaVector.dot(originalAreaVector) }) > 0,
                      areaResidual <= p.areaTolerance else { throw .physicalResidual }
                areaVector = try RefinementArithmetic.core { () throws(CoreError) in try areaVector.adding(childAreaVector) }
                totalArea = try RefinementArithmetic.finite(totalArea+childArea)
                maximumAreaResidual = max(maximumAreaResidual,areaResidual)
                children.append(refinedFaces[selected])
            }
            var group: UInt64?
            if face.isBoundary {
                try RefinementArithmetic.charge(layout.boundaryFaces.count,p,&work)
                guard let index = layout.boundaryFaces.firstIndex(where: { $0.cell == face.cell && $0.oppositeNode == face.oppositeNode }) else { throw .invalidAssignment }
                group = assignments.originalFaceGroups[index]
            }
            let totalAreaResidual = try RefinementArithmetic.core { () throws(CoreError) in try areaVector.subtracting(originalAreaVector).magnitude() }
            guard totalAreaResidual <= p.areaTolerance, abs(totalArea-originalArea) <= p.areaTolerance else { throw .physicalResidual }
            result.append(RefinementFaceSubdivision(original: face,children: children,group: group,owner: assignments.owner,
                originalArea: originalArea,refinedArea: totalArea,areaResidual: max(maximumAreaResidual,totalAreaResidual)))
        }
        for i in refinedFaces.indices {
            try RefinementArithmetic.charge(1,p,&work)
            guard refinedFaces[i].isBoundary == mappedBoundary[i] else { throw .invalidTopology }
        }
        return result
    }

    private func transferLoads(_ loads: ConcentratedRefinementLoads, prolongation: [RefinementProlongationRow],
                               state: NodalState, policy p: RefinementPolicy,
                               work: inout NumericalWork) throws(RefinementError) -> (forces: [Vector3], dual: Double, force: Double, moment: Double, power: Double) {
        let old = loads.source.state
        var forces = [Vector3](repeating: .zero,count: state.positions.count)
        for i in loads.forces.indices { try RefinementArithmetic.charge(1,p,&work); forces[i] = loads.forces[i] }
        var dual = [Vector3](repeating: .zero,count: old.positions.count)
        for row in prolongation {
            try RefinementArithmetic.charge(24,p,&work)
            dual[row.firstOriginalNode] = try RefinementArithmetic.core { () throws(CoreError) in try dual[row.firstOriginalNode].adding(forces[row.refinedNode].scaled(by: row.firstWeight)) }
            if let second = row.secondOriginalNode {
                dual[second] = try RefinementArithmetic.core { () throws(CoreError) in try dual[second].adding(forces[row.refinedNode].scaled(by: row.secondWeight)) }
            }
        }
        var dualResidual = 0.0, oldForce = Vector3.zero, oldMoment = Vector3.zero, oldPower = 0.0
        let origin = old.positions[0]
        for i in loads.forces.indices {
            try RefinementArithmetic.charge(96,p,&work)
            dualResidual = max(dualResidual,try RefinementArithmetic.core { () throws(CoreError) in try dual[i].subtracting(loads.forces[i]).magnitude() })
            oldForce = try RefinementArithmetic.core { () throws(CoreError) in try oldForce.adding(loads.forces[i]) }
            oldMoment = try RefinementArithmetic.core { () throws(CoreError) in try oldMoment.adding(old.positions[i].subtracting(origin).cross(loads.forces[i])) }
            oldPower = try RefinementArithmetic.finite(oldPower+RefinementArithmetic.core { () throws(CoreError) in try loads.forces[i].dot(old.velocities[i]) })
        }
        var newForce = Vector3.zero, newMoment = Vector3.zero, newPower = 0.0
        for i in forces.indices {
            try RefinementArithmetic.charge(96,p,&work)
            newForce = try RefinementArithmetic.core { () throws(CoreError) in try newForce.adding(forces[i]) }
            newMoment = try RefinementArithmetic.core { () throws(CoreError) in try newMoment.adding(state.positions[i].subtracting(origin).cross(forces[i])) }
            newPower = try RefinementArithmetic.finite(newPower+RefinementArithmetic.core { () throws(CoreError) in try forces[i].dot(state.velocities[i]) })
        }
        let fr = try RefinementArithmetic.core { () throws(CoreError) in try newForce.subtracting(oldForce).magnitude() }
        let mr = try RefinementArithmetic.core { () throws(CoreError) in try newMoment.subtracting(oldMoment).magnitude() }
        let pr = abs(try RefinementArithmetic.finite(newPower-oldPower))
        guard dualResidual <= p.forceTolerance, fr <= p.forceTolerance, mr <= p.momentTolerance, pr <= p.powerTolerance else { throw .physicalResidual }
        return (forces,dualResidual,fr,mr,pr)
    }
}
