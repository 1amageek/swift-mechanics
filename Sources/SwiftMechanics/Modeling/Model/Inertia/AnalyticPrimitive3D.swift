public enum AnalyticPrimitive3D: Equatable, Sendable {
    case box(width: Double, depth: Double, height: Double)
    case sphere(radius: Double)
    case cylinder(radius: Double, height: Double)

    internal func validating() throws(ModelError) {
        let dimensions: [Double]
        switch self {
        case .box(let x, let y, let z): dimensions = [x, y, z]
        case .sphere(let radius): dimensions = [radius]
        case .cylinder(let radius, let height): dimensions = [radius, height]
        }
        guard dimensions.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw .invalidDimensions }
    }
}
