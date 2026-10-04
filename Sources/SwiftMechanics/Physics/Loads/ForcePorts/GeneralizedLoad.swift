public struct GeneralizedLoad: Equatable, Sendable {
    public let values: [Double]
    public let power: LoadPower
    internal init(values: [Double], power: LoadPower) { self.values = values; self.power = power }
}
