/// Motion of a fixed unit direction in a named body-attached frame.
internal struct GeometricDirectionMotion {
    let direction: Vector3
    let rate: Vector3
    let drift: Vector3
    let bias: Vector3
    let columns: [Vector3]
    static func make(_ endpoint:GeometricFrameEndpoint,frameDirection:Vector3,snapshot:KinematicSnapshot) throws(GeometricConstraintError) -> Self {
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
