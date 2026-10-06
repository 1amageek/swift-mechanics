import SwiftMechanics
#if canImport(HeightfieldsQualificationSupport)
import HeightfieldsQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct HeightfieldsQualificationTests {
    @Test func originalFlatFaceEdgeVertexUnsignedAndTie() throws { try HeightfieldsQualificationCases.flatOriginalFeatures() }
    @Test func originalSlopedProjectionAndTransformBounds() throws { try HeightfieldsQualificationCases.slopeAndTransform() }
    @Test func actualDiagonalsTwoSidedCoplanarAndOrder() throws { try HeightfieldsQualificationCases.diagonalsAndRayOrder() }
    @Test func originalIntervalMissCapacityAndAmbiguity() throws { try HeightfieldsQualificationCases.rayRejectionsAndAmbiguity() }
    @Test func actualSphereBoundaryMarginAndFidelity() throws { try HeightfieldsQualificationCases.sphereClearanceAndQuality() }
    @Test func actualRefitSourceRevisionAndOriginalLifetime() throws { try HeightfieldsQualificationCases.refitOriginalLifetime() }
    @Test func actualAdmissionCapacityAndCapabilityRefusals() throws { try HeightfieldsQualificationCases.admissionAndResourceRefusals() }
    @Test func actualCancelledTaskRefusesPublicQueryPaths() async throws {
        var work = try HeightfieldsQualificationFixtures.work()
        let field = try HeightfieldsQualificationFixtures.field(motion:.deformingSnapshots,work:&work)
        let sphere = try HeightfieldsQualificationFixtures.proxy(center:.unitZ)
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try HeightfieldsQualificationCases.cancelledPaths(field:field,sphere:sphere)
        }
        try await task.value
    }
}
