internal struct GeometryResolvedDirections: Sendable {
    /// Root placement followed by parent/child anchors for each tree-ordered joint.
    let translations: [Vector3]
    let bodyRotations: [Vector3]
    let axes: [Vector3]
    let witnesses: [GeometryAxisWitness]
}
