import SwiftMechanics
#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("The verification profile must provide system scalar mathematics.")
#endif

/// Independent body Newton/Euler and energy equations, without production sampling or matrices.
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
struct TrajectoryEvolutionProbeOracle: Sendable {
    let q: [Double]
    let v: [Double]
    let baseAcceleration: [Double]
    let coordinateRate: [Double]
    let rootEffort: [Double]
    let dynamicAcceleration: Double?
    let kineticEnergy: Double
    let kineticEnergyRate: Double
    let rootPower: Double
    let drivePower: Double

    @inline(never)
    init(_ fixture: TrajectoryEvolutionProbeModel, time: Double,
         relativePosition: Double = 0, relativeVelocity: Double = 0) throws {
        guard time.isFinite, time >= 0, time <= 2, fixture.futureAngularOffset == 0,
              relativePosition.isFinite, relativeVelocity.isFinite else {
            throw FoundationVerificationError.analyticCheckFailed
        }
        let jets = fixture.piecewise ? TrajectoryProbeOracle(piecewiseAt: time) : TrajectoryProbeOracle(harmonicAt: time)
        let angle = (fixture.planar || fixture.piecewise ? 0.4 : 0) + jets.angleIncrement
        let c = cos(angle), s = sin(angle)
        let rotation: Matrix3
        let translationRate: Vector3, translationAcceleration: Vector3, omega: Vector3, alpha: Vector3
        let rootQ: [Double], rootV: [Double], rootA: [Double], rootQdot: [Double]
        if fixture.piecewise {
            rotation = try Matrix3(c, -s, 0, s, c, 0, 0, 0, 1)
            translationRate = try Vector3(jets.v[0], jets.v[1], 0)
            translationAcceleration = try Vector3(jets.a[0], jets.a[1], 0)
            omega = try Vector3(0, 0, jets.angularRate)
            alpha = try Vector3(0, 0, jets.angularAcceleration)
            if fixture.planar {
                rootQ = jets.q; rootV = jets.v; rootA = jets.a; rootQdot = jets.coordinateRate
            } else {
                let ch = cos(angle / 2), sh = sin(angle / 2), halfRate = jets.angularRate / 2
                rootQ = [jets.q[0], jets.q[1], 0, ch, 0, 0, sh]
                rootV = [translationRate.x, translationRate.y, 0, 0, 0, omega.z]
                rootA = [translationAcceleration.x, translationAcceleration.y, 0, 0, 0, alpha.z]
                rootQdot = [translationRate.x, translationRate.y, 0, -sh * halfRate, 0, 0, ch * halfRate]
            }
        } else if fixture.planar {
            rotation = try Matrix3(c, -s, 0, s, c, 0, 0, 0, 1)
            translationRate = try Vector3(jets.v[0], jets.v[1], 0)
            translationAcceleration = try Vector3(jets.a[0], jets.a[1], 0)
            omega = try Vector3(0, 0, jets.angularRate)
            alpha = try Vector3(0, 0, jets.angularAcceleration)
            rootQ = [jets.q[0], jets.q[1], angle]
            rootV = [translationRate.x, translationRate.y, omega.z]
            rootA = [translationAcceleration.x, translationAcceleration.y, alpha.z]
            rootQdot = rootV
        } else {
            let cr = cos(0.4), sr = sin(0.4)
            rotation = try Matrix3(c, -s * cr, s * sr, s, c * cr, -c * sr, 0, sr, cr)
            translationRate = try Vector3(jets.v[0], jets.v[1], jets.v[2])
            translationAcceleration = try Vector3(jets.a[0], jets.a[1], jets.a[2])
            omega = try Vector3(jets.v[3], jets.v[4], jets.v[5])
            alpha = try Vector3(jets.a[3], jets.a[4], jets.a[5])
            rootQ = jets.q; rootV = jets.v; rootA = jets.a; rootQdot = jets.coordinateRate
        }
        q = rootQ; v = rootV; baseAcceleration = rootA; coordinateRate = rootQdot
        let inverse = rotation.transposed()
        let originVelocity = try inverse.applying(to: translationRate)
        let originAcceleration = try inverse.applying(to: translationAcceleration)
        let rootVelocity = try originVelocity.adding(omega.cross(fixture.center))
        let rootAcceleration = try originAcceleration.adding(alpha.cross(fixture.center))
            .adding(omega.cross(omega.cross(fixture.center)))
        let rootForce = try rootAcceleration.scaled(by: fixture.mass)
        let inertiaOmega = try fixture.inertiaAtCenter.applying(to: omega)
        let inertiaAlpha = try fixture.inertiaAtCenter.applying(to: alpha)
        var totalForce = rootForce
        var totalTorque = try inertiaAlpha.adding(omega.cross(inertiaOmega)).adding(fixture.center.cross(rootForce))
        var energy = try 0.5 * fixture.mass * rootVelocity.dot(rootVelocity) + 0.5 * omega.dot(inertiaOmega)
        var rate = try fixture.mass * rootVelocity.dot(rootAcceleration) + omega.dot(inertiaAlpha)
        let childAcceleration: Double?
        if fixture.descendant {
            let d = try fixture.descendantCenter.adding(Vector3.unitY.scaled(by: relativePosition))
            let baseChildAcceleration = try originAcceleration.adding(alpha.cross(d)).adding(omega.cross(omega.cross(d)))
                .adding(omega.cross(Vector3.unitY).scaled(by: 2 * relativeVelocity))
            let qdd = fixture.descendantDrive / fixture.descendantMass - baseChildAcceleration.y
            childAcceleration = qdd
            let velocity = try originVelocity.adding(omega.cross(d)).adding(Vector3.unitY.scaled(by: relativeVelocity))
            let acceleration = try baseChildAcceleration.adding(Vector3.unitY.scaled(by: qdd))
            let force = try acceleration.scaled(by: fixture.descendantMass)
            let childIOmega = try fixture.descendantInertiaAtCenter.applying(to: omega)
            let childIAlpha = try fixture.descendantInertiaAtCenter.applying(to: alpha)
            totalForce = try totalForce.adding(force)
            totalTorque = try totalTorque.adding(childIAlpha).adding(omega.cross(childIOmega)).adding(d.cross(force))
            energy += try 0.5 * fixture.descendantMass * velocity.dot(velocity) + 0.5 * omega.dot(childIOmega)
            rate += try fixture.descendantMass * velocity.dot(acceleration) + omega.dot(childIAlpha)
        } else {
            childAcceleration = nil
        }
        let worldForce = try rotation.applying(to: totalForce)
        rootEffort = fixture.planar ? [worldForce.x, worldForce.y, totalTorque.z] :
            [worldForce.x, worldForce.y, worldForce.z, totalTorque.x, totalTorque.y, totalTorque.z]
        dynamicAcceleration = childAcceleration
        kineticEnergy = energy; kineticEnergyRate = rate
        rootPower = try worldForce.dot(translationRate) + totalTorque.dot(omega)
        drivePower = fixture.descendantDrive * relativeVelocity
    }
}
