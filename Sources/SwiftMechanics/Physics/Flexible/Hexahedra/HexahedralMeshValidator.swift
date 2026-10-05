public struct HexahedralMeshValidator: HexahedralMeshValidating {
    public init() {}

    public func validate(_ mesh: HexahedralMesh, admission: HexahedralAdmission,
                         work: inout NumericalWork) throws(HexahedralError) -> ValidatedHexahedralMesh {
        let nodeCount = mesh.nodes.count, cellCount = mesh.cells.count, materialCount = mesh.materials.count
        guard nodeCount > 0, cellCount > 0, materialCount > 0 else { throw .invalidParameter }
        guard nodeCount <= admission.maximumNodes, cellCount <= admission.maximumCells,
              materialCount <= admission.maximumMaterials else { throw .capacityExceeded }
        try HexahedralArithmetic.checkpoint(admission.isCancelled)
        let retained = try HexahedralArithmetic.product(cellCount, 336)
        let storage = try HexahedralArithmetic.sum(retained, HexahedralArithmetic.sum(nodeCount, 128))
        try HexahedralArithmetic.storage(storage, &work)
        try HexahedralArithmetic.admit(mesh.frame.key, isCancelled: admission.isCancelled, work: &work)
        try HexahedralArithmetic.admit(mesh.source.source, isCancelled: admission.isCancelled, work: &work)
        var participation = [Bool](repeating: false, count: nodeCount)
        var reference: [ReferenceHexahedron] = []
        reference.reserveCapacity(cellCount)
        for i in mesh.nodes.indices {
            try HexahedralArithmetic.checkpoint(admission.isCancelled)
            for j in 0..<i {
                try HexahedralArithmetic.charge(1, &work)
                guard mesh.nodes[i].identifier != mesh.nodes[j].identifier else { throw .invalidIdentity }
            }
        }
        for i in mesh.materials.indices {
            let material = mesh.materials[i]
            try HexahedralArithmetic.admit(material.identifier.key, isCancelled: admission.isCancelled, work: &work)
            try HexahedralArithmetic.admit(material.source.source, isCancelled: admission.isCancelled, work: &work)
            for j in 0..<i {
                guard try !HexahedralArithmetic.same(material.identifier, mesh.materials[j].identifier,
                    isCancelled: admission.isCancelled, work: &work) else { throw .invalidIdentity }
            }
        }
        for (index, cell) in mesh.cells.enumerated() {
            try HexahedralArithmetic.checkpoint(admission.isCancelled)
            try HexahedralArithmetic.admit(cell.source.source, isCancelled: admission.isCancelled, work: &work)
            for previous in 0..<index {
                try HexahedralArithmetic.checkpoint(admission.isCancelled)
                try HexahedralArithmetic.charge(1, &work)
                guard cell.identifier != mesh.cells[previous].identifier else { throw .invalidIdentity }
                var sameConnectivity = true
                for node in cell.nodes {
                    try HexahedralArithmetic.charge(8, &work)
                    if !mesh.cells[previous].nodes.contains(node) { sameConnectivity = false }
                }
                guard !sameConnectivity else { throw .duplicateCell }
            }
            for i in 0..<8 {
                try HexahedralArithmetic.charge(2, &work)
                let node = cell.nodes[i]
                guard node >= 0, node < nodeCount else { throw .invalidConnectivity }
                for j in 0..<i {
                    try HexahedralArithmetic.charge(1, &work)
                    guard node != cell.nodes[j] else { throw .invalidConnectivity }
                }
                participation[node] = true
            }
            var materialIndex: Int?
            for i in mesh.materials.indices {
                if try HexahedralArithmetic.same(cell.material, mesh.materials[i].identifier,
                    isCancelled: admission.isCancelled, work: &work) { materialIndex = i }
            }
            guard let materialIndex else { throw .missingMaterial }
            guard try TrilinearHexahedralMapping.certified(nodes: cell.nodes,
                position: { mesh.nodes[$0].referencePosition }, floor: admission.minimumReferenceDeterminant,
                relativeMargin: admission.certificateRelativeMargin, isCancelled: admission.isCancelled,
                work: &work) else { throw .referenceJacobianNotCertified(cell: cell.identifier) }
            var points: [ReferenceHexahedralPoint] = []
            points.reserveCapacity(8)
            for point in 0..<8 {
                try HexahedralArithmetic.checkpoint(admission.isCancelled)
                let natural = try TrilinearHexahedralMapping.gaussCoordinate(point)
                let jacobian = try TrilinearHexahedralMapping.jacobian(nodes: cell.nodes, at: natural,
                    position: { mesh.nodes[$0].referencePosition }, work: &work)
                try HexahedralArithmetic.charge(15, &work)
                let determinant = try HexahedralArithmetic.core { () throws(CoreError) in try jacobian.determinant() }
                guard determinant > admission.minimumReferenceDeterminant else {
                    throw .referenceJacobianNotCertified(cell: cell.identifier)
                }
                try HexahedralArithmetic.charge(68, &work)
                let inverse: Matrix3
                do { inverse = try jacobian.inverted(relativeTolerance: admission.inverseRelativeTolerance) }
                catch { throw .singularReferenceJacobian(cell: cell.identifier, point: point) }
                var shapes: [Double] = [], gradients: [Vector3] = []
                shapes.reserveCapacity(8)
                gradients.reserveCapacity(8)
                let inverseTranspose = inverse.transposed()
                for node in 0..<8 {
                    shapes.append(try TrilinearHexahedralMapping.shape(node, at: natural, work: &work))
                    let gradient = try TrilinearHexahedralMapping.naturalGradient(node, at: natural, work: &work)
                    try HexahedralArithmetic.charge(15, &work)
                    gradients.append(try HexahedralArithmetic.core { () throws(CoreError) in try inverseTranspose.applying(to: gradient) })
                }
                points.append(ReferenceHexahedralPoint(inverseJacobian: inverse, determinant: determinant,
                                                       shape: shapes, gradients: gradients))
            }
            reference.append(ReferenceHexahedron(materialIndex: materialIndex, points: points))
        }
        for used in participation {
            try HexahedralArithmetic.checkpoint(admission.isCancelled)
            try HexahedralArithmetic.charge(1, &work)
            guard used else { throw .unusedNode }
        }
        try HexahedralArithmetic.checkpoint(admission.isCancelled)
        return ValidatedHexahedralMesh(mesh: mesh, scalarStorage: retained, referenceCells: reference, admission: admission)
    }
}
