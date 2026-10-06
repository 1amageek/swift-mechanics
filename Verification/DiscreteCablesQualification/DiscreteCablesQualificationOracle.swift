internal enum DiscreteCablesQualificationOracle {
    // Independent scalar implementation: no CableJet, producer norm, returned force or tangent.
    static func dot(_ a: [Double], _ b: [Double]) -> Double {
        var result = 0.0; for i in a.indices { result += a[i]*b[i] }; return result
    }
    static func edge(_ x: [Double], _ first: Int, _ second: Int) -> [Double] {
        (0..<3).map { x[3*second+$0]-x[3*first+$0] }
    }
    static func length(_ a: [Double]) -> Double { dot(a,a).squareRoot() }
    static func cross(_ a: [Double], _ b: [Double]) -> [Double] {
        [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    }
    static func energy(_ x: [Double], rest: [Double], bend: Double = 3, unilateral: Bool = false) -> Double {
        let n = x.count/3; var result = 0.0
        for i in 0..<n-1 {
            let l0 = length(edge(rest,i,i+1)), l = length(edge(x,i,i+1))
            let extensionValue = unilateral ? max(l-l0,0) : l-l0
            result += 30/l0*extensionValue*extensionValue
        }
        for i in 1..<n-1 {
            let a = edge(x,i-1,i), b = edge(x,i,i+1)
            let dual = 0.5*(length(edge(rest,i-1,i))+length(edge(rest,i,i+1)))
            result += bend/dual*(1-dot(a,b)/(length(a)*length(b)))
        }
        return result
    }
    static func force(_ x: [Double], rest: [Double], bend: Double = 3, unilateral: Bool = false) -> [Double] {
        let n = x.count/3; var f = [Double](repeating: 0,count: x.count)
        for i in 0..<n-1 {
            let a = edge(x,i,i+1), l = length(a), l0 = length(edge(rest,i,i+1))
            let extensionValue = unilateral ? max(l-l0,0) : l-l0
            for axis in 0..<3 { let value = 60/l0*extensionValue*a[axis]/l; f[3*i+axis] += value; f[3*(i+1)+axis] -= value }
        }
        for i in 1..<n-1 {
            let a = edge(x,i-1,i), b = edge(x,i,i+1), la = length(a), lb = length(b)
            let c = dot(a,b)/(la*lb)
            let dual = 0.5*(length(edge(rest,i-1,i))+length(edge(rest,i,i+1)))
            for axis in 0..<3 {
                let da = (b[axis]/lb-c*a[axis]/la)/la
                let db = (a[axis]/la-c*b[axis]/lb)/lb
                let factor = bend/dual
                f[3*(i-1)+axis] -= factor*da
                f[3*i+axis] += factor*(da-db)
                f[3*(i+1)+axis] += factor*db
            }
        }
        return f
    }
    static func action(_ k: [Double], _ q: [Double]) -> [Double] {
        var result = [Double](repeating: 0,count: q.count)
        for i in q.indices { for j in q.indices { result[i] += k[i*q.count+j]*q[j] } }; return result
    }
    static func rotate(_ flat: [Double], translate: Bool = false) -> [Double] {
        var result: [Double] = []
        for i in stride(from: 0,to: flat.count,by: 3) {
            result += [-flat[i+1]+(translate ? 2 : 0),flat[i+2]+(translate ? 3 : 0),-flat[i]+(translate ? 4 : 0)]
        }
        return result
    }
    static func momentum(_ x: [Double], _ v: [Double], mass: [Double], angular: Bool) -> [Double] {
        var result = [0.0,0,0]
        for i in mass.indices {
            let p = [mass[i]*v[3*i],mass[i]*v[3*i+1],mass[i]*v[3*i+2]]
            let contribution = angular ? cross([x[3*i],x[3*i+1],x[3*i+2]],p) : p
            for axis in 0..<3 { result[axis] += contribution[axis] }
        }
        return result
    }
}
