public protocol LinearEstimatorContinuationCoding: Sendable {
    func schema(model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                work: inout NumericalWork) throws(LinearEstimatorFailure) -> RuntimeContributorSchema
    func record(_ state: LinearEstimatorState, policy: LinearEstimatorPolicy,
                work: inout NumericalWork) throws(LinearEstimatorFailure) -> RuntimeContributorState
    func restore(_ record: RuntimeContributorState, model: LinearEstimatorModel, policy: LinearEstimatorPolicy,
                 work: inout NumericalWork) throws(LinearEstimatorFailure) -> LinearEstimatorState
}
