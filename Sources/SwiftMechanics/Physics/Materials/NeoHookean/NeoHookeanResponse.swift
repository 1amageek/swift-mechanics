public struct NeoHookeanResponse: Sendable {
    public let greenStrain: SymmetricTensor
    public let volumeRatio: Double
    public let secondPiolaStress: Matrix3
    public let firstPiolaStress: Matrix3
    public let cauchyStress: Matrix3
    public let energyDensity: Double
}
