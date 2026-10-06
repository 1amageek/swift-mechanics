import SwiftMechanics

public enum AttachmentsQualificationError: Error, Sendable {
    case assertion(String)
    case attachment(AttachmentError)
    case core(CoreError)
    case joint(JointError)
    case model(ModelError)
    case flexible(FlexibleError)
    case material(MaterialError)
    case numerical(NumericalError)
    case surface(DeformingContactError)
    case unexpectedSupplierFailure
    case mutexUnavailable
}
