internal enum PrescribedQuintic {
    static func value(_ p0:Double,_ p1:Double,_ v0:Double,_ v1:Double,_ a0:Double,_ a1:Double,
                      duration h:Double,fraction s:Double) throws(PrescribedMotionError) -> (Double,Double,Double) {
        let c0=p0,c1=h*v0,c2=0.5*h*h*a0
        let d=p1-c0-c1-c2,v=h*v1-c1-2*c2,a=h*h*a1-2*c2
        let c3=10*d-4*v+0.5*a,c4 = -15*d+7*v-a,c5=6*d-3*v+0.5*a
        let inverse=1/h
        let valueBound=abs(c0)+abs(c1)+abs(c2)+abs(c3)+abs(c4)+abs(c5)
        let rateBound=(abs(c1)+2*abs(c2)+3*abs(c3)+4*abs(c4)+5*abs(c5))*inverse
        let accelerationBound=(2*abs(c2)+6*abs(c3)+12*abs(c4)+20*abs(c5))*inverse*inverse
        guard s.isFinite,s >= 0,s <= 1,h.isFinite,h > 0,valueBound.isFinite,rateBound.isFinite,accelerationBound.isFinite else { throw .invalidInput }
        let position=(((((c5*s+c4)*s+c3)*s+c2)*s+c1)*s+c0)
        let rate=((((5*c5*s+4*c4)*s+3*c3)*s+2*c2)*s+c1)*inverse
        let acceleration=(((20*c5*s+12*c4)*s+6*c3)*s+2*c2)*inverse*inverse
        return (try PrescribedTrajectoryArithmetic.finite(position),try PrescribedTrajectoryArithmetic.finite(rate),try PrescribedTrajectoryArithmetic.finite(acceleration))
    }
}
