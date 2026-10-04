internal struct GeometricEndpointMotion {
    let point: Vector3
    let velocity: Vector3
    let drift: Vector3
    let bias: Vector3
    let columns: [Vector3]
    let axis: Vector3
    let axisRate: Vector3
    let axisDrift: Vector3
    let axisBias: Vector3
    let axisColumns: [Vector3]
    static func make(_ endpoint:GeometricFrameEndpoint,snapshot:KinematicSnapshot,original:Bool) throws(GeometricConstraintError) -> Self {
        let transform=try GeometricConstraintSystem.resolve(endpoint,tree:snapshot.tree)
        return try GeometricArithmetic.geometry {
            let local=try transform.transforming(point:endpoint.point),localAxis=try transform.transforming(direction:endpoint.axis)
            let body=try snapshot.body(endpoint.body),motion=body.motion,offset=try motion.pose.rotation.rotating(local)
            let axis=try motion.pose.rotation.rotating(localAxis),w=motion.velocity.angular
            let raw=try snapshot.geometricColumns(body:endpoint.body)
            var columns:[Vector3]=[],axisColumns:[Vector3]=[];columns.reserveCapacity(raw.count);axisColumns.reserveCapacity(raw.count)
            for column in raw {
                if original { columns.append(try column.linear.adding(column.angular.cross(offset))) }
                axisColumns.append(try column.angular.cross(axis))
            }
            let position:Vector3,velocity:Vector3,drift:Vector3,bias:Vector3
            if original {
                position=try motion.pose.translation.adding(offset)
                velocity=try motion.velocity.linear.adding(w.cross(offset))
                drift=try body.prescribedDriftVelocity.linear.adding(body.prescribedDriftVelocity.angular.cross(offset))
                bias=try body.accelerationBias.linear.adding(body.accelerationBias.angular.cross(offset)).adding(w.cross(w.cross(offset)))
            } else {
                let calculator=KinematicJacobianCalculator(),jacobian=try calculator.point(body:endpoint.body,bodyLocalPoint:local,snapshot:snapshot)
                let point=try calculator.pointMotion(body:endpoint.body,bodyLocalPoint:local,snapshot:snapshot)
                position=point.position;velocity=point.velocity;drift=point.prescribedDriftVelocity;bias=point.accelerationBias;columns=jacobian.columns
            }
            return Self(point:position,velocity:velocity,drift:drift,bias:bias,columns:columns,axis:axis,
                axisRate:try w.cross(axis),axisDrift:try body.prescribedDriftVelocity.angular.cross(axis),
                axisBias:try body.accelerationBias.angular.cross(axis).adding(w.cross(w.cross(axis))),axisColumns:axisColumns)
        }
    }
}
