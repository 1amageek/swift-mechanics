import SwiftMechanics
import Synchronization

@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class SleepTopologyPassThroughHandler: RuntimeCheckpointHandling, Sendable {
    private let accepted:RuntimeAcceptedState
    private let count=Mutex(0)
    init(_ accepted:RuntimeAcceptedState) { self.accepted=accepted }
    func calls() -> Int { count.withLock {$0} }
    func admit(_ checkpoint:RuntimeCheckpoint,model:CompiledMechanicalModel,configuration:RuntimeConfiguration,cancellation:RuntimeCancellationSource?) throws(RuntimeFailure) -> RuntimeAcceptedState {
        count.withLock {$0 += 1};return accepted
    }
    func migrate(_ checkpoint:RuntimeCheckpoint,from source:CompiledMechanicalModel,to target:CompiledMechanicalModel,using transition:ModelTransition,configuration:RuntimeConfiguration) throws(RuntimeFailure) -> RuntimeCheckpoint {
        throw RuntimeFailure(.incompatibleMigration,message:"Test context does not migrate.")
    }
}
