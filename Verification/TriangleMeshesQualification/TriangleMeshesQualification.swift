#if canImport(TriangleMeshesQualificationSupport)
import TriangleMeshesQualificationSupport
#endif

@main
struct TriangleMeshesQualification {
    static func main() throws {
        try TriangleMeshesQualificationCases.manufacturedPointFeatures(); print("triangle:original-point-features:pass")
        try TriangleMeshesQualificationCases.originalHierarchyRayAndBounds(); print("triangle:hierarchy-ray-bounds:pass")
        try TriangleMeshesQualificationCases.selectedSignedTetrahedron(); print("triangle:tetrahedral-signed-domain:pass")
        try TriangleMeshesQualificationCases.refitOriginalSnapshotLifetime(); print("triangle:refit-source-lifetime:pass")
        try TriangleMeshesQualificationCases.originalSphereAdvanceAndMiss(); print("triangle:original-sphere-advance:pass")
        try TriangleMeshesQualificationCases.exactWorkAndCapacity(); print("triangle:exact-consumed-work:pass")
        try TriangleMeshesQualificationCases.explicitGeometricAndAdmissionRefusals(); print("triangle:typed-refusals:pass")
    }
}
