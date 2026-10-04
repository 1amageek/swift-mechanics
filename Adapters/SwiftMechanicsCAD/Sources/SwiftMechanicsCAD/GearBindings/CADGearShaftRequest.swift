import SwiftMechanics

public struct CADGearShaftRequest: Sendable {
    public let occurrenceID: String
    public let joint: EntityID
    public let endFace: CADAnchorReference
    public let mountingPhase: Double
    public init(occurrenceID: String, joint: EntityID, endFace: CADAnchorReference,
                mountingPhase: Double) throws(CADGearBindingError) {
        guard !occurrenceID.isEmpty, joint.kind == .joint, mountingPhase.isFinite else { throw .invalidInput }
        self.occurrenceID = occurrenceID; self.joint = joint
        self.endFace = endFace; self.mountingPhase = mountingPhase
    }
}
