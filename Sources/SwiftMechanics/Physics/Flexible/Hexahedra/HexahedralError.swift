public enum HexahedralError: Error, Equatable, Sendable {
    case invalidParameter
    case invalidIdentity
    case invalidConnectivity
    case duplicateCell
    case missingMaterial
    case unusedNode
    case capacityExceeded
    case layoutMismatch
    case referenceJacobianNotCertified(cell: UInt64)
    case currentJacobianNotCertified(cell: UInt64)
    case singularReferenceJacobian(cell: UInt64, point: Int)
    case nonFiniteResult
    case constitutiveCallLimit(limit: Int)
    case cancelled
    case core(CoreError)
    case material(MaterialError)
    case numerical(NumericalError)
}
