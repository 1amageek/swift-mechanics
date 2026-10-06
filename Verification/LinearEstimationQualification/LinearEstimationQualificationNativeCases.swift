import SwiftMechanics

public enum LinearEstimationQualificationNativeCases {
    public static func cancelledTaskRetainsOriginalPrefix() async throws {
        let initial = try LinearEstimationQualificationFixtures.initial(LinearEstimationQualificationFixtures.model())
        let policy = try LinearEstimationQualificationFixtures.policy()
        let child = Task { () throws -> Void in
            var work = try LinearEstimationQualificationFixtures.work()
            try work.chargeOperations(7)
            let before = work
            withUnsafeCurrentTask { task in task?.cancel() }
            try LinearEstimationQualificationFixtures.require(Task.isCancelled,"Native child must actually be cancelled")
            let service: any LinearEstimating = ReferenceLinearEstimator()
            let failure = try LinearEstimationQualificationFixtures.failure { () throws(LinearEstimatorFailure) in
                _ = try service.predict(initial,input:LinearEstimationQualificationFixtures.input(initial),policy:policy,work:&work)
            }
            try LinearEstimationQualificationFixtures.prefix(failure,initial,work:work,cause:.cancelled)
            try LinearEstimationQualificationFixtures.require(work==before,"Actual Native cancellation preserves seeded caller ledger")
        }
        try await child.value
    }
}
