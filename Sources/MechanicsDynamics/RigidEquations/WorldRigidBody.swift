import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsNumerics
internal struct WorldRigidBody {
    let mass: Double
    let position: Vector3
    let offset: Vector3
    let inertia: Matrix3
    let omega: Vector3
    let velocity: Vector3
    let angularBias: Vector3
    let accelerationBias: Vector3
    let drift: SpatialMotion
    static func evaluate(_ input: RigidDynamicsInput, index: Int, work: inout NumericalWork) throws(DynamicsError) -> WorldRigidBody {
        let motion = input.snapshot.bodies[index], properties = input.inertias[index].properties
        let rotation = try DynamicsArithmetic.rotation(motion.motion.pose.rotation,&work)
        let offset = try DynamicsArithmetic.apply(rotation,properties.centerOfMass,&work)
        let position = try DynamicsArithmetic.add(motion.motion.pose.translation,offset,&work)
        let inertia = try DynamicsArithmetic.inertia(properties.inertiaAtCenter,rotation:rotation,&work)
        let omega = motion.motion.velocity.angular
        let velocity = try DynamicsArithmetic.add(motion.motion.velocity.linear,DynamicsArithmetic.cross(omega,offset,&work),&work)
        let bias = motion.accelerationBias
        let centripetal = try DynamicsArithmetic.cross(omega,DynamicsArithmetic.cross(omega,offset,&work),&work)
        let accelerationBias = try DynamicsArithmetic.add(bias.linear,DynamicsArithmetic.add(DynamicsArithmetic.cross(bias.angular,offset,&work),centripetal,&work),&work)
        let drift = motion.prescribedDriftVelocity
        let driftLinear = try DynamicsArithmetic.add(drift.linear,DynamicsArithmetic.cross(drift.angular,offset,&work),&work)
        return WorldRigidBody(mass:properties.mass,position:position,offset:offset,inertia:inertia,omega:omega,
            velocity:velocity,angularBias:bias.angular,accelerationBias:accelerationBias,
            drift:SpatialMotion(angular:drift.angular,linear:driftLinear))
    }
    func comColumn(_ column: SpatialMotion, work: inout NumericalWork) throws(DynamicsError) -> SpatialMotion {
        SpatialMotion(angular:column.angular,linear:try DynamicsArithmetic.add(column.linear,DynamicsArithmetic.cross(column.angular,offset,&work),&work))
    }
    func required(_ acceleration: [Double], columns: ArraySlice<SpatialMotion>, includeBias: Bool,
                  work: inout NumericalWork) throws(DynamicsError) -> SpatialWrench {
        var alpha = includeBias ? angularBias : .zero, linear = includeBias ? accelerationBias : .zero
        for (i,column) in columns.enumerated() {
            let com = try comColumn(column,work:&work)
            alpha = try DynamicsArithmetic.add(alpha,DynamicsArithmetic.scale(com.angular,acceleration[i],&work),&work)
            linear = try DynamicsArithmetic.add(linear,DynamicsArithmetic.scale(com.linear,acceleration[i],&work),&work)
        }
        let force = try DynamicsArithmetic.scale(linear,mass,&work)
        var torque = try DynamicsArithmetic.apply(inertia,alpha,&work)
        if includeBias { torque = try DynamicsArithmetic.add(torque,DynamicsArithmetic.cross(omega,DynamicsArithmetic.apply(inertia,omega,&work),&work),&work) }
        return SpatialWrench(torque:torque,force:force)
    }
}
