@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
internal final class SleepTopologySourceAuthority: Sendable {
    let source:RuntimeAcceptedState
    let release:SubtreeRelease
    let record:RuntimeContributorState
    let history:MechanismSleepHistory
    let cut:Int
    init(source:RuntimeAcceptedState,release:SubtreeRelease,record:RuntimeContributorState,history:MechanismSleepHistory,cut:Int) {
        self.source=source;self.release=release;self.record=record;self.history=history;self.cut=cut
    }
}
