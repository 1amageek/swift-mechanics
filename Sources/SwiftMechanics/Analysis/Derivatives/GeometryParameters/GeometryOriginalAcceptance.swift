internal struct GeometryOriginalAcceptance {
    private var maximumNormalized = 0.0
    private var components = 0
    mutating func scalar(_ a: Double, _ b: Double, tolerance: NumericalTolerance, primal: Bool,
                         work: inout NumericalWork) throws(GeometryParameterError) {
        try GeometryParameterArithmetic.charge(6, &work)
        let error = try GeometryParameterArithmetic.finite(abs(a - b))
        let threshold = try GeometryParameterArithmetic.finite(tolerance.absolute + tolerance.relative * max(abs(a), abs(b)))
        guard error <= threshold else {
            if primal { throw .originalPrimalMismatch }
            throw .originalResidualRejected(value: error, threshold: threshold)
        }
        if error > 0 { maximumNormalized = max(maximumNormalized, try GeometryParameterArithmetic.finite(error / threshold)) }
        components = try GeometryParameterArithmetic.sum(components, 1)
    }
    mutating func vector(_ a: Vector3, _ b: Vector3, tolerance: NumericalTolerance, primal: Bool,
                         work: inout NumericalWork) throws(GeometryParameterError) {
        try scalar(a.x, b.x, tolerance: tolerance, primal: primal, work: &work)
        try scalar(a.y, b.y, tolerance: tolerance, primal: primal, work: &work)
        try scalar(a.z, b.z, tolerance: tolerance, primal: primal, work: &work)
    }
    mutating func motion(_ a: SpatialMotion, _ b: SpatialMotion, tolerance: NumericalTolerance, primal: Bool,
                         work: inout NumericalWork) throws(GeometryParameterError) {
        try vector(a.angular, b.angular, tolerance: tolerance, primal: primal, work: &work)
        try vector(a.linear, b.linear, tolerance: tolerance, primal: primal, work: &work)
    }
    mutating func matrix(_ a: Matrix3, _ b: Matrix3, tolerance: NumericalTolerance,
                         work: inout NumericalWork) throws(GeometryParameterError) {
        for r in 0..<3 { for c in 0..<3 {
            let av = try GeometryParameterArithmetic.core { () throws(CoreError) in try a.element(row: r, column: c) }
            let bv = try GeometryParameterArithmetic.core { () throws(CoreError) in try b.element(row: r, column: c) }
            try scalar(av, bv, tolerance: tolerance, primal: true, work: &work)
        } }
    }
    var witness: GeometryResidualWitness { GeometryResidualWitness(maximumNormalizedResidual: maximumNormalized, checkedComponents: components) }
}
