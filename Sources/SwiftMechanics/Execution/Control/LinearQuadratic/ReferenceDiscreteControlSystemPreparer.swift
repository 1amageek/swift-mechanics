public struct ReferenceDiscreteControlSystemPreparer: DiscreteControlSystemPreparing, Sendable {
    public let linear: any LinearSolving<Double>
    public init(linear: any LinearSolving<Double> = ReferenceLinearSolver<Double>()) { self.linear = linear }
    public func analytic(identity: String, samplePeriodSeconds: Double, stateDimensions: [PhysicalDimension], inputDimensions: [PhysicalDimension],
                         stateScales: [Double], inputScales: [Double], stateMatrix: [Double], inputMatrix: [Double],
                         policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> DiscreteControlSystem {
        do {
            _ = try LinearQuadraticArithmetic.reserve(states: stateDimensions.count, inputs: inputDimensions.count, policy: policy, work: &work)
            try admit(identity: identity, period: samplePeriodSeconds, n: stateDimensions.count, m: inputDimensions.count,
                      scales: stateScales, inputScales: inputScales, a: stateMatrix, b: inputMatrix, policy: policy, work: &work)
            try LinearQuadraticArithmetic.check(policy, work: work)
            return DiscreteControlSystem(identity: identity, samplePeriodSeconds: samplePeriodSeconds,
                stateDimensions: stateDimensions, inputDimensions: inputDimensions, stateScales: stateScales, inputScales: inputScales,
                stateMatrix: stateMatrix, inputMatrix: inputMatrix, provenance: .analytic(identity: identity))
        } catch { throw error.retaining(work) }
    }
    public func bilinear(_ source: EquilibriumLinearization, identity: String, samplePeriodSeconds: Double, stateScales: [Double],
                         inputDimension: PhysicalDimension, inputScale: Double, parameterChangePerInputUnit: Double,
                         policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> DiscreteControlSystem {
        do throws(LinearQuadraticFailure) {
            let k = source.reduction.freeCoordinates
            let n = try LinearQuadraticArithmetic.size(2, k)
            let basicReserve = try LinearQuadraticArithmetic.reserve(states: n, inputs: 1, policy: policy, work: &work)
            let reserve = try LinearQuadraticArithmetic.retainingSource(source, reserve: basicReserve, policy: policy, work: &work)
            guard source.operatingPoint.model.chart.count <= policy.maximumStates,
                  stateScales.count == n, source.stateMatrix.count == (try LinearQuadraticArithmetic.size(n, n)),
                  source.inputMatrix.count == n, parameterChangePerInputUnit.isFinite, parameterChangePerInputUnit != 0,
                  inputScale.isFinite, inputScale > 0, samplePeriodSeconds.isFinite, samplePeriodSeconds > 0,
                  source.maximumDirectionalError.isFinite, source.maximumDirectionalError >= 0,
                  source.maximumInertialError.isFinite, source.maximumInertialError >= 0 else {
                throw LinearQuadraticFailure(.invalidInput, phase: "linearization")
            }
            try LinearQuadraticArithmetic.metadata(identity, policy: policy, work: &work)
            for name in [source.operatingPoint.model.identity, source.operatingPoint.model.parameterIdentity,
                         source.operatingPoint.model.chart.stamp.identity] {
                try LinearQuadraticArithmetic.metadata(name, policy: policy, work: &work)
            }
            try LinearQuadraticArithmetic.finite(source.stateMatrix, policy: policy, work: &work)
            try LinearQuadraticArithmetic.finite(source.inputMatrix, policy: policy, work: &work)
            try LinearQuadraticArithmetic.finite(stateScales, policy: policy, work: &work)
            guard stateScales.allSatisfy({ $0 > 0 }) else { throw LinearQuadraticFailure(.invalidInput, phase: "scales") }
            var left = [Double](repeating: 0, count: source.stateMatrix.count), right = left
            try LinearQuadraticArithmetic.charge(try LinearQuadraticArithmetic.size(8, left.count), policy: policy, work: &work)
            for i in 0..<n { for j in 0..<n {
                let entry = samplePeriodSeconds*0.5*source.stateMatrix[i*n+j]*(stateScales[j]/stateScales[i])
                left[i*n+j] = (i == j ? 1 : 0)-entry
                right[i*n+j] = (i == j ? 1 : 0)+entry
            } }
            var a = left, b = [Double](repeating: 0, count: n), rhs = b
            for j in 0..<n {
                for i in 0..<n { rhs[i] = right[i*n+j] }
                let column = try LinearQuadraticArithmetic.solve(left, dimension: n, rhs: rhs, algorithm: .partialPivotLU,
                    linear: linear, reserve: reserve, policy: policy, work: &work)
                for i in 0..<n { a[i*n+j] = column[i] }
            }
            try LinearQuadraticArithmetic.charge(try LinearQuadraticArithmetic.size(5, n), policy: policy, work: &work)
            for i in 0..<n { rhs[i] = samplePeriodSeconds*source.inputMatrix[i]*parameterChangePerInputUnit*inputScale/stateScales[i] }
            b = try LinearQuadraticArithmetic.solve(left, dimension: n, rhs: rhs, algorithm: .partialPivotLU,
                linear: linear, reserve: reserve, policy: policy, work: &work)
            let dimensions = [PhysicalDimension](repeating: .dimensionless, count: k)+[PhysicalDimension](repeating: PhysicalDimension(time: -1), count: k)
            try admit(identity: identity, period: samplePeriodSeconds, n: n, m: 1, scales: stateScales, inputScales: [inputScale],
                a: a, b: b, policy: policy, work: &work)
            try LinearQuadraticArithmetic.check(policy, work: work)
            return DiscreteControlSystem(identity: identity, samplePeriodSeconds: samplePeriodSeconds, stateDimensions: dimensions,
                inputDimensions: [inputDimension], stateScales: stateScales, inputScales: [inputScale], stateMatrix: a, inputMatrix: b,
                provenance: .equilibriumBilinear(source: source, parameterChangePerInputUnit: parameterChangePerInputUnit))
        } catch { throw error.retaining(work) }
    }
    private func admit(identity: String, period: Double, n: Int, m: Int, scales: [Double], inputScales: [Double], a: [Double], b: [Double],
                       policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) {
        try LinearQuadraticArithmetic.metadata(identity, policy: policy, work: &work)
        guard period.isFinite, period > 0, scales.count == n, inputScales.count == m,
              a.count == (try LinearQuadraticArithmetic.size(n, n)), b.count == (try LinearQuadraticArithmetic.size(n, m)) else {
            throw LinearQuadraticFailure(.invalidInput, phase: "system")
        }
        for array in [a, b, scales, inputScales] { try LinearQuadraticArithmetic.finite(array, policy: policy, work: &work) }
        guard scales.allSatisfy({ $0 > 0 }), inputScales.allSatisfy({ $0 > 0 }) else {
            throw LinearQuadraticFailure(.invalidInput, phase: "scales")
        }
    }
}
