@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class LoadedSleepStepContext: Sendable {
    let adapter:LoadedSleepMechanismEquation
    let execution:StationaryLoadExecution
    init(adapter:LoadedSleepMechanismEquation,execution:StationaryLoadExecution) { self.adapter=adapter;self.execution=execution }
}
