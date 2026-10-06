public protocol AttachmentsQualifying: Sendable {
    func run(_ selected: AttachmentsQualificationCase) throws(AttachmentsQualificationError)
}
