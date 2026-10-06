public enum AttachmentError: Error, Sendable {
    case invalidInput, nonFinite, capacityExceeded, cancelled
    case staleSite, staleSource, staleGeometry, staleLayout, frameMismatch, timeMismatch
    case boundaryOwnershipMismatch, duplicateAttachment, rankDeficient, overconstrained
    case physicalResidual, invalidSupplierOutput, unsupportedOrientation, unsupportedDomain
    case rigidSupplierFailure
    case core(CoreError), joint(JointError), numerical(NumericalError), surface(DeformingContactError)
}
