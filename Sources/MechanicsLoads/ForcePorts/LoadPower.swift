public struct LoadPower: Equatable, Sendable {
    public let virtual: Double
    public let prescribedDrift: Double
    public let actual: Double
    public let conservativeActual: Double
    public let dissipativeActual: Double
    public let activeActual: Double
    internal init(virtual: Double, prescribedDrift: Double, actual: Double,
                  conservativeActual: Double, dissipativeActual: Double, activeActual: Double) {
        self.virtual = virtual; self.prescribedDrift = prescribedDrift; self.actual = actual
        self.conservativeActual = conservativeActual; self.dissipativeActual = dissipativeActual
        self.activeActual = activeActual
    }
}
