import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsJoints

public struct CompilationPolicy: Equatable, Sendable {
    public let kinematicCapacity: KinematicCapacity
    public let jointPolicy: JointEvaluationPolicy
    public let inertiaPolicy: InertiaValidationPolicy
    public let translationTolerance: NumericalTolerance
    public let rotationTolerance: NumericalTolerance
    public let maximumRecords: Int
    public let maximumIdentifierBytes: Int
    public let maximumSparsityEntries: Int
    public let maximumDependencyEntries: Int
    public let maximumExtensionRecords: Int
    public let maximumDiagnostics: Int
    public let extensionBudget: NumericalBudget
    public let target: CompilerTarget

    public init(kinematicCapacity: KinematicCapacity, jointPolicy: JointEvaluationPolicy, inertiaPolicy: InertiaValidationPolicy,
                translationTolerance: NumericalTolerance, rotationTolerance: NumericalTolerance, maximumRecords: Int,
                maximumIdentifierBytes: Int, maximumSparsityEntries: Int, maximumDependencyEntries: Int, maximumExtensionRecords: Int,
                maximumDiagnostics: Int, extensionBudget: NumericalBudget, target: CompilerTarget) throws(CompilationFailure) {
        guard maximumRecords >= 0, maximumIdentifierBytes >= 0, maximumSparsityEntries >= 0, maximumDependencyEntries >= 0,
              maximumExtensionRecords >= 0, maximumDiagnostics > 0 else { throw .one(.invalidPolicy, .input, message: "Compiler capacities must be nonnegative and diagnostic capacity positive.") }
        self.kinematicCapacity = kinematicCapacity; self.jointPolicy = jointPolicy; self.inertiaPolicy = inertiaPolicy
        self.translationTolerance = translationTolerance; self.rotationTolerance = rotationTolerance
        self.maximumRecords = maximumRecords; self.maximumIdentifierBytes = maximumIdentifierBytes
        self.maximumSparsityEntries = maximumSparsityEntries; self.maximumDependencyEntries = maximumDependencyEntries; self.maximumExtensionRecords = maximumExtensionRecords
        self.maximumDiagnostics = maximumDiagnostics; self.extensionBudget = extensionBudget; self.target = target
    }
}
