public struct HydroelasticTriangle: Sendable {
    public let first: Vector3, second: Vector3, third: Vector3
    public let firstPressurePascals: Double, secondPressurePascals: Double, thirdPressurePascals: Double
    public let area: Double
}
