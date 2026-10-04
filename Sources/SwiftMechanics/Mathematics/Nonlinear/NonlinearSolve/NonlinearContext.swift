
struct NonlinearContext<Scalar: NumericalScalar> {
    let equationIdentity: String
    let coordinateCount: Int
    var work: NumericalWork
    var failedSupplierWorkUnavailable = false
    var phase: NonlinearPhase = .validation
    var lastResidual: Scalar?
    var point: [Scalar]
    var nonlinearIterations = 0
    var acceptedSteps = 0
    var rejectedSteps = 0
    var residualEvaluations = 0
    var jacobianEvaluations = 0
    var originalEvaluations = 0
    var tangentPoint: [Scalar] = []
    var tangentRank: Int?
    var condition: NonlinearMetric<Scalar> = .unavailable(.noTangentEvaluated)
    var lastStepFraction: Scalar?
    var lastTrustRatio: Scalar?
    mutating func charge(_ count: Int) throws(NonlinearCause) {
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    mutating func reserve(_ count: Int) throws(NonlinearCause) {
        do { try work.requireStorage(count) } catch { throw .numerical(error) }
    }
    mutating func advance() throws(NonlinearCause) {
        do { try work.advanceIteration() } catch { throw .numerical(error) }
    }
    func checkCancellation() throws(NonlinearCause) {
        guard !Task.isCancelled else { throw .numerical(.cancelled) }
    }
}
