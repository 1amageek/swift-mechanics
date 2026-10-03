import MechanicsCompiler

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct RuntimeOperationLease: Sendable {
    let ticket: UInt64
    let model: CompiledMechanicalModel
    let accepted: RuntimeAcceptedState
    let source: RuntimeCancellationSource
    var workspace: RuntimeTrial
}
