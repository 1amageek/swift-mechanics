public struct ReferenceSpatialBeamAssembler: SpatialBeamAssembling, Sendable {
    public init() {}
    public func assemble(_ beam: SpatialBeamDefinition, admission: SpatialBeamAdmission,
                         work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamAssembly {
        try SpatialBeamAlgebra.admit(beam, admission: admission, work: &work)
        // Retained six operators, shape rows, transform and normalized acceptance scratch.
        try SpatialBeamAlgebra.storage(2304, work: &work)
        let frame = try SpatialBeamAlgebra.frame(beam, admission: admission, work: &work)
        try SpatialBeamAlgebra.charge(80, work: &work)
        let d = try SpatialBeamAlgebra.diagonal(beam)
        let factors = try SpatialBeamAlgebra.factors(beam, length: frame.length, diagonal: d)
        var k = [Double](repeating: 0, count: 144), m = k
        let section = beam.section, density = beam.material.density
        let inertia = try [SpatialBeamAlgebra.positive(density * section.area),
                           SpatialBeamAlgebra.positive(density * section.area),
                           SpatialBeamAlgebra.positive(density * section.area),
                           SpatialBeamAlgebra.positive(density * (section.secondMomentY + section.secondMomentZ)),
                           SpatialBeamAlgebra.positive(density * section.secondMomentY),
                           SpatialBeamAlgebra.positive(density * section.secondMomentZ)]
        for (xi, weight) in SpatialBeamAlgebra.quadrature {
            try SpatialBeamAlgebra.cancel(admission); try SpatialBeamAlgebra.charge(8000, work: &work)
            let shape = try SpatialBeamInterpolation(xi: xi, length: frame.length, factors: factors)
            let dx = try SpatialBeamAlgebra.positive(frame.length * weight)
            for i in 0..<12 { for j in i..<12 {
                var stiffness = 0.0, mass = 0.0
                for r in 0..<6 {
                    let value = try SpatialBeamAlgebra.finite(shape.strain[r * 12 + i] * d[r] * shape.strain[r * 12 + j] * dx)
                    stiffness = try SpatialBeamAlgebra.finite(stiffness + value)
                    if beam.massForm == .consistent {
                        let kinetic = try SpatialBeamAlgebra.finite(shape.kinematics[r * 12 + i] * inertia[r] * shape.kinematics[r * 12 + j] * dx)
                        mass = try SpatialBeamAlgebra.finite(mass + kinetic)
                    }
                }
                k[i * 12 + j] = try SpatialBeamAlgebra.finite(k[i * 12 + j] + stiffness)
                m[i * 12 + j] = try SpatialBeamAlgebra.finite(m[i * 12 + j] + mass)
                k[j * 12 + i] = k[i * 12 + j]; m[j * 12 + i] = m[i * 12 + j]
            } }
        }
        if beam.massForm == .endpointLumped {
            try SpatialBeamAlgebra.charge(24, work: &work)
            for node in 0..<2 { for r in 0..<6 {
                let index = node * 6 + r
                m[index * 12 + index] = try SpatialBeamAlgebra.positive(inertia[r] * frame.length / 2)
            } }
        }
        try SpatialBeamAlgebra.charge(432, work: &work)
        var c = [Double](repeating: 0, count: 144)
        for i in 0..<144 { c[i] = try SpatialBeamAlgebra.finite(beam.massDamping * m[i] + beam.stiffnessDamping * k[i]) }
        try validate(k: k, m: m, frame: frame, admission: admission, work: &work)
        let referenceK = try SpatialBeamAlgebra.congruence(k, frame: frame, admission: admission, work: &work)
        let referenceM = try SpatialBeamAlgebra.congruence(m, frame: frame, admission: admission, work: &work)
        try SpatialBeamAlgebra.charge(432, work: &work)
        var referenceC = [Double](repeating: 0, count: 144)
        for i in 0..<144 {
            referenceC[i] = try SpatialBeamAlgebra.finite(beam.massDamping * referenceM[i] + beam.stiffnessDamping * referenceK[i])
        }
        for i in 0..<12 {
            guard referenceM[i * 12 + i] > 0, referenceK[i * 12 + i] > 0 else {
                throw .inconsistentOperator(measure: "referencePositiveDiagonal")
            }
            if beam.massDamping > 0 || beam.stiffnessDamping > 0 {
                guard referenceC[i * 12 + i] > 0 else { throw .nonFiniteResult }
            }
        }
        try SpatialBeamAlgebra.cancel(admission)
        return SpatialBeamAssembly(beam: beam, frame: frame, elasticStiffness: referenceK,
            mass: referenceM, damping: referenceC, localStiffness: k, localMass: m, localDamping: c,
            constitutiveDiagonal: d, interpolationFactors: factors)
    }

    private func validate(k: [Double], m: [Double], frame: SpatialBeamFrame,
                          admission: SpatialBeamAdmission, work: inout NumericalWork) throws(SpatialBeamError) {
        try SpatialBeamAlgebra.charge(6000, work: &work)
        var normalized = [Double](repeating: 0, count: 144), normalizedMass = normalized, scale = 0.0
        for i in 0..<12 {
            guard m[i * 12 + i] > 0, k[i * 12 + i] > 0 else { throw .inconsistentOperator(measure: "positiveDiagonal") }
            var row = 0.0
            for j in 0..<12 {
                let si = i % 6 < 3 ? frame.length : 1.0, sj = j % 6 < 3 ? frame.length : 1.0
                normalized[i * 12 + j] = try SpatialBeamAlgebra.finite(k[i * 12 + j] * si * sj)
                normalizedMass[i * 12 + j] = try SpatialBeamAlgebra.finite(m[i * 12 + j] * si * sj)
                row = try SpatialBeamAlgebra.finite(row + abs(normalized[i * 12 + j]))
                guard k[i * 12 + j] == k[j * 12 + i], m[i * 12 + j] == m[j * 12 + i] else {
                    throw .inconsistentOperator(measure: "symmetry")
                }
            }
            scale = max(scale, row)
        }
        try SpatialBeamAlgebra.charge(3000, work: &work)
        try positivePivots(normalizedMass, dimension: 12, offset: 0, admission: admission, measure: "positiveMass")
        try positivePivots(normalized, dimension: 6, offset: 6, admission: admission, measure: "positiveDeformationStiffness")
        // Six exact infinitesimal rigid fields, in length-scaled translation coordinates.
        for mode in 0..<6 {
            try SpatialBeamAlgebra.cancel(admission)
            var r = [Double](repeating: 0, count: 12)
            if mode < 3 { r[mode] = 1; r[mode + 6] = 1 }
            else {
                let axis = mode - 3; r[axis + 3] = 1; r[axis + 9] = 1
                if axis == 1 { r[8] = -1 }
                if axis == 2 { r[7] = 1 }
            }
            let action = try SpatialBeamAlgebra.action(normalized, r)
            for value in action {
                try SpatialBeamAlgebra.accepts(value, scale: scale, tolerance: admission.normalizedOperatorTolerance, measure: "rigidNullAction")
            }
        }
    }

    private func positivePivots(_ matrix: [Double], dimension: Int, offset: Int,
                                admission: SpatialBeamAdmission, measure: String) throws(SpatialBeamError) {
        var lower = [Double](repeating: 0, count: dimension * dimension)
        for i in 0..<dimension {
            try SpatialBeamAlgebra.cancel(admission)
            for j in 0...i {
                var residual = matrix[(i + offset) * 12 + j + offset]
                for k in 0..<j {
                    residual = try SpatialBeamAlgebra.finite(residual - (try SpatialBeamAlgebra.finite(lower[i * dimension + k] * lower[j * dimension + k])))
                }
                if i == j {
                    guard residual > 0 else { throw .inconsistentOperator(measure: measure) }
                    lower[i * dimension + j] = try SpatialBeamAlgebra.positive(residual.squareRoot())
                } else {
                    lower[i * dimension + j] = try SpatialBeamAlgebra.finite(residual / lower[j * dimension + j])
                }
            }
        }
    }
}
