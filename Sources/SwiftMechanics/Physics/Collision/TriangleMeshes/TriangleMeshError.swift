public enum TriangleMeshError: Error, Equatable, Sendable {
    case collision(CollisionError)
    case invalidMesh
    case degenerateTriangle(faceID: UInt64)
    case nonmanifoldMesh
    case uncertifiedSolid
    case ambiguousRay(faceID: UInt64)
    case ambiguousSweep
    case unsupportedSweep
    case residualRejected(value: Double, threshold: Double)
    case nonConvergence(iterations: Int)
}
