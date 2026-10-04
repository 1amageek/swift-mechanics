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

/// Independent scalar derivatives and chart coordinates, without production sampling.
struct TrajectoryProbeOracle: Sendable {
    let q: [Double]
    let v: [Double]
    let a: [Double]
    let coordinateRate: [Double]
    let angleIncrement: Double
    let angularRate: Double
    let angularAcceleration: Double

    @inline(never)
    init(harmonicAt time: Double) {
        let phase = 0.3+2*time
        let s = sin(phase), c = cos(phase), s0 = sin(0.3), c0 = cos(0.3)
        let ds = s-s0, dc = c-c0
        angleIncrement = 0.4*ds+0.2*dc
        angularRate = 2*(0.4*c-0.2*s)
        angularAcceleration = -4*(0.4*s+0.2*c)
        let px = 1+0.3*ds+0.1*dc, py = 2-0.2*ds+0.2*dc, pz = 3+0.1*ds-0.1*dc
        let vx = 2*(0.3*c-0.1*s), vy = 2*(-0.2*c-0.2*s), vz = 2*(0.1*c+0.1*s)
        let ax = -4*(0.3*s+0.1*c), ay = -4*(-0.2*s+0.2*c), az = -4*(0.1*s-0.1*c)
        let half = angleIncrement/2, ch = cos(half), sh = sin(half)
        let cr = cos(0.2), sr = sin(0.2)
        // Quaternion product Rz(delta) Rx(0.4), in w,x,y,z order.
        q = [px, py, pz, ch*cr, ch*sr, sh*sr, sh*cr]
        // R^-1 z = Rx(-0.4) z; no changing-axis transport term exists.
        v = [vx, vy, vz, 0, sin(0.4)*angularRate, cos(0.4)*angularRate]
        a = [ax, ay, az, 0, sin(0.4)*angularAcceleration, cos(0.4)*angularAcceleration]
        let halfRate = angularRate/2
        coordinateRate = [vx, vy, vz, -sh*cr*halfRate, -sh*sr*halfRate,
            ch*sr*halfRate, ch*cr*halfRate]
    }

    @inline(never)
    init(piecewiseAt time: Double) {
        let displacement: Double, rate: Double, acceleration: Double
        if time < 1 {
            displacement = time*time*time
            rate = 3*time*time
            acceleration = 6*time
        } else {
            // The following segment owns the exact knot; its cubic has a different jerk.
            let u = time-1
            displacement = 1+3*u+3*u*u+2*u*u*u
            rate = 3+6*u+6*u*u
            acceleration = 6+12*u
        }
        angleIncrement = displacement
        angularRate = rate
        angularAcceleration = acceleration
        q = [1, 2+0.125*displacement, 0.4+displacement]
        v = [0, 0.125*rate, rate]
        a = [0, 0.125*acceleration, acceleration]
        coordinateRate = v
    }
}
