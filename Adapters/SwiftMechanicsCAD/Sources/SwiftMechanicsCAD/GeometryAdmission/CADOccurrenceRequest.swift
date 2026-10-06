import CADCore
import CADIR
import SwiftMechanics

public struct CADOccurrenceRequest: Sendable {
    public let id: String
    public let sourceFeature: FeatureID
    public let body: EntityID
    public let frame: EntityID
    public let placement: RigidTransform
    public let material: Material

    public init(id: String, sourceFeature: FeatureID, body: EntityID, frame: EntityID,
                placement: RigidTransform, material: Material) {
        self.id = id
        self.sourceFeature = sourceFeature
        self.body = body
        self.frame = frame
        self.placement = placement
        self.material = material
    }
}
