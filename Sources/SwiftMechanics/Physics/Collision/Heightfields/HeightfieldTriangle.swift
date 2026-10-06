internal struct HeightfieldTriangle: Sendable {
    let first: Vector3
    let second: Vector3
    let third: Vector3
    let firstIndex: Int
    let secondIndex: Int
    let thirdIndex: Int
    let face: HeightfieldFace
    let normal: Vector3
    let scale: Double
    private let edge0: Vector3
    private let edge1: Vector3
    private let basis0: Vector3
    private let basis1: Vector3
    private let gram00: Double
    private let gram01: Double
    private let gram11: Double
    private let determinant: Double

    init(first: Vector3, second: Vector3, third: Vector3, firstIndex: Int,
         secondIndex: Int, thirdIndex: Int, face: HeightfieldFace) throws(HeightfieldError) {
        self.first = first; self.second = second; self.third = third
        self.firstIndex = firstIndex; self.secondIndex = secondIndex; self.thirdIndex = thirdIndex
        self.face = face
        edge0 = try HeightfieldMath.sub(second,first); edge1 = try HeightfieldMath.sub(third,first)
        scale = max(max(abs(edge0.x),max(abs(edge0.y),abs(edge0.z))),max(abs(edge1.x),max(abs(edge1.y),abs(edge1.z))))
        guard scale > 0 else { throw .degenerateTriangle(row:face.row,column:face.column,half:face.half) }
        basis0 = try HeightfieldMath.divide(edge0,scale); basis1 = try HeightfieldMath.divide(edge1,scale)
        gram00 = try HeightfieldMath.dot(basis0,basis0); gram01 = try HeightfieldMath.dot(basis0,basis1)
        gram11 = try HeightfieldMath.dot(basis1,basis1)
        determinant = try HeightfieldMath.finite(gram00*gram11-gram01*gram01)
        guard determinant > 128*Double.ulpOfOne*gram00*gram11 else {
            throw .degenerateTriangle(row:face.row,column:face.column,half:face.half)
        }
        normal = try HeightfieldMath.unit(HeightfieldMath.cross(basis0,basis1))
    }

    func maximumEdge() throws(HeightfieldError) -> Double {
        max(try HeightfieldMath.norm(edge0),max(try HeightfieldMath.norm(edge1),try HeightfieldMath.norm(HeightfieldMath.sub(third,second))))
    }

    /// The unconstrained stationary point of the original triangle distance quadratic.
    func planeWeights(_ query: Vector3) throws(HeightfieldError) -> HeightfieldBarycentric {
        let offset = try HeightfieldMath.divide(HeightfieldMath.sub(query,first),scale)
        return try weights(forScaledOffset:offset)
    }

    func weightRates(_ direction: Vector3) throws(HeightfieldError) -> HeightfieldBarycentric {
        let offset = try HeightfieldMath.divide(direction,scale)
        let d0 = try HeightfieldMath.dot(offset,basis0), d1 = try HeightfieldMath.dot(offset,basis1)
        let second = try HeightfieldMath.finite((d0*gram11-d1*gram01)/determinant)
        let third = try HeightfieldMath.finite((d1*gram00-d0*gram01)/determinant)
        return HeightfieldBarycentric(first:try HeightfieldMath.finite(-second-third),second:second,third:third)
    }

    func reconstructed(_ weights: HeightfieldBarycentric) throws(HeightfieldError) -> Vector3 {
        try HeightfieldMath.add(first,HeightfieldMath.add(HeightfieldMath.scale(edge0,weights.second),
                                                       HeightfieldMath.scale(edge1,weights.third)))
    }

    func closest(_ query: Vector3, policy: CollisionQueryPolicy,
                 work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldTriangleProjection {
        try HeightfieldMath.charge(4096,&work)
        var best = try segment(query,from:first,to:second,edge:0)
        let secondCandidate = try segment(query,from:second,to:third,edge:1)
        if secondCandidate.distance < best.distance { best = secondCandidate }
        let thirdCandidate = try segment(query,from:third,to:first,edge:2)
        if thirdCandidate.distance < best.distance { best = thirdCandidate }
        let weights = try planeWeights(query)
        if weights.first >= 0, weights.second >= 0, weights.third >= 0 {
            let point = try reconstructed(weights)
            let distance = try HeightfieldMath.norm(HeightfieldMath.sub(query,point))
            if distance < best.distance {
                best = HeightfieldTriangleProjection(point:point,barycentric:weights,distance:distance,
                    feature:feature(weights),residual:0)
            }
        }
        let delta = try HeightfieldMath.sub(query,best.point)
        let reconstructed = try reconstructed(best.barycentric)
        var residual = try HeightfieldMath.norm(HeightfieldMath.sub(reconstructed,best.point))
        residual = max(residual,abs(try HeightfieldMath.dot(normal,HeightfieldMath.sub(best.point,first))))
        // Original triangle KKT: query - closest has nonpositive projection along every feasible vertex direction.
        for index in 0..<3 {
            let vertex = index == 0 ? first : (index == 1 ? second : third)
            let direction = try HeightfieldMath.sub(vertex,best.point)
            let length = try HeightfieldMath.norm(direction)
            if length > 0 {
                residual = max(residual,max(0,try HeightfieldMath.dot(delta,HeightfieldMath.unit(direction))))
            }
        }
        try HeightfieldMath.accept(residual,policy.lengthTolerance)
        let sum = try HeightfieldMath.finite(best.barycentric.first+best.barycentric.second+best.barycentric.third)
        try HeightfieldMath.accept(abs(sum-1),policy.normalTolerance)
        guard best.barycentric.first >= 0, best.barycentric.second >= 0, best.barycentric.third >= 0 else { throw .arithmeticFailure }
        try HeightfieldMath.accept(abs(try HeightfieldMath.norm(normal)-1),policy.normalTolerance)
        return HeightfieldTriangleProjection(point:best.point,barycentric:best.barycentric,distance:best.distance,
            feature:best.feature,residual:residual)
    }

    func feature(_ w: HeightfieldBarycentric) -> HeightfieldFeature {
        if w.second == 0, w.third == 0 { return .vertex(index:firstIndex) }
        if w.first == 0, w.third == 0 { return .vertex(index:secondIndex) }
        if w.first == 0, w.second == 0 { return .vertex(index:thirdIndex) }
        if w.third == 0 { return edgeFeature(firstIndex,secondIndex) }
        if w.first == 0 { return edgeFeature(secondIndex,thirdIndex) }
        if w.second == 0 { return edgeFeature(thirdIndex,firstIndex) }
        return .face
    }

    private func weights(forScaledOffset offset: Vector3) throws(HeightfieldError) -> HeightfieldBarycentric {
        let d0 = try HeightfieldMath.dot(offset,basis0), d1 = try HeightfieldMath.dot(offset,basis1)
        let second = try HeightfieldMath.finite((d0*gram11-d1*gram01)/determinant)
        let third = try HeightfieldMath.finite((d1*gram00-d0*gram01)/determinant)
        return HeightfieldBarycentric(first:try HeightfieldMath.finite(1-second-third),second:second,third:third)
    }

    private func segment(_ query: Vector3, from a: Vector3, to b: Vector3,
                         edge: Int) throws(HeightfieldError) -> HeightfieldTriangleProjection {
        let direction = try HeightfieldMath.sub(b,a)
        let normalizedEdge = try HeightfieldMath.divide(direction,scale)
        let denominator = try HeightfieldMath.dot(normalizedEdge,normalizedEdge)
        guard denominator > 0 else { throw .degenerateTriangle(row:face.row,column:face.column,half:face.half) }
        let offset = try HeightfieldMath.divide(HeightfieldMath.sub(query,a),scale)
        let parameter = max(0,min(1,try HeightfieldMath.finite(HeightfieldMath.dot(offset,normalizedEdge)/denominator)))
        let weights: HeightfieldBarycentric
        switch edge {
        case 0: weights = HeightfieldBarycentric(first:1-parameter,second:parameter,third:0)
        case 1: weights = HeightfieldBarycentric(first:0,second:1-parameter,third:parameter)
        default: weights = HeightfieldBarycentric(first:parameter,second:0,third:1-parameter)
        }
        let point = try reconstructed(weights)
        return HeightfieldTriangleProjection(point:point,barycentric:weights,
            distance:try HeightfieldMath.norm(HeightfieldMath.sub(query,point)),feature:feature(weights),residual:0)
    }

    private func edgeFeature(_ a: Int, _ b: Int) -> HeightfieldFeature {
        .edge(first:min(a,b),second:max(a,b))
    }
}
