internal struct ReferenceHexahedralPoint: Sendable {
    let inverseJacobian: Matrix3
    let determinant: Double
    let shape: [Double]
    let gradients: [Vector3]
}
