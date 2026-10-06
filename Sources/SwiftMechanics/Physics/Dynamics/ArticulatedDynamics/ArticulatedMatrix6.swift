internal enum ArticulatedMatrix6 {
    static func inertia(mass: Double, offset: Vector3, tensor: Matrix3,
                        work: inout NumericalWork) throws(ArticulatedDynamicsFailure) -> [Double] {
        var result = [Double](repeating:0,count:36)
        let axes = [Vector3.unitX,.unitY,.unitZ]
        for column in 0..<6 {
            try ArticulatedArithmetic.charge(72,&work)
            let alpha = column < 3 ? axes[column] : .zero
            let linear = column < 3 ? Vector3.zero : axes[column-3]
            let wrench = try ArticulatedArithmetic.core { () throws(CoreError) in
                let force = try linear.adding(alpha.cross(offset)).scaled(by:mass)
                let torque = try tensor.applying(to:alpha).adding(offset.cross(force))
                return SpatialWrench(torque:torque,force:force)
            }
            let values = ArticulatedArithmetic.vector(wrench)
            for row in 0..<6 { result[row*6+column] = values[row] }
        }
        return result
    }
    static func transport(offset: Vector3) -> [Double] {
        // [angular; linear] at child = [angular; linear+angular cross offset] at parent.
        var result = [Double](repeating:0,count:36)
        for i in 0..<6 { result[i*6+i] = 1 }
        result[3*6+1] = offset.z; result[3*6+2] = -offset.y
        result[4*6] = -offset.z; result[4*6+2] = offset.x
        result[5*6] = offset.y; result[5*6+1] = -offset.x
        return result
    }
    static func applying(_ matrix: [Double], offset: Int, vector: [Double],
                         into output: inout [Double], work: inout NumericalWork) throws(ArticulatedDynamicsFailure) {
        guard vector.count == 6, output.count == 6 else { throw ArticulatedDynamicsFailure(.invalidShape) }
        for row in 0..<6 {
            var value = 0.0
            for column in 0..<6 { try ArticulatedArithmetic.charge(2,&work); value = try ArticulatedArithmetic.finite(value+matrix[offset+row*6+column]*vector[column]) }
            output[row] = value
        }
    }
}
