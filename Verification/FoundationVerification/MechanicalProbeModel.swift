import SwiftMechanics

struct MechanicalProbeModel {
    let descriptor: MechanicalDescriptor
    let policy: CompilationPolicy
    let model: CompiledMechanicalModel
    let inertiaPolicy: InertiaValidationPolicy

    init(extensions: [MechanicalExtensionRecord] = []) throws {
        let tolerance = try NumericalTolerance(absolute: 1e-12, relative: 1e-12)
        inertiaPolicy = try InertiaValidationPolicy(symmetry: tolerance, physicalityRelative: 1e-12)
        descriptor = try FoundationVerification.compilerDescriptor(inertiaPolicy: inertiaPolicy, displacedChild: false, extensions: extensions)
        policy = try CompilationPolicy(kinematicCapacity: KinematicCapacity(maximumBodies: 2, maximumVelocities: 1, maximumJacobianScalars: 12),
            jointPolicy: JointEvaluationPolicy(quaternionTolerance: tolerance, chartRankRelative: 1e-9, characteristicLengthMeters: 1),
            inertiaPolicy: inertiaPolicy, translationTolerance: tolerance, rotationTolerance: tolerance,
            maximumRecords: 20, maximumIdentifierBytes: 2000, maximumSparsityEntries: 12, maximumDependencyEntries: 200,
            maximumExtensionRecords: 1, maximumDiagnostics: 4,
            extensionBudget: NumericalBudget(scalarStorage: 100, arithmeticOperations: 1000, iterations: 10),
            target: FoundationVerification.compilerVerificationTarget)
        model = try ReferenceMechanicalCompiler(extensions: RuntimeCompilerValidator()).compile(descriptor, policy: policy)
    }
}
