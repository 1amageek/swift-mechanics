import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints
import MechanicsTransmissions

extension FoundationVerification {
    @inline(never) static func verifyTransmissions() throws {
        try verifyTransmissionGear(internalMesh: false)
        try verifyTransmissionGear(internalMesh: true)
        try verifyTransmissionBacklashAndDrag()
    }

    @inline(never) private static func transmissionProbeWork() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 200_000, arithmeticOperations: 2_000_000, iterations: 1000))
    }

    @inline(never) private static func transmissionProbePolicy() throws(TransmissionError) -> TransmissionPolicy {
        try TransmissionPolicy(maximumCoordinates: 2, maximumPorts: 2, maximumRelations: 2, expectedLayoutRevision: 7,
            expectedModelRevision: 9, geometryTolerance: 1e-9, originalTolerance: 1e-8, powerScale: 10, powerTolerance: 1e-8)
    }

    @inline(never) private static func transmissionProbePort(_ index: Int) throws -> TransmissionPortBinding {
        try TransmissionPortBinding(coordinateIndex: index, coordinateID: UInt64(index + 1), body: EntityID(kind: .body, key: "transmission-body-\(index)"),
            joint: EntityID(kind: .joint, key: "transmission-joint-\(index)"), frame: EntityID(kind: .frame, key: "transmission-world"),
            manifold: JointManifold(.revolute(axis: .unitZ)), jointToReference: .identity, layoutRevision: 7, modelRevision: 9)
    }

    @inline(never) private static func transmissionProbeNetwork(_ kind: TransmissionRelationKind) throws -> CompiledTransmissionNetwork {
        let layout = try ConstraintCoordinateLayout(coordinateIDs: [1, 2], dimensions: [.angle, .angle], scales: [1, 1], timeScale: 2, revision: 7)
        let compiler: any TransmissionCompiling = AffineTransmissionCompiler()
        var work = try transmissionProbeWork()
        return try compiler.compile(id: 100, layout: layout, ports: [transmissionProbePort(0), transmissionProbePort(1)],
            relations: [TransmissionRelation(id: 1, kind: kind)], minimumPosition: [-10, -10], maximumPosition: [10, 10],
            minimumTime: 0, maximumTime: 10, policy: transmissionProbePolicy(), work: &work)
    }

    @inline(never) private static func transmissionProbeAssemblyPolicy() throws -> ConstraintSolvePolicy {
        let tolerance = try LinearTolerance<Double>(absoluteResidual: 1e-10, relativeResidual: 0, pivotThreshold: 1e-13)
        let nonlinear = try NonlinearPolicy<Double>(strategy: .newton,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU), tolerance: tolerance,
            referenceScale: 1, minimumDirectionNorm: 0, derivativeProbeDistance: 1e-6, derivativeAbsoluteTolerance: 1e-5,
            derivativeRelativeTolerance: 1e-5, maximumFactorEntries: 1000, estimateCondition: false,
            budget: NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 1_000_000, iterations: 1000))
        return try ConstraintSolvePolicy(evaluation: ConstraintEvaluationPolicy(maximumCoordinates: 2, maximumRows: 2, expectedLayoutRevision: 7),
            diagonalMetric: [1, 1], energyScale: 1, rankPolicy: .allowRedundancy, rankRelativeTolerance: 1e-10,
            originalResidualTolerance: 1e-8, maximumCorrection: 10, nonlinear: nonlinear,
            linearCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky), linearTolerance: tolerance)
    }

    @inline(never) private static func verifyTransmissionGear(internalMesh: Bool) throws {
        let kind: TransmissionRelationKind = internalMesh
            ? .internalGear(first: 0, second: 1, firstTeeth: 20, secondTeeth: 40, phase: 4, phaseScale: 2)
            : .externalGear(first: 0, second: 1, firstTeeth: 20, secondTeeth: 40, phase: 4, phaseScale: 2)
        let network = try transmissionProbeNetwork(kind)
        let assembler: any ConstraintAssembling = WeightedConstraintAssembler()
        let service: any TransmissionNetworkOperating = AffineTransmissionOperator(assembler: assembler)
        var work = try transmissionProbeWork(), supplier = try transmissionProbeWork()
        let solved = try service.assemble(network, initialPosition: [1, 0], time: 0, assemblyPolicy: transmissionProbeAssemblyPolicy(),
            policy: transmissionProbePolicy(), work: &work, constraintWork: &supplier)
        let sign = internalMesh ? 1.0 : -1.0
        // Weighted nearest point to 20*q0 +/- 40*q1 = 4.
        try require(abs(solved.assembly.position[0] - 0.84) < 1e-7 && abs(solved.assembly.position[1] - sign * 0.32) < 1e-7)
        try require(solved.assembly.rank.rank == 1 && solved.originalPhysicalPhaseResidual < 1e-8 && supplier.operations > 0)
        try verifyTransmissionGearPower(network, sign: sign)
    }

    @inline(never) private static func verifyTransmissionGearPower(_ network: CompiledTransmissionNetwork, sign: Double) throws {
        let service: any TransmissionNetworkOperating = AffineTransmissionOperator()
        var work = try transmissionProbeWork()
        let response = try service.idealEfforts(network, position: [1, sign * 0.4], velocity: [2, sign], normalizedEnergyMultipliers: [4],
            policy: transmissionProbePolicy(), work: &work)
        try require(abs(response.generalizedEfforts[0] - 40) < 1e-10 && abs(response.generalizedEfforts[1] + sign * 80) < 1e-10)
        try require(abs(response.totalPower) < 1e-10 && response.powerResidual < 1e-8 && response.originalSpeedResidual < 1e-8)
        try require(abs(response.ports[0].wrenchAboutReferenceOrigin.torque.z - 40) < 1e-10)
        var rejected = false
        do throws(TransmissionError) {
            _ = try service.idealEfforts(network, position: [1, sign * 0.4], velocity: [1, 0], normalizedEnergyMultipliers: [0],
                policy: transmissionProbePolicy(), work: &work)
        } catch {
            switch error {
            case .originalResidual(let row, let value): try require(row == 1 && abs(value - 20) < 1e-10); rejected = true
            default: throw FoundationVerificationError.unexpectedFailure
            }
        }
        try require(rejected)
    }

    @inline(never) private static func verifyTransmissionBacklashAndDrag() throws {
        let network = try transmissionProbeNetwork(.rigidShaft(first: 0, second: 1, phase: 0, phaseScale: 1))
        let law = try BacklashLaw(id: 5, revision: 2, halfClearance: 0.1, stiffness: 100, damping: 2, maximumAbsPhase: 1, energyScale: 1)
        let service: any TransmissionConstitutiveEvaluating = PassiveTransmissionEvaluator()
        var work = try transmissionProbeWork()
        let accepted = try service.initializeBacklash(network, rowIndex: 0, position: [0.2, 0], time: 0, law: law, policy: transmissionProbePolicy(), work: &work)
        let response = try service.backlash(network, rowIndex: 0, position: [0.2, 0], velocity: [0.3, 0], time: 1, law: law,
            accepted: accepted, policy: transmissionProbePolicy(), work: &work)
        try require(abs(response.phaseEffort + 10.6) < 1e-10 && abs(response.potentialEnergy - 0.5) < 1e-10)
        try require(abs(response.dissipativePower + 0.18) < 1e-10 && abs(response.mapped.totalPower + 3.18) < 1e-10)
        try require(response.originalPowerResidual < 1e-8 && accepted.time == 0 && accepted.branch == .positiveFlank)
        let drag = try DirectionalDragLaw(positiveViscous: 2, negativeViscous: 4, positiveCoulomb: 3, negativeCoulomb: 5, maximumAbsVelocity: 10)
        let dragResponse = try service.drag(network.ports[0], layout: network.equations.layout, velocity: -2, law: drag, policy: transmissionProbePolicy(), work: &work)
        try require(dragResponse.selectedEffort == 13 && dragResponse.dissipativePower == -26)
    }
}
