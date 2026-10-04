import Foundation

/// Independent scalar Newton-Euler oracle; it does not consume tree columns or kernel diagnostics.
internal struct PrescribedRootOracle {
    let force:[Double]
    let effort:[Double]
    let kinetic:Double
    let power:Double
    init(planar:Bool,time:Double) {
        let t=time,w=0.2+0.3*t,alpha=0.3,theta=0.2*t+0.15*t*t
        let c=cos(0.4),s=sin(0.4),angle=planar ? theta+0.4 : theta
        let rx=0.4,ry=planar ? -0.3 : -0.3*c-0.2*s,rz=planar ? 0 : -0.3*s+0.2*c
        let x=cos(angle)*rx-sin(angle)*ry,y=sin(angle)*rx+cos(angle)*ry
        let vx=0.4+0.3*t-w*y,vy = -0.2+0.2*t+w*x,vz=planar ? 0 : 0.1-0.1*t
        let ax=0.3-alpha*y-w*w*x,ay=0.2+alpha*x-w*w*y,az=planar ? 0 : -0.1
        let f=[2*ax,2*ay,2*az]
        force=f
        if planar {
            effort=[f[0],f[1],5*alpha+x*f[1]-y*f[0]]
            kinetic=vx*vx+vy*vy+2.5*w*w
            power=f[0]*vx+f[1]*vy+5*w*alpha
        } else {
            let worldCross=[y*f[2]-rz*f[1],rz*f[0]-x*f[2],x*f[1]-y*f[0]]
            let tx=cos(theta)*worldCross[0]+sin(theta)*worldCross[1]
            let ty = -sin(theta)*worldCross[0]+cos(theta)*worldCross[1]
            let bodyCross=[tx,c*ty+s*worldCross[2],-s*ty+c*worldCross[2]]
            let gyroscope=s*c*w*w*(5-4)
            effort=f+[bodyCross[0]+gyroscope,bodyCross[1]+4*s*alpha,bodyCross[2]+5*c*alpha]
            kinetic=vx*vx+vy*vy+vz*vz+0.5*(4*s*s+5*c*c)*w*w
            power=f[0]*vx+f[1]*vy+f[2]*vz+(4*s*s+5*c*c)*w*alpha
        }
    }
    static func rotorKinetic(time:Double,relativeVelocity:Double) -> Double {
        let vx=0.4+0.3*time,vy = -0.2+0.2*time,vz=0.1-0.1*time,w=0.2+0.3*time
        return 2*(vx*vx+vy*vy+vz*vz)+w*w+2.5*(w+relativeVelocity)*(w+relativeVelocity)
    }
}
