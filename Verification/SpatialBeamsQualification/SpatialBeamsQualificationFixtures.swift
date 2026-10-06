import SwiftMechanics

internal enum SpatialBeamsQualificationFixtures {
    typealias E = SpatialBeamsQualificationError
    static func require(_ condition: Bool, _ label: String) throws(E) {
        guard condition else { throw .assertion(label) }
    }
    static func near(_ actual: Double, _ expected: Double, _ label: String) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual - expected) <= 1e-12 + 1e-9 * max(abs(actual), abs(expected)), label)
    }
    static func near(_ actual: [Double], _ expected: [Double], _ label: String) throws(E) {
        try require(actual.count == expected.count, label + " count")
        for i in expected.indices { try near(actual[i], expected[i], label + " " + String(i)) }
    }
    static func producer<T>(_ body: () throws(SpatialBeamError) -> T) throws(E) -> T {
        do throws(SpatialBeamError) { return try body() } catch { throw .producer(error) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T {
        do throws(ModelError) { return try body() } catch { throw .model(error) }
    }
    static func work(storage: Int = 4096, operations: Int = 200_000) throws(E) -> NumericalWork {
        do throws(NumericalError) {
            return NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 0))
        } catch { throw .numerical(error) }
    }
    static func vector(_ x: Double, _ y: Double, _ z: Double) throws(E) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x, y, z) }
    }
    static func admission(bytes: Int = 512, minimumSlenderness: Double = 2, maximumSlenderness: Double = 1000,
                          cancelled: @escaping @Sendable () -> Bool = { false }) throws(E) -> SpatialBeamAdmission {
        let tolerance = try core { () throws(CoreError) in try NumericalTolerance(absolute: 1e-12, relative: 1e-9) }
        return try producer { () throws(SpatialBeamError) in
            try SpatialBeamAdmission(maximumMetadataBytes: bytes, minimumOrientationSine: 0.1,
                minimumSlenderness: minimumSlenderness, maximumSlenderness: maximumSlenderness,
                normalizedOperatorTolerance: tolerance, energyTolerance: tolerance, powerTolerance: tolerance,
                forceTolerance: tolerance, momentTolerance: tolerance, isCancelled: cancelled)
        }
    }
    static func beam(formulation: SpatialBeamFormulation = .eulerBernoulli,
                     mass: SpatialBeamMassForm = .consistent, rotated: Bool = false,
                     revision: UInt64 = 7, alpha: Double = 0, beta: Double = 0,
                     zeroLength: Bool = false, collinear: Bool = false, density: Double = 3) throws(E) -> SpatialBeamDefinition {
        let source = try model { () throws(ModelError) in try SourceProvenance(source: "spatial-beam-source", revision: 4) }
        let materialSource = try model { () throws(ModelError) in try SourceProvenance(source: "beam-material-source", revision: 2) }
        let sectionSource = try model { () throws(ModelError) in try SourceProvenance(source: "beam-section-source", revision: 3) }
        let materialID = try model { () throws(ModelError) in try EntityID(kind: .material, key: "spatial-material") }
        let reference = try model { () throws(ModelError) in try EntityID(kind: .frame, key: "beam-reference") }
        let element = try model { () throws(ModelError) in try EntityID(kind: .frame, key: "beam-element") }
        let material = try producer { () throws(SpatialBeamError) in
            try SpatialBeamMaterial(identity: materialID, source: materialSource, youngModulus: 1200, shearModulus: 500, density: density)
        }
        let section = try producer { () throws(SpatialBeamError) in
            try SpatialBeamSection(source: sectionSource, area: 0.02, secondMomentY: 0.00002, secondMomentZ: 0.00004,
                torsionConstant: 0.00003, shearFactorY: 0.8, shearFactorZ: 0.6, outerHalfY: 0.1, outerHalfZ: 0.1)
        }
        let envelope = try producer { () throws(SpatialBeamError) in
            try SpatialBeamEnvelope(maximumRotation: 0.5, maximumSlope: 0.5, maximumFiberStrain: 0.5,
                maximumShear: 0.5, maximumTwistDistortion: 0.5)
        }
        let origin = try vector(1, 2, 3)
        let end: Vector3
        if zeroLength { end = origin } else { end = try vector(rotated ? 1 : 3, rotated ? 4 : 2, 3) }
        let direction: Vector3
        if collinear { direction = rotated ? .unitY : .unitX }
        else if rotated { direction = try vector(-1, 0, 0) } else { direction = .unitY }
        return try producer { () throws(SpatialBeamError) in
            try SpatialBeamDefinition(identity: "spatial-element", revision: revision, source: source,
                first: FlexibleNode(identifier: 10, referencePosition: origin, boundaryGroup: 91),
                second: FlexibleNode(identifier: 20, referencePosition: end, boundaryGroup: 92),
                referenceFrame: reference, elementFrame: element, principalYDirection: direction,
                material: material, section: section, formulation: formulation, massForm: mass,
                massDamping: alpha, stiffnessDamping: beta, envelope: envelope)
        }
    }
    static func assemble(_ beam: SpatialBeamDefinition) throws(E) -> SpatialBeamAssembly {
        let assembler: any SpatialBeamAssembling = ReferenceSpatialBeamAssembler()
        let admission = try Self.admission(); var work = try Self.work()
        return try producer { () throws(SpatialBeamError) in try assembler.assemble(beam, admission: admission, work: &work) }
    }
    static func state(_ beam: SpatialBeamDefinition, _ q: [Double], _ v: [Double] = [Double](repeating: 0, count: 12)) throws(E) -> SpatialBeamState {
        try producer { () throws(SpatialBeamError) in try SpatialBeamState(beam: beam, displacement: q, velocity: v) }
    }
    static func response(_ assembly: SpatialBeamAssembly, _ state: SpatialBeamState) throws(E) -> SpatialBeamResponse {
        let evaluator: any SpatialBeamEvaluating = ReferenceSpatialBeamEvaluator()
        let admission = try Self.admission(); var work = try Self.work()
        return try producer { () throws(SpatialBeamError) in try evaluator.evaluate(assembly, state: state, admission: admission, work: &work) }
    }
    static func field(_ assembly: SpatialBeamAssembly, _ state: SpatialBeamState, xi: Double, y: Double = 0, z: Double = 0) throws(E) -> SpatialBeamField {
        let location = try producer { () throws(SpatialBeamError) in try SpatialBeamLocation(xi: xi, y: y, z: z) }
        let evaluator: any SpatialBeamEvaluating = ReferenceSpatialBeamEvaluator()
        let admission = try Self.admission(); var work = try Self.work()
        return try producer { () throws(SpatialBeamError) in
            try evaluator.field(assembly, state: state, location: location, stress: .axialNormal, admission: admission, work: &work)
        }
    }
    static func expect(_ expected: SpatialBeamError, _ label: String, _ body: () throws(SpatialBeamError) -> Void) throws(E) {
        do throws(SpatialBeamError) { try body() } catch {
            try require(error == expected, label + " original error"); return
        }
        throw .assertion(label + " unexpectedly succeeded")
    }
    static func domain(_ measure: String, _ body: () throws(SpatialBeamError) -> Void) throws(E) {
        do throws(SpatialBeamError) { try body() } catch {
            guard case .outsideDomain(let actual, _, _) = error, actual == measure else { throw .producer(error) }; return
        }
        throw .assertion(measure + " unexpectedly succeeded")
    }
    static func action(_ matrix: [Double], _ vector: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: 12)
        for i in 0..<12 { for j in 0..<12 { result[i] += matrix[i * 12 + j] * vector[j] } }
        return result
    }
    static func dot(_ a: [Double], _ b: [Double]) -> Double {
        var value = 0.0; for i in a.indices { value += a[i] * b[i] }; return value
    }
    static func rotate(_ local: [Double]) -> [Double] {
        var result = local
        for block in 0..<4 { let i = block * 3; result[i] = -local[i + 1]; result[i + 1] = local[i] }
        return result
    }
    static func metadataBytes(_ beam: SpatialBeamDefinition) -> Int {
        [beam.identity, beam.source.source, beam.referenceFrame.key, beam.elementFrame.key,
         beam.material.identity.key, beam.material.source.source, beam.section.source.source].reduce(0) { $0 + $1.utf8.count }
    }
    // Classical closed beam stiffness; no use of producer interpolation, quadrature or internal operators.
    static func stiffness(timoshenko: Bool) -> [Double] {
        var k = [Double](repeating: 0, count: 144)
        for (a, b, value) in [(0, 6, 12.0), (3, 9, 0.0075)] {
            k[a * 12 + a] = value; k[b * 12 + b] = value
            k[a * 12 + b] = -value; k[b * 12 + a] = -value
        }
        for plane in 0..<2 {
            let ei = plane == 0 ? 0.048 : 0.024, shear = plane == 0 ? 8.0 : 6.0
            let phi = timoshenko ? 3 * ei / shear : 0, factor = ei / (8 * (1 + phi))
            let indices = plane == 0 ? [1, 5, 7, 11] : [2, 4, 8, 10]
            let signs = plane == 0 ? [1.0, 1, 1, 1] : [1.0, -1, 1, -1]
            let values = [12.0, 12, -12, 12, 12, 4 * (4 + phi), -12, 4 * (2 - phi),
                          -12, -12, 12, -12, 12, 4 * (2 - phi), -12, 4 * (4 + phi)]
            for i in 0..<4 { for j in 0..<4 { k[indices[i] * 12 + indices[j]] = factor * values[i * 4 + j] * signs[i] * signs[j] } }
        }
        return k
    }
}
