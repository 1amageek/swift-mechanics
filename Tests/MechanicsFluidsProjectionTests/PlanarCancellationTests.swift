import SwiftMechanics
import Testing
struct PlanarCancellationTests {
    @Test func cancellationAfterActualPressureSolveCannotPublish() throws {
        if #available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*) {
            let owner=PlanarCancellationOwner(),policy=try PlanarFixtures.policy(cancel:{owner.read()})
            let old=try PlanarFixtures.vortex(PlanarFixtures.grid()),source=try PlanarFixtures.source()
            let solver:any PlanarFlowOperating=ReferencePlanarFlowSolver(linear:PlanarCancellingSolver(owner:owner))
            var work=try PlanarFixtures.work()
            PlanarFixtures.failure(.cancelled) { () throws(PlanarFluidError) in _=try solver.step(state:old,source:source,duration:0.01,policy:policy,work:&work) }
            #expect(work.operations > 1000);#expect(owner.read());#expect(old.time == 0);#expect(old.sequence == 0)
        } else { Issue.record("Cancellation proof requires Mutex availability.") }
    }
}
