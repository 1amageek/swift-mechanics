public protocol PhysicalParameterIdentifying: Sendable {
    func estimate(_ problem: PhysicalIdentificationProblem, policy: IdentificationPolicy,
                  workspace: inout IdentificationWorkspace, loadWork: inout LoadWork,
                  supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork) throws(ParameterIdentificationFailure) -> PhysicalParameterEstimate
}
