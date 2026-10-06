internal struct ConvexPolytopeFace: Sendable {
    let a: Int
    let b: Int
    let c: Int
    let normal: Vector3
    let distance: Double
}
