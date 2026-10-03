import MechanicsCore
import MechanicsModel
import MechanicsNumerics
public struct TetrahedralMeshValidator: TetrahedralMeshValidating {
    public init() {}
    public func validate(_ mesh: TetrahedralMesh, admission: MeshAdmission, work: inout NumericalWork) throws(FlexibleError) -> ValidatedTetrahedralMesh {
        try capacity(mesh.nodes.count,mesh.cells.count,mesh.materials.count,admission)
        guard !admission.isCancelled() else { throw .cancelled }
        let storage = try FlexibleArithmetic.sum(FlexibleArithmetic.multiply(mesh.cells.count,26),mesh.nodes.count)
        try FlexibleArithmetic.storage(storage,&work)
        // The positions array is intentionally avoided: node owners retain original coordinates.
        var participation = [Bool](repeating:false,count:mesh.nodes.count)
        var prepared: [ReferenceTetrahedron] = []; prepared.reserveCapacity(mesh.cells.count)
        for i in mesh.nodes.indices { for j in 0..<i { try FlexibleArithmetic.charge(1,&work); guard mesh.nodes[i].identifier != mesh.nodes[j].identifier else { throw .invalidIdentity } } }
        for i in mesh.materials.indices { for j in 0..<i { guard try !FlexibleArithmetic.sameIdentity(mesh.materials[i].identifier,mesh.materials[j].identifier,isCancelled:admission.isCancelled,work:&work) else { throw .invalidIdentity } } }
        for (index,cell) in mesh.cells.enumerated() {
            guard !admission.isCancelled() else { throw .cancelled }
            try FlexibleArithmetic.charge(1,&work)
            for previous in 0..<index {
                try FlexibleArithmetic.charge(1,&work)
                guard cell.identifier != mesh.cells[previous].identifier else { throw .invalidIdentity }
                var same = true
                for n in cell.nodes { try FlexibleArithmetic.charge(4,&work); if !mesh.cells[previous].nodes.contains(n) { same = false } }
                guard !same else { throw .duplicateCell }
            }
            for i in 0..<4 {
                let n = cell.nodes[i]; guard n >= 0, n < mesh.nodes.count else { throw .invalidConnectivity }
                for j in 0..<i { try FlexibleArithmetic.charge(1,&work); guard n != cell.nodes[j] else { throw .invalidConnectivity } }
                participation[n] = true
            }
            var materialIndex: Int?
            for i in mesh.materials.indices { if try FlexibleArithmetic.sameIdentity(mesh.materials[i].identifier,cell.material,isCancelled:admission.isCancelled,work:&work) { materialIndex = i } }
            guard let materialIndex else { throw .missingMaterial }
            let p0 = mesh.nodes[cell.nodes[0]].referencePosition
            let a = try FlexibleArithmetic.subtract(mesh.nodes[cell.nodes[1]].referencePosition,p0,&work)
            let b = try FlexibleArithmetic.subtract(mesh.nodes[cell.nodes[2]].referencePosition,p0,&work)
            let c = try FlexibleArithmetic.subtract(mesh.nodes[cell.nodes[3]].referencePosition,p0,&work)
            let edges = try FlexibleArithmetic.core { () throws(CoreError) in try Matrix3(a.x,b.x,c.x,a.y,b.y,c.y,a.z,b.z,c.z) }
            try FlexibleArithmetic.charge(15,&work)
            let determinant = try FlexibleArithmetic.core { () throws(CoreError) in try edges.determinant() }
            try FlexibleArithmetic.charge(1,&work)
            let volume = try FlexibleArithmetic.finite(determinant/6)
            guard volume >= admission.minimumReferenceVolume else { throw .invalidReferenceCell(element:cell.identifier) }
            // 9 scaling divisions + 14 determinant ops + 45 cofactor/division ops; comparisons are charged separately.
            try FlexibleArithmetic.charge(68,&work)
            let inverse: Matrix3
            do { inverse = try edges.inverted(relativeTolerance:admission.inverseRelativeTolerance) } catch { throw .invalidReferenceCell(element:cell.identifier) }
            let g1 = try FlexibleArithmetic.core { () throws(CoreError) in try Vector3(inverse.m00,inverse.m01,inverse.m02) }
            let g2 = try FlexibleArithmetic.core { () throws(CoreError) in try Vector3(inverse.m10,inverse.m11,inverse.m12) }
            let g3 = try FlexibleArithmetic.core { () throws(CoreError) in try Vector3(inverse.m20,inverse.m21,inverse.m22) }
            try FlexibleArithmetic.charge(9,&work)
            let g0 = try FlexibleArithmetic.core { () throws(CoreError) in try Vector3(-g1.x-g2.x-g3.x,-g1.y-g2.y-g3.y,-g1.z-g2.z-g3.z) }
            prepared.append(ReferenceTetrahedron(cell:cell,materialIndex:materialIndex,volume:volume,inverseEdges:inverse,gradient0:g0,gradient1:g1,gradient2:g2,gradient3:g3))
        }
        guard !participation.contains(false) else { throw .unusedNode }
        return ValidatedTetrahedralMesh(mesh:mesh,referenceCells:prepared,scalarStorage:try FlexibleArithmetic.multiply(mesh.cells.count,26))
    }
    public func refine(_ validated: ValidatedTetrahedralMesh, revision: UInt64, newNodeIdentifiers: [UInt64], newCellIdentifiers: [UInt64], admission: MeshAdmission, work: inout NumericalWork) throws(FlexibleError) -> ValidatedTetrahedralMesh {
        let mesh = validated.mesh, count = mesh.cells.count
        let cellCount = try FlexibleArithmetic.multiply(count,4), nodeCount = try FlexibleArithmetic.sum(mesh.nodes.count,count)
        try capacity(nodeCount,cellCount,mesh.materials.count,admission)
        guard revision != mesh.revision, newNodeIdentifiers.count == count, newCellIdentifiers.count == cellCount else { throw .layoutMismatch }
        guard !admission.isCancelled() else { throw .cancelled }
        let outputStorage = try FlexibleArithmetic.sum(FlexibleArithmetic.multiply(nodeCount,5),FlexibleArithmetic.multiply(cellCount,8))
        try FlexibleArithmetic.storage(FlexibleArithmetic.sum(validated.scalarStorage,outputStorage),&work)
        // Copy-on-write ownership creates new reference geometry; old boundary identities remain unchanged.
        var nodes = mesh.nodes, cells: [TetrahedronCell] = []; nodes.reserveCapacity(nodeCount); cells.reserveCapacity(cellCount)
        for (i,cell) in mesh.cells.enumerated() {
            guard !admission.isCancelled() else { throw .cancelled }
            let a = mesh.nodes[cell.nodes[0]].referencePosition, b = mesh.nodes[cell.nodes[1]].referencePosition
            let c = mesh.nodes[cell.nodes[2]].referencePosition, d = mesh.nodes[cell.nodes[3]].referencePosition
            try FlexibleArithmetic.charge(12,&work)
            let centroid = try FlexibleArithmetic.core { () throws(CoreError) in try Vector3((a.x+b.x+c.x+d.x)/4,(a.y+b.y+c.y+d.y)/4,(a.z+b.z+c.z+d.z)/4) }
            let middle = nodes.count; nodes.append(FlexibleNode(identifier:newNodeIdentifiers[i],referencePosition:centroid))
            for j in 0..<4 {
                var indexes = cell.nodes; indexes[j] = middle
                cells.append(try TetrahedronCell(identifier:newCellIdentifiers[4*i+j],nodes:indexes,material:cell.material,source:cell.source,parentIdentifier:cell.identifier))
            }
        }
        let refined = try TetrahedralMesh(frame:mesh.frame,revision:revision,source:mesh.source,nodes:nodes,cells:cells,materials:mesh.materials)
        // Include both immutable meshes and all new arrays in the validation reserve, without resetting counters.
        let extra = try FlexibleArithmetic.sum(validated.scalarStorage,outputStorage)
        let ownReserve = try FlexibleArithmetic.sum(FlexibleArithmetic.multiply(cellCount,26),nodeCount)
        try FlexibleArithmetic.storage(FlexibleArithmetic.sum(extra,ownReserve),&work)
        return try validate(refined,admission:admission,work:&work)
    }
    private func capacity(_ nodes: Int, _ cells: Int, _ materials: Int, _ a: MeshAdmission) throws(FlexibleError) {
        guard nodes > 0, cells > 0, materials > 0 else { throw .invalidParameter }
        guard nodes <= a.maximumNodes, cells <= a.maximumCells, materials <= a.maximumMaterials else { throw .capacityExceeded }
    }
}
