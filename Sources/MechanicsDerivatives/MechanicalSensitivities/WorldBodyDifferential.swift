import MechanicsCore
import MechanicsModel
import MechanicsDynamics
import MechanicsJoints
import MechanicsNumerics
internal struct WorldBodyDifferential: Sendable {
    let mass: DirectionalScalar
    let offset: DifferentialVector
    let position: DifferentialVector
    let inertia: DifferentialMatrix
    let omega: DifferentialVector
    let velocity: DifferentialVector
    let accelerationBias: DifferentialMotion
    let drift: DifferentialMotion
    @inline(never)
    static func evaluate(_ tree: TreeTangent, _ inertias: [RigidBodyInertia], _ directions: [BodyInertiaDirection], _ index: Int,
                         _ w: inout NumericalWork) throws(DerivativeError) -> WorldBodyDifferential {
        let f=tree.frames[index], p=inertias[index].properties, d=directions[index], bias=tree.bias[index]
        let mass=try DifferentialArithmetic.scalar(p.mass,d.mass)
        let offset=try DifferentialArithmetic.apply(f.rotation,DifferentialVector(p.centerOfMass,d.centerOfMass),&w)
        let position=try DifferentialArithmetic.add(f.translation,offset,&w)
        let inertia=try DifferentialArithmetic.multiply(DifferentialArithmetic.multiply(f.rotation,DifferentialMatrix(p.inertiaAtCenter,d.inertiaAtCenter),&w),DifferentialArithmetic.transpose(f.rotation),&w)
        let velocity=try DifferentialArithmetic.add(f.velocity.linear,DifferentialArithmetic.cross(f.velocity.angular,offset,&w),&w)
        var ab=try DifferentialArithmetic.add(bias.linear,DifferentialArithmetic.cross(bias.angular,offset,&w),&w)
        ab=try DifferentialArithmetic.add(ab,DifferentialArithmetic.cross(f.velocity.angular,DifferentialArithmetic.cross(f.velocity.angular,offset,&w),&w),&w)
        let actual=tree.snapshot.bodies[index].prescribedDriftVelocity, dd=tree.bodies[index].prescribedDrift
        let driftOmega=DifferentialVector(actual.angular,dd.angular)
        let driftLinear=try DifferentialArithmetic.add(DifferentialVector(actual.linear,dd.linear),DifferentialArithmetic.cross(driftOmega,offset,&w),&w)
        return WorldBodyDifferential(mass:mass,offset:offset,position:position,inertia:inertia,omega:f.velocity.angular,velocity:velocity,
            accelerationBias:DifferentialMotion(bias.angular,ab),drift:DifferentialMotion(driftOmega,driftLinear))
    }
    func column(_ c: DifferentialMotion, _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialMotion {
        DifferentialMotion(c.angular,try DifferentialArithmetic.add(c.linear,DifferentialArithmetic.cross(c.angular,offset,&w),&w))
    }
    func required(_ tree: TreeTangent, body index: Int, acceleration: [Double], direction: [Double],
                  _ w: inout NumericalWork) throws(DerivativeError) -> DifferentialMotion {
        var alpha=accelerationBias.angular, linear=accelerationBias.linear
        for k in acceleration.indices {
            let c=try column(tree.columns[index*acceleration.count+k],&w), a=try DifferentialArithmetic.scalar(acceleration[k],direction[k])
            alpha=try DifferentialArithmetic.add(alpha,DifferentialArithmetic.scale(c.angular,a,&w),&w)
            linear=try DifferentialArithmetic.add(linear,DifferentialArithmetic.scale(c.linear,a,&w),&w)
        }
        let momentum=try DifferentialArithmetic.apply(inertia,omega,&w)
        let torque=try DifferentialArithmetic.add(DifferentialArithmetic.apply(inertia,alpha,&w),DifferentialArithmetic.cross(omega,momentum,&w),&w)
        return DifferentialMotion(torque,try DifferentialArithmetic.scale(linear,mass,&w))
    }
}
