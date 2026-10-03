import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsJoints
import MechanicsLoads
import MechanicsNumerics
public protocol ActuationTransmitting: Sendable {
    func affine(_ transmission:AffineTransmission,model:ModelStamp,frame:EntityID,effort:Double,rate:[Double],tolerance:NumericalTolerance,
                work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> TransmissionResponse
    func tendon(_ route:CableRouteResponse,frame:EntityID,tension:Double,rate:[Double],tolerance:NumericalTolerance,
                work:inout ActuationWork,loads:inout LoadWork,numerical:inout NumericalWork) throws(ActuationError) -> TransmissionResponse
    func point(_ load:FramedPointLoad,jacobian:PointJacobian,rate:[Double],work:inout ActuationWork,loads:inout LoadWork) throws(ActuationError) -> GeneralizedLoad
}
