internal enum SpatialBeamAlgebra {
    static func finite(_ value: Double) throws(SpatialBeamError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
    static func positive(_ value: Double) throws(SpatialBeamError) -> Double {
        guard value.isFinite, value > 0 else { throw .nonFiniteResult }; return value
    }
    static func weightedSquare(_ value: Double, coefficient: Double, weight: Double) throws(SpatialBeamError) -> Double {
        if value == 0 { return 0 }
        let scale = try positive(coefficient * weight)
        return try positive(value * (try finite(scale * value)))
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(SpatialBeamError) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func charge(_ count: Int, work: inout NumericalWork) throws(SpatialBeamError) {
        do throws(NumericalError) { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    static func storage(_ count: Int, work: inout NumericalWork) throws(SpatialBeamError) {
        do throws(NumericalError) { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    static func cancel(_ admission: SpatialBeamAdmission) throws(SpatialBeamError) {
        guard !admission.isCancelled() else { throw .cancelled }
    }
    static func admit(_ beam: SpatialBeamDefinition, admission: SpatialBeamAdmission,
                      work: inout NumericalWork) throws(SpatialBeamError) {
        try cancel(admission)
        var count = 0
        for text in [beam.identity, beam.source.source, beam.referenceFrame.key, beam.elementFrame.key,
                     beam.material.identity.key, beam.material.source.source, beam.section.source.source] {
            for _ in text.utf8 {
                guard count < admission.maximumMetadataBytes else { throw .capacityExceeded }
                try charge(1, work: &work); count += 1
                if count % 64 == 0 { try cancel(admission) }
            }
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): The actual assembler/evaluator supports linear rotations only.
        // This selected production branch must fail until objective finite-rotation laws and
        // their full force/inertia/field path are implemented and behaviorally qualified.
        if beam.formulation == .finiteRotation { throw .unsupportedFiniteRotation }
    }
    static func accepts(_ error: Double, scale: Double, tolerance: NumericalTolerance,
                        measure: String) throws(SpatialBeamError) {
        guard try core({ () throws(CoreError) in try tolerance.contains(error: error, scale: scale) }) else {
            throw .inconsistentOperator(measure: measure)
        }
    }
    static func frame(_ beam: SpatialBeamDefinition, admission: SpatialBeamAdmission,
                      work: inout NumericalWork) throws(SpatialBeamError) -> SpatialBeamFrame {
        try charge(300, work: &work)
        let edge = try core { () throws(CoreError) in try beam.second.referencePosition.subtracting(beam.first.referencePosition) }
        let length = try core { () throws(CoreError) in try edge.magnitude() }
        guard length > 0 else { throw .invalidInput(parameter: "zeroLength") }
        let x = try core { () throws(CoreError) in try edge.normalized() }
        let yInput = try core { () throws(CoreError) in try beam.principalYDirection.normalized() }
        let normal = try core { () throws(CoreError) in try x.cross(yInput) }
        let sine = try core { () throws(CoreError) in try normal.magnitude() }
        guard sine >= admission.minimumOrientationSine else { throw .invalidInput(parameter: "principalDirectionCondition") }
        let z = try core { () throws(CoreError) in try normal.normalized() }
        let y = try core { () throws(CoreError) in try z.cross(x).normalized() }
        let q = try core { () throws(CoreError) in try Matrix3(x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z) }
        let section = beam.section
        let radius = try positive(max((section.secondMomentY / section.area).squareRoot(),
                                     (section.secondMomentZ / section.area).squareRoot()))
        let slenderness = try positive(length / radius)
        guard slenderness >= admission.minimumSlenderness else {
            throw .outsideDomain(measure: "minimumSlenderness", value: slenderness, limit: admission.minimumSlenderness)
        }
        guard slenderness <= admission.maximumSlenderness else {
            throw .outsideDomain(measure: "maximumSlenderness", value: slenderness, limit: admission.maximumSlenderness)
        }
        return SpatialBeamFrame(length: length, localToReference: q)
    }
    static func diagonal(_ beam: SpatialBeamDefinition) throws(SpatialBeamError) -> [Double] {
        let e = beam.material.youngModulus, g = beam.material.shearModulus, s = beam.section
        return try [positive(e * s.area), positive(s.shearFactorY * g * s.area),
                    positive(s.shearFactorZ * g * s.area), positive(g * s.torsionConstant),
                    positive(e * s.secondMomentY), positive(e * s.secondMomentZ)]
    }
    static func factors(_ beam: SpatialBeamDefinition, length: Double,
                        diagonal d: [Double]) throws(SpatialBeamError) -> [Double] {
        if beam.formulation == .eulerBernoulli { return [1, 0, 1, 0] }
        var result: [Double] = []
        for (shear, bend) in [(d[1], d[5]), (d[2], d[4])] {
            let a = try positive(shear * length * length), b = try positive(12 * bend)
            let denominator = try positive(a + b)
            result.append(try positive(a / denominator)); result.append(try positive(b / denominator))
        }
        return result
    }
    static var quadrature: [(Double, Double)] {
        // Four-point Gauss-Legendre, exact through degree seven on [0,1].
        [(0.06943184420297371, 0.1739274225687269),
         (0.33000947820757187, 0.3260725774312731),
         (0.6699905217924281, 0.3260725774312731),
         (0.9305681557970262, 0.1739274225687269)]
    }
    static func dot(_ a: [Double], offset: Int = 0, _ b: [Double]) throws(SpatialBeamError) -> Double {
        var value = 0.0
        for i in b.indices { value = try finite(value + (try finite(a[offset + i] * b[i]))) }
        return value
    }
    static func action(_ a: [Double], _ x: [Double]) throws(SpatialBeamError) -> [Double] {
        var result = [Double](repeating: 0, count: 12)
        for i in 0..<12 { result[i] = try dot(a, offset: i * 12, x) }
        return result
    }
    static func toLocal(_ input: [Double], frame: SpatialBeamFrame) throws(SpatialBeamError) -> [Double] {
        guard input.count == 12, input.allSatisfy({ $0.isFinite }) else { throw .invalidInput(parameter: "nodalCoordinates") }
        var output = [Double](repeating: 0, count: 12)
        for block in 0..<4 {
            let i = block * 3
            let v = try core { () throws(CoreError) in try Vector3(input[i], input[i + 1], input[i + 2]) }
            let result = try core { () throws(CoreError) in try frame.localToReference.transposed().applying(to: v) }
            output[i] = result.x; output[i + 1] = result.y; output[i + 2] = result.z
        }
        return output
    }
    static func toReference(_ input: [Double], frame: SpatialBeamFrame) throws(SpatialBeamError) -> [Double] {
        var output = [Double](repeating: 0, count: 12)
        for block in 0..<4 {
            let i = block * 3
            let v = try core { () throws(CoreError) in try Vector3(input[i], input[i + 1], input[i + 2]) }
            let result = try core { () throws(CoreError) in try frame.localToReference.applying(to: v) }
            output[i] = result.x; output[i + 1] = result.y; output[i + 2] = result.z
        }
        return output
    }
    static func congruence(_ local: [Double], frame: SpatialBeamFrame,
                           admission: SpatialBeamAdmission, work: inout NumericalWork) throws(SpatialBeamError) -> [Double] {
        let q = frame.localToReference
        let r = [q.m00, q.m01, q.m02, q.m10, q.m11, q.m12, q.m20, q.m21, q.m22]
        var result = [Double](repeating: 0, count: 144)
        for i in 0..<12 {
            try cancel(admission); try charge(12 * 27, work: &work)
            for j in i..<12 {
                var value = 0.0
                for a in 0..<3 { for b in 0..<3 {
                    let term = try finite(r[(i % 3) * 3 + a] * local[(i / 3 * 3 + a) * 12 + j / 3 * 3 + b] * r[(j % 3) * 3 + b])
                    value = try finite(value + term)
                } }
                result[i * 12 + j] = value; result[j * 12 + i] = value
            }
        }
        return result
    }
}
