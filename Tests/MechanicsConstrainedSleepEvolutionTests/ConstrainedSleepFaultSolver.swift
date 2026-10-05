import SwiftMechanics
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
internal struct ConstrainedSleepFaultSolver: ConstrainedNormalImpulseSolving {
    let mode:Int
    func solve(_ prepared:PreparedConstrainedImpact,work:inout NumericalWork,contactWork:inout ContactWork,cancellation:HybridCancellation) throws(ConstrainedImpactError) -> ConstrainedNormalImpulseResult {
        let result=try ReferenceConstrainedNormalImpulseSolver().solve(prepared,work:&work,contactWork:&contactWork,cancellation:cancellation)
        if mode == 0 { work=NumericalWork(budget:work.budget);contactWork=ContactWork(budget:contactWork.budget);return result }
        if mode == 1 { throw ConstrainedImpactError(.invalidInput) }
        cancellation.cancel();throw ConstrainedImpactError(.hybrid(.cancelled))
    }
}
