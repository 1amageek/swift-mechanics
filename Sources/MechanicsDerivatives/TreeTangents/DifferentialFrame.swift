import MechanicsCore
import MechanicsJoints
import MechanicsNumerics
internal struct DifferentialFrame: Sendable {
    let rotation: DifferentialMatrix
    let translation: DifferentialVector
    let velocity: DifferentialMotion
    let acceleration: DifferentialMotion
    init(rotation: DifferentialMatrix = .identity, translation: DifferentialVector = .zero,
         velocity: DifferentialMotion = .zero, acceleration: DifferentialMotion = .zero) {
        self.rotation=rotation; self.translation=translation; self.velocity=velocity; self.acceleration=acceleration
    }
    static let identity = DifferentialFrame()
    static func sample(_ motion: FrameMotion, _ direction: FrameMotionDirection, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        DifferentialFrame(rotation:try DifferentialArithmetic.rotation(motion.pose.rotation,tangent:direction.rotationTangent,&w),
            translation:DifferentialVector(motion.pose.translation,direction.translation),
            velocity:DifferentialMotion(DifferentialVector(motion.velocity.angular,direction.angularVelocity),DifferentialVector(motion.velocity.linear,direction.linearVelocity)),
            acceleration:DifferentialMotion(DifferentialVector(motion.acceleration.angular,direction.angularAcceleration),DifferentialVector(motion.acceleration.linear,direction.linearAcceleration)))
    }
    static func compose(_ p: DifferentialFrame, _ r: DifferentialFrame, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        let offset=try DifferentialArithmetic.apply(p.rotation,r.translation,&w)
        let rw=try DifferentialArithmetic.apply(p.rotation,r.velocity.angular,&w), rv=try DifferentialArithmetic.apply(p.rotation,r.velocity.linear,&w)
        let rotation=try DifferentialArithmetic.multiply(p.rotation,r.rotation,&w), translation=try DifferentialArithmetic.add(p.translation,offset,&w)
        let omega=try DifferentialArithmetic.add(p.velocity.angular,rw,&w)
        let vel=try DifferentialArithmetic.add(DifferentialArithmetic.add(p.velocity.linear,DifferentialArithmetic.cross(p.velocity.angular,offset,&w),&w),rv,&w)
        let alpha=try DifferentialArithmetic.add(DifferentialArithmetic.add(p.acceleration.angular,DifferentialArithmetic.apply(p.rotation,r.acceleration.angular,&w),&w),DifferentialArithmetic.cross(p.velocity.angular,rw,&w),&w)
        var acc=try DifferentialArithmetic.add(p.acceleration.linear,DifferentialArithmetic.cross(p.acceleration.angular,offset,&w),&w)
        acc=try DifferentialArithmetic.add(acc,DifferentialArithmetic.cross(p.velocity.angular,DifferentialArithmetic.cross(p.velocity.angular,offset,&w),&w),&w)
        acc=try DifferentialArithmetic.add(acc,DifferentialArithmetic.scale(DifferentialArithmetic.cross(p.velocity.angular,rv,&w),DifferentialArithmetic.scalar(2),&w),&w)
        acc=try DifferentialArithmetic.add(acc,DifferentialArithmetic.apply(p.rotation,r.acceleration.linear,&w),&w)
        return DifferentialFrame(rotation:rotation,translation:translation,velocity:DifferentialMotion(omega,vel),acceleration:DifferentialMotion(alpha,acc))
    }
    static func inverse(_ f: DifferentialFrame, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialFrame {
        let rt=DifferentialArithmetic.transpose(f.rotation), minus=try DifferentialArithmetic.scalar(-1)
        let t=try DifferentialArithmetic.scale(DifferentialArithmetic.apply(rt,f.translation,&w),minus,&w)
        let omega=try DifferentialArithmetic.scale(DifferentialArithmetic.apply(rt,f.velocity.angular,&w),minus,&w)
        let vel=try DifferentialArithmetic.apply(rt,DifferentialArithmetic.subtract(DifferentialArithmetic.cross(f.velocity.angular,f.translation,&w),f.velocity.linear,&w),&w)
        let alpha=try DifferentialArithmetic.scale(DifferentialArithmetic.apply(rt,f.acceleration.angular,&w),minus,&w)
        var acc=try DifferentialArithmetic.cross(f.acceleration.angular,f.translation,&w)
        acc=try DifferentialArithmetic.add(acc,DifferentialArithmetic.scale(DifferentialArithmetic.cross(f.velocity.angular,f.velocity.linear,&w),DifferentialArithmetic.scalar(2),&w),&w)
        acc=try DifferentialArithmetic.subtract(acc,DifferentialArithmetic.cross(f.velocity.angular,DifferentialArithmetic.cross(f.velocity.angular,f.translation,&w),&w),&w)
        acc=try DifferentialArithmetic.subtract(acc,f.acceleration.linear,&w)
        return try DifferentialFrame(rotation:rt,translation:t,velocity:DifferentialMotion(omega,vel),acceleration:DifferentialMotion(alpha,DifferentialArithmetic.apply(rt,acc,&w)))
    }
}
