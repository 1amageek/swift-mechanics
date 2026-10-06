struct ImplicitEquationWorkspace: Sendable {
    var input: [Double]
    var derivative: [Double]
    var tangent: [Double]
    init(count: Int, entries: Int) {
        input = [Double](repeating: .nan, count: count)
        derivative = [Double](repeating: .nan, count: count)
        tangent = [Double](repeating: .nan, count: entries)
    }
}
