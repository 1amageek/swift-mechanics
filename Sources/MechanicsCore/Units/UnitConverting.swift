public protocol UnitConverting: Sendable {
    func convert(_ value: Double, from source: UnitDefinition, to destination: UnitDefinition) throws(CoreError) -> Double
}
