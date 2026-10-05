import SwiftMechanics

public enum GeometryParametersQualificationOracle {
    public static func require(_ value: Bool, _ message: String) throws {
        guard value else { throw GeometryParametersQualificationError.assertion(message) }
    }
    public static func scalar(_ actual: Double, _ expected: Double, _ label: String, difference: Bool = false) throws {
        let absolute = difference ? 2e-7 : 2e-10, relative = difference ? 2e-6 : 2e-10
        guard actual.isFinite, expected.isFinite,
              abs(actual - expected) <= absolute + relative * max(abs(actual), abs(expected)) else {
            throw GeometryParametersQualificationError.assertion("\(label): \(actual) versus \(expected)")
        }
    }
    public static func vector(_ actual: Vector3, _ expected: Vector3, _ label: String, difference: Bool = false) throws {
        try scalar(actual.x, expected.x, label + ".x", difference: difference)
        try scalar(actual.y, expected.y, label + ".y", difference: difference)
        try scalar(actual.z, expected.z, label + ".z", difference: difference)
    }
    public static func matrix(_ actual: Matrix3, _ expected: Matrix3, _ label: String, difference: Bool = false) throws {
        for r in 0..<3 { for c in 0..<3 {
            try scalar(actual.element(row: r, column: c), expected.element(row: r, column: c), label, difference: difference)
        } }
    }
    public static func motion(_ actual: SpatialMotion, _ expected: SpatialMotion, _ label: String, difference: Bool = false) throws {
        try vector(actual.angular, expected.angular, label + ".angular", difference: difference)
        try vector(actual.linear, expected.linear, label + ".linear", difference: difference)
    }
    private static func derivative(_ plus: Vector3, _ minus: Vector3, _ h: Double) throws -> Vector3 {
        try plus.subtracting(minus).scaled(by: 1 / (2*h))
    }
    private static func derivative(_ plus: Matrix3, _ minus: Matrix3, _ h: Double) throws -> Matrix3 {
        try plus.subtracting(minus).scaled(by: 1 / (2*h))
    }
    private static func derivative(_ plus: SpatialMotion, _ minus: SpatialMotion, _ h: Double) throws -> SpatialMotion {
        try SpatialMotion(angular: derivative(plus.angular, minus.angular, h), linear: derivative(plus.linear, minus.linear, h))
    }

    public static func finiteDifferences(_ fixture: GeometryParametersQualificationFixture,
        bindings: [GeometryParameterBinding], direction: [Double], product: GeometryParameterProduct) throws {
        try require(product.source.state == fixture.state && product.snapshot.time == fixture.state.time && product.stateHeldFixed,
                    "Held q/v/a/time and returned source")
        try require(product.source.modelSource == fixture.provenance && product.parameterDirection == direction && product.source.bindings == bindings,
                    "Original model/parameter source mapping")
        try require(product.coordinateRate.allSatisfy { $0 == 0 }, "Scalar coordinate rates held fixed")
        try require(product.originalPrimal.checkedComponents > 0 && product.originalMotionResidual.checkedComponents > 0,
                    "Original primal/motion acceptance actually traversed")
        for h in [1e-5, 5e-6] {
            let plusTree = try GeometryParametersQualificationFixture.build(fixture.specifications, bindings: bindings, direction: direction, delta: h)
            let minusTree = try GeometryParametersQualificationFixture.build(fixture.specifications, bindings: bindings, direction: direction, delta: -h)
            let primal: any TreeKinematicsComputing = TreeKinematicsEvaluator()
            let plus = try primal.evaluate(plusTree, state: fixture.state, policy: GeometryParametersQualificationFixture.jointPolicy())
            let minus = try primal.evaluate(minusTree, state: fixture.state, policy: GeometryParametersQualificationFixture.jointPolicy())
            try require(product.bodies.count == plus.bodies.count && product.frames.count == plus.frames.count, "Original body/frame layout")
            for i in product.frames.indices {
                let p = plus.frames[i], m = minus.frames[i], actual = product.frames[i]
                try require(actual.frame == p.frame && actual.referenceFrame == p.referenceFrame, "Frame identity")
                try vector(actual.translation, derivative(p.motion.pose.translation, m.motion.pose.translation, h), "Frame translation", difference: true)
                try matrix(actual.rotationMatrix, derivative(p.motion.pose.rotation.matrix(), m.motion.pose.rotation.matrix(), h), "Frame rotation", difference: true)
                try motion(actual.velocity, derivative(p.motion.velocity, m.motion.velocity, h), "Frame velocity", difference: true)
                try motion(actual.acceleration, derivative(p.motion.acceleration, m.motion.acceleration, h), "Frame acceleration", difference: true)
            }
            for i in product.bodies.indices {
                let p = plus.bodies[i], m = minus.bodies[i], actual = product.bodies[i]
                try require(actual.body == p.body && actual.frame == p.bodyFrame, "Body identity")
                try vector(actual.translation, derivative(p.motion.pose.translation, m.motion.pose.translation, h), "Body translation", difference: true)
                try matrix(actual.rotationMatrix, derivative(p.motion.pose.rotation.matrix(), m.motion.pose.rotation.matrix(), h), "Body rotation", difference: true)
                try motion(actual.velocity, derivative(p.motion.velocity, m.motion.velocity, h), "Body velocity", difference: true)
                try motion(actual.acceleration, derivative(p.motion.acceleration, m.motion.acceleration, h), "Body acceleration", difference: true)
                try motion(actual.prescribedDrift, derivative(p.prescribedDriftVelocity, m.prescribedDriftVelocity, h), "Drift", difference: true)
                try motion(actual.accelerationBias, derivative(p.accelerationBias, m.accelerationBias, h), "Bias", difference: true)
                let pc = try plus.geometricColumns(body: p.body), mc = try minus.geometricColumns(body: m.body)
                for k in 0..<fixture.tree.layout.velocityCount {
                    try motion(product.geometricColumns[i*fixture.tree.layout.velocityCount + k], derivative(pc[pc.startIndex + k], mc[mc.startIndex + k], h), "Original J column", difference: true)
                }
            }
        }
    }

    public static func refusal(_ label: String, match: (GeometryParameterError) -> Bool,
                               _ body: () throws -> Void) throws {
        do { try body() }
        catch let error as GeometryParameterError {
            guard match(error) else { throw GeometryParametersQualificationError.unexpectedFailure(error) }
            return
        }
        throw GeometryParametersQualificationError.unexpectedSuccess(label)
    }
}
