public struct ControlObservation: Sendable {
    public let accepted:RuntimeAcceptedState
    public let controller:ControlHistory
    public let actuator:ActuatorState
    internal init(accepted:RuntimeAcceptedState,controller:ControlHistory,actuator:ActuatorState) {
        self.accepted=accepted;self.controller=controller;self.actuator=actuator
    }
}
