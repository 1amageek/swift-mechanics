import SwiftMechanics

/// A genuine public equilibrium/rigid-inertia pencil, with an independent coupled-root oracle.
final class GeneralDampedSpectrumProbeContext: Sendable {
    let pencil: StructuralPencil
    var binding: StructuralBinding { pencil.binding }
    let policy: StructuralPolicy
    let budget: NumericalBudget

    @inline(never) init() throws {
        let policy = try StructuralPolicy(maximumCoordinates: 8, maximumMetadataBytes: 4096,
            energyScale: 1, timeScale: 1, spectralTolerance: 1e-12,
            positiveMassThreshold: 1e-14, originalResidualTolerance: 1e-7,
            zeroEigenvalueThreshold: 1e-9, isCancelled: { false })
        let budget = try NumericalBudget(scalarStorage: 2_000_000,
            arithmeticOperations: 100_000_000, iterations: 100_000)
        self.policy = policy
        self.budget = budget
        pencil = try Self.makePencil(policy: policy, budget: budget)
    }

    /// det(s*s*M+s*C+K)=(s*s+s+4)*(s*s+2*s+4), computed independently of the solver.
    var expectedPoles: [SpectrumComplex] {
        let firstImaginary = Double(15).squareRoot() / 2
        let secondImaginary = Double(3).squareRoot()
        return [SpectrumComplex(real: -0.5, imaginary: firstImaginary),
                SpectrumComplex(real: -0.5, imaginary: -firstImaginary),
                SpectrumComplex(real: -1, imaginary: secondImaginary),
                SpectrumComplex(real: -1, imaginary: -secondImaginary)]
    }

    /// The first original quadratic row fixes z2/z1; no modal orthogonality is inferred.
    func modeRatio(_ pole: SpectrumComplex) throws(FoundationVerificationError) -> SpectrumComplex {
        let a = pole.real, b = pole.imaginary, rootTwo = Double(2).squareRoot()
        let numeratorReal = a * a - b * b + a + 2
        let numeratorImaginary = 2 * a * b + b
        let denominatorReal = rootTwo * a, denominatorImaginary = rootTwo * b
        let denominator = denominatorReal * denominatorReal + denominatorImaginary * denominatorImaginary
        guard a.isFinite, b.isFinite, denominator.isFinite, denominator > 0 else { throw .analyticCheckFailed }
        let real = -(numeratorReal * denominatorReal + numeratorImaginary * denominatorImaginary) / denominator
        let imaginary = -(numeratorImaginary * denominatorReal - numeratorReal * denominatorImaginary) / denominator
        guard real.isFinite, imaginary.isFinite else { throw .analyticCheckFailed }
        return SpectrumComplex(real: real, imaginary: imaginary)
    }

    @inline(never) private static func makePencil(policy: StructuralPolicy, budget: NumericalBudget) throws -> StructuralPencil {
        let compiled = try compile()
        let limits = try EquilibriumLimits(coordinates: 2, rows: 0, cases: 1, identifierBytes: 256, bodies: 3)
        let chart = try StaticCoordinateChart(stamp: compiled.stamp, frame: compiled.tree.worldFrame,
            coordinateIDs: [101, 102], joints: compiled.tree.joints.map { $0.id },
            dimensions: [.length, .length], scales: [1, 1], limits: limits)
        let point = try operatingPoint(chart: chart, limits: limits, budget: budget)
        let dynamics = try mass(compiled, point: point, budget: budget)
        let linearization = try linearize(point, compiled: compiled, dynamics: dynamics, limits: limits, budget: budget)
        var work = NumericalWork(budget: budget)
        let builder: any StructuralModelBuilding = ReferenceStructuralModelBuilder()
        return try builder.equilibrium(linearization, expectedModel: compiled.stamp, policy: policy, work: &work)
    }

    @inline(never) private static func operatingPoint(chart: StaticCoordinateChart, limits: EquilibriumLimits,
                                                      budget: NumericalBudget) throws -> EquilibriumSolution {
        // These are actual public physical spring laws, not a supplied stiffness matrix.
        let model = try StaticForceModel(identity: "general-damped-independent-springs", chart: chart,
            law: .springs(linear: [2, 8], cubic: [0, 0], constant: [0, 0], loadDirection: [0, 0]),
            minimumPosition: [-1, -1], maximumPosition: [1, 1], parameterIdentity: "zero-spring-load",
            minimumParameter: -1, maximumParameter: 1, energyScale: 1, limits: limits)
        let nonlinear = try NonlinearPolicy<Double>(
            strategy: .lineSearch(contraction: 0.5, sufficientDecrease: 0.0001, minimumFraction: 1e-10),
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            tolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 0, pivotThreshold: 1e-12),
            referenceScale: 1, minimumDirectionNorm: 1e-15, derivativeProbeDistance: 1e-6,
            derivativeAbsoluteTolerance: 1e-4, derivativeRelativeTolerance: 1e-4,
            maximumFactorEntries: 64, estimateCondition: false,
            budget: NumericalBudget(scalarStorage: 100_000, arithmeticOperations: 1_000_000, iterations: 100))
        let policy = try EquilibriumPolicy(limits: limits, nonlinear: nonlinear,
            physicalForceTolerances: [1e-9, 1e-9], constraintTolerance: 1e-9,
            reactionSelection: .independentRowRepresentative)
        let branch = try EquilibriumBranch(identity: "independent-zero-spring-equilibrium",
            minimumPosition: [-1, -1], maximumPosition: [1, 1], maximumNormalizedStep: 1, limits: limits)
        var work = NumericalWork(budget: budget)
        let solver: any EquilibriumSolving = ReferenceEquilibriumSolver()
        return try solver.solve(model, constraints: nil, initialPosition: [0, 0], parameter: 0, time: 0,
            branch: branch, policy: policy, work: &work)
    }

    @inline(never) private static func linearize(_ point: EquilibriumSolution, compiled: CompiledMechanicalModel,
                                                dynamics: RigidDynamicsSystem, limits: EquilibriumLimits,
                                                budget: NumericalBudget) throws -> EquilibriumLinearization {
        let rootTwo = Double(2).squareRoot()
        // The declared physical linear damping is nonproportional: its off-diagonal coupling is nonzero.
        let reduction = EquilibriumReduction(freeCoordinates: 2, basis: [1, 0, 0, 1],
            damping: [1, rootTwo, rootTwo, 2], outputRows: 2,
            outputMap: [1, 0, 0, 1], outputDimensions: [.length, .length])
        let policy = try EquilibriumLinearizationPolicy(limits: limits,
            capability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            tolerance: LinearTolerance(absoluteResidual: 1e-9, relativeResidual: 1e-10, pivotThreshold: 1e-12),
            displacementProbe: 1e-5, parameterProbe: 1e-5, derivativeAbsoluteTolerances: [1e-8, 1e-8],
            derivativeRelativeTolerance: 1e-7, constraintTolerance: 1e-9, inertialAbsoluteTolerances: [1e-9, 1e-9])
        var work = NumericalWork(budget: budget)
        let service: any EquilibriumLinearizing = ReferenceEquilibriumLinearizer()
        return try service.linearize(point, compiled: compiled, dynamics: dynamics,
            reduction: reduction, policy: policy, work: &work)
    }

    @inline(never) private static func mass(_ compiled: CompiledMechanicalModel, point: EquilibriumSolution,
                                           budget: NumericalBudget) throws -> RigidDynamicsSystem {
        let state = try KinematicState(revision: compiled.stamp.revision, time: point.time,
            q: point.position, v: [0, 0], acceleration: [0, 0])
        let snapshot = try compiled.evaluate(compiled.makeState(state))
        var inertias: [RigidBodyInertia] = []
        for body in snapshot.bodies {
            guard let descriptor = compiled.descriptor.bodies.first(where: { $0.id == body.body }),
                  case .spatial(let record) = descriptor, let inertia = record.inertia,
                  record.frame == body.bodyFrame else { throw DynamicsError.inertiaIdentityMismatch }
            inertias.append(try RigidBodyInertia(body: body.body, frame: body.bodyFrame, properties: inertia.properties))
        }
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let admission = DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 3,
            maximumVelocities: 2, maximumBodyWrenches: 0, maximumGeneralizedContributions: 0),
            angularVelocityTolerance: tolerance, linearVelocityTolerance: tolerance)
        var loadWork = LoadWork(budget: try LoadBudget(maximumWork: 100, maximumScalars: 0))
        var work = NumericalWork(budget: budget)
        let equations: any RigidEquationComputing = RigidEquationKernel()
        return try equations.assemble(RigidDynamicsInput(snapshot: snapshot, velocity: [0, 0],
            inertias: inertias, gravity: nil), admission: admission, loadWork: &loadWork, work: &work)
    }

    @inline(never) private static func body(_ name: String, mode: BodyMotionMode) throws -> BodyRecord3D {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let properties = try MassProperties3D(mass: 1, centerOfMass: .zero, inertiaAtCenter: .identity,
            policy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0))
        return try BodyRecord3D(id: EntityID(kind: .body, key: name),
            frame: EntityID(kind: .frame, key: name + "-frame"), mode: mode,
            bodyToWorld: .identity, representations: BodyRepresentations(),
            inertia: InertialRepresentation3D(properties: properties,
                provenance: SourceProvenance(source: "independent unit slider inertia", revision: 1), quality: .exact))
    }

    @inline(never) private static func descriptor() throws -> MechanicalDescriptor {
        let root = try body("general-damped-root", mode: .static)
        let first = try body("general-damped-first", mode: .dynamic)
        let second = try body("general-damped-second", mode: .dynamic)
        let firstJoint = try JointRecord(id: EntityID(kind: .joint, key: "general-damped-first-slider"),
            parentBody: root.id, childBody: first.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "general-damped-first-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "general-damped-first-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitX)))
        let secondJoint = try JointRecord(id: EntityID(kind: .joint, key: "general-damped-second-slider"),
            parentBody: root.id, childBody: second.id,
            parentAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "general-damped-second-parent"), placement: .fixed(.identity)),
            childAnchor: JointAnchor(frame: EntityID(kind: .frame, key: "general-damped-second-child"), placement: .fixed(.identity)),
            manifold: JointManifold(.prismatic(axis: .unitY)))
        return try MechanicalDescriptor(identity: "general-damped-physical-sliders", revision: 1,
            bodies: [.spatial(second), .spatial(root), .spatial(first)],
            joints: [MechanicalJoint(record: firstJoint, authority: .dynamicState),
                     MechanicalJoint(record: secondJoint, authority: .dynamicState)],
            root: root.id, rootBase: .fixed, rootAuthority: .fixed,
            worldFrame: EntityID(kind: .frame, key: "general-damped-world"),
            initialState: KinematicState(revision: 1, time: 0, q: [0, 0], v: [0, 0], acceleration: [0, 0]),
            representationRequirements: [], features: [], extensions: [])
    }

    @inline(never) private static func compile() throws -> CompiledMechanicalModel {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        let policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 3,
            maximumVelocities: 2, maximumJacobianScalars: 36),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance,
                chartRankRelative: 1e-10, characteristicLengthMeters: 1),
            inertiaPolicy: InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 0),
            translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 30, maximumIdentifierBytes: 4096, maximumSparsityEntries: 36,
            maximumDependencyEntries: 300, maximumExtensionRecords: 0, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        let compiler: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())
        return try compiler.compile(descriptor(), policy: policy)
    }
}
