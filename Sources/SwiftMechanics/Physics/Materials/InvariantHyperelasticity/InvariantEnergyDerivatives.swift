internal struct InvariantEnergyDerivatives {
    let energy: Double
    let w1: Double
    let w2: Double
    let wj: Double
    let w11: Double
    let w12: Double
    let w22: Double
    let w1j: Double
    let w2j: Double
    let wjj: Double

    init(energy: Double, w1: Double = 0, w2: Double = 0, wj: Double = 0,
         w11: Double = 0, w12: Double = 0, w22: Double = 0, w1j: Double = 0,
         w2j: Double = 0, wjj: Double = 0) throws(MaterialError) {
        guard energy.isFinite, energy >= 0, w1.isFinite, w2.isFinite, wj.isFinite,
              w11.isFinite, w12.isFinite, w22.isFinite, w1j.isFinite, w2j.isFinite, wjj.isFinite else {
            throw .nonFiniteResult(operation: "invariantPotentialDerivatives")
        }
        self.energy=energy; self.w1=w1; self.w2=w2; self.wj=wj
        self.w11=w11; self.w12=w12; self.w22=w22; self.w1j=w1j; self.w2j=w2j; self.wjj=wjj
    }
}
