/// Explicit mechanical proxy geometry, not a CAD shape or source-fidelity claim.
public enum ConvexShape: Equatable, Sendable {
    case sphere(radius: Double)
    case box(halfExtents: Vector3)
    /// Segment endpoints are local (0, 0, +/-halfLength), inflated by radius.
    case capsule(radius: Double, halfLength: Double)
    /// Axis is local Z; planar caps are at +/-halfHeight.
    case cylinder(radius: Double, halfHeight: Double)
    /// Apex is at +halfHeight; base disk is at -halfHeight.
    case cone(radius: Double, halfHeight: Double)
    /// Solid convex hull of the supplied local vertices; original indices are retained.
    case hull(vertices: [Vector3])

    internal func validate(work: inout CollisionWork) throws(ConvexCollisionError) {
        try ConvexMath.charge(64, &work)
        switch self {
        case .sphere(let r):
            guard r.isFinite, r > 0 else { throw .invalidShape }
        case .box(let h):
            guard h.x > 0, h.y > 0, h.z > 0 else { throw .invalidShape }
        case .capsule(let r, let h):
            guard r.isFinite, r > 0, h.isFinite, h >= 0 else { throw .invalidShape }
        case .cylinder(let r, let h), .cone(let r, let h):
            guard r.isFinite, r > 0, h.isFinite, h > 0 else { throw .invalidShape }
        case .hull(let vertices):
            guard vertices.count >= 4 else { throw .invalidShape }
            try ConvexMath.storage(vertices: vertices.count, faces: 0, edges: 0, work: &work)
            let origin = vertices[0]
            var axis = Vector3.zero, longest = 0.0
            for v in vertices {
                try ConvexMath.charge(32, &work)
                let edge = try ConvexMath.sub(v, origin), length = try ConvexMath.norm(edge)
                if length > longest { axis = edge; longest = length }
            }
            guard longest > 0 else { throw .degenerateSimplex }
            axis = try ConvexMath.unit(axis)
            var normal = Vector3.zero, largestArea = 0.0
            for v in vertices {
                try ConvexMath.charge(64, &work)
                let e = try ConvexMath.scale(ConvexMath.sub(v, origin), 1 / longest)
                let n = try ConvexMath.cross(axis, e), area = try ConvexMath.norm(n)
                if area > largestArea { normal = n; largestArea = area }
            }
            guard largestArea > 64 * Double.ulpOfOne else { throw .degenerateSimplex }
            normal = try ConvexMath.unit(normal)
            var thickness = 0.0
            for v in vertices {
                try ConvexMath.charge(64, &work)
                let e = try ConvexMath.scale(ConvexMath.sub(v, origin), 1 / longest)
                thickness = max(thickness, abs(try ConvexMath.dot(normal, e)))
            }
            guard thickness > 64 * Double.ulpOfOne else { throw .degenerateSimplex }
        }
    }
}
