import MechanicsCore
import MechanicsModel
public struct ContactBasis: Equatable, Sendable {
    public let frame: ModelReference
    public let contactToQuery: UnitQuaternion
    public let normal: Vector3
    public let firstTangent: Vector3
    public let secondTangent: Vector3
    public init(frame: ModelReference, contactToQuery: UnitQuaternion) throws(ContactLawError) {
        guard frame.id.kind == .frame else { throw .invalidIdentity }
        self.frame=frame; self.contactToQuery=contactToQuery
        normal=try contactCore { () throws(CoreError) in try contactToQuery.rotating(.unitZ) }
        firstTangent=try contactCore { () throws(CoreError) in try contactToQuery.rotating(.unitX) }
        secondTangent=try contactCore { () throws(CoreError) in try contactToQuery.rotating(.unitY) }
    }
}
