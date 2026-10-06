public enum NonlinearEstimationQualificationOracle {
    public static func acceleration(_ q: Double, _ v: Double, effort: Double = 1.5) -> Double {
        let displacement = q-0.1
        return (effort-3*displacement-2*displacement*displacement*displacement-0.4*v-0.6*v*v*v)/2
    }
    public static func rk4(position: Double, rate: Double, interval: Double, steps: Int) -> [Double] {
        var q = position, v = rate
        let h = interval/Double(steps)
        for _ in 0..<steps {
            let k1q = v, k1v = acceleration(q,v)
            let k2q = v+h*k1v/2, k2v = acceleration(q+h*k1q/2,v+h*k1v/2)
            let k3q = v+h*k2v/2, k3v = acceleration(q+h*k2q/2,v+h*k2v/2)
            let k4q = v+h*k3v, k4v = acceleration(q+h*k3q,v+h*k3v)
            q += h*(k1q+2*k2q+2*k3q+k4q)/6
            v += h*(k1v+2*k2v+2*k3v+k4v)/6
        }
        return [q,v]
    }
    public static func covariance(_ f: [Double], _ p: [Double], _ q: [Double]) -> [Double] {
        var result = q
        for i in 0..<2 { for j in 0..<2 {
            for k in 0..<2 { for l in 0..<2 { result[2*i+j] += f[2*i+k]*p[2*k+l]*f[2*j+l] } }
        } }
        return result
    }
    public static func physical(_ p: [Double], scales: [Double]) -> [Double] {
        [p[0]*scales[0]*scales[0],p[1]*scales[0]*scales[1],p[2]*scales[1]*scales[0],p[3]*scales[1]*scales[1]]
    }
}
