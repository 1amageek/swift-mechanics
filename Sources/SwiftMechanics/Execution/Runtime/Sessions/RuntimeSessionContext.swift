
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class RuntimeSessionContext: Sendable {
    let model: CompiledMechanicalModel
    let configuration: RuntimeConfiguration
    let checkpoints: any RuntimeCheckpointHandling
    init(model: CompiledMechanicalModel, configuration: RuntimeConfiguration, checkpoints: any RuntimeCheckpointHandling) {
        self.model=model;self.configuration=configuration;self.checkpoints=checkpoints
    }
}
