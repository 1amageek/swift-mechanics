import SwiftMechanics
import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepObservedDynamics: StationaryIslandComputing,Sendable {
    private let base=ReferenceStationaryIslandDynamics()
    private let counts=Mutex<[UInt64:Int]>([:])
    private let proofs=Mutex(0)
    private let hook=Mutex<(@Sendable () -> Void)?>(nil)
    func install(_ action:@escaping @Sendable () -> Void) { hook.withLock { $0=action } }
    func reset() { counts.withLock { $0=[:] };proofs.withLock { $0=0 } }
    func motionCount(_ id:UInt64) -> Int { counts.withLock { $0[id,default:0] } }
    var restCount:Int { proofs.withLock { $0 } }
    func motion(program:StationaryIslandProgram,islandID:UInt64,physical:KinematicState,work:inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandMotion {
        counts.withLock { $0[islandID,default:0] += 1 }
        let action=hook.withLock { let a=$0;$0=nil;return a };action?()
        return try base.motion(program:program,islandID:islandID,physical:physical,work:&work)
    }
    func certifyRest(program:StationaryIslandProgram,islandID:UInt64,physical:KinematicState,thresholds:MechanismSleepPolicy,work:inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandRestCertificate? { proofs.withLock { $0 += 1 };return try base.certifyRest(program:program,islandID:islandID,physical:physical,thresholds:thresholds,work:&work) }
    func associateRest(certificate:StationaryIslandRestCertificate,program:StationaryIslandProgram,physical:KinematicState,work:inout StationaryIslandWork) throws(StationaryIslandFailure) -> Bool { try base.associateRest(certificate:certificate,program:program,physical:physical,work:&work) }
}
