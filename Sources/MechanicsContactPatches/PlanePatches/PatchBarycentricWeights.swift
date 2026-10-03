internal struct PatchBarycentricWeights: Sendable {
    var a: Double, b: Double, c: Double, d: Double
    static let zero=Self(a:0,b:0,c:0,d:0)
    func value(_ i: Int) -> Double { switch i { case 0: return a; case 1: return b; case 2: return c; default: return d } }
    mutating func set(_ i: Int,_ value: Double) { switch i { case 0: a=value; case 1: b=value; case 2: c=value; default: d=value } }
}
