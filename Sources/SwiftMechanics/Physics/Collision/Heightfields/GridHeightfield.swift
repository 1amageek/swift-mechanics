public struct GridHeightfield: Sendable {
    public let identity: HeightfieldIdentity
    public let pose: RigidTransform
    public let maximumTriangleEdgeMeters: Double
    internal let vertices: [Vector3]

    public init(colliderID: EntityID, bodyID: EntityID, frameID: EntityID,
                frameRevision: UInt64, geometryRevision: UInt64,
                rows: Int, columns: Int, spacingX: Double, spacingY: Double,
                origin: Vector3, heights: [Double], diagonal: HeightfieldDiagonal,
                representation: GeometryRepresentation, expectedSourceRevision: UInt64,
                motion: HeightfieldMotion, pose: RigidTransform,
                work: inout CollisionWork) throws(HeightfieldError) {
        try HeightfieldMath.charge(64,&work)
        guard bodyID.kind == .body, representation.kind == .collisionGeometry else { throw .invalidIdentity }
        guard representation.provenance.revision == expectedSourceRevision else { throw .staleReference }
        do { try representation.quality.validating() } catch { throw .model(error) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Dynamic concave terrain response is unavailable.
        // Grid construction consumers must fail until a separately qualified dynamic contact domain exists.
        guard motion != .dynamicConcaveBody else { throw .forbiddenMotion }
        guard rows >= 2, columns >= 2, Double(rows) <= 9_007_199_254_740_991,
              Double(columns) <= 9_007_199_254_740_991,
              spacingX.isFinite, spacingX > 0, spacingY.isFinite, spacingY > 0 else { throw .invalidGrid }
        let count = try HeightfieldMath.product(rows,columns)
        guard heights.count == count else { throw .invalidGrid }
        try HeightfieldMath.reserve(vertexCount:count,work:&work)
        let reference = try HeightfieldReference(colliderID:colliderID,frameID:frameID,
            frameRevision:frameRevision,geometryRevision:geometryRevision,source:representation.provenance)
        let identity = HeightfieldIdentity(reference:reference,bodyID:bodyID,rows:rows,columns:columns,
            spacingX:spacingX,spacingY:spacingY,origin:origin,heights:heights,diagonal:diagonal,
            representation:representation,motion:motion)
        var vertices: [Vector3] = []
        vertices.reserveCapacity(count)
        for row in 0..<rows {
            let y = try HeightfieldMath.finite(origin.y+Double(row)*spacingY)
            if row > 0 {
                guard y > vertices[(row-1)*columns].y else { throw .invalidGrid }
            }
            for column in 0..<columns {
                try HeightfieldMath.charge(64,&work)
                let index = row*columns+column
                guard heights[index].isFinite else { throw .invalidGrid }
                let x = try HeightfieldMath.finite(origin.x+Double(column)*spacingX)
                if column > 0 { guard x > vertices[index-1].x else { throw .invalidGrid } }
                let z = try HeightfieldMath.finite(origin.z+heights[index])
                vertices.append(try HeightfieldMath.vector(x,y,z))
            }
        }
        var maximumEdge = 0.0
        for row in 0..<(rows-1) { for column in 0..<(columns-1) { for half in 0..<2 {
            try HeightfieldMath.charge(1024,&work)
            let triangle = try Self.triangle(identity:identity,vertices:vertices,row:row,column:column,half:half,pose:.identity)
            guard triangle.normal.z > 0 else { throw .degenerateTriangle(row:row,column:column,half:half) }
            maximumEdge = max(maximumEdge,try triangle.maximumEdge())
        } } }
        self.identity = identity; self.vertices = vertices; self.pose = pose
        self.maximumTriangleEdgeMeters = maximumEdge
    }

    public func moved(to pose: RigidTransform) throws(HeightfieldError) -> GridHeightfield {
        guard identity.motion != .staticSurface || pose == self.pose else { throw .forbiddenMotion }
        return GridHeightfield(identity:identity,vertices:vertices,pose:pose,maximumEdge:maximumTriangleEdgeMeters)
    }

    public func refitted(heights: [Double], representation: GeometryRepresentation,
                         geometryRevision: UInt64, work: inout CollisionWork) throws(HeightfieldError) -> GridHeightfield {
        try HeightfieldMath.charge(32,&work)
        for _ in representation.provenance.source.utf8 { try HeightfieldMath.charge(4,&work) }
        for _ in identity.reference.source.source.utf8 { try HeightfieldMath.charge(4,&work) }
        guard identity.motion == .deformingSnapshots else { throw .forbiddenMotion }
        guard representation.provenance.source == identity.reference.source.source,
              representation.provenance.revision > identity.reference.source.revision,
              geometryRevision > identity.reference.geometryRevision else { throw .staleReference }
        return try GridHeightfield(colliderID:identity.reference.colliderID,bodyID:identity.bodyID,
            frameID:identity.reference.frameID,frameRevision:identity.reference.frameRevision,
            geometryRevision:geometryRevision,rows:identity.rows,columns:identity.columns,
            spacingX:identity.spacingX,spacingY:identity.spacingY,origin:identity.origin,
            heights:heights,diagonal:identity.diagonal,representation:representation,
            expectedSourceRevision:representation.provenance.revision,motion:identity.motion,pose:pose,work:&work)
    }

    internal func triangle(row: Int, column: Int, half: Int) throws(HeightfieldError) -> HeightfieldTriangle {
        try Self.triangle(identity:identity,vertices:vertices,row:row,column:column,half:half,pose:pose)
    }

    private static func triangle(identity: HeightfieldIdentity, vertices: [Vector3], row: Int,
                                 column: Int, half: Int, pose: RigidTransform) throws(HeightfieldError) -> HeightfieldTriangle {
        let lowerLeft = row*identity.columns+column
        let lowerRight = lowerLeft+1, upperLeft = lowerLeft+identity.columns, upperRight = upperLeft+1
        let indices: (Int,Int,Int)
        switch identity.diagonal {
        case .lowerLeftToUpperRight:
            indices = half == 0 ? (lowerLeft,lowerRight,upperRight) : (lowerLeft,upperRight,upperLeft)
        case .lowerRightToUpperLeft:
            indices = half == 0 ? (lowerLeft,lowerRight,upperLeft) : (lowerRight,upperRight,upperLeft)
        }
        return try HeightfieldTriangle(first:HeightfieldMath.point(pose,vertices[indices.0]),
            second:HeightfieldMath.point(pose,vertices[indices.1]),third:HeightfieldMath.point(pose,vertices[indices.2]),
            firstIndex:indices.0,secondIndex:indices.1,thirdIndex:indices.2,
            face:HeightfieldFace(row:row,column:column,half:half))
    }

    private init(identity: HeightfieldIdentity, vertices: [Vector3], pose: RigidTransform, maximumEdge: Double) {
        self.identity = identity; self.vertices = vertices; self.pose = pose
        self.maximumTriangleEdgeMeters = maximumEdge
    }
}
