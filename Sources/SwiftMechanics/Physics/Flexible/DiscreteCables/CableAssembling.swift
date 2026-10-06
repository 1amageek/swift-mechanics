public protocol CableAssembling: Sendable {
    func assemble(_ cable: DiscreteCable, state: NodalState, derivativeOrder: CableDerivativeOrder,
                  policy: CablePolicy, work: inout NumericalWork) throws(CableError) -> CableAssembly
}
