public struct OrthotropicElasticLaw: Equatable, Sendable {
    public let c11: Double, c22: Double, c33: Double, c12: Double, c13: Double, c23: Double
    public let g12: Double, g23: Double, g13: Double
    internal let normalScale: Double
    internal let l11: Double, l21: Double, l31: Double, l22: Double, l32: Double, l33: Double
    public init(c11: Double, c22: Double, c33: Double, c12: Double, c13: Double, c23: Double,
                g12: Double, g23: Double, g13: Double) throws(MaterialError) {
        guard c11.isFinite, c22.isFinite, c33.isFinite, c12.isFinite, c13.isFinite, c23.isFinite,
              c11 > 0, c22 > 0, c33 > 0, g12.isFinite, g23.isFinite, g13.isFinite,
              g12 > 0, g23 > 0, g13 > 0, (2*g12).isFinite, (2*g23).isFinite, (2*g13).isFinite else {
            throw .invalidParameter(name: "orthotropicStiffness")
        }
        // A fixed normalized Cholesky admission proves positive definiteness without raw determinant overflow.
        let scale = max(c11, c22, c33, abs(c12), abs(c13), abs(c23))
        let a = c11/scale, b = c22/scale, c = c33/scale
        guard a > 0 else { throw .invalidParameter(name: "orthotropicPositiveDefiniteness") }
        let l11 = a.squareRoot(), l21 = (c12/scale)/l11, l31 = (c13/scale)/l11
        let second = b - l21*l21
        guard second.isFinite, second > 0 else { throw .invalidParameter(name: "orthotropicPositiveDefiniteness") }
        let l22 = second.squareRoot(), l32 = (c23/scale - l21*l31)/l22
        let third = c - l31*l31 - l32*l32
        guard third.isFinite, third > 0 else { throw .invalidParameter(name: "orthotropicPositiveDefiniteness") }
        self.c11=c11; self.c22=c22; self.c33=c33; self.c12=c12; self.c13=c13; self.c23=c23
        self.g12=g12; self.g23=g23; self.g13=g13
        self.normalScale=scale; self.l11=l11; self.l21=l21; self.l31=l31
        self.l22=l22; self.l32=l32; self.l33=third.squareRoot()
    }
}
