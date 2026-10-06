public protocol TaskSpaceControlling: Sendable {
    func evaluate(_ request: TaskSpaceRequest, policy: TaskSpacePolicy,
                  work: inout NumericalWork) throws(TaskSpaceFailure) -> TaskSpaceResult
}
