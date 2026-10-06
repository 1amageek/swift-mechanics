public protocol DiscreteCablesQualifying: Sendable {
    func run(_ selected: DiscreteCablesQualificationCase) throws(DiscreteCablesQualificationError)
}
