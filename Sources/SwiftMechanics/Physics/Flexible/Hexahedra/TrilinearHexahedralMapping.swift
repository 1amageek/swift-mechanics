internal enum TrilinearHexahedralMapping {
    static func gaussCoordinate(_ point: Int) throws(HexahedralError) -> Vector3 {
        let g = 0.57735026918962576451
        return try HexahedralArithmetic.core { () throws(CoreError) in
            try Vector3(point & 1 == 0 ? -g : g,
                        point & 2 == 0 ? -g : g,
                        point & 4 == 0 ? -g : g)
        }
    }

    static func shape(_ node: Int, at natural: Vector3, work: inout NumericalWork) throws(HexahedralError) -> Double {
        let s = node == 1 || node == 2 || node == 5 || node == 6 ? 1.0 : -1.0
        let t = node == 2 || node == 3 || node == 6 || node == 7 ? 1.0 : -1.0
        let u = node < 4 ? -1.0 : 1.0
        try HexahedralArithmetic.charge(9, &work)
        return try HexahedralArithmetic.finite((1 + s * natural.x) * (1 + t * natural.y) * (1 + u * natural.z) / 8)
    }

    static func naturalGradient(_ node: Int, at natural: Vector3,
                                work: inout NumericalWork) throws(HexahedralError) -> Vector3 {
        let s = node == 1 || node == 2 || node == 5 || node == 6 ? 1.0 : -1.0
        let t = node == 2 || node == 3 || node == 6 || node == 7 ? 1.0 : -1.0
        let u = node < 4 ? -1.0 : 1.0
        try HexahedralArithmetic.charge(15, &work)
        let a = 1 + s * natural.x, b = 1 + t * natural.y, c = 1 + u * natural.z
        return try HexahedralArithmetic.core { () throws(CoreError) in
            try Vector3(s * b * c / 8, t * a * c / 8, u * a * b / 8)
        }
    }

    /// Coordinates are borrowed from their immutable node/state owner; no positions copy is made.
    static func jacobian(nodes: [Int], at natural: Vector3,
                         position: (Int) -> Vector3, work: inout NumericalWork) throws(HexahedralError) -> Matrix3 {
        let origin = position(nodes[0])
        var a00 = 0.0, a01 = 0.0, a02 = 0.0
        var a10 = 0.0, a11 = 0.0, a12 = 0.0
        var a20 = 0.0, a21 = 0.0, a22 = 0.0
        // Partition-of-unity derivatives sum to zero, so subtracting the anchor preserves the map derivative.
        for node in 1..<8 {
            let gradient = try naturalGradient(node, at: natural, work: &work)
            try HexahedralArithmetic.charge(21, &work)
            let p = try HexahedralArithmetic.core { () throws(CoreError) in try position(nodes[node]).subtracting(origin) }
            a00 += p.x * gradient.x; a01 += p.x * gradient.y; a02 += p.x * gradient.z
            a10 += p.y * gradient.x; a11 += p.y * gradient.y; a12 += p.y * gradient.z
            a20 += p.z * gradient.x; a21 += p.z * gradient.y; a22 += p.z * gradient.z
        }
        return try HexahedralArithmetic.core { () throws(CoreError) in
            try Matrix3(a00, a01, a02, a10, a11, a12, a20, a21, a22)
        }
    }

    /// Conservative positivity certificate for det(J) throughout the closed natural cube.
    static func certified(nodes: [Int], position: (Int) -> Vector3, floor: Double, relativeMargin: Double,
                          isCancelled: @Sendable () -> Bool, work: inout NumericalWork) throws(HexahedralError) -> Bool {
        var coefficients = [Double](repeating: 0, count: 27)
        for i in 0..<3 { for j in 0..<3 { for k in 0..<3 {
            try HexahedralArithmetic.checkpoint(isCancelled)
            let natural = try HexahedralArithmetic.core { () throws(CoreError) in
                try Vector3(Double(i) - 1, Double(j) - 1, Double(k) - 1)
            }
            try HexahedralArithmetic.charge(3, &work)
            let jacobian = try jacobian(nodes: nodes, at: natural, position: position, work: &work)
            try HexahedralArithmetic.charge(14, &work)
            coefficients[9 * i + 3 * j + k] = try HexahedralArithmetic.core { () throws(CoreError) in try jacobian.determinant() }
        } } }
        // A quadratic sampled at t=0,1/2,1 has Bernstein middle coefficient 2*f(1/2)-(f(0)+f(1))/2.
        // Tensor conversion is separable; determinant degree is at most two in each natural variable.
        for j in 0..<3 { for k in 0..<3 {
            try convert(&coefficients, 3 * j + k, 9 + 3 * j + k, 18 + 3 * j + k, &work)
        } }
        for i in 0..<3 { for k in 0..<3 {
            try convert(&coefficients, 9 * i + k, 9 * i + 3 + k, 9 * i + 6 + k, &work)
        } }
        for i in 0..<3 { for j in 0..<3 {
            try convert(&coefficients, 9 * i + 3 * j, 9 * i + 3 * j + 1, 9 * i + 3 * j + 2, &work)
        } }
        var lower = coefficients[0], scale = 0.0
        for value in coefficients {
            try HexahedralArithmetic.charge(3, &work)
            lower = min(lower, value)
            scale = max(scale, abs(value))
        }
        try HexahedralArithmetic.checkpoint(isCancelled)
        try HexahedralArithmetic.charge(3, &work)
        return try HexahedralArithmetic.finite(lower - relativeMargin * scale) > floor
    }

    private static func convert(_ values: inout [Double], _ first: Int, _ middle: Int, _ last: Int,
                                _ work: inout NumericalWork) throws(HexahedralError) {
        try HexahedralArithmetic.charge(4, &work)
        values[middle] = try HexahedralArithmetic.finite(2 * values[middle] - 0.5 * (values[first] + values[last]))
    }
}
