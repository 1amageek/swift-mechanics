public protocol NumericalScalar: BinaryFloatingPoint, Sendable {
    static var numericalPrecision: NumericalPrecision { get }
}
extension Float: NumericalScalar {
    public static var numericalPrecision: NumericalPrecision { .float32 }
}
extension Double: NumericalScalar {
    public static var numericalPrecision: NumericalPrecision { .float64 }
}
