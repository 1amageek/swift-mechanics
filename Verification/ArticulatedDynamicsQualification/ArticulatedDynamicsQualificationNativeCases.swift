import SwiftMechanics

/// Native Task cancellation evidence is separate from the synchronous portable cases.
public enum ArticulatedDynamicsQualificationNativeCases {
    public static func taskCancellation() async throws {
        let input=try ArticulatedDynamicsQualificationFixtures.pendulum()
        let policy=try ArticulatedDynamicsQualificationFixtures.policy(1)
        let numericalBudget=try NumericalBudget(scalarStorage:100_000,arithmeticOperations:2_000_000,iterations:1000)
        let loadBudget=try LoadBudget(maximumWork:10000,maximumScalars:1000)
        let gate=AsyncStream<Void>.makeStream(bufferingPolicy:.bufferingNewest(1))
        defer { gate.continuation.finish() }
        let task=Task { () async -> (ArticulatedDynamicsFailure?,Int,Int) in
            for await _ in gate.stream { break }
            var work=NumericalWork(budget:numericalBudget), loads=LoadWork(budget:loadBudget)
            do throws(ArticulatedDynamicsFailure) {
                _=try ReferenceArticulatedDynamics().forward(input,driveForce:[0],policy:policy,loadWork:&loads,work:&work)
                return (nil,work.operations,loads.consumed)
            } catch {
                return (error,work.operations,loads.consumed)
            }
        }
        task.cancel()
        gate.continuation.yield(())
        let result=await task.value
        guard let failure=result.0 else { throw ArticulatedDynamicsQualificationError.unexpectedSuccess("cancelled Native Task query") }
        guard case .cancelled=failure.cause else { throw ArticulatedDynamicsQualificationError.unexpectedArticulatedFailure(failure) }
        try ArticulatedDynamicsQualificationCases.require(!failure.failedSupplierWorkUnavailable && result.1==0 && result.2==0,
            "actual cancelled Native Task must reach producer typed cancellation before any work/result")
    }
}
