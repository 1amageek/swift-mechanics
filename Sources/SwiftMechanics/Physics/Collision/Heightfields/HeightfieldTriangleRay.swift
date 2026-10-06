internal enum HeightfieldTriangleRay {
    static func intersection(_ triangle: HeightfieldTriangle, ray: CollisionRay,
                             policy: CollisionQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> Double? {
        try HeightfieldMath.charge(2048,&work)
        let height = try HeightfieldMath.dot(triangle.normal,HeightfieldMath.sub(ray.origin,triangle.first))
        let slope = try HeightfieldMath.dot(triangle.normal,ray.direction)
        let barycentricTolerance = try HeightfieldMath.finite(policy.lengthTolerance/triangle.scale)
        let parameter: Double
        if slope == 0 {
            if abs(height) > policy.lengthTolerance { return try rejected(triangle,ray:ray,work:&work) }
            guard height == 0 else { throw .ambiguousRay }
            let originWeights = try triangle.planeWeights(ray.origin)
            let rates = try triangle.weightRates(ray.direction)
            var lower = 0.0, upper = ray.maximumDistance
            for axis in 0..<3 {
                let w = component(originWeights,axis), rate = component(rates,axis)
                if rate == 0 {
                    if w < -barycentricTolerance { return try rejected(triangle,ray:ray,work:&work) }
                    if w < 0 { throw .ambiguousRay }
                } else {
                    let root = try HeightfieldMath.finite(-w/rate)
                    if rate > 0 { lower = max(lower,root) } else { upper = min(upper,root) }
                }
            }
            if lower > upper {
                if try HeightfieldMath.finite(lower-upper) <= policy.lengthTolerance { throw .ambiguousRay }
                return try rejected(triangle,ray:ray,work:&work)
            }
            parameter = lower
        } else {
            let root = try HeightfieldMath.finite(-height/slope)
            if root < 0 {
                if root >= -policy.lengthTolerance { throw .ambiguousRay }
                return try rejected(triangle,ray:ray,work:&work)
            }
            if root > ray.maximumDistance {
                if try HeightfieldMath.finite(root-ray.maximumDistance) <= policy.lengthTolerance { throw .ambiguousRay }
                return try rejected(triangle,ray:ray,work:&work)
            }
            parameter = root
        }
        let point = try HeightfieldMath.add(ray.origin,HeightfieldMath.scale(ray.direction,parameter))
        let weights = try triangle.planeWeights(point)
        if weights.first < -barycentricTolerance || weights.second < -barycentricTolerance || weights.third < -barycentricTolerance {
            return try rejected(triangle,ray:ray,work:&work)
        }
        guard weights.first >= 0, weights.second >= 0, weights.third >= 0 else { throw .ambiguousRay }
        let boundary = try triangle.reconstructed(weights)
        try HeightfieldMath.accept(HeightfieldMath.norm(HeightfieldMath.sub(point,boundary)),policy.lengthTolerance)
        return parameter
    }

    private static func rejected(_ triangle: HeightfieldTriangle, ray: CollisionRay,
                                 work: inout CollisionWork) throws(HeightfieldError) -> Double? {
        guard try HeightfieldRayCertificate.misses(triangle,ray:ray,work:&work) else { throw .ambiguousRay }
        return nil
    }

    private static func component(_ weights: HeightfieldBarycentric, _ axis: Int) -> Double {
        axis == 0 ? weights.first : (axis == 1 ? weights.second : weights.third)
    }
}
