public protocol GeometryParameterDifferentiating: Sendable {
    func direction(_ source: GeometryParameterSource, direction: [Double], policy: GeometryParameterPolicy,
                   supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork) throws(GeometryParameterError) -> GeometryParameterProduct
}
