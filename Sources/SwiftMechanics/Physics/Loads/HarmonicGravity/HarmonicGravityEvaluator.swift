#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif

public struct HarmonicGravityEvaluator: HarmonicGravityEvaluating {
    public init() {}
    public func evaluate(_ law: HarmonicGravityLaw, body: EntityID, sample: GravitySample, velocity: Vector3,
                         time: Double, work: inout LoadWork) throws(LoadError) -> HarmonicGravityResponse {
        try work.charge(400); try work.reserve(scalars: 128)
        guard time.isFinite else { throw .invalidInput }
        let argument = try finite(law.angularFrequency * finite(time - law.timeOrigin) + law.phase)
        let c = try finite(cos(argument)), s = try finite(sin(argument))
        let dc = try finite(-law.angularFrequency*s), ds = try finite(law.angularFrequency*c)
        let a = try core { () throws(CoreError) in try law.constantAcceleration.adding(law.cosineAcceleration.scaled(by:c)).adding(law.sineAcceleration.scaled(by:s)) }
        let adot = try core { () throws(CoreError) in try law.cosineAcceleration.scaled(by:dc).adding(law.sineAcceleration.scaled(by:ds)) }
        let g = try core { () throws(CoreError) in try law.constantGradient.adding(law.cosineGradient.scaled(by:c)).adding(law.sineGradient.scaled(by:s)) }
        let gdot = try core { () throws(CoreError) in try law.cosineGradient.scaled(by:dc).adding(law.sineGradient.scaled(by:ds)) }
        let gx = try core { () throws(CoreError) in try g.applying(to:sample.point) }
        let force = try core { () throws(CoreError) in try a.adding(gx).scaled(by:sample.mass) }
        let potential = try finite(-sample.mass * core { () throws(CoreError) in try a.dot(sample.point) + sample.point.dot(gx)/2 })
        let explicit = try finite(-sample.mass * core { () throws(CoreError) in try adot.dot(sample.point) + sample.point.dot(gdot.applying(to:sample.point))/2 })
        let power = try core { () throws(CoreError) in try force.dot(velocity) }
        let rate = try finite(-power + explicit)
        let derivative = try core { () throws(CoreError) in try g.scaled(by:sample.mass) }
        let load = try FramedPointLoad(body:body,frame:law.frame,point:sample.point,forces:ForceParts(conservative:force),potentialEnergy:potential)
        try work.charge(0)
        return HarmonicGravityResponse(load:load,time:time,forcePositionDerivative:derivative,
            explicitPotentialTimeDerivative:explicit,mechanicalPower:power,potentialRate:rate)
    }

    private func core<T>(_ operation: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
}
