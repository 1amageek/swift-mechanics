internal enum SpatialBeamDomainChecking {
    static func localState(_ assembly: SpatialBeamAssembly, state: SpatialBeamState,
                           admission: SpatialBeamAdmission, work: inout NumericalWork) throws(SpatialBeamError) -> ([Double], [Double]) {
        try SpatialBeamAlgebra.admit(assembly.beam, admission: admission, work: &work)
        // Includes retained assembly, four shape evaluations and response/field scratch.
        try SpatialBeamAlgebra.storage(4096, work: &work)
        guard state.beam == assembly.beam else { throw .invalidInput(parameter: "stateSource") }
        _ = try SpatialBeamAlgebra.frame(assembly.beam, admission: admission, work: &work)
        try SpatialBeamAlgebra.charge(300, work: &work)
        let q = try SpatialBeamAlgebra.toLocal(state.displacement, frame: assembly.frame)
        let v = try SpatialBeamAlgebra.toLocal(state.velocity, frame: assembly.frame)
        let l = assembly.frame.length
        let section = assembly.beam.section, envelope = assembly.beam.envelope
        try SpatialBeamAlgebra.charge(4500, work: &work)
        let start = try SpatialBeamInterpolation(xi: 0, length: l, factors: assembly.interpolationFactors)
        let middle = try SpatialBeamInterpolation(xi: 0.5, length: l, factors: assembly.interpolationFactors)
        let end = try SpatialBeamInterpolation(xi: 1, length: l, factors: assembly.interpolationFactors)
        var rotationBound = 0.0, slopeBound = 0.0
        // Component extrema give conservative L1 bounds on vector rotation and transverse slope.
        for row in 3..<6 {
            let bound = try maximumQuadratic(
                SpatialBeamAlgebra.dot(start.kinematics, offset: row * 12, q),
                SpatialBeamAlgebra.dot(middle.kinematics, offset: row * 12, q),
                SpatialBeamAlgebra.dot(end.kinematics, offset: row * 12, q))
            rotationBound = try SpatialBeamAlgebra.finite(rotationBound + bound)
        }
        for row in 0..<2 {
            let bound = try maximumQuadratic(
                SpatialBeamAlgebra.dot(start.slopes, offset: row * 12, q),
                SpatialBeamAlgebra.dot(middle.slopes, offset: row * 12, q),
                SpatialBeamAlgebra.dot(end.slopes, offset: row * 12, q))
            slopeBound = try SpatialBeamAlgebra.finite(slopeBound + bound)
        }
        try bound(rotationBound, limit: envelope.maximumRotation, measure: "rotationL1Bound")
        try bound(slopeBound, limit: envelope.maximumSlope, measure: "slopeL1Bound")
        for shape in [start, end] {
            let axial = try SpatialBeamAlgebra.dot(shape.strain, q)
            let ky = try SpatialBeamAlgebra.dot(shape.strain, offset: 4 * 12, q)
            let kz = try SpatialBeamAlgebra.dot(shape.strain, offset: 5 * 12, q)
            let fiber = try SpatialBeamAlgebra.finite(abs(axial) + section.outerHalfZ * abs(ky) + section.outerHalfY * abs(kz))
            try bound(fiber, limit: envelope.maximumFiberStrain, measure: "fiberAxialStrainBound")
        }
        let gy = try SpatialBeamAlgebra.dot(start.strain, offset: 12, q)
        let gz = try SpatialBeamAlgebra.dot(start.strain, offset: 24, q)
        try bound(SpatialBeamAlgebra.finite(abs(gy) + abs(gz)), limit: envelope.maximumShear, measure: "shearL1Bound")
        let twist = try SpatialBeamAlgebra.dot(start.strain, offset: 36, q)
        // Outer radius is bounded by cy+cz. This is kinematic distortion, not torsional stress.
        let distortion = try SpatialBeamAlgebra.finite((section.outerHalfY + section.outerHalfZ) * abs(twist))
        try bound(distortion, limit: envelope.maximumTwistDistortion, measure: "twistDistortionBound")
        try SpatialBeamAlgebra.cancel(admission)
        return (q, v)
    }
    private static func bound(_ value: Double, limit: Double, measure: String) throws(SpatialBeamError) {
        guard value <= limit else { throw .outsideDomain(measure: measure, value: value, limit: limit) }
    }
    private static func maximumQuadratic(_ f0: Double, _ fm: Double, _ f1: Double) throws(SpatialBeamError) -> Double {
        let a = try SpatialBeamAlgebra.finite(2 * (f1 + f0 - 2 * fm))
        let b = try SpatialBeamAlgebra.finite(f1 - f0 - a)
        var result = max(abs(f0), abs(f1))
        if a != 0 {
            // Only evaluate a vertex inside [0,1]; overflowing outside roots are irrelevant.
            let root = -0.5 * (b / a)
            if root > 0, root < 1 {
                result = max(result, abs(try SpatialBeamAlgebra.finite((a * root + b) * root + f0)))
            }
        }
        return result
    }
}
