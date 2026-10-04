import Foundation
import SwiftMechanics

internal struct TrajectoryAnchorOracle {
    let displacement:[Double]
    let velocity:[Double]
    let acceleration:[Double]
    let angle:Double
    let rate:Double
    let second:Double
    init(_ t:Double,piecewise:Bool) {
        let h=max(0,t-1),u=[0.6,0.1,0.0],c=[0.3,-0.1,0.0],j=[0.12,0.06,0.0]
        if piecewise {
            displacement=(0..<3).map { u[$0]*t+c[$0]*t*t/2+j[$0]*t*t*t/6-($0 == 0 ? 0.02*h*h*h/6 : 0) }
            velocity=(0..<3).map { u[$0]+c[$0]*t+j[$0]*t*t/2-($0 == 0 ? 0.02*h*h/2 : 0) }
            acceleration=(0..<3).map { c[$0]+j[$0]*t-($0 == 0 ? 0.02*h : 0) }
            angle=0.4*t+0.1*t*t+0.06*t*t*t/6-0.04*h*h*h/6
            rate=0.4+0.2*t+0.06*t*t/2-0.04*h*h/2;second=0.2+0.06*t-0.04*h
        } else {
            displacement=(0..<3).map { u[$0]*sin(t)+c[$0]*(1-cos(t)) }
            velocity=(0..<3).map { u[$0]*cos(t)+c[$0]*sin(t) }
            acceleration=(0..<3).map { -u[$0]*sin(t)+c[$0]*cos(t) }
            angle=0.4*sin(t)+0.2*(1-cos(t));rate=0.4*cos(t)+0.2*sin(t);second = -0.4*sin(t)+0.2*cos(t)
        }
    }
    func jet() throws -> PrescribedMotionJet {
        try PrescribedMotionJet(displacement:Vector3(displacement[0],displacement[1],displacement[2]),angle:angle,
            linearVelocity:Vector3(velocity[0],velocity[1],velocity[2]),angularRate:rate,
            linearAcceleration:Vector3(acceleration[0],acceleration[1],acceleration[2]),angularAcceleration:second)
    }
}
