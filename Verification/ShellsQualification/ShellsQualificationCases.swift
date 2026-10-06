import SwiftMechanics

@available(macOS 15.0, *)
public struct ShellsQualificationCases: ShellsQualifying, Sendable {
    private typealias F = ShellsQualificationFixtures
    private typealias E = ShellsQualificationError
    public init() {}
    public func run(_ selected: ShellsQualificationCase) throws(ShellsQualificationError) {
        switch selected {
        case .membranePatch: try membranePatch()
        case .bendingAndShear: try bendingAndShear()
        case .massAndDamping: try massAndDamping()
        case .rigidFrameAndPower: try rigidFrameAndPower()
        case .originalRefusals: try originalRefusals()
        case .resourcesAndCancellation: try resourcesAndCancellation()
        }
    }
    private func membranePatch() throws(E) {
        for (x, y) in [(1, 1), (2, 2), (3, 2)] {
            let plate = try F.plate(x: x, y: y), q = try F.coordinates(plate, F.membrane)
            let state = try F.state(plate, q, q.map { 2 * $0 }), result = try F.assemble(plate, state)
            try F.require(result.plate.identity == plate.identity && result.plate.revision == 7 && result.plate.source == plate.source && result.plate.frame == plate.frame, "actual plate/source retained")
            try F.near(result.storedEnergy, 0.000672, "independent constant plane stress energy")
            try F.near(F.dot(q, result.internalForce), 0.001344, "independent strain-resultant work")
            try F.near(F.dot(state.velocities, result.internalForce), 0.002688, "independent elastic power")
            try F.near(result.internalForce, F.action(result.tangent, q), "positive energy gradient")
            _ = try F.wrenchAndPower(result, rate: state.velocities)
            if x == 1 && y == 1 { try F.near(result.internalForce, F.membraneForce(), "closed integrated membrane nodal traction") }
        }
        let plate = try F.plate(), q = try F.coordinates(plate, F.membrane)
        let delta = try F.coordinates(plate) { x, y in [0.004 * x - 0.001 * y, 0.002 * x + 0.003 * y, 0.005 * x + 0.002 * y, 0.002, -0.001] }
        let epsilon = 1e-4
        var plus = q, minus = q
        for i in q.indices { plus[i] += epsilon * delta[i]; minus[i] -= epsilon * delta[i] }
        let base = try F.assemble(plate, F.state(plate, q)), forward = try F.assemble(plate, F.state(plate, plus)), backward = try F.assemble(plate, F.state(plate, minus))
        try F.near((forward.storedEnergy - backward.storedEnergy) / (2 * epsilon), 0.002112, "original independent virtual strain work")
        try F.near(F.dot(base.internalForce, delta), 0.002112, "gradient conjugate virtual work")
        var derivative = q
        for i in q.indices { derivative[i] = (forward.internalForce[i] - backward.internalForce[i]) / (2 * epsilon) }
        try F.near(derivative, F.action(base.tangent, delta), "directional positive energy tangent")
    }
    private func bendingAndShear() throws(E) {
        for (x, y) in [(1, 1), (2, 2), (3, 2)] {
            for thickness in [0.2, 0.1, 0.05] {
                let plate = try F.plate(x: x, y: y, thickness: thickness), q = try F.coordinates(plate, F.bending)
                let result = try F.assemble(plate, F.state(plate, q, q.map { 2 * $0 }))
                let ratio = thickness / 0.2, energy = 0.00000224 * ratio * ratio * ratio
                try F.near(result.storedEnergy, energy, "constant curvature no tied shear energy and cubic thickness scale")
                try F.near(F.dot(result.internalForce, q), 2 * energy, "original curvature-resultant work")
                try F.near(F.wrenchAndPower(result, rate: q.map { 2 * $0 }), 4 * energy, "physical bending moment power")
                if x == 1 && y == 1 && thickness == 0.2 { try F.near(result.internalForce, F.bendingForce(), "independent constant curvature nodal moments") }
            }
        }
        let plate = try F.plate(), q = try F.coordinates(plate) { x, y in [0, 0, 0.001 * x + 0.002 * y, 0, 0] }
        let result = try F.assemble(plate, F.state(plate, q))
        let force = [0.0, 0, -0.021, 0.009, 0.018, 0, 0, -0.003, 0.009, 0.018,
                     0, 0, 0.003, 0.009, 0.018, 0, 0, 0.021, 0.009, 0.018]
        try F.near(result.storedEnergy, 0.00009, "independent tied shear energy")
        try F.near(result.internalForce, force, "original shear nodal force and director moment")
        try F.near(F.wrenchAndPower(result, rate: q.map { 2 * $0 }), 0.00036, "physical shear wrench power")
    }
    private func massAndDamping() throws(E) {
        for form in [ShellMassForm.consistent, .rowSumLumped] {
            let plate = try F.plate(alpha: 0.2, beta: 0.3)
            let q = try F.coordinates(plate, F.membrane)
            let uniform = try F.coordinates(plate) { _, _ in [0.01, 0.02, -0.03, 0.04, -0.05] }
            let result = try F.assemble(plate, F.state(plate, q, uniform), mass: form)
            try F.require(result.massForm == form, "explicit actual mass policy")
            try F.near(result.totalReferenceMass, 6, "original translational mass")
            try F.near(result.totalReferenceRotaryInertia, 0.02, "original director rotary inertia")
            try F.near(result.mass, F.mass(form), "independent Q4 physical mass matrix")
            try F.near(F.dot(uniform, F.action(result.mass, uniform)), 0.008482, "constant translational/rotary mass integral")
            try F.near(result.dissipatedPower, 0.0459764, "independent Rayleigh mass and shear dissipation")
            let damping = [0.003, 0.006, -0.027, 0.10804, -0.13505, 0.003, 0.006, 0.189, 0.10804, -0.13505,
                           0.003, 0.006, -0.207, 0.10804, -0.13505, 0.003, 0.006, 0.009, 0.10804, -0.13505]
            try F.near(result.dampingForce, damping, "original positive Cv covector")
            try F.near(F.dot(uniform, result.dampingForce), 0.0459764, "damping covector virtual power")
            try F.near(F.dot(uniform, result.dampingForce.map { -$0 }), -0.0459764, "physical damping force dissipates")
            let physicalMass = F.mass(form)
            for i in 0..<400 { try F.near(result.damping[i], 0.2 * physicalMass[i] + 0.3 * result.tangent[i], "Rayleigh operator identity") }
            let linear = try F.coordinates(plate) { x, y in [0, 0, x + y, 0, 0] }
            let massQuadratic = F.dot(linear, F.action(result.mass, linear))
            try F.near(massQuadratic, form == .consistent ? 44 : 57, "original distributed versus row-sum kinetic integral")
        }
        let plate = try F.plate(alpha: 0.2)
        let zero = [Double](repeating: 0, count: plate.coordinateCount), v = try F.coordinates(plate) { _, _ in [0.01, 0, 0, 0, 0] }
        let rigid = try F.assemble(plate, F.state(plate, zero, v))
        try F.near(rigid.dissipatedPower, 0.00012, "reference mass damping of rigid translation is explicit")
    }
    private func rigidFrameAndPower() throws(E) {
        let plate = try F.plate(), zero = [Double](repeating: 0, count: plate.coordinateCount)
        let original = try F.assemble(plate, F.state(plate, zero))
        for mode in 0..<6 {
            let q = try F.coordinates(plate) { x, y in
                switch mode {
                case 0: return [0.01, 0, 0, 0, 0]
                case 1: return [0, 0.01, 0, 0, 0]
                case 2: return [0, 0, 0.01, 0, 0]
                case 3: return [0, 0, 0.01 * y, 0, -0.01]
                case 4: return [0, 0, -0.01 * x, 0.01, 0]
                default: return [-0.01 * y, 0.01 * x, 0, 0, 0]
                }
            }
            let result = try F.assemble(plate, F.state(plate, q))
            try F.near(result.storedEnergy, 0, "six independent infinitesimal rigid energies")
            try F.near(result.internalForce, zero, "six rigid zero forces")
            try F.near(F.action(original.tangent, q), zero, "rigid tangent null action")
        }
        let rotated = try F.plate(rotated: true, revision: 8)
        let q = try F.coordinates(plate, F.membrane), v = try F.coordinates(plate) { x, y in [0.004 * x - 0.001 * y, 0.002 * x + 0.003 * y, 0.005 * x, 0.002, -0.003] }
        let first = try F.assemble(plate, F.state(plate, q, v)), second = try F.assemble(rotated, F.state(rotated, q, v))
        try F.near(second.tangent, first.tangent, "local tangent unchanged by reference embedding")
        try F.near(second.mass, first.mass, "local mass unchanged by reference embedding")
        try F.near(second.internalForce, F.membraneForce(), "local conjugate force remains local")
        try F.near(F.wrenchAndPower(first, rate: v), 0.002112, "original physical world power")
        try F.near(F.wrenchAndPower(second, rate: v), 0.002112, "rotated physical world power")
        let positions = [[1.0, 2, 3], [1.0, 4, 3], [1.0, 2, 6], [1.0, 4, 6]]
        for node in 0..<4 {
            let point = try F.shell { () throws(ShellError) in try rotated.referencePosition(node: node) }
            try F.near([point.x, point.y, point.z], positions[node], "identified rotated reference occurrence")
        }
        try F.require(second.plate.revision == 8 && second.plate.basis == rotated.basis && second.plate.frame == rotated.frame && second.plate.source == rotated.source, "original rotated source metadata")
    }
    private func originalRefusals() throws(E) {
        let plate = try F.plate(), zero = [Double](repeating: 0, count: plate.coordinateCount), state = try F.state(plate, zero)
        let assembler: any ShellAssembling = RectangularMindlinShellAssembler(); let admission = try F.admission(); var work = try F.work()
        let finite = try F.plate(formulation: .finiteRotation), finiteState = try F.state(finite, zero)
        try F.expect(.unsupportedFormulation, "finite rotation") { () throws(ShellError) in _ = try assembler.assemble(finite, state: finiteState, admission: admission, work: &work) }
        let stale = try F.state(plate, zero, revision: 8)
        try F.expect(.staleSource, "original stale revision") { () throws(ShellError) in _ = try assembler.assemble(plate, state: stale, admission: admission, work: &work) }
        let foreign = try F.model { () throws(ModelError) in try EntityID(kind: .frame, key: "foreign-shell-frame") }, foreignState = try F.state(plate, zero, frame: foreign)
        try F.expect(.frameMismatch, "original frame") { () throws(ShellError) in _ = try assembler.assemble(plate, state: foreignState, admission: admission, work: &work) }
        let source = try F.model { () throws(ModelError) in try SourceProvenance(source: "shell-source", revision: 5) }, foreignSource = try F.state(plate, zero, source: source)
        try F.expect(.staleSource, "original provenance") { () throws(ShellError) in _ = try assembler.assemble(plate, state: foreignSource, admission: admission, work: &work) }
        let wrongCount = try F.state(plate, [Double](repeating: 0, count: 10))
        try F.expect(.invalidLayout, "original layout count") { () throws(ShellError) in _ = try assembler.assemble(plate, state: wrongCount, admission: admission, work: &work) }
        var nan = zero; nan[2] = .nan
        try F.expect(.invalidLayout, "nonfinite state") { () throws(ShellError) in _ = try ShellNodalState(plateIdentity: plate.identity, plateRevision: 7, frame: plate.frame, source: plate.source, coordinates: nan, velocities: zero) }
        try F.expect(.degenerateGeometry, "parallel reference tangents") { () throws(ShellError) in _ = try ShellBasis(origin: .zero, firstDirection: .unitX, secondDirection: .unitX) }
        try F.expect(.core(.degenerateVector), "original Core failure") { () throws(ShellError) in _ = try ShellBasis(origin: .zero, firstDirection: .zero, secondDirection: .unitY) }
        let inverted = try F.state(plate, F.coordinates(plate) { x, _ in [-2 * x, 0, 0, 0, 0] })
        try F.expect(.invertedGeometry(cell: 0), "in-plane orientation") { () throws(ShellError) in _ = try assembler.assemble(plate, state: inverted, admission: admission, work: &work) }
        let strained = try F.state(plate, F.coordinates(plate) { x, _ in [0.06 * x, 0, 0, 0, 0] })
        try F.expect(.outsideLinearDomain(cell: 0), "surface linear strain") { () throws(ShellError) in _ = try assembler.assemble(plate, state: strained, admission: admission, work: &work) }
        let rawShear = try F.state(plate, F.coordinates(plate) { x, _ in [0, 0, 0.06 * x, 0, 0] })
        try F.expect(.outsideLinearDomain(cell: 0), "raw corner shear") { () throws(ShellError) in _ = try assembler.assemble(plate, state: rawShear, admission: admission, work: &work) }
        let rotation = try F.state(plate, F.coordinates(plate) { _, _ in [0, 0, 0, 0.2, 0] })
        try F.expect(.outsideLinearDomain(cell: 0), "director magnitude") { () throws(ShellError) in _ = try assembler.assemble(plate, state: rotation, admission: admission, work: &work) }
        let thin = try F.plate(thickness: 1e-200), thinState = try F.state(thin, zero)
        try F.expect(.nonFiniteResult, "lost positive thickness scale") { () throws(ShellError) in _ = try assembler.assemble(thin, state: thinState, admission: admission, work: &work) }
        let large = try F.plate(width: 1e308), largeState = try F.state(large, zero)
        try F.expect(.nonFiniteResult, "reference area overflow") { () throws(ShellError) in _ = try assembler.assemble(large, state: largeState, admission: admission, work: &work) }
        try F.expect(.invalidLayout, "invalid node") { () throws(ShellError) in _ = try plate.referencePosition(node: 4) }
        try F.expect(.invalidParameter(name: "referenceCoordinates"), "nonfinite reference query") { () throws(ShellError) in _ = try plate.basis.referencePosition(x: .infinity, y: 0) }
        try F.expect(.numerical(.invalidDimensions), "original subdivision overflow") { () throws(ShellError) in
            _ = try RectangularShellPlate(identity: plate.identity, revision: 7, frame: plate.frame, source: plate.source, basis: plate.basis,
                width: 2, height: 3, thickness: 0.2, density: 5, elasticity: plate.elasticity, elementsX: Int.max, elementsY: 1,
                shearCorrection: 0.75, massDampingRate: 0, stiffnessDampingTime: 0, maximumKinematicMagnitude: 0.1, maximumLinearStrain: 0.05)
        }
        var materialRejected = false
        do throws(MaterialError) { _ = try IsotropicElasticity(bulkModulus: -1, shearModulus: 40) }
        catch { materialRejected = true; try F.require(error == .invalidParameter(name: "bulkModulus"), "original material construction rejection") }
        try F.require(materialRejected, "original material constructor must fail")
    }
    private func resourcesAndCancellation() throws(E) {
        let plate = try F.plate(), zero = [Double](repeating: 0, count: plate.coordinateCount), state = try F.state(plate, zero)
        let assembler: any ShellAssembling = RectangularMindlinShellAssembler(); let normal = try F.admission(), bytes = F.metadataBytes(plate, state)
        var work = try F.work(); _ = try F.shell { () throws(ShellError) in try assembler.assemble(plate, state: state, admission: normal, work: &work) }
        try F.require(work.operations == 2 * bytes + 133_796 && work.peakScalarStorage == 1536, "independent singleQ4 work/storage")
        let lumped = try F.admission(mass: .rowSumLumped); work = try F.work()
        _ = try F.shell { () throws(ShellError) in try assembler.assemble(plate, state: state, admission: lumped, work: &work) }
        try F.require(work.operations == 2 * bytes + 134_276 && work.peakScalarStorage == 1536, "original lumped work")
        let cells = try F.admission(cells: 1, nodes: 3); work = try F.work()
        try F.expect(.capacityExceeded, "node cap") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: cells, work: &work) }
        try F.require(work.operations == 0, "capacity before work")
        let limited = try F.admission(bytes: bytes - 1); work = try F.work()
        try F.expect(.capacityExceeded, "metadata cap") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: limited, work: &work) }
        try F.require(work.operations == bytes - 1, "metadata spent prefix")
        work = try F.work(storage: 1535)
        try F.expect(.numerical(.resourceLimit(resource: .scalarStorage, limit: 1535)), "storage cap") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: normal, work: &work) }
        try F.require(work.operations == 2 * bytes, "original storage refusal prefix")
        let limit = 2 * bytes + 133_795; work = try F.work(operations: limit)
        try F.expect(.numerical(.resourceLimit(resource: .arithmeticOperations, limit: limit)), "operation cap") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: normal, work: &work) }
        try F.require(work.operations == 2 * bytes + 133_792, "original last four-operation refusal prefix")
        let early = try F.admission(cancelled: { true }); work = try F.work()
        try F.expect(.cancelled, "early cancel") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: early, work: &work) }
        try F.require(work.operations == 0 && work.peakScalarStorage == 0, "early cancel before allocation")
        let counter = ShellsCancellationCounter(), counted = try F.admission(cancelled: { counter.checkpoint() })
        work = try F.work(); _ = try F.shell { () throws(ShellError) in try assembler.assemble(plate, state: state, admission: counted, work: &work) }
        let last = ShellsCancellationCounter(limit: counter.count), late = try F.admission(cancelled: { last.checkpoint() }); work = try F.work()
        try F.expect(.cancelled, "last original publication checkpoint") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: late, work: &work) }
        try F.require(work.operations == 2 * bytes + 133_796 && last.count == counter.count, "no partial shell publication")
    }
    public func taskCancellationEntry() throws(ShellsQualificationError) -> @Sendable () throws(ShellsQualificationError) -> Void {
        let plate = try F.plate(), state = try F.state(plate, [Double](repeating: 0, count: plate.coordinateCount))
        return { () throws(E) in
            let assembler: any ShellAssembling = RectangularMindlinShellAssembler(); let admission = try F.admission(); var work = try F.work()
            try F.expect(.cancelled, "actual awaited native cancellation") { () throws(ShellError) in _ = try assembler.assemble(plate, state: state, admission: admission, work: &work) }
            try F.require(work.operations == 0, "actual Task cancellation zero prefix")
        }
    }
}
