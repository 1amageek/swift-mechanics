internal struct HydroelasticCoordinates: Sendable {
    let n0: Double, n1: Double, n2: Double, n3: Double
    func value(_ index: Int) -> Double {
        switch index { case 0: return n0; case 1: return n1; case 2: return n2; default: return n3 }
    }
}
