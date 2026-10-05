public struct HydraulicElementResponse: Equatable, Sendable {
    public let pressureDifference: Double
    public let volumeFlow: Double
    public let storedEnergy: Double
    public let storagePower: Double
    public let dissipatedPower: Double
    public let fluidPower: Double
    public let balanceResidual: Double

    internal init(pressure: Double, flow: Double, energy: Double = 0,
                  storagePower: Double = 0, loss: Double = 0) throws(ActuationError) {
        guard pressure.isFinite, flow.isFinite, energy.isFinite, storagePower.isFinite,
              loss.isFinite, energy >= 0, loss >= 0 else { throw .nonfiniteResult }
        pressureDifference = pressure; volumeFlow = flow; storedEnergy = energy
        self.storagePower = storagePower; dissipatedPower = loss
        fluidPower = try HydraulicArithmetic.finite(pressure * flow)
        balanceResidual = try HydraulicArithmetic.finite(fluidPower - storagePower - loss)
    }
}
