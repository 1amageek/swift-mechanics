public protocol RefinementQualifying: Sendable {
    func run(_ selected: RefinementQualificationCase) throws(RefinementQualificationError)
}
