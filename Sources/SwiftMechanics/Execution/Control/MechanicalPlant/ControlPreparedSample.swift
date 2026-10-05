internal final class ControlPreparedSample: Sendable {
    let response:ActuatorResponse
    let history:ControlHistory
    init(response:ActuatorResponse,history:ControlHistory) {
        self.response=response;self.history=history
    }
}
