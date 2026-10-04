
/// Exclusive operation-local buffers survive phase calls without intermediate arrays.
internal struct NormalResponseWorkspace {
    var freeVelocity: [Double]
    var endpoint: [Double]
    var images: [Double]
    var effective: [Double]
    var scaled: [Double]
    var linear: [Double]
    var rhs: [Double]
    var generalized: [Double]
    var trialAcceleration: [Double]
    var original: [Double]
    var observations: [ContactObservation]
    var lawResidual=0.0, coneResidual=0.0, wrenchResidual=0.0, powerResidual=0.0
    var actualPower=0.0, prescribedPower=0.0, virtualPower=0.0
    init(velocityCount n: Int, contactCount c: Int) {
        // Products and total capacity were checked by the response admission phase.
        freeVelocity=[Double](repeating:0,count:n); endpoint=[Double](repeating:0,count:n)
        images=[Double](repeating:0,count:c*n); effective=[Double](repeating:0,count:c*c)
        scaled=[Double](repeating:0,count:c*c); linear=[Double](repeating:0,count:c)
        rhs=[Double](repeating:0,count:n); generalized=[Double](repeating:0,count:n)
        trialAcceleration=[Double](repeating:0,count:n); original=[Double](repeating:0,count:n)
        observations=[]; observations.reserveCapacity(c)
    }
}
