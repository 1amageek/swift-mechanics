#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted scalar mathematics platform module is available.")
#endif

public struct AerodynamicPolarEvaluator: AerodynamicPolarEvaluating {
    public init() {}
    public func evaluate(_ law: AerodynamicPolarLaw, density: Double, body: EntityID, frame: EntityID,
                         point: Vector3, chordAxis: Vector3, spanAxis: Vector3, velocity: Vector3,
                         mediumVelocity: Vector3, work: inout LoadWork) throws(LoadError) -> AerodynamicPolarResponse {
        try work.charge(300); try work.reserve(scalars: 96)
        guard density.isFinite, density > 0 else { throw .invalidInput }
        let span = try core { () throws(CoreError) in try spanAxis.normalized() }
        let inputChord = try core { () throws(CoreError) in try chordAxis.normalized() }
        let basisDot = try core { () throws(CoreError) in try inputChord.dot(span) }
        guard abs(basisDot) <= law.maximumBasisDot else { throw .invalidInput }
        // Explicit section-frame definition: normalize the chord projected perpendicular to span.
        let chord = try core { () throws(CoreError) in try inputChord.subtracting(span.scaled(by: basisDot)).normalized() }
        let normal = try core { () throws(CoreError) in try span.cross(chord).normalized() }
        let relative = try core { () throws(CoreError) in try velocity.subtracting(mediumVelocity) }
        let speed = try core { () throws(CoreError) in try relative.magnitude() }
        let spanSpeed = try core { () throws(CoreError) in try relative.dot(span) }
        guard abs(spanSpeed) <= law.maximumSpanwiseFraction * speed else { throw .outsideDomain }
        let planar = try core { () throws(CoreError) in try relative.subtracting(span.scaled(by: spanSpeed)) }
        let planarSpeed = try core { () throws(CoreError) in try planar.magnitude() }
        guard planarSpeed >= law.minimumPlanarSpeed, planarSpeed <= law.maximumPlanarSpeed else { throw .outsideDomain }
        let x = try core { () throws(CoreError) in try planar.dot(chord) }
        let y = try core { () throws(CoreError) in try planar.dot(normal) }
        let angle = try finite(atan2(y, x))
        guard let first = law.samples.first, let last = law.samples.last,
              angle >= first.angle, angle <= last.angle else { throw .outsideDomain }
        var index = 1
        while index < law.samples.count - 1 {
            try work.charge(1)
            if angle <= law.samples[index].angle { break }; index += 1
        }
        try work.charge(1)
        let lower = law.samples[index-1], upper = law.samples[index]
        let width = try finite(upper.angle - lower.angle)
        let fraction = try finite((angle - lower.angle) / width)
        let cl = try finite((1-fraction) * lower.liftCoefficient + fraction * upper.liftCoefficient)
        let cd = try finite((1-fraction) * lower.dragCoefficient + fraction * upper.dragCoefficient)
        guard cd >= 0 else { throw .nonFiniteResult }
        let pressure = try finite(0.5 * density * planarSpeed * planarSpeed)
        let lift = try finite(pressure * law.area * cl), drag = try finite(pressure * law.area * cd)
        let flow = try core { () throws(CoreError) in try planar.normalized() }
        let liftDirection = try core { () throws(CoreError) in try span.cross(flow).normalized() }
        let force = try core { () throws(CoreError) in try flow.scaled(by: -drag).adding(liftDirection.scaled(by: lift)) }
        let loss = try finite(drag * planarSpeed)
        let mediumPower = try core { () throws(CoreError) in try force.dot(mediumVelocity) }
        // Lift is work-free in the admitted relative section flow; the whole medium force is dissipative in that frame.
        let load = try FramedPointLoad(body: body, frame: frame, point: point, forces: ForceParts(dissipative: force))
        try work.charge(0)
        return AerodynamicPolarResponse(load: load, angle: angle, liftCoefficient: cl, dragCoefficient: cd,
            dynamicPressure: pressure, relativeDissipatedPower: loss, prescribedMediumPower: mediumPower)
    }

    private func core<T>(_ operation: () throws(CoreError) -> T) throws(LoadError) -> T {
        do { return try operation() } catch { throw .core(error) }
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }; return value
    }
}
