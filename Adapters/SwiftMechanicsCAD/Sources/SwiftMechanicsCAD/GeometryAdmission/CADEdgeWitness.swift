import CADKernel
import SwiftMechanics

public struct CADEdgeWitness: Sendable {
    public let anchor: CADAnchorReference
    public let occurrence: CADOccurrence
    public let original: EdgeQueryFrame
    public let localPoint: Vector3
    public let localTangent: Vector3
    public let worldPoint: Vector3
    public let worldTangent: Vector3
}
