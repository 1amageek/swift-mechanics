import MechanicsNumerics

public struct ReferenceNonlinearSolver<Scalar: NumericalScalar>: NonlinearSolving, Sendable {
    public init() {}

    public func solve(_ equations: any NonlinearEquations<Scalar>, initialPoint: [Scalar], policy: NonlinearPolicy<Scalar>) throws(NonlinearFailure<Scalar>) -> NonlinearSolution<Scalar> {
        var context = NonlinearContext<Scalar>(equationIdentity: equations.identity, coordinateCount: equations.coordinateCount, work: NumericalWork(budget: policy.budget), point: initialPoint)
        do { return try run(equations, policy: policy, context: &context) }
        catch {
            throw NonlinearFailure(equationIdentity: context.equationIdentity, capability: policy.capability, phase: context.phase,
                cause: error, lastResidual: context.lastResidual, lastIterate: context.point, failedSupplierWorkUnavailable: context.failedSupplierWorkUnavailable, work: context.work)
        }
    }

    private func run(_ equations: any NonlinearEquations<Scalar>, policy: NonlinearPolicy<Scalar>, context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> NonlinearSolution<Scalar> {
        let n = ctx.coordinateCount
        guard n > 0, ctx.point.count == n else { throw .numerical(.invalidDimensions) }
        guard ctx.point.allSatisfy({ $0.isFinite }) else { throw .numerical(.nonFiniteInput) }
        try ctx.checkCancellation()
        do { try policy.capability.validate(for: Scalar.self, algorithms: [.partialPivotLU]) } catch { throw .numerical(error) }
        let entries = try product(n,n)
        try ctx.reserve(try product(6,n))
        var residual = [Scalar](repeating: 0, count: n)
        var original = [Scalar](repeating: 0, count: n)
        ctx.phase = .initialResidual
        try evaluate(equations, at: ctx.point, into: &residual, original: false, context: &ctx)
        var norm = try infinityNorm(residual, context: &ctx)
        ctx.lastResidual = norm
        let threshold: Scalar
        try ctx.charge(2)
        do { threshold = try policy.tolerance.threshold(scale: policy.referenceScale) } catch { throw .numerical(error) }
        if norm <= threshold { return try finish(equations, residual: residual, original: &original, policy: policy, threshold: threshold, context: &ctx) }

        ctx.phase = .workspace
        let reserved = try sum(entries, product(12,n))
        try ctx.reserve(reserved)
        var jacobian = [Scalar](repeating: 0, count: entries)
        var rhs = [Scalar](repeating: 0, count: n)
        var candidate = [Scalar](repeating: 0, count: n)
        var trialResidual = [Scalar](repeating: 0, count: n)
        var probePoint = [Scalar](repeating: 0, count: n)
        var probeResidual = [Scalar](repeating: 0, count: n)
        var image = [Scalar](repeating: 0, count: n)
        var conditioningColumn = [Scalar](repeating: 0, count: n)
        ctx.tangentPoint = [Scalar](repeating: 0, count: n)
        var radius: Scalar = 0
        if case .trustRegion(let initial, _, _, _, _, _, _, _) = policy.strategy { radius = initial }

        while true {
            ctx.phase = .iteration
            try ctx.advance(); ctx.nonlinearIterations += 1
            ctx.phase = .jacobian
            try ctx.checkCancellation()
            try checkMetadata(equations, context: ctx)
            ctx.jacobianEvaluations += 1
            for i in jacobian.indices { jacobian[i] = .nan }
            try equations.jacobian(at: ctx.point, into: &jacobian, work: &ctx.work)
            try ctx.checkCancellation()
            try checkMetadata(equations, context: ctx)
            guard jacobian.count == entries, jacobian.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
            for i in 0..<n { ctx.tangentPoint[i] = ctx.point[i] }
            ctx.phase = .linearSolve
            guard entries <= policy.maximumFactorEntries else { throw .denseFillLimit(required: entries, limit: policy.maximumFactorEntries) }
            let matrix: DenseMatrix<Scalar>
            do { matrix = try DenseMatrix(rows: n, columns: n, values: jacobian) } catch { throw .numerical(error) }
            try ctx.charge(n)
            for i in 0..<n { rhs[i] = -residual[i] }
            let linear = try linearSolve(matrix, rhs: rhs, policy: policy, reserved: reserved, context: &ctx)
            ctx.tangentRank = linear.diagnostics.numericalRank
            let direction = linear.values
            let directionNorm = try euclideanNorm(direction, context: &ctx)
            guard directionNorm > policy.minimumDirectionNorm else { throw .noAcceptableStep }
            ctx.phase = .conditioning
            if policy.estimateCondition {
                ctx.condition = .available(try condition(matrix, column: &conditioningColumn, policy: policy, reserved: reserved, context: &ctx))
            } else { ctx.condition = .unavailable(.notRequested) }

            try ctx.charge(try product(2, entries))
            for i in 0..<n {
                var value: Scalar = 0
                for j in 0..<n { value += jacobian[i*n+j] * direction[j] }
                guard value.isFinite else { throw .numerical(.nonFiniteResult) }
                image[i] = value
            }
            ctx.phase = .derivativeProbe
            let divisor = max(1,directionNorm)
            try ctx.charge(try product(3,n))
            for i in 0..<n {
                probePoint[i] = ctx.point[i] + policy.derivativeProbeDistance * (direction[i]/divisor)
                guard probePoint[i].isFinite else { throw .numerical(.nonFiniteResult) }
            }
            try evaluate(equations, at: probePoint, into: &probeResidual, original: false, context: &ctx)
            try ctx.charge(try product(7,n))
            for i in 0..<n {
                let observed = (probeResidual[i]-residual[i]) / policy.derivativeProbeDistance
                let predicted = image[i]/divisor
                let error = abs(observed-predicted)
                let allowed = policy.derivativeAbsoluteTolerance + policy.derivativeRelativeTolerance * max(abs(observed),abs(predicted))
                guard observed.isFinite, predicted.isFinite, error.isFinite, allowed.isFinite else { throw .numerical(.nonFiniteResult) }
                guard error <= allowed else { throw .invalidDerivative(error: Double(error), threshold: Double(allowed)) }
            }

            let currentMerit = try merit(residual, context: &ctx)
            try ctx.charge(try product(2,n))
            var directionalMerit: Scalar = 0
            for i in 0..<n { directionalMerit += residual[i] * image[i] }
            guard directionalMerit.isFinite else { throw .numerical(.nonFiniteResult) }
            guard directionalMerit < 0 else { throw .noAcceptableStep }
            var fraction: Scalar = 1
            while true {
                ctx.phase = .trial
                try ctx.advance()
                if case .trustRegion = policy.strategy { try ctx.charge(1); fraction = min(1,radius/directionNorm) }
                guard fraction.isFinite, fraction > 0 else { throw .noAcceptableStep }
                ctx.lastStepFraction = fraction
                try ctx.charge(try product(2,n))
                for i in 0..<n {
                    candidate[i] = ctx.point[i] + fraction*direction[i]
                    guard candidate[i].isFinite else { throw .numerical(.nonFiniteResult) }
                }
                var inDomain = true
                do { try evaluate(equations, at: candidate, into: &trialResidual, original: false, context: &ctx) }
                catch {
                    if case .equation(.outsideDomain) = error { inDomain = false }
                    else { throw error }
                }
                var accepted = false
                if inDomain {
                    let candidateMerit = try merit(trialResidual, context: &ctx)
                    switch policy.strategy {
                    case .newton: accepted = true
                    case .lineSearch(_,let sufficient,_):
                        try ctx.charge(3)
                        let bound = currentMerit + sufficient*fraction*directionalMerit
                        guard bound.isFinite else { throw .numerical(.nonFiniteResult) }
                        accepted = candidateMerit <= bound
                    case .trustRegion(_,_,_,let accept,_,_,_,_):
                        try ctx.charge(try product(5,n))
                        var predictedMerit: Scalar = 0
                        for i in 0..<n {
                            let value = residual[i]+fraction*image[i]
                            predictedMerit += value*value/2
                        }
                        try ctx.charge(3)
                        let decrease = currentMerit-predictedMerit
                        guard decrease.isFinite, decrease > 0 else { throw .noAcceptableStep }
                        let ratio = (currentMerit-candidateMerit)/decrease
                        guard ratio.isFinite else { throw .numerical(.nonFiniteResult) }
                        ctx.lastTrustRatio = ratio
                        accepted = ratio >= accept
                    }
                }
                if accepted {
                    ctx.acceptedSteps += 1
                    for i in 0..<n { ctx.point[i] = candidate[i]; residual[i] = trialResidual[i] }
                    norm = try infinityNorm(residual, context: &ctx); ctx.lastResidual = norm
                    if case .trustRegion(_,let minimum,let maximum,_,let shrink,let grow,let contraction,let expansion) = policy.strategy,
                       let ratio = ctx.lastTrustRatio {
                        if ratio < shrink { try ctx.charge(1); radius = max(minimum,radius*contraction) }
                        else if ratio > grow && fraction < 1 {
                            try ctx.charge(1)
                            let expanded = radius*expansion
                            guard expanded.isFinite else { throw .numerical(.nonFiniteResult) }
                            radius = min(maximum,expanded)
                        }
                    }
                    break
                }
                ctx.rejectedSteps += 1
                switch policy.strategy {
                case .newton: throw .equation(.outsideDomain)
                case .lineSearch(let contraction,_,let minimum):
                    try ctx.charge(1); fraction *= contraction
                    guard fraction.isFinite, fraction >= minimum else { throw .noAcceptableStep }
                case .trustRegion(_,let minimum,_,_,_,_,let contraction,_):
                    try ctx.charge(1); radius *= contraction
                    guard radius.isFinite, radius >= minimum else { throw .noAcceptableStep }
                }
            }
            if norm <= threshold { return try finish(equations, residual: residual, original: &original, policy: policy, threshold: threshold, context: &ctx) }
        }
    }

    private func finish(_ equations: any NonlinearEquations<Scalar>, residual: [Scalar], original: inout [Scalar], policy: NonlinearPolicy<Scalar>, threshold: Scalar, context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> NonlinearSolution<Scalar> {
        ctx.phase = .originalAcceptance
        try evaluate(equations, at: ctx.point, into: &original, original: true, context: &ctx)
        let originalNorm = try infinityNorm(original, context: &ctx)
        guard let internalNorm = ctx.lastResidual else { throw .invalidEvaluation }
        guard originalNorm <= threshold, internalNorm <= threshold else {
            throw .originalResidualDisagreement(internalNorm: Double(internalNorm), originalNorm: Double(originalNorm), threshold: Double(threshold))
        }
        let internalEvidence: ResidualEvidence<Scalar>, originalEvidence: ResidualEvidence<Scalar>
        do {
            internalEvidence = try ResidualEvidence(infinityNorm: internalNorm, referenceScale: policy.referenceScale, threshold: threshold)
            originalEvidence = try ResidualEvidence(infinityNorm: originalNorm, referenceScale: policy.referenceScale, threshold: threshold)
        } catch { throw .numerical(error) }
        return NonlinearSolution(values: ctx.point, internalResidual: internalEvidence, originalResidual: originalEvidence,
            diagnostics: NonlinearDiagnostics(nonlinearIterations: ctx.nonlinearIterations, acceptedSteps: ctx.acceptedSteps,
                rejectedSteps: ctx.rejectedSteps, residualEvaluations: ctx.residualEvaluations, jacobianEvaluations: ctx.jacobianEvaluations,
                originalEvaluations: ctx.originalEvaluations, tangentPoint: ctx.tangentRank == nil ? nil : ctx.tangentPoint,
                tangentRank: ctx.tangentRank, conditionOneNorm: ctx.condition, activeSetChanges: .notDefinedByEquationProvider,
                constraintRank: .notDefinedByEquationProvider, feasibility: .notDefinedByEquationProvider,
                optimality: .notDefinedByEquationProvider, lastStepFraction: ctx.lastStepFraction, lastTrustRatio: ctx.lastTrustRatio, work: ctx.work))
    }

    private func evaluate(_ equations: any NonlinearEquations<Scalar>, at point: [Scalar], into output: inout [Scalar], original: Bool, context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) {
        try ctx.checkCancellation()
        try checkMetadata(equations, context: ctx)
        guard point.count == ctx.coordinateCount, output.count == ctx.coordinateCount else { throw .invalidEvaluation }
        try equations.validateDomain(at: point, work: &ctx.work)
        try ctx.checkCancellation()
        try checkMetadata(equations, context: ctx)
        for i in output.indices { output[i] = .nan }
        if original { ctx.originalEvaluations += 1; try equations.originalResidual(at: point, into: &output, work: &ctx.work) }
        else { ctx.residualEvaluations += 1; try equations.residual(at: point, into: &output, work: &ctx.work) }
        try ctx.checkCancellation()
        try checkMetadata(equations, context: ctx)
        guard output.count == ctx.coordinateCount, output.allSatisfy({ $0.isFinite }) else { throw .invalidEvaluation }
    }

    private func checkMetadata(_ equations: any NonlinearEquations<Scalar>, context ctx: NonlinearContext<Scalar>) throws(NonlinearCause) {
        guard equations.coordinateCount == ctx.coordinateCount, equations.identity == ctx.equationIdentity else { throw .equationMetadataChanged }
    }

    private func linearSolve(_ matrix: DenseMatrix<Scalar>, rhs: [Scalar], policy: NonlinearPolicy<Scalar>, reserved: Int, context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> LinearSolution<Scalar> {
        do {
            let result = try ReferenceLinearSolver<Scalar>().solve(matrix, rightHandSide: rhs, capability: policy.capability,
                tolerance: policy.tolerance, budget: ctx.work.remainingBudget(reservedStorage: reserved))
            try ctx.work.absorb(result.diagnostics.work, reservedStorage: reserved)
            return result
        } catch {
            ctx.failedSupplierWorkUnavailable = true
            throw .numerical(error)
        }
    }

    private func condition(_ matrix: DenseMatrix<Scalar>, column: inout [Scalar], policy: NonlinearPolicy<Scalar>, reserved: Int, context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> Scalar {
        let n = matrix.rowCount
        var norm: Scalar = 0, inverseNorm: Scalar = 0
        for j in 0..<n {
            try ctx.charge(n)
            var sum: Scalar = 0
            for i in 0..<n {
                do { sum += abs(try matrix.coefficient(row: i, column: j)) } catch { throw .numerical(error) }
                column[i] = i == j ? 1 : 0
            }
            guard sum.isFinite else { throw .numerical(.nonFiniteResult) }
            norm = max(norm,sum)
            let solved = try linearSolve(matrix, rhs: column, policy: policy, reserved: reserved, context: &ctx)
            try ctx.charge(n)
            var inverseSum: Scalar = 0
            for i in 0..<n { inverseSum += abs(solved.values[i]) }
            guard inverseSum.isFinite else { throw .numerical(.nonFiniteResult) }
            inverseNorm = max(inverseNorm,inverseSum)
        }
        try ctx.charge(1)
        let estimate = norm*inverseNorm
        guard estimate.isFinite else { throw .numerical(.nonFiniteResult) }
        return estimate
    }

    private func infinityNorm(_ vector: [Scalar], context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> Scalar {
        try ctx.charge(vector.count)
        var result: Scalar = 0
        for value in vector { result = max(result,abs(value)) }
        guard result.isFinite else { throw .numerical(.nonFiniteResult) }
        return result
    }
    private func euclideanNorm(_ vector: [Scalar], context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> Scalar {
        try ctx.charge(try sum(product(2,vector.count),1))
        var sum: Scalar = 0
        for value in vector { sum += value*value }
        let result = sum.squareRoot()
        guard result.isFinite else { throw .numerical(.nonFiniteResult) }
        return result
    }
    private func merit(_ vector: [Scalar], context ctx: inout NonlinearContext<Scalar>) throws(NonlinearCause) -> Scalar {
        let norm = try euclideanNorm(vector, context: &ctx)
        try ctx.charge(2)
        let result = norm*norm/2
        guard result.isFinite else { throw .numerical(.nonFiniteResult) }
        return result
    }
    private func product(_ a: Int, _ b: Int) throws(NonlinearCause) -> Int {
        do { return try NumericalWork.product(a,b) } catch { throw .numerical(error) }
    }
    private func sum(_ a: Int, _ b: Int) throws(NonlinearCause) -> Int {
        do { return try NumericalWork.sum(a,b) } catch { throw .numerical(error) }
    }
}
