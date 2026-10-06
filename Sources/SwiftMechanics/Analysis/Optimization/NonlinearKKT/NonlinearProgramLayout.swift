public final class NonlinearProgramLayout: Sendable {
    public let metadata: OptimizationMetadata
    public let equalityJacobian: SparseOptimizationPattern, inequalityJacobian: SparseOptimizationPattern, lagrangianHessian: SparseOptimizationPattern
    public var variableCount: Int { metadata.variableIDs.count }
    public var equalityCount: Int { metadata.equalityReferences.count }
    public var inequalityCount: Int { metadata.inequalityReferences.count }
    public init(metadata: OptimizationMetadata,equalityJacobian: SparseOptimizationPattern,inequalityJacobian: SparseOptimizationPattern,lagrangianHessian: SparseOptimizationPattern) {
        self.metadata=metadata; self.equalityJacobian=equalityJacobian; self.inequalityJacobian=inequalityJacobian; self.lagrangianHessian=lagrangianHessian
    }
}
