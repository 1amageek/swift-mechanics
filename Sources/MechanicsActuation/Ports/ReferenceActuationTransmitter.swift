import MechanicsCore
import MechanicsModel
import MechanicsCompiler
import MechanicsJoints
import MechanicsLoads
import MechanicsNumerics
public struct ReferenceActuationTransmitter: ActuationTransmitting, Sendable {
    public let mapper:any LoadMapping
    public init(mapper:any LoadMapping) { self.mapper=mapper }
    public func affine(_ transmission:AffineTransmission,model:ModelStamp,frame:EntityID,effort:Double,rate:[Double],tolerance:NumericalTolerance,
                       work:inout ActuationWork,numerical:inout NumericalWork) throws(ActuationError) -> TransmissionResponse {
        try work.metadata(model.identity);try work.metadata(frame.key)
        guard transmission.model == model else { throw .staleBinding };guard transmission.frame == frame else { throw .frameMismatch }
        guard effort.isFinite,rate.count == transmission.gradient.count else { throw .invalidInput }
        try work.reserve(scalars:rate.count);try actuationNumerics { () throws(NumericalError) in try numerical.requireStorage(rate.count);try numerical.chargeOperations(try NumericalWork.product(rate.count,6)) }
        var result=[Double](repeating:0,count:rate.count),virtualRate=0.0,virtualPower=0.0
        for i in rate.indices {
            try work.charge(1);guard rate[i].isFinite else { throw .invalidInput }
            result[i]=try actuationFinite(effort*transmission.gradient[i]);virtualRate=try actuationFinite(virtualRate+transmission.gradient[i]*rate[i]);virtualPower=try actuationFinite(virtualPower+result[i]*rate[i])
        }
        let drift=try actuationFinite(effort*transmission.prescribedRate),actual=try actuationFinite(effort*(virtualRate+transmission.prescribedRate))
        let residual=try balance(virtualPower:virtualPower,drift:drift,actual:actual,tolerance:tolerance);try work.charge(0)
        return TransmissionResponse(efforts:result,virtualPower:virtualPower,prescribedPower:drift,actualPower:actual,balanceResidual:residual)
    }
    public func tendon(_ route:CableRouteResponse,frame:EntityID,tension:Double,rate:[Double],tolerance:NumericalTolerance,
                       work:inout ActuationWork,loads:inout LoadWork,numerical:inout NumericalWork) throws(ActuationError) -> TransmissionResponse {
        try work.metadata(frame.key);guard route.frame == frame else { throw .frameMismatch }
        guard tension.isFinite,tension >= 0,rate.count == route.coordinateGradient.count else { throw .invalidInput }
        try work.reserve(scalars:rate.count);try actuationNumerics { () throws(NumericalError) in try numerical.requireStorage(rate.count);try numerical.chargeOperations(try NumericalWork.product(rate.count,6)) }
        var original=0.0
        for i in rate.indices { try work.charge(1);guard rate[i].isFinite else { throw .invalidInput };original=try actuationFinite(original+route.coordinateGradient[i]*rate[i]) }
        let accepted:Bool
        do throws(CoreError) { accepted=try tolerance.contains(error:original-route.virtualLengthRate,scale:max(abs(original),abs(route.virtualLengthRate))) } catch { throw .core(error) }
        guard accepted else { throw .residualMismatch }
        let result:[Double],actualRate:Double
        do { result=try route.generalizedPull(tension:tension,work:&loads);actualRate=try route.actualLengthRate() } catch { throw .load(error) }
        var virtual=0.0
        for i in rate.indices { try work.charge(1);virtual=try actuationFinite(virtual+result[i]*rate[i]) }
        let drift=try actuationFinite(-tension*route.prescribedLengthRate),actual=try actuationFinite(-tension*actualRate)
        let residual=try balance(virtualPower:virtual,drift:drift,actual:actual,tolerance:tolerance);try work.charge(0)
        return TransmissionResponse(efforts:result,virtualPower:virtual,prescribedPower:drift,actualPower:actual,balanceResidual:residual)
    }
    public func point(_ load:FramedPointLoad,jacobian:PointJacobian,rate:[Double],work:inout ActuationWork,loads:inout LoadWork) throws(ActuationError) -> GeneralizedLoad {
        try work.reserve(scalars:rate.count);try work.charge(1)
        let result:GeneralizedLoad
        do throws(LoadError) { result=try mapper.point(load,jacobian:jacobian,rate:rate,work:&loads) } catch { throw .load(error) }
        try work.charge(0);return result
    }
    private func balance(virtualPower:Double,drift:Double,actual:Double,tolerance:NumericalTolerance) throws(ActuationError) -> Double {
        let residual=try actuationFinite(virtualPower+drift-actual)
        let accepted:Bool
        do throws(CoreError) { accepted=try tolerance.contains(error:residual,scale:max(abs(actual),max(abs(virtualPower),abs(drift)))) } catch { throw .core(error) }
        guard accepted else { throw .residualMismatch };return residual
    }
}
