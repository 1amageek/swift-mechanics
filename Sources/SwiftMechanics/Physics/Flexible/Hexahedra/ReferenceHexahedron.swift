internal struct ReferenceHexahedron: Sendable {
    let materialIndex: Int
    let points: [ReferenceHexahedralPoint]
}
