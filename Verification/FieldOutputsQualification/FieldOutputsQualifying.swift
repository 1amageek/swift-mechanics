public protocol FieldOutputsQualifying: Sendable {
    func run(_ selected: FieldOutputsQualificationCase) throws(FieldOutputsQualificationError)
}
