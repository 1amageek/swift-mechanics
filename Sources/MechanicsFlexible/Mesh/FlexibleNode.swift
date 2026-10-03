import MechanicsCore
public struct FlexibleNode: Equatable, Sendable {
    public let identifier: UInt64
    public let referencePosition: Vector3
    public let boundaryGroup: UInt64?
    public init(identifier: UInt64, referencePosition: Vector3, boundaryGroup: UInt64? = nil) {
        self.identifier = identifier; self.referencePosition = referencePosition; self.boundaryGroup = boundaryGroup
    }
}
