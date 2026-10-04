internal final class DenseConvexProgram: Sendable {
    let n: Int, r: Int, m: Int, userInequalities: Int
    let cost: [Double], constant: Double, hessian: [Double]?
    let equality: [Double], equalityRHS: [Double]
    let inequality: [Double], inequalityRHS: [Double]
    let lower: [Double], upper: [Double]
    init(n: Int,r: Int,m: Int,userInequalities: Int,cost: [Double],constant: Double,hessian: [Double]?,equality: [Double],equalityRHS: [Double],
        inequality: [Double],inequalityRHS: [Double],lower: [Double],upper: [Double]) {
        self.n=n; self.r=r; self.m=m; self.userInequalities=userInequalities; self.cost=cost; self.constant=constant; self.hessian=hessian
        self.equality=equality; self.equalityRHS=equalityRHS; self.inequality=inequality; self.inequalityRHS=inequalityRHS; self.lower=lower; self.upper=upper
    }
}
