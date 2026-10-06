internal enum GeometryAxisRotation {
    static func evaluate(_ axis: GeometryVectorJet, coordinate: Double, work: inout NumericalWork) throws(GeometryParameterError) -> GeometryMatrixJet {
        // JointAxis.pose constructs UnitQuaternion(axis:angle:), which normalizes its axis again.
        let unit = try GeometryParameterArithmetic.normalize(axis, minimum: 0, work: &work)
        let half = try GeometryParameterArithmetic.scalar(coordinate / 2)
        let sine = try GeometryParameterArithmetic.operation(.sine, half, nil, &work)
        let cosine = try GeometryParameterArithmetic.operation(.cosine, half, nil, &work)
        let rawX = try GeometryParameterArithmetic.operation(.multiply, GeometryParameterArithmetic.scalar(unit.value.x, unit.direction.x), sine, &work)
        let rawY = try GeometryParameterArithmetic.operation(.multiply, GeometryParameterArithmetic.scalar(unit.value.y, unit.direction.y), sine, &work)
        let rawZ = try GeometryParameterArithmetic.operation(.multiply, GeometryParameterArithmetic.scalar(unit.value.z, unit.direction.z), sine, &work)
        var square = try GeometryParameterArithmetic.operation(.multiply, cosine, cosine, &work)
        square = try GeometryParameterArithmetic.operation(.add, square, GeometryParameterArithmetic.operation(.multiply, rawX, rawX, &work), &work)
        square = try GeometryParameterArithmetic.operation(.add, square, GeometryParameterArithmetic.operation(.multiply, rawY, rawY, &work), &work)
        square = try GeometryParameterArithmetic.operation(.add, square, GeometryParameterArithmetic.operation(.multiply, rawZ, rawZ, &work), &work)
        let norm = try GeometryParameterArithmetic.operation(.squareRoot, square, nil, &work)
        let w = try GeometryParameterArithmetic.operation(.divide, cosine, norm, &work)
        let x = try GeometryParameterArithmetic.operation(.divide, rawX, norm, &work)
        let y = try GeometryParameterArithmetic.operation(.divide, rawY, norm, &work)
        let z = try GeometryParameterArithmetic.operation(.divide, rawZ, norm, &work)
        try GeometryParameterArithmetic.charge(100, &work)
        let direction = try GeometryParameterArithmetic.core { () throws(CoreError) in
            try Matrix3(-4*(y.value*y.direction + z.value*z.direction),
                2*(x.direction*y.value + x.value*y.direction - z.direction*w.value - z.value*w.direction),
                2*(x.direction*z.value + x.value*z.direction + y.direction*w.value + y.value*w.direction),
                2*(x.direction*y.value + x.value*y.direction + z.direction*w.value + z.value*w.direction),
                -4*(x.value*x.direction + z.value*z.direction),
                2*(y.direction*z.value + y.value*z.direction - x.direction*w.value - x.value*w.direction),
                2*(x.direction*z.value + x.value*z.direction - y.direction*w.value - y.value*w.direction),
                2*(y.direction*z.value + y.value*z.direction + x.direction*w.value + x.value*w.direction),
                -4*(x.value*x.direction + y.value*y.direction))
        }
        let primal = try GeometryParameterArithmetic.core { () throws(CoreError) in try UnitQuaternion(axis: axis.value, angle: coordinate).matrix() }
        return GeometryMatrixJet(primal, direction)
    }
}
