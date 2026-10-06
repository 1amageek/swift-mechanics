/// Rectangular Q4 Mindlin membrane/plate assembly with MITC4 tied transverse shear.
public struct RectangularMindlinShellAssembler: ShellAssembling, Sendable {
    public init() {}

    public func assemble(_ plate: RectangularShellPlate, state: ShellNodalState, admission: ShellAdmission,
                         work: inout NumericalWork) throws(ShellError) -> ShellAssembly {
        try ShellArithmetic.check(admission)
        // FIXME(INCOMPLETE_IMPLEMENTATION): This production assembler implements infinitesimal MITC4 only.
        // Finite-rotation requests remain typed failures until objective strain, force, tangent,
        // inertia and their full physical execution path are implemented and qualified.
        guard plate.formulation == .infinitesimalMITC4 else { throw .unsupportedFormulation }
        guard plate.cellCount <= admission.maximumCells, plate.nodeCount <= admission.maximumNodes else {
            throw .capacityExceeded
        }
        var metadataBytes = 0
        for text in [plate.identity, state.plateIdentity, plate.frame.key, state.frame.key,
                     plate.source.source, state.source.source] {
            try ShellArithmetic.metadata(text, byteCount: &metadataBytes, admission: admission, work: &work)
        }
        try ShellArithmetic.charge(metadataBytes, &work)
        guard state.frame == plate.frame else { throw .frameMismatch }
        guard state.plateIdentity == plate.identity, state.plateRevision == plate.revision,
              state.source == plate.source else { throw .staleSource }
        let count = plate.coordinateCount
        guard state.coordinates.count == count, state.velocities.count == count else { throw .invalidLayout }
        let square = try ShellArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(count, count) }
        // Three dense operators, two input arrays, two force arrays, and fixed local workspaces.
        let storage = try ShellArithmetic.numerical { () throws(NumericalError) in
            try NumericalWork.sum(NumericalWork.product(3, square), NumericalWork.sum(NumericalWork.product(4, count), 256))
        }
        do { try work.requireStorage(storage) } catch { throw .numerical(error) }
        try ShellArithmetic.charge(512, &work)
        let dx = try ShellArithmetic.positive(plate.width / Double(plate.elementsX))
        let dy = try ShellArithmetic.positive(plate.height / Double(plate.elementsY))
        let inverseHalfWidth = try ShellArithmetic.positive(0.5 / dx)
        let inverseHalfHeight = try ShellArithmetic.positive(0.5 / dy)
        let weight = try ShellArithmetic.positive((dx * dy) / 4)
        let h = plate.thickness
        let h3over12 = try ShellArithmetic.positive((h * h) * (h / 12))
        let translationDensity = try ShellArithmetic.positive(plate.density * h)
        let rotaryDensity = try ShellArithmetic.positive(plate.density * h3over12)
        let shearScale = try ShellArithmetic.positive(plate.shearCorrection * plate.elasticity.shearModulus * h)
        let area = try ShellArithmetic.positive(plate.width * plate.height)
        let totalMass = try ShellArithmetic.positive(translationDensity * area)
        let totalRotaryInertia = try ShellArithmetic.positive(rotaryDensity * area)
        let (c11, c12, c33) = try planeStress(plate.elasticity)
        // Reject lost physical scales, including derivative-squared underflow, before publishing a matrix.
        for scale in [h * c11, h3over12 * c11, shearScale, translationDensity, rotaryDensity] {
            _ = try ShellArithmetic.positive(weight * scale)
        }
        for inverseLength in [inverseHalfWidth, inverseHalfHeight] {
            _ = try ShellArithmetic.positive(((weight * h) * inverseLength) * (c11 * inverseLength))
            _ = try ShellArithmetic.positive(((weight * h3over12) * inverseLength) * (c11 * inverseLength))
        }
        _ = try plate.basis.referencePosition(x: plate.width, y: 0)
        _ = try plate.basis.referencePosition(x: 0, y: plate.height)
        _ = try plate.basis.referencePosition(x: plate.width, y: plate.height)
        var tangent = [Double](repeating: 0, count: square)
        var mass = [Double](repeating: 0, count: square)
        var damping = [Double](repeating: 0, count: square)
        var force = [Double](repeating: 0, count: count)
        var dampingForce = [Double](repeating: 0, count: count)
        // Reused local arrays prevent per-cell/quadrature materialization.
        var membrane = [Double](repeating: 0, count: 60)
        var bending = [Double](repeating: 0, count: 60)
        var shear = [Double](repeating: 0, count: 40)
        var shapes = [Double](repeating: 0, count: 4)
        var nodes = [Int](repeating: 0, count: 4)
        var energy = 0.0, massPower = 0.0, stiffnessPower = 0.0
        let gauss = 1 / 3.0.squareRoot()
        for row in 0..<plate.elementsY {
            for column in 0..<plate.elementsX {
                try ShellArithmetic.check(admission)
                let cell = row * plate.elementsX + column
                let lowerLeft = row * (plate.elementsX + 1) + column
                nodes[0] = lowerLeft; nodes[1] = lowerLeft + 1
                nodes[2] = lowerLeft + plate.elementsX + 2; nodes[3] = lowerLeft + plate.elementsX + 1
                for corner in 0..<4 {
                    try ShellArithmetic.check(admission)
                    let xi = corner == 0 || corner == 3 ? -1.0 : 1.0
                    let eta = corner < 2 ? -1.0 : 1.0
                    try validateCorner(plate, state: state, nodes: nodes, cell: cell, xi: xi, eta: eta,
                                       inverseHalfWidth: inverseHalfWidth, inverseHalfHeight: inverseHalfHeight, work: &work)
                }
                for point in 0..<4 {
                    try ShellArithmetic.check(admission)
                    // Conservative charge includes interpolation, all twenty-column bilinear products and mass assembly.
                    try ShellArithmetic.charge(32_000, &work)
                    let xi = point % 2 == 0 ? -gauss : gauss
                    let eta = point < 2 ? -gauss : gauss
                    interpolate(xi: xi, eta: eta, inverseHalfWidth: inverseHalfWidth,
                                inverseHalfHeight: inverseHalfHeight, membrane: &membrane,
                                bending: &bending, shear: &shear, shapes: &shapes)
                    let storedDensity = try energyDensity(membrane: membrane, bending: bending, shear: shear,
                                                          coordinates: state.coordinates, nodes: nodes,
                                                          h: h, h3over12: h3over12, shearScale: shearScale,
                                                          c11: c11, c12: c12, c33: c33)
                    energy = try ShellArithmetic.finite(energy + weight * storedDensity)
                    if plate.stiffnessDampingTime > 0 {
                        let rateDensity = try energyDensity(membrane: membrane, bending: bending, shear: shear,
                                                            coordinates: state.velocities, nodes: nodes,
                                                            h: h, h3over12: h3over12, shearScale: shearScale,
                                                            c11: c11, c12: c12, c33: c33)
                        stiffnessPower = try ShellArithmetic.finite(stiffnessPower + 2 * weight * rateDensity)
                    }
                    if plate.massDampingRate > 0, admission.massForm == .consistent {
                        var kineticRate = 0.0
                        for axis in 0..<5 {
                            var rate = 0.0
                            for node in 0..<4 {
                                rate = try ShellArithmetic.finite(rate + shapes[node] * state.velocities[5 * nodes[node] + axis])
                            }
                            kineticRate = try ShellArithmetic.finite(kineticRate + (axis < 3 ? translationDensity : rotaryDensity) * rate * rate)
                        }
                        massPower = try ShellArithmetic.finite(massPower + weight * kineticRate)
                    }
                    for i in 0..<20 {
                        let globalI = 5 * nodes[i / 5] + i % 5
                        for j in i..<20 {
                            let globalJ = 5 * nodes[j / 5] + j % 5
                            let membranePart = try ShellArithmetic.finite(h * contraction(membrane, i, j, c11, c12, c33))
                            let bendingPart = try ShellArithmetic.finite(h3over12 * contraction(bending, i, j, c11, c12, c33))
                            let shearPart = try ShellArithmetic.finite(shearScale * (shear[i] * shear[j] + shear[20 + i] * shear[20 + j]))
                            let contribution = try ShellArithmetic.finite(weight * (membranePart + bendingPart + shearPart))
                            let entry = globalI * count + globalJ
                            tangent[entry] = try ShellArithmetic.finite(tangent[entry] + contribution)
                            if i != j { tangent[globalJ * count + globalI] = tangent[entry] }
                        }
                    }
                    for i in 0..<4 {
                        for j in i..<4 {
                            let base = try ShellArithmetic.finite(weight * shapes[i] * shapes[j])
                            for axis in 0..<5 {
                                let globalI = 5 * nodes[i] + axis, globalJ = 5 * nodes[j] + axis
                                let contribution = try ShellArithmetic.finite(base * (axis < 3 ? translationDensity : rotaryDensity))
                                let entry = globalI * count + globalJ
                                mass[entry] = try ShellArithmetic.finite(mass[entry] + contribution)
                                if i != j { mass[globalJ * count + globalI] = mass[entry] }
                            }
                        }
                    }
                }
            }
        }
        if admission.massForm == .rowSumLumped {
            for i in 0..<count {
                try ShellArithmetic.check(admission)
                let lumpOperations = try ShellArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(count, 4) }
                try ShellArithmetic.charge(lumpOperations, &work)
                var rowMass = 0.0
                for j in 0..<count {
                    rowMass = try ShellArithmetic.finite(rowMass + mass[i * count + j])
                    mass[i * count + j] = 0
                }
                mass[i * count + i] = try ShellArithmetic.positive(rowMass)
                if plate.massDampingRate > 0 {
                    massPower = try ShellArithmetic.finite(massPower + rowMass * state.velocities[i] * state.velocities[i])
                }
            }
        }
        for i in 0..<count {
            try ShellArithmetic.check(admission)
            let rowOperations = try ShellArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(10, count) }
            try ShellArithmetic.charge(rowOperations, &work)
            for j in 0..<count {
                let index = i * count + j
                damping[index] = try ShellArithmetic.finite(plate.massDampingRate * mass[index] + plate.stiffnessDampingTime * tangent[index])
                force[i] = try ShellArithmetic.finite(force[i] + tangent[index] * state.coordinates[j])
                dampingForce[i] = try ShellArithmetic.finite(dampingForce[i] + damping[index] * state.velocities[j])
            }
        }
        try ShellArithmetic.charge(4, &work)
        let power = try ShellArithmetic.finite(plate.massDampingRate * massPower + plate.stiffnessDampingTime * stiffnessPower)
        try ShellArithmetic.check(admission)
        return ShellAssembly(plate: plate, massForm: admission.massForm, internalForce: force, tangent: tangent,
                             mass: mass, damping: damping, dampingForce: dampingForce, storedEnergy: energy,
                             dissipatedPower: power, totalReferenceMass: totalMass,
                             totalReferenceRotaryInertia: totalRotaryInertia, numericalWork: work)
    }

    private func planeStress(_ elasticity: IsotropicElasticity) throws(ShellError) -> (Double, Double, Double) {
        let denominator = try ShellArithmetic.positive(elasticity.lameLambda + 2 * elasticity.shearModulus)
        let ratio = try ShellArithmetic.finite(elasticity.lameLambda / denominator)
        let direction = try ShellArithmetic.material { () throws(MaterialError) in
            try SymmetricTensor(xx: 1, yy: 0, zz: -ratio)
        }
        let law: any LinearElasticResponding = elasticity
        let stress = try ShellArithmetic.material { () throws(MaterialError) in try law.tangent(direction: direction) }
        let diagonal = try ShellArithmetic.positive(stress.xx)
        let coupling = try ShellArithmetic.finite(stress.yy)
        guard diagonal > abs(coupling) else { throw .nonFiniteResult }
        _ = try ShellArithmetic.positive(diagonal + coupling)
        _ = try ShellArithmetic.positive(diagonal - coupling)
        return (diagonal, coupling, elasticity.shearModulus)
    }

    private func signs(_ node: Int) -> (Double, Double) {
        (node == 0 || node == 3 ? -1 : 1, node < 2 ? -1 : 1)
    }

    private func interpolate(xi: Double, eta: Double, inverseHalfWidth: Double, inverseHalfHeight: Double, membrane: inout [Double],
                             bending: inout [Double], shear: inout [Double], shapes: inout [Double]) {
        for node in 0..<4 {
            let (sx, sy) = signs(node)
            let nx = sx * (1 + sy * eta) * inverseHalfWidth, ny = sy * (1 + sx * xi) * inverseHalfHeight
            let index = 5 * node
            shapes[node] = (1 + sx * xi) * (1 + sy * eta) / 4
            membrane[index] = nx; membrane[20 + index + 1] = ny
            membrane[40 + index] = ny; membrane[40 + index + 1] = nx
            bending[index + 3] = nx; bending[20 + index + 4] = ny
            bending[40 + index + 3] = ny; bending[40 + index + 4] = nx
            // MITC4: transverse gradients and edge-midpoint director tying in the rectangular basis.
            shear[index + 2] = nx; shear[index + 3] = (1 + sy * eta) / 4
            shear[20 + index + 2] = ny; shear[20 + index + 4] = (1 + sx * xi) / 4
        }
    }

    private func contraction(_ b: [Double], _ i: Int, _ j: Int,
                             _ c11: Double, _ c12: Double, _ c33: Double) -> Double {
        c11 * (b[i] * b[j] + b[20 + i] * b[20 + j])
            + c12 * (b[i] * b[20 + j] + b[20 + i] * b[j])
            + c33 * b[40 + i] * b[40 + j]
    }

    private func energyDensity(membrane: [Double], bending: [Double], shear: [Double], coordinates: [Double],
                               nodes: [Int], h: Double, h3over12: Double, shearScale: Double,
                               c11: Double, c12: Double, c33: Double) throws(ShellError) -> Double {
        let membraneDensity = try planeEnergy(membrane, coordinates: coordinates, nodes: nodes, c11: c11, c12: c12, c33: c33)
        let bendingDensity = try planeEnergy(bending, coordinates: coordinates, nodes: nodes, c11: c11, c12: c12, c33: c33)
        var gx = 0.0, gy = 0.0
        for i in 0..<20 {
            let value = coordinates[5 * nodes[i / 5] + i % 5]
            gx = try ShellArithmetic.finite(gx + shear[i] * value)
            gy = try ShellArithmetic.finite(gy + shear[20 + i] * value)
        }
        let shearDensity = try ShellArithmetic.finite(0.5 * shearScale * (gx * gx + gy * gy))
        return try ShellArithmetic.finite(h * membraneDensity + h3over12 * bendingDensity + shearDensity)
    }

    private func planeEnergy(_ b: [Double], coordinates: [Double], nodes: [Int],
                             c11: Double, c12: Double, c33: Double) throws(ShellError) -> Double {
        var ex = 0.0, ey = 0.0, gamma = 0.0
        for i in 0..<20 {
            let value = coordinates[5 * nodes[i / 5] + i % 5]
            ex = try ShellArithmetic.finite(ex + b[i] * value)
            ey = try ShellArithmetic.finite(ey + b[20 + i] * value)
            gamma = try ShellArithmetic.finite(gamma + b[40 + i] * value)
        }
        let dilatation = try ShellArithmetic.finite(ex + ey), difference = try ShellArithmetic.finite(ex - ey)
        // Positive squares preserve nonnegative energy near rigid modes despite assembled K cancellation.
        return try ShellArithmetic.finite(0.25 * (c11 + c12) * dilatation * dilatation
            + 0.25 * (c11 - c12) * difference * difference + 0.5 * c33 * gamma * gamma)
    }

    private func validateCorner(_ plate: RectangularShellPlate, state: ShellNodalState, nodes: [Int], cell: Int,
                                xi: Double, eta: Double, inverseHalfWidth: Double, inverseHalfHeight: Double,
                                work: inout NumericalWork) throws(ShellError) {
        try ShellArithmetic.charge(320, &work)
        var ux = 0.0, uy = 0.0, vx = 0.0, vy = 0.0, wx = 0.0, wy = 0.0
        var bx = 0.0, by = 0.0, bxx = 0.0, bxy = 0.0, byx = 0.0, byy = 0.0
        for node in 0..<4 {
            let (sx, sy) = signs(node)
            let nx = sx * (1 + sy * eta) * inverseHalfWidth, ny = sy * (1 + sx * xi) * inverseHalfHeight
            let shape = (1 + sx * xi) * (1 + sy * eta) / 4
            let base = 5 * nodes[node]
            let q = state.coordinates
            ux = try ShellArithmetic.finite(ux + nx * q[base]); uy = try ShellArithmetic.finite(uy + ny * q[base])
            vx = try ShellArithmetic.finite(vx + nx * q[base + 1]); vy = try ShellArithmetic.finite(vy + ny * q[base + 1])
            wx = try ShellArithmetic.finite(wx + nx * q[base + 2]); wy = try ShellArithmetic.finite(wy + ny * q[base + 2])
            bx = try ShellArithmetic.finite(bx + shape * q[base + 3]); by = try ShellArithmetic.finite(by + shape * q[base + 4])
            bxx = try ShellArithmetic.finite(bxx + nx * q[base + 3]); bxy = try ShellArithmetic.finite(bxy + ny * q[base + 3])
            byx = try ShellArithmetic.finite(byx + nx * q[base + 4]); byy = try ShellArithmetic.finite(byy + ny * q[base + 4])
        }
        let jacobian = try ShellArithmetic.finite((1 + ux) * (1 + vy) - uy * vx)
        guard jacobian > 0 else { throw .invertedGeometry(cell: cell) }
        let magnitude = max(abs(ux), abs(uy), abs(vx), abs(vy), abs(wx), abs(wy), abs(bx), abs(by))
        guard magnitude <= plate.maximumKinematicMagnitude else { throw .outsideLinearDomain(cell: cell) }
        let transverseX = try ShellArithmetic.finite(wx + bx), transverseY = try ShellArithmetic.finite(wy + by)
        guard max(abs(transverseX), abs(transverseY)) <= plate.maximumLinearStrain else {
            throw .outsideLinearDomain(cell: cell)
        }
        let halfThickness = plate.thickness / 2
        for surface in 0..<2 {
            let z = surface == 0 ? -halfThickness : halfThickness
            let ex = try ShellArithmetic.finite(ux + z * bxx)
            let ey = try ShellArithmetic.finite(vy + z * byy)
            let engineeringShear = try ShellArithmetic.finite(uy + vx + z * (bxy + byx))
            guard max(abs(ex), abs(ey), abs(engineeringShear)) <= plate.maximumLinearStrain else {
                throw .outsideLinearDomain(cell: cell)
            }
        }
    }
}
