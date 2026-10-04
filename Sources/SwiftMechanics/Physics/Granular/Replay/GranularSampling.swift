public protocol GranularSampling: Sendable {
    func sample(count: Int, templates: [GranularDistributionTemplate], random: RuntimeRandomState, policy: GranularPolicy,
        numericalWork: inout NumericalWork, supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularDistributionResult
}
