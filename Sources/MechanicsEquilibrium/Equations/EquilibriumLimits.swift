public struct EquilibriumLimits: Sendable {
    public let coordinates: Int
    public let rows: Int
    public let cases: Int
    public let identifierBytes: Int
    public let bodies: Int
    public init(coordinates: Int, rows: Int, cases: Int, identifierBytes: Int, bodies: Int) throws(EquilibriumError) {
        guard coordinates > 0, rows >= 0, cases > 0, identifierBytes > 0, bodies > 0 else { throw .invalidInput }
        self.coordinates=coordinates; self.rows=rows; self.cases=cases; self.identifierBytes=identifierBytes; self.bodies=bodies
    }
}
