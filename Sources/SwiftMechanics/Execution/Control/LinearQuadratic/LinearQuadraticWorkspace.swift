/// Operation-local arrays are retained and overwritten across Riccati iterations.
internal struct LinearQuadraticWorkspace {
    var pa: [Double]
    var pb: [Double]
    var at: [Double]
    var bt: [Double]
    var apa: [Double]
    var bpb: [Double]
    var bpa: [Double]
    var bpat: [Double]
    var denominator: [Double]
    var gain: [Double]
    var correction: [Double]
    var next: [Double]
    var rhs: [Double]
    init(statesSquared: Int, stateInputs: Int, inputsSquared: Int, inputs: Int) {
        pa = [Double](repeating: 0, count: statesSquared); at = pa; apa = pa; correction = pa; next = pa
        pb = [Double](repeating: 0, count: stateInputs); bt = pb; bpa = pb; bpat = pb; gain = pb
        bpb = [Double](repeating: 0, count: inputsSquared); denominator = bpb
        rhs = [Double](repeating: 0, count: inputs)
    }
}
