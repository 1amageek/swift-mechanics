import SwiftMechanics
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class ConstrainedSleepFaultSession: RuntimeSessionOperating, Sendable {
    let base:any RuntimeSessionOperating
    let schema:RuntimeContributorSchema
    let reject:Bool
    init(base:any RuntimeSessionOperating,schema:RuntimeContributorSchema,reject:Bool) { self.base=base;self.schema=schema;self.reject=reject }
    func snapshot() -> RuntimeAcceptedState { base.snapshot() }
    func profile() -> RuntimeProfile { base.profile() }
    func performTrial(_ operation:@Sendable (inout RuntimeTrial,inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision) throws(RuntimeFailure) -> RuntimeTrialOutcome {
        try base.performTrial { (trial:inout RuntimeTrial,control:inout RuntimeStepControl) throws(RuntimeFailure) -> RuntimeTrialDecision in
            _=try operation(&trial,&control)
            if reject { return .reject }
            let original=try trial.contributor(schema.id)
            var bytes=original.bytes;bytes[0] ^= 1
            try trial.replaceContributor(RuntimeContributorState(id:original.id,category:original.category,version:original.version,bytes:bytes));return .accept
        }
    }
    func observe(_ operation:@Sendable (RuntimeAcceptedState) throws(RuntimeFailure) -> Void) throws(RuntimeFailure) { try base.observe(operation) }
    func restart(_ bytes:[UInt8],codec:any RuntimeCheckpointCoding) throws(RuntimeFailure) -> RuntimeAcceptedState { try base.restart(bytes,codec:codec) }
    func checkpoint(codec:any RuntimeCheckpointCoding) throws(RuntimeFailure) -> [UInt8] { try base.checkpoint(codec:codec) }
    func cancel() { base.cancel() }
    func shutdown() -> RuntimeShutdownStatus { base.shutdown() }
    func shutdownStatus() -> RuntimeShutdownStatus? { base.shutdownStatus() }
}
