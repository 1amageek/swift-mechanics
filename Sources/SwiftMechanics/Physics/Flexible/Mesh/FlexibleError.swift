public enum FlexibleError: Error, Equatable, Sendable {
    case invalidParameter, invalidIdentity, invalidConnectivity, missingMaterial, unusedNode
    case invalidReferenceCell(element: UInt64), duplicateCell, layoutMismatch
    case capacityExceeded, constitutiveCallLimit(limit: Int), cancelled, nonFiniteResult
    case core(CoreError), material(MaterialError), numerical(NumericalError)
}
