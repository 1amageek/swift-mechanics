import SwiftMechanics

internal enum ShellsQualificationFixtures {
    typealias E = ShellsQualificationError
    static func require(_ condition: Bool, _ label: String) throws(E) { guard condition else { throw .assertion(label) } }
    static func near(_ actual: Double, _ expected: Double, _ label: String) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual - expected) <= 1e-12 + 1e-9 * max(abs(actual), abs(expected)), label)
    }
    static func near(_ actual: [Double], _ expected: [Double], _ label: String) throws(E) {
        try require(actual.count == expected.count, label + " count")
        for i in expected.indices { try near(actual[i], expected[i], label + " " + String(i)) }
    }
    static func shell<T>(_ body: () throws(ShellError) -> T) throws(E) -> T {
        do throws(ShellError) { return try body() } catch { throw .producer(error) }
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T {
        do throws(ModelError) { return try body() } catch { throw .model(error) }
    }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T {
        do throws(MaterialError) { return try body() } catch { throw .material(error) }
    }
    static func work(storage: Int = 20_000, operations: Int = 2_000_000) throws(E) -> NumericalWork {
        do throws(NumericalError) {
            return NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 0))
        } catch { throw .numerical(error) }
    }
    static func vector(_ x: Double, _ y: Double, _ z: Double) throws(E) -> Vector3 { try core { () throws(CoreError) in try Vector3(x, y, z) } }
    static func plate(x: Int = 1, y: Int = 1, thickness: Double = 0.2, rotated: Bool = false,
                      width: Double = 2, height: Double = 3,
                      revision: UInt64 = 7, alpha: Double = 0, beta: Double = 0,
                      formulation: ShellFormulation = .infinitesimalMITC4) throws(E) -> RectangularShellPlate {
        let frame = try model { () throws(ModelError) in try EntityID(kind: .frame, key: "shell-frame") }
        let source = try model { () throws(ModelError) in try SourceProvenance(source: "shell-source", revision: 4) }
        let origin = try vector(1, 2, 3)
        let basis = try shell { () throws(ShellError) in
            try ShellBasis(origin: origin, firstDirection: rotated ? .unitY : .unitX, secondDirection: rotated ? .unitZ : .unitY)
        }
        let elasticity = try material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus: 320 / 3.0, shearModulus: 40) }
        return try shell { () throws(ShellError) in
            try RectangularShellPlate(identity: "shell-plate", revision: revision, frame: frame, source: source,
                basis: basis, width: width, height: height, thickness: thickness, density: 5, elasticity: elasticity,
                elementsX: x, elementsY: y, shearCorrection: 0.75, massDampingRate: alpha, stiffnessDampingTime: beta,
                maximumKinematicMagnitude: 0.1, maximumLinearStrain: 0.05, formulation: formulation)
        }
    }
    static func admission(mass: ShellMassForm = .consistent, cells: Int = 16, nodes: Int = 25, bytes: Int = 512,
                          cancelled: @escaping @Sendable () -> Bool = { false }) throws(E) -> ShellAdmission {
        try shell { () throws(ShellError) in try ShellAdmission(maximumCells: cells, maximumNodes: nodes, maximumMetadataBytes: bytes, massForm: mass, isCancelled: cancelled) }
    }
    static func coordinates(_ plate: RectangularShellPlate, _ field: (Double, Double) -> [Double]) throws(E) -> [Double] {
        var result: [Double] = []
        for node in 0..<plate.nodeCount {
            let x = plate.width * Double(node % (plate.elementsX + 1)) / Double(plate.elementsX)
            let y = plate.height * Double(node / (plate.elementsX + 1)) / Double(plate.elementsY)
            let values = field(x, y); try require(values.count == 5, "fixture fiveDOF field"); result += values
        }
        return result
    }
    static func state(_ plate: RectangularShellPlate, _ q: [Double], _ v: [Double]? = nil,
                      revision: UInt64? = nil, frame: EntityID? = nil, source: SourceProvenance? = nil) throws(E) -> ShellNodalState {
        try shell { () throws(ShellError) in
            try ShellNodalState(plateIdentity: plate.identity, plateRevision: revision ?? plate.revision, frame: frame ?? plate.frame,
                source: source ?? plate.source, coordinates: q, velocities: v ?? [Double](repeating: 0, count: q.count))
        }
    }
    static func assemble(_ plate: RectangularShellPlate, _ state: ShellNodalState, mass: ShellMassForm = .consistent) throws(E) -> ShellAssembly {
        let assembler: any ShellAssembling = RectangularMindlinShellAssembler(); let admission = try Self.admission(mass: mass); var work = try Self.work()
        return try shell { () throws(ShellError) in try assembler.assemble(plate, state: state, admission: admission, work: &work) }
    }
    static func expect(_ expected: ShellError, _ label: String, _ body: () throws(ShellError) -> Void) throws(E) {
        do throws(ShellError) { try body() } catch { try require(error == expected, label + " original typed cause"); return }
        throw .assertion(label + " unexpectedly succeeded")
    }
    static func action(_ matrix: [Double], _ q: [Double]) -> [Double] {
        var result = [Double](repeating: 0, count: q.count)
        for i in q.indices { for j in q.indices { result[i] += matrix[i * q.count + j] * q[j] } }; return result
    }
    static func dot(_ a: [Double], _ b: [Double]) -> Double { var value = 0.0; for i in a.indices { value += a[i] * b[i] }; return value }
    static func membrane(_ x: Double, _ y: Double) -> [Double] { [0.001 * x + 0.0015 * y, 0.0015 * x + 0.002 * y, 0, 0, 0] }
    static func bending(_ x: Double, _ y: Double) -> [Double] { [0, 0, -0.0005 * x * x - 0.001 * y * y - 0.0015 * x * y, 0.001 * x + 0.0015 * y, 0.0015 * x + 0.002 * y] }
    static func membraneForce() -> [Double] { [-0.084, -0.092, 0, 0, 0, 0.036, -0.020, 0, 0, 0, -0.036, 0.020, 0, 0, 0, 0.084, 0.092, 0, 0, 0] }
    static func bendingForce() -> [Double] { [0, 0, 0, -0.00028, -0.00092 / 3, 0, 0, 0, 0.00012, -0.0002 / 3, 0, 0, 0, -0.00012, 0.0002 / 3, 0, 0, 0, 0.00028, 0.00092 / 3] }
    static func mass(_ form: ShellMassForm) -> [Double] {
        var result = [Double](repeating: 0, count: 400)
        let weights = [4.0, 2, 2, 1, 2, 4, 1, 2, 2, 1, 4, 2, 1, 2, 2, 4]
        for i in 0..<4 { for j in 0..<4 { for axis in 0..<5 {
            let total = axis < 3 ? 6.0 : 0.02
            let value = form == .consistent ? total * weights[i * 4 + j] / 36 : (i == j ? total / 4 : 0)
            result[(5 * i + axis) * 20 + 5 * j + axis] = value
        } } }; return result
    }
    static func metadataBytes(_ plate: RectangularShellPlate, _ state: ShellNodalState) -> Int {
        [plate.identity, state.plateIdentity, plate.frame.key, state.frame.key, plate.source.source, state.source.source].reduce(0) { $0 + $1.utf8.count }
    }
    static func world(_ plate: RectangularShellPlate, _ x: Double, _ y: Double, _ z: Double) -> [Double] {
        let b = plate.basis
        return [b.firstTangent.x * x + b.secondTangent.x * y + b.normal.x * z,
                b.firstTangent.y * x + b.secondTangent.y * y + b.normal.y * z,
                b.firstTangent.z * x + b.secondTangent.z * y + b.normal.z * z]
    }
    // Director betaX/betaY are physical omegaY/-omegaX, so their covectors map to momentY/-momentX.
    static func wrenchAndPower(_ assembly: ShellAssembly, rate: [Double]) throws(E) -> Double {
        let plate = assembly.plate, g = assembly.internalForce
        var resultant = [Double](repeating: 0, count: 3), moment = resultant, power = 0.0
        for node in 0..<plate.nodeCount {
            let i = 5 * node, force = world(plate, g[i], g[i + 1], g[i + 2])
            let torque = world(plate, -g[i + 4], g[i + 3], 0)
            let p = try shell { () throws(ShellError) in try plate.referencePosition(node: node) }
            let arm = [p.y * force[2] - p.z * force[1], p.z * force[0] - p.x * force[2], p.x * force[1] - p.y * force[0]]
            for axis in 0..<3 { resultant[axis] += force[axis]; moment[axis] += torque[axis] + arm[axis] }
            power += dot(force, world(plate, rate[i], rate[i + 1], rate[i + 2]))
            power += dot(torque, world(plate, -rate[i + 4], rate[i + 3], 0))
        }
        try near(resultant, [0, 0, 0], "original physical nodal force balance")
        try near(moment, [0, 0, 0], "original world moment balance")
        try near(power, dot(g, rate), "nodal/director vs physical wrench virtual power")
        return power
    }
}
