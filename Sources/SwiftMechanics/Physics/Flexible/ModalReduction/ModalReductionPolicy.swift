public struct ModalReductionPolicy: Sendable {
    public let structural: StructuralPolicy
    public let maximumPorts: Int
    public let massGramTolerance: Double
    public let projectedResidualTolerance: Double
    public let interfacePowerTolerance: Double
    public init(structural: StructuralPolicy, maximumPorts: Int, massGramTolerance: Double,
                projectedResidualTolerance: Double, interfacePowerTolerance: Double) throws(ModalReductionError) {
        guard maximumPorts >= 0, massGramTolerance.isFinite, massGramTolerance > 0, massGramTolerance < 1,
              projectedResidualTolerance.isFinite, projectedResidualTolerance > 0,
              interfacePowerTolerance.isFinite, interfacePowerTolerance > 0 else { throw .invalidInput }
        self.structural=structural; self.maximumPorts=maximumPorts; self.massGramTolerance=massGramTolerance
        self.projectedResidualTolerance=projectedResidualTolerance; self.interfacePowerTolerance=interfacePowerTolerance
    }
}
