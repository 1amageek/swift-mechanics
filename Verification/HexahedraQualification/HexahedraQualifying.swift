public protocol HexahedraQualifying: Sendable {
    func run(_ selected: HexahedraQualificationCase) throws(HexahedraQualificationError)
}
