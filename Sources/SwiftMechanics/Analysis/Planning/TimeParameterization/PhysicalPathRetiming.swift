public protocol PhysicalPathRetiming: Sendable {
    func parameterize(_ request: RetimingRequest, policy: RetimingPolicy,
                      loadWork: inout LoadWork, work: inout NumericalWork) throws(RetimingError) -> RetimedPath
    func sample(_ path: RetimedPath, query: RetimingQuery,
                loadWork: inout LoadWork, work: inout NumericalWork) throws(RetimingError) -> RetimingSample
}
