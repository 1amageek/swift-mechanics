public protocol TreeDifferentiating: Sendable {
    func direction(_ tree: KinematicTree, state: KinematicState, direction: TreeDirection,
                   jointPolicy: JointEvaluationPolicy, policy: DerivativePolicy,
                   workspace: inout TreeTangentWorkspace, supplierWork: inout DerivativeSupplierWork,
                   work: inout NumericalWork) throws(DerivativeError) -> TreeTangent
}
