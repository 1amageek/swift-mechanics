import SwiftMechanics

public enum PoseIKQualificationOracle {
    /// Independent pointwise Taylor evaluation on the small selected fixture angles.
    public static func sine(_ x: Double) -> Double {
        var term = x, value = x
        for k in 1...18 { term *= -x*x/Double((2*k)*(2*k+1)); value += term }
        return value
    }
    public static func cosine(_ x: Double) -> Double {
        var term = 1.0, value = 1.0
        for k in 1...18 { term *= -x*x/Double((2*k-1)*(2*k)); value += term }
        return value
    }
    public static func multiply(_ a: [Double], _ b: [Double]) -> [Double] {
        var c = [Double](repeating: 0, count: 9)
        for i in 0..<3 { for j in 0..<3 { for k in 0..<3 { c[3*i+j] += a[3*i+k]*b[3*k+j] } } }
        return c
    }
    public static func rotation(_ angles: [Double]) -> [Double] {
        let z = angles[0], y = angles[1], x = angles[2]
        let rz = [cosine(z), -sine(z), 0, sine(z), cosine(z), 0, 0, 0, 1]
        let ry = [cosine(y), 0, sine(y), 0, 1, 0, -sine(y), 0, cosine(y)]
        let rx = [1, 0, 0, 0, cosine(x), -sine(x), 0, sine(x), cosine(x)]
        return multiply([0, -1, 0, 1, 0, 0, 0, 0, 1], multiply(multiply(rz, ry), rx))
    }
    public static func apply(_ r: [Double], _ v: [Double]) -> [Double] {
        (0..<3).map { i in r[3*i]*v[0]+r[3*i+1]*v[1]+r[3*i+2]*v[2] }
    }
    public static func point(_ q: [Double], local: [Double], rotating: Bool, redundant: Bool = false) -> [Double] {
        let r = rotation(rotating ? Array(q[3..<6]) : [0, 0, 0])
        let offset = apply(r, local)
        let x = q[0]+(redundant ? q[3] : 0)-0.1, y = q[1]-0.2, z = q[2]+0.1
        return [1-y+offset[0], -2+x+offset[1], 0.5+z+offset[2]]
    }
}
