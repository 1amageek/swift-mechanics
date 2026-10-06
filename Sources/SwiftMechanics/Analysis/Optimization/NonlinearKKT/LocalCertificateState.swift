internal final class LocalCertificateState: Sendable {
    let point: [Double],equalities: [Double],inequalities: [Double],values: NonlinearProgramValues<Double>,activeJacobian: [Double]
    let primal: Double,dual: Double,stationarity: Double,complementarity: Double
    let primalThreshold: Double,dualThreshold: Double,stationarityThreshold: Double,complementarityThreshold: Double
    init(point: [Double],equalities: [Double],inequalities: [Double],values: NonlinearProgramValues<Double>,activeJacobian: [Double],
        primal: Double,dual: Double,stationarity: Double,complementarity: Double,primalThreshold: Double,dualThreshold: Double,stationarityThreshold: Double,complementarityThreshold: Double) {
        self.point=point; self.equalities=equalities; self.inequalities=inequalities; self.values=values; self.activeJacobian=activeJacobian
        self.primal=primal; self.dual=dual; self.stationarity=stationarity; self.complementarity=complementarity
        self.primalThreshold=primalThreshold; self.dualThreshold=dualThreshold; self.stationarityThreshold=stationarityThreshold; self.complementarityThreshold=complementarityThreshold
    }
}
