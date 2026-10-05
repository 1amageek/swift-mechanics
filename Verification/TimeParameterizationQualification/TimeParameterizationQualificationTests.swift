import SwiftMechanics
import Testing
#if canImport(TimeParameterizationQualificationSupport)
import TimeParameterizationQualificationSupport
#endif

@Suite struct TimeParameterizationQualificationTests {
    @Test(.timeLimit(.minutes(1))) func originalCoupledPhysicalTree() throws {
        try TimeParameterizationQualificationCases.originalCoupledPhysicalTree()
    }
    @Test(.timeLimit(.minutes(1))) func originalAnalyticDurationAndSignedExtrema() throws {
        try TimeParameterizationQualificationCases.originalAnalyticDurationAndSignedExtrema()
    }
    @Test(.timeLimit(.minutes(1))) func originalWaypointsClockAndIdentity() throws {
        try TimeParameterizationQualificationCases.originalWaypointsClockAndIdentity()
    }
    @Test(.timeLimit(.minutes(1))) func originalStaticAndSignedMotionInfeasibility() throws {
        try TimeParameterizationQualificationCases.originalStaticAndSignedMotionInfeasibility()
    }
    @Test(.timeLimit(.minutes(1))) func originalDomainsShapesAndRevisions() throws {
        try TimeParameterizationQualificationCases.originalDomainsShapesAndRevisions()
    }
    @Test(.timeLimit(.minutes(1))) func originalWorkCapacityAndCancellation() throws {
        try TimeParameterizationQualificationCases.originalWorkCapacityAndCancellation()
    }
    @Test(.timeLimit(.minutes(1))) func originalArithmeticAndDurationFailures() throws {
        try TimeParameterizationQualificationCases.originalArithmeticAndDurationFailures()
    }
    @Test(.timeLimit(.minutes(1))) func actualAwaitedNativeTaskCancellation() async throws {
        let source = try TimeParameterizationQualificationFixtures.single()
        let limit = try TimeParameterizationQualificationFixtures.limit()
        let path = try TimeParameterizationQualificationFixtures.parameterize(
            TimeParameterizationQualificationFixtures.request(source, points: [[0], [1]], limits: [limit]))
        let task = Task { () throws -> Void in
            while !Task.isCancelled { await Task.yield() }
            try TimeParameterizationQualificationCases.actualNativeCancellation(path: path)
        }
        task.cancel()
        try await task.value
    }
}
