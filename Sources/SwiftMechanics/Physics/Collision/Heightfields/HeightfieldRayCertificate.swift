internal enum HeightfieldRayCertificate {
    private typealias I = HeightfieldInterval
    private typealias V = (I,I,I)

    /// True only if outward original-plane or original-barycentric inequalities exclude the entire ray interval.
    static func misses(_ triangle: HeightfieldTriangle, ray: CollisionRay,
                       work: inout CollisionWork) throws(HeightfieldError) -> Bool {
        try HeightfieldMath.charge(4096,&work)
        let a = vector(triangle.first), b = vector(triangle.second), c = vector(triangle.third)
        let size = I(point:triangle.scale)
        let edge0 = try divide(sub(b,a),size), edge1 = try divide(sub(c,a),size)
        let normal = try cross(edge0,edge1)
        let origin = vector(ray.origin), direction = vector(ray.direction)
        let h = try dot(normal,sub(origin,a)), slope = try dot(normal,direction)
        let endpointHeight = try h.adding(slope.multiplied(by:I(point:ray.maximumDistance)))
        if h.lower > 0, endpointHeight.lower > 0 { return true }
        if h.upper < 0, endpointHeight.upper < 0 { return true }
        let interval: I
        if slope.excludesZero {
            let parameter = try h.negated().divided(by:slope)
            if parameter.upper < 0 || parameter.lower > ray.maximumDistance { return true }
            interval = try I(lower:max(0,parameter.lower),upper:min(ray.maximumDistance,parameter.upper))
        } else {
            // A barycentric separating inequality can reject even a coplanar or uncertifiable plane.
            interval = try I(lower:0,upper:ray.maximumDistance)
        }
        let aa = try dot(edge0,edge0), ab = try dot(edge0,edge1), bb = try dot(edge1,edge1)
        let determinant = try aa.multiplied(by:bb).subtracting(ab.multiplied(by:ab))
        guard determinant.lower > 0 else { return false }
        func weights(at parameter: Double) throws(HeightfieldError) -> V {
            let point = try add(origin,multiply(direction,I(point:parameter)))
            let offset = try divide(sub(point,a),size)
            let d0 = try dot(offset,edge0), d1 = try dot(offset,edge1)
            let second = try d0.multiplied(by:bb).subtracting(d1.multiplied(by:ab)).divided(by:determinant)
            let third = try d1.multiplied(by:aa).subtracting(d0.multiplied(by:ab)).divided(by:determinant)
            let first = try I(point:1).subtracting(second).subtracting(third)
            return (first,second,third)
        }
        // Every original coordinate is affine in the ray parameter. Endpoint bounds enclose
        // its extrema on the whole interval without boxing away correlation. Membership
        // requires each coordinate in [0,1], since nonnegative coordinates sum to one.
        let lower = try weights(at:interval.lower), upper = try weights(at:interval.upper)
        return max(lower.0.upper,upper.0.upper) < 0 ||
               max(lower.1.upper,upper.1.upper) < 0 || max(lower.2.upper,upper.2.upper) < 0 ||
               min(lower.0.lower,upper.0.lower) > 1 || min(lower.1.lower,upper.1.lower) > 1 ||
               min(lower.2.lower,upper.2.lower) > 1
    }

    private static func vector(_ value: Vector3) -> V { (I(point:value.x),I(point:value.y),I(point:value.z)) }
    private static func add(_ a: V, _ b: V) throws(HeightfieldError) -> V {
        (try a.0.adding(b.0),try a.1.adding(b.1),try a.2.adding(b.2))
    }
    private static func sub(_ a: V, _ b: V) throws(HeightfieldError) -> V {
        (try a.0.subtracting(b.0),try a.1.subtracting(b.1),try a.2.subtracting(b.2))
    }
    private static func multiply(_ a: V, _ b: I) throws(HeightfieldError) -> V {
        (try a.0.multiplied(by:b),try a.1.multiplied(by:b),try a.2.multiplied(by:b))
    }
    private static func divide(_ a: V, _ b: I) throws(HeightfieldError) -> V {
        (try a.0.divided(by:b),try a.1.divided(by:b),try a.2.divided(by:b))
    }
    private static func dot(_ a: V, _ b: V) throws(HeightfieldError) -> I {
        try a.0.multiplied(by:b.0).adding(a.1.multiplied(by:b.1)).adding(a.2.multiplied(by:b.2))
    }
    private static func cross(_ a: V, _ b: V) throws(HeightfieldError) -> V {
        (try a.1.multiplied(by:b.2).subtracting(a.2.multiplied(by:b.1)),
         try a.2.multiplied(by:b.0).subtracting(a.0.multiplied(by:b.2)),
         try a.0.multiplied(by:b.1).subtracting(a.1.multiplied(by:b.0)))
    }
}
