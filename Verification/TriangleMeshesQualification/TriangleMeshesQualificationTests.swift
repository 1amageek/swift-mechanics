import SwiftMechanics
#if canImport(TriangleMeshesQualificationSupport)
import TriangleMeshesQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct TriangleMeshesQualificationTests {
    @Test func independentFaceEdgeVertexAndTransform() throws { try TriangleMeshesQualificationCases.manufacturedPointFeatures() }
    @Test func originalHierarchyNearestRayTiesMissAndBounds() throws { try TriangleMeshesQualificationCases.originalHierarchyRayAndBounds() }
    @Test func outwardTetrahedronSelectedSignedDomain() throws { try TriangleMeshesQualificationCases.selectedSignedTetrahedron() }
    @Test func refitPreservesOriginalSourceLifetime() throws { try TriangleMeshesQualificationCases.refitOriginalSnapshotLifetime() }
    @Test func actualOriginalSphereAdvanceAndMiss() throws { try TriangleMeshesQualificationCases.originalSphereAdvanceAndMiss() }
    @Test func exactWorkCapacityAndConsumedFailurePrefix() throws { try TriangleMeshesQualificationCases.exactWorkAndCapacity() }
    @Test func actualTypedGeometryAndAdmissionRefusals() throws { try TriangleMeshesQualificationCases.explicitGeometricAndAdmissionRefusals() }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let mesh = try TriangleMeshesQualificationFixture.triangle()
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try TriangleMeshesQualificationCases.cancelledTask(mesh: mesh)
        }
        try await task.value
    }
}
