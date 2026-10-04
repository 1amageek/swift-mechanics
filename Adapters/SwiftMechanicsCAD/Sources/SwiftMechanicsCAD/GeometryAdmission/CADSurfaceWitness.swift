import CADKernel
import SwiftMechanics

public struct CADSurfaceWitness: Sendable {
    public let anchor: CADAnchorReference
    public let occurrence: CADOccurrence
    public let original: SurfaceOutwardFrame
    public let localPoint: Vector3
    public let localOutwardNormal: Vector3
    public let worldPoint: Vector3
    public let worldOutwardNormal: Vector3
}
