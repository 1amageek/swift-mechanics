import MechanicsModel
import MechanicsNumerics
public struct OptimizationMetadata: Sendable {
    public let identity: String
    public let provenance: SourceProvenance
    public let variableIDs: [UInt64]
    public let variableReferences: [SIReferenceQuantity<Double>]
    public let objectiveReference: SIReferenceQuantity<Double>
    public let equalityReferences: [SIReferenceQuantity<Double>]
    public let inequalityReferences: [SIReferenceQuantity<Double>]
    public init(identity: String, provenance: SourceProvenance, variableIDs: [UInt64], variableReferences: [SIReferenceQuantity<Double>],
        objectiveReference: SIReferenceQuantity<Double>, equalityReferences: [SIReferenceQuantity<Double>] = [], inequalityReferences: [SIReferenceQuantity<Double>] = []) throws(OptimizationCause) {
        guard !identity.isEmpty else { throw .invalidProblem }
        self.identity=identity; self.provenance=provenance; self.variableIDs=variableIDs; self.variableReferences=variableReferences
        self.objectiveReference=objectiveReference; self.equalityReferences=equalityReferences; self.inequalityReferences=inequalityReferences
    }
}
