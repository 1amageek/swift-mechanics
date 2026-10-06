import SwiftMechanics
import Synchronization
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal final class IslandSleepFaultDynamics: StationaryIslandComputing,Sendable {
    let mode:Int
    let token:HybridCancellation
    private let active=Mutex(false)
    private let base=ReferenceStationaryIslandDynamics()
    init(mode:Int,token:HybridCancellation) { self.mode=mode;self.token=token }
    func enable() { active.withLock { $0=true } }
    func motion(program:StationaryIslandProgram,islandID:UInt64,physical:KinematicState,work:inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandMotion {
        guard active.withLock({$0}) else { return try base.motion(program:program,islandID:islandID,physical:physical,work:&work) }
        if mode == 1 {
            do throws(StationaryIslandFailure) { return try base.motion(program:program,islandID:UInt64.max,physical:physical,work:&work) }
            catch { work.numerical=NumericalWork(budget:work.numerical.budget);work.loads=LoadWork(budget:work.loads.budget);throw error }
        }
        let actual=try base.motion(program:program,islandID:islandID,physical:physical,work:&work)
        if mode == 2 { token.cancel();return try base.motion(program:program,islandID:islandID,physical:physical,work:&work) }
        work.numerical=NumericalWork(budget:work.numerical.budget);work.loads=LoadWork(budget:work.loads.budget);return actual
    }
    func certifyRest(program:StationaryIslandProgram,islandID:UInt64,physical:KinematicState,thresholds:MechanismSleepPolicy,work:inout StationaryIslandWork) throws(StationaryIslandFailure) -> StationaryIslandRestCertificate? { try base.certifyRest(program:program,islandID:islandID,physical:physical,thresholds:thresholds,work:&work) }
    func associateRest(certificate:StationaryIslandRestCertificate,program:StationaryIslandProgram,physical:KinematicState,work:inout StationaryIslandWork) throws(StationaryIslandFailure) -> Bool { try base.associateRest(certificate:certificate,program:program,physical:physical,work:&work) }
}
