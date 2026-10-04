/// Motion of a fixed unit direction in a named body-attached frame.
internal struct GeometricDirectionMotion {
    let direction: Vector3
    let rate: Vector3
    let drift: Vector3
    let bias: Vector3
    let columns: [Vector3]
    static func make(_ endpoint:GeometricFrameEndpoint,frameDirection:Vector3,snapshot:KinematicSnapshot) throws(GeometricConstraintError) -> Self {
        if GeometricConstraintSystem.isPrescribed(endpoint,tree:snapshot.tree) {
            return try GeometricArithmetic.geometry {
                let frame=try snapshot.frame(endpoint.frame).motion,direction=try frame.pose.rotation.rotating(frameDirection)
                let rate=try frame.velocity.angular.cross(direction)
                return Self(direction:direction,rate:rate,drift:rate,
                    bias:try frame.acceleration.angular.cross(direction).adding(frame.velocity.angular.cross(rate)),
                    columns:[Vector3](repeating:.zero,count:snapshot.tree.layout.velocityCount))
            }
        }
        let frameToBody=try GeometricConstraintSystem.resolve(endpoint,tree:snapshot.tree)
        return try GeometricArithmetic.geometry {
            let body=try snapshot.body(endpoint.body)
            let direction=try body.motion.pose.rotation.rotating(frameToBody.transforming(direction:frameDirection)),w=body.motion.velocity.angular
            let raw=try snapshot.geometricColumns(body:endpoint.body)
            var columns:[Vector3]=[];columns.reserveCapacity(raw.count)
            for column in raw { columns.append(try column.angular.cross(direction)) }
            return Self(direction:direction,rate:try w.cross(direction),drift:try body.prescribedDriftVelocity.angular.cross(direction),
                bias:try body.accelerationBias.angular.cross(direction).adding(w.cross(w.cross(direction))),columns:columns)
        }
    }
}
