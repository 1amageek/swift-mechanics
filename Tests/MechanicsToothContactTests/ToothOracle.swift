import Foundation

/// Scalar geometry and rigid-shaft equations; does not consume contact/dynamics reports.
enum ToothOracle {
    struct Pair {
        let centerA: [Double], centerB: [Double], pointA: [Double], pointB: [Double], normal: [Double]
        let separation: Double, force: Double, potential: Double, torques: [Double]
        let relative: [Double], slip: [Double]
    }
    static func pair(qa: Double, qb: Double, va: Double, vb: Double, za: Double = 0, zb: Double = 0, stiffness: Double = 10) -> Pair {
        let ya=0.25+0.4*za*za, yb = -0.25-0.2*zb*zb
        let ca=[cos(qa)-ya*sin(qa),sin(qa)+ya*cos(qa),za]
        let cb=[2-cos(qb)-yb*sin(qb),-sin(qb)+yb*cos(qb),zb]
        let delta=zip(cb,ca).map(-), distance=sqrt(delta.reduce(0){$0+$1*$1}), n=delta.map{$0/distance}
        let pA=zip(ca,n).map{$0+0.3*$1}, pB=zip(cb,n).map{$0-0.3*$1}
        let penetration=max(0,0.6-distance), force=stiffness*penetration
        let ta=pA[0]*(-force*n[1])-pA[1]*(-force*n[0])
        let tb=(pB[0]-2)*(force*n[1])-pB[1]*(force*n[0])
        let relative=[-vb*pB[1]+va*pA[1],vb*(pB[0]-2)-va*pA[0],0]
        let vn=zip(relative,n).reduce(0){$0+$1.0*$1.1}, slip=zip(relative,n).map{$0-vn*$1}
        return Pair(centerA:ca,centerB:cb,pointA:pA,pointB:pB,normal:n,separation:distance-0.6,force:force,
                    potential:0.5*stiffness*penetration*penetration,torques:[ta,tb],relative:relative,slip:slip)
    }
    static func distributedTorque(_ count: Int) -> Double {
        var sum=0.0
        for i in 0..<count { for j in 0..<count {
            let za = -0.05+(Double(i)+0.5)*0.1/Double(count), zb = -0.05+(Double(j)+0.5)*0.1/Double(count)
            sum += pair(qa:0,qb:0,va:0,vb:0,za:za,zb:zb,stiffness:10/Double(count*count)).torques[0]
        } }
        return sum
    }
    static func derivative(_ point: [Double]) -> [Double] {
        let p=pair(qa:point[0],qb:point[1],va:point[2],vb:point[3])
        return [point[2],point[3],-2+p.torques[0],-0.25+p.torques[1]]
    }
    static func integrated(to time: Double) -> [Double] {
        let steps=10_000, h=time/Double(steps)
        var y=[0.0,0.0,0.0,0.0]
        for _ in 0..<steps {
            let k1=derivative(y), k2=derivative(zip(y,k1).map{$0+h*0.5*$1})
            let k3=derivative(zip(y,k2).map{$0+h*0.5*$1}), k4=derivative(zip(y,k3).map{$0+h*$1})
            for i in y.indices { y[i] += h*(k1[i]+2*k2[i]+2*k3[i]+k4[i])/6 }
        }
        return y
    }
}
