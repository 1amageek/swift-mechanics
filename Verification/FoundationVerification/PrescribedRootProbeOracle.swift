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

/// Independent scalar rigid-body balance for the public root-only fixture.
struct PrescribedRootProbeOracle: Sendable {
    let effort: [Double]
    let kineticEnergy: Double
    let requiredPower: Double

    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
    init(_ fixture: PrescribedRootProbeModel, time: Double, inertiaScale: Double = 1) {
        let alpha = fixture.base.law.angularAcceleration
        let omega = 0.2+alpha*time
        let theta = 0.2*time+0.5*alpha*time*time
        let cr = cos(0.4), sr = sin(0.4)
        let c = cos(theta), s = sin(theta)
        let cx = fixture.center.x, cy = fixture.center.y, cz = fixture.center.z
        let rx: Double, ry: Double, rz: Double
        let izz: Double, iyz: Double
        if fixture.planar {
            let cp = cos(0.4+theta), sp = sin(0.4+theta)
            rx = cp*cx-sp*cy; ry = sp*cx+cp*cy; rz = 0
            izz = 5*inertiaScale; iyz = 0
        } else {
            let y0 = cr*cy-sr*cz, z0 = sr*cy+cr*cz
            rx = c*cx-s*y0; ry = s*cx+c*y0; rz = z0
            izz = (4*sr*sr+5*cr*cr)*inertiaScale
            iyz = -sr*cr*inertiaScale
        }
        let vx = 0.4+0.3*time, vy = -0.2+0.2*time
        let vz = fixture.planar ? 0 : 0.1-0.1*time
        let ax = 0.3-alpha*ry-omega*omega*rx
        let ay = 0.2+alpha*rx-omega*omega*ry
        let az = fixture.planar ? 0 : -0.1
        let fx = fixture.mass*ax, fy = fixture.mass*ay, fz = fixture.mass*az
        let tx = -alpha*s*iyz-omega*omega*c*iyz+ry*fz-rz*fy
        let ty = alpha*c*iyz-omega*omega*s*iyz+rz*fx-rx*fz
        let tz = alpha*izz+rx*fy-ry*fx
        if fixture.planar {
            effort = [fx, fy, tz]
        } else {
            // R = Rz(theta) Rx(0.4); floating-root angular coordinates use body axes.
            let x0 = c*tx+s*ty, y0 = -s*tx+c*ty
            effort = [fx, fy, fz, x0, cr*y0+sr*tz, -sr*y0+cr*tz]
        }
        let vcx = vx-omega*ry, vcy = vy+omega*rx
        kineticEnergy = 0.5*fixture.mass*(vcx*vcx+vcy*vcy+vz*vz)+0.5*omega*omega*izz
        requiredPower = fixture.mass*(vcx*ax+vcy*ay+vz*az)+omega*alpha*izz
    }
}
