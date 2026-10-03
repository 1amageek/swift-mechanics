import MechanicsCore
import MechanicsModel
import MechanicsContactLaws
internal enum GranularContactTransport {
    static func basis(normal: Vector3, previous: ContactBasis?, frame: ModelReference, policy: GranularPolicy) throws(GranularError) -> ContactBasis {
        let source=previous?.normal ?? .unitZ
        let c=try GranularArithmetic.dot(source,normal)
        let cross=try GranularArithmetic.cross(source,normal)
        let rotation: UnitQuaternion
        if previous != nil && c <= policy.minimumTransportDot {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Transport outside the caller normal-angle admission requires a path branch.
            throw .unsupportedDomain
        }
        if c <= -1 {
            if previous == nil { rotation=try GranularArithmetic.core { () throws(CoreError) in try UnitQuaternion(w:0,x:1,y:0,z:0) } }
            else {
                // FIXME(INCOMPLETE_IMPLEMENTATION): An antipodal normal has no unique shortest tangent transport.
                // Current persistent-contact callers must fail until a declared path/tangent branch resolves it.
                throw .unsupportedDomain
            }
        } else { rotation=try GranularArithmetic.core { () throws(CoreError) in try UnitQuaternion(w:1+c,x:cross.x,y:cross.y,z:cross.z) } }
        let q=try GranularArithmetic.core { () throws(CoreError) in try rotation.multiplied(by:previous?.contactToQuery ?? .identity) }
        do { return try ContactBasis(frame:frame,contactToQuery:q) } catch { throw .contact(error,failedSupplierWorkUnavailable:false) }
    }
}
