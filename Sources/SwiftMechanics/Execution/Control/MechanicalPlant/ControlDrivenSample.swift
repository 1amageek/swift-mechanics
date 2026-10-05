internal final class ControlDrivenSample: Sendable {
    let sample:ControlPreparationSample
    let system:RigidDynamicsSystem
    let response:ActuatorResponse
    init(sample:ControlPreparationSample,system:RigidDynamicsSystem,response:ActuatorResponse) {
        self.sample=sample;self.system=system;self.response=response
    }
}
