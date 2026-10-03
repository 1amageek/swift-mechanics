import MechanicsCore
public struct PressureTriangle: Sendable {
    public let cellIdentifier: UInt64
    public let first: Vector3, second: Vector3, third: Vector3
    public let firstPressure: Double, secondPressure: Double, thirdPressure: Double
    public let area: Double
}
