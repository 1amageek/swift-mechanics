public protocol SpatialBeamsQualifying: Sendable {
    func run(_ selected: SpatialBeamsQualificationCase) throws(SpatialBeamsQualificationError)
}
