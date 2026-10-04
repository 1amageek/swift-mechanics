import CADCore
import CADIR
import SwiftMechanics

public struct CADOccurrence: Sendable {
    public let id: String
    public let sourceFeature: FeatureID
    public let sourceBody: BodyID
    public let body: EntityID
    public let frame: EntityID
    public let placement: RigidTransform
    public let material: Material
    public let density: Double

    init(request: CADOccurrenceRequest, sourceBody: BodyID, density: Double) {
        id = request.id
        sourceFeature = request.sourceFeature
        self.sourceBody = sourceBody
        body = request.body
        frame = request.frame
        placement = request.placement
        material = request.material
        self.density = density
    }
}
