public protocol CustomLoadEvaluating: Sendable {
    func evaluate(_ provider: any CustomLoadProvider, state: CustomLoadState, coordinate: Double,
                  rate: Double, policy: CustomLoadPolicy, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
