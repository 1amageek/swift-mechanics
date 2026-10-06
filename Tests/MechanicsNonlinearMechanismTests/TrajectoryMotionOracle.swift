import Foundation
import SwiftMechanics

/// Independent scalar jets and Newton-Euler equations, not supplier diagnostics.
internal struct TrajectoryMotionOracle {
    let displacement:[Double]
    let velocity:[Double]
    let acceleration:[Double]
    let angle:Double
    let rate:Double
    let second:Double
    init(time t:Double,planar:Bool,piecewise:Bool,futureChange:Double=0) {
        let u=[0.4,-0.2,planar ? 0 : 0.1],c=[0.3,0.2,planar ? 0 : -0.1],j=[0.1,0.05,planar ? 0 : -0.02]
        if piecewise {
            let h=max(0,t-1),delta = -0.04+futureChange
            displacement=(0..<3).map { u[$0]*t+c[$0]*t*t/2+j[$0]*t*t*t/6+($0 == 0 ? delta*h*h*h/6 : 0) }
            velocity=(0..<3).map { u[$0]+c[$0]*t+j[$0]*t*t/2+($0 == 0 ? delta*h*h/2 : 0) }
            acceleration=(0..<3).map { c[$0]+j[$0]*t+($0 == 0 ? delta*h : 0) }
            angle=0.2*t+0.15*t*t+0.12*t*t*t/6-0.06*h*h*h/6
            rate=0.2+0.3*t+0.12*t*t/2-0.06*h*h/2
            second=0.3+0.12*t-0.06*h
        } else {
            displacement=(0..<3).map { u[$0]*sin(t)+c[$0]*(1-cos(t)) }
            velocity=(0..<3).map { u[$0]*cos(t)+c[$0]*sin(t) }
            acceleration=(0..<3).map { -u[$0]*sin(t)+c[$0]*cos(t) }
            angle=0.2*sin(t)+0.3*(1-cos(t));rate=0.2*cos(t)+0.3*sin(t);second = -0.2*sin(t)+0.3*cos(t)
        }
    }
    func jet() throws -> PrescribedMotionJet {
        try PrescribedMotionJet(displacement:Vector3(displacement[0],displacement[1],displacement[2]),angle:angle,
            linearVelocity:Vector3(velocity[0],velocity[1],velocity[2]),angularRate:rate,
            linearAcceleration:Vector3(acceleration[0],acceleration[1],acceleration[2]),angularAcceleration:second)
    }
    func physical(planar:Bool) -> (effort:[Double],kinetic:Double,power:Double) {
        let c=cos(0.4),s=sin(0.4),theta=planar ? angle+0.4 : angle,w=rate,alpha=second
        let rx=0.4,ry=planar ? -0.3 : -0.3*c-0.2*s,rz=planar ? 0 : -0.3*s+0.2*c
        let x=cos(theta)*rx-sin(theta)*ry,y=sin(theta)*rx+cos(theta)*ry
        let vx=velocity[0]-w*y,vy=velocity[1]+w*x,vz=velocity[2]
        let f=[2*(acceleration[0]-alpha*y-w*w*x),2*(acceleration[1]+alpha*x-w*w*y),2*acceleration[2]]
        if planar {
            return ([f[0],f[1],5*alpha+x*f[1]-y*f[0]],vx*vx+vy*vy+2.5*w*w,f[0]*vx+f[1]*vy+5*w*alpha)
        }
        let cross=[y*f[2]-rz*f[1],rz*f[0]-x*f[2],x*f[1]-y*f[0]]
        let tx=cos(angle)*cross[0]+sin(angle)*cross[1],ty = -sin(angle)*cross[0]+cos(angle)*cross[1]
        let torque=[tx+s*c*w*w,c*ty+s*cross[2]+4*s*alpha,-s*ty+c*cross[2]+5*c*alpha]
        return (f+torque,vx*vx+vy*vy+vz*vz+0.5*(4*s*s+5*c*c)*w*w,
                f[0]*vx+f[1]*vy+f[2]*vz+(4*s*s+5*c*c)*w*alpha)
    }
}
