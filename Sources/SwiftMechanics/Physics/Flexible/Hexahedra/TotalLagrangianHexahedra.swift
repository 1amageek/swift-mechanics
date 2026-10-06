public struct TotalLagrangianHexahedra: HexahedralAssembling {
    public let isCancelled: @Sendable () -> Bool

    public init(isCancelled: @escaping @Sendable () -> Bool = { false }) {
        self.isCancelled = isCancelled
    }

    public func assemble(_ validated: ValidatedHexahedralMesh, state: HexahedralNodalState,
                         massForm: FlexibleMassForm, constitutiveWork: inout HexahedralConstitutiveWork,
                         work: inout NumericalWork) throws(HexahedralError) -> HexahedralAssembly {
        let mesh = validated.mesh, admission = validated.admission
        let cancelled: @Sendable () -> Bool = { admission.isCancelled() || self.isCancelled() }
        try HexahedralArithmetic.checkpoint(cancelled)
        let nodeCount = mesh.nodes.count
        guard state.meshIdentifier == mesh.identifier, state.meshRevision == mesh.revision,
              state.nodeIdentifiers.count == nodeCount, state.positions.count == nodeCount,
              state.velocities.count == nodeCount else { throw .layoutMismatch }
        guard try HexahedralArithmetic.same(state.frame, mesh.frame, isCancelled: cancelled, work: &work),
              try HexahedralArithmetic.same(state.meshSource, mesh.source, isCancelled: cancelled, work: &work)
        else { throw .layoutMismatch }
        try HexahedralArithmetic.admit(state.source.source, isCancelled: cancelled, work: &work)
        for i in 0..<nodeCount {
            try HexahedralArithmetic.checkpoint(cancelled)
            try HexahedralArithmetic.charge(1, &work)
            guard state.nodeIdentifiers[i] == mesh.nodes[i].identifier else { throw .layoutMismatch }
        }
        let n = try HexahedralArithmetic.product(nodeCount, 3)
        let square = try HexahedralArithmetic.product(n, n)
        let outputStorage = try HexahedralArithmetic.sum(HexahedralArithmetic.product(square, 3), HexahedralArithmetic.product(n, 2))
        let peakStorage = try HexahedralArithmetic.sum(validated.scalarStorage, HexahedralArithmetic.sum(outputStorage, 128))
        try HexahedralArithmetic.storage(peakStorage, &work)
        var force = [Double](repeating: 0, count: n), tangent = [Double](repeating: 0, count: square)
        var mass = [Double](repeating: 0, count: square), damping = [Double](repeating: 0, count: square)
        var dampingForce = [Double](repeating: 0, count: n)
        var energy = 0.0, totalMass = 0.0, totalVolume = 0.0, power = 0.0
        for (cellIndex, reference) in validated.referenceCells.enumerated() {
            try HexahedralArithmetic.checkpoint(cancelled)
            let cell = mesh.cells[cellIndex], material = mesh.materials[reference.materialIndex]
            guard try TrilinearHexahedralMapping.certified(nodes: cell.nodes,
                position: { state.positions[$0] }, floor: admission.minimumCurrentDeterminant,
                relativeMargin: admission.certificateRelativeMargin, isCancelled: cancelled,
                work: &work) else { throw .currentJacobianNotCertified(cell: cell.identifier) }
            let law: any HyperelasticResponding = material.law
            for (pointIndex, point) in reference.points.enumerated() {
                try HexahedralArithmetic.checkpoint(cancelled)
                let natural = try TrilinearHexahedralMapping.gaussCoordinate(pointIndex)
                let currentJacobian = try TrilinearHexahedralMapping.jacobian(nodes: cell.nodes, at: natural,
                    position: { state.positions[$0] }, work: &work)
                try HexahedralArithmetic.charge(15, &work)
                let determinant = try HexahedralArithmetic.core { () throws(CoreError) in try currentJacobian.determinant() }
                guard determinant > admission.minimumCurrentDeterminant else {
                    throw .currentJacobianNotCertified(cell: cell.identifier)
                }
                try HexahedralArithmetic.charge(45, &work)
                let f = try HexahedralArithmetic.core { () throws(CoreError) in
                    try currentJacobian.multiplied(by: point.inverseJacobian)
                }
                try constitutiveWork.charge()
                let response: FiniteStressResponse
                do { response = try law.evaluate(deformationGradient: f) } catch { throw .material(error) }
                // All Gauss weights are one. The determinant is physical reference volume per point.
                try HexahedralArithmetic.charge(7, &work)
                energy = try HexahedralArithmetic.finite(energy + point.determinant * response.energyDensity)
                let pointMass = try HexahedralArithmetic.finite(material.referenceDensity * point.determinant)
                let pointDamping = try HexahedralArithmetic.finite(material.massDampingRate * pointMass)
                totalMass = try HexahedralArithmetic.finite(totalMass + pointMass)
                totalVolume = try HexahedralArithmetic.finite(totalVolume + point.determinant)
                let pointPower = try dissipatedPower(point, cell: cell, state: state, coefficient: pointDamping,
                    massForm: massForm, work: &work)
                try HexahedralArithmetic.charge(1, &work)
                power = try HexahedralArithmetic.finite(power + pointPower)
                for i in 0..<8 {
                    try HexahedralArithmetic.charge(15, &work)
                    let p = try HexahedralArithmetic.core { () throws(CoreError) in
                        try response.firstPiolaStress.applying(to: point.gradients[i])
                    }
                    for axis in 0..<3 {
                        let row = 3 * cell.nodes[i] + axis
                        try HexahedralArithmetic.charge(2, &work)
                        force[row] = try HexahedralArithmetic.finite(force[row] + point.determinant * HexahedralArithmetic.component(p, axis))
                    }
                }
                for j in 0..<8 { for axis in 0..<3 {
                    try HexahedralArithmetic.checkpoint(cancelled)
                    let gradient = point.gradients[j]
                    let h = try HexahedralArithmetic.core { () throws(CoreError) in
                        try Matrix3(axis == 0 ? gradient.x : 0, axis == 0 ? gradient.y : 0, axis == 0 ? gradient.z : 0,
                                    axis == 1 ? gradient.x : 0, axis == 1 ? gradient.y : 0, axis == 1 ? gradient.z : 0,
                                    axis == 2 ? gradient.x : 0, axis == 2 ? gradient.y : 0, axis == 2 ? gradient.z : 0)
                    }
                    try constitutiveWork.charge()
                    let derivative: FiniteStressDirectionalResponse
                    do { derivative = try law.tangent(deformationGradient: f, direction: h) }
                    catch { throw .material(error) }
                    for i in 0..<8 {
                        try HexahedralArithmetic.charge(15, &work)
                        // dP = h*S + F*dS includes geometric prestress and material stiffness exactly once.
                        let dp = try HexahedralArithmetic.core { () throws(CoreError) in
                            try derivative.firstPiolaDirection.applying(to: point.gradients[i])
                        }
                        for rowAxis in 0..<3 {
                            let entry = (3 * cell.nodes[i] + rowAxis) * n + 3 * cell.nodes[j] + axis
                            try HexahedralArithmetic.charge(2, &work)
                            tangent[entry] = try HexahedralArithmetic.finite(tangent[entry] + point.determinant * HexahedralArithmetic.component(dp, rowAxis))
                        }
                    }
                } }
                for i in 0..<8 { for j in 0..<8 {
                    try HexahedralArithmetic.charge(3, &work)
                    let shapeProduct = try HexahedralArithmetic.finite(point.shape[i] * point.shape[j])
                    let m = try HexahedralArithmetic.finite(pointMass * shapeProduct)
                    let c = try HexahedralArithmetic.finite(pointDamping * shapeProduct)
                    for axis in 0..<3 {
                        let entry = (3 * cell.nodes[i] + axis) * n + 3 * cell.nodes[j] + axis
                        try HexahedralArithmetic.charge(2, &work)
                        mass[entry] = try HexahedralArithmetic.finite(mass[entry] + m)
                        damping[entry] = try HexahedralArithmetic.finite(damping[entry] + c)
                    }
                } }
            }
        }
        if massForm == .rowSumLumped {
            for row in 0..<n {
                try HexahedralArithmetic.checkpoint(cancelled)
                var rowMass = 0.0, rowDamping = 0.0
                for column in 0..<n {
                    let entry = row * n + column
                    try HexahedralArithmetic.charge(2, &work)
                    rowMass = try HexahedralArithmetic.finite(rowMass + mass[entry])
                    rowDamping = try HexahedralArithmetic.finite(rowDamping + damping[entry])
                    mass[entry] = 0
                    damping[entry] = 0
                }
                mass[row * n + row] = rowMass
                damping[row * n + row] = rowDamping
            }
        }
        for row in 0..<n {
            try HexahedralArithmetic.checkpoint(cancelled)
            for column in 0..<n {
                try HexahedralArithmetic.charge(2, &work)
                dampingForce[row] = try HexahedralArithmetic.finite(dampingForce[row]
                    + damping[row * n + column] * HexahedralArithmetic.component(state.velocities[column / 3], column % 3))
            }
        }
        try HexahedralArithmetic.checkpoint(cancelled)
        return HexahedralAssembly(reference: validated, state: state, nodeIdentifiers: state.nodeIdentifiers,
            coordinateCount: n, internalForce: force, tangent: tangent, mass: mass, damping: damping,
            dampingForce: dampingForce, storedEnergy: energy, dissipatedPower: power,
            totalReferenceMass: totalMass, totalReferenceVolume: totalVolume, massForm: massForm,
            numericalWork: work, constitutiveWork: constitutiveWork)
    }

    private func dissipatedPower(_ point: ReferenceHexahedralPoint, cell: HexahedronCell,
                                 state: HexahedralNodalState, coefficient: Double, massForm: FlexibleMassForm,
                                 work: inout NumericalWork) throws(HexahedralError) -> Double {
        // Evaluate the positive quadrature quadratic form directly rather than cancellation-prone v dot (C*v).
        // In exact arithmetic this is the assembled consistent or row-sum-lumped v^T*C*v.
        try HexahedralArithmetic.charge(1, &work)
        if coefficient == 0 { return 0 }
        if massForm == .consistent {
            var x = 0.0, y = 0.0, z = 0.0
            for i in 0..<8 {
                let velocity = state.velocities[cell.nodes[i]], shape = point.shape[i]
                try HexahedralArithmetic.charge(6, &work)
                x = try HexahedralArithmetic.finite(x + shape * velocity.x)
                y = try HexahedralArithmetic.finite(y + shape * velocity.y)
                z = try HexahedralArithmetic.finite(z + shape * velocity.z)
            }
            try HexahedralArithmetic.charge(6, &work)
            return try HexahedralArithmetic.finite(coefficient * (x * x + y * y + z * z))
        }
        var result = 0.0
        for i in 0..<8 {
            let velocity = state.velocities[cell.nodes[i]]
            try HexahedralArithmetic.charge(8, &work)
            let squared = try HexahedralArithmetic.finite(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
            result = try HexahedralArithmetic.finite(result + coefficient * point.shape[i] * squared)
        }
        return result
    }
}
