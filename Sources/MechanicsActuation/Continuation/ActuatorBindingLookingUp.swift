public protocol ActuatorBindingLookingUp: Sendable {
    func binding(id:String,work:inout ActuationWork) throws(ActuationError) -> ActuatorBinding
}
