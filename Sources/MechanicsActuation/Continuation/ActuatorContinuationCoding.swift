import MechanicsRuntime
public protocol ActuatorContinuationCoding: Sendable {
    func encodedSize(binding:ActuatorBinding,work:inout ActuationWork) throws(ActuationError) -> Int
    func encode(_ state:ActuatorState,work:inout ActuationWork) throws(ActuationError) -> RuntimeContributorState
    func decode(_ record:RuntimeContributorState,binding:ActuatorBinding,work:inout ActuationWork) throws(ActuationError) -> ActuatorState
}
