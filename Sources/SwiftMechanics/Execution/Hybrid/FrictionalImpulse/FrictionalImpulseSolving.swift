public protocol FrictionalImpulseSolving: Sendable {
    func solve(_ input: FrictionalImpulseInput, policy: FrictionalImpulsePolicy,
               work: inout NumericalWork, loadWork: inout LoadWork,
               contactWork: inout ContactWork) throws(FrictionalImpulseFailure) -> FrictionalImpulseResult
}
