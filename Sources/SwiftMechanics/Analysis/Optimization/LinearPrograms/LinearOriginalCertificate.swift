/// Re-evaluates original data independently of the mutated simplex tableau.
internal enum LinearOriginalCertificate {
    static func rowProduct(_ row: Int, point: [Double], rows: LinearOriginalRows,
                           policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> (value: Double, scale: Double) {
        try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(3, rows.variableCount), policy: policy, work: &work)
        var value: Double = 0, scale: Double = 0
        for j in 0..<rows.variableCount {
            let product = try LinearProgramArithmetic.finite(rows.coefficients[row*rows.variableCount+j]*point[j])
            value = try LinearProgramArithmetic.finite(value+product); scale = try LinearProgramArithmetic.finite(scale+abs(product))
        }
        return (value, scale)
    }

    static func primal(_ point: [Double], rows: LinearOriginalRows, strict: Bool,
                       policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> Double {
        var maximum: Double = 0
        for r in 0..<rows.count {
            let product = try rowProduct(r, point: point, rows: rows, policy: policy, work: &work)
            let error = try LinearProgramArithmetic.finite(product.value-rows.rightHandSide[r])
            let equality = r < rows.equalityCount
            if strict { guard equality ? error == 0 : error <= 0 else { throw .certificateRejected } }
            let scale = try LinearProgramArithmetic.finite(product.scale+abs(rows.rightHandSide[r]))
            maximum = max(maximum, try LinearProgramArithmetic.residual(equality ? error : max(0, error), scale: scale, tolerance: policy.certificateTolerance))
        }
        return maximum
    }

    static func objective(_ point: [Double], problem: GeneralLinearProgram, policy: LinearProgramPolicy,
                          work: inout NumericalWork) throws(LinearProgramCause) -> (value: Double, scale: Double) {
        var value: Double = 0, scale: Double = 0
        try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(3, point.count), policy: policy, work: &work)
        for j in 0..<point.count {
            let product = try LinearProgramArithmetic.finite(problem.linearCost[j]*point[j])
            value = try LinearProgramArithmetic.finite(value+product); scale = try LinearProgramArithmetic.finite(scale+abs(product))
        }
        return (value, scale)
    }

    static func physical(_ point: [Double], problem: GeneralLinearProgram, policy: LinearProgramPolicy,
                         work: inout NumericalWork) throws(LinearProgramCause) -> [Double] {
        try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(2, point.count), policy: policy, work: &work)
        var output = [Double](repeating: 0, count: point.count)
        for j in 0..<point.count { output[j] = try LinearProgramArithmetic.finite(point[j]*problem.metadata.variableReferences[j].magnitude) }
        return output
    }

    static func multipliers(_ values: [Double], rows: LinearOriginalRows, problem: GeneralLinearProgram,
                            policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> [LinearRowMultiplier] {
        var output = [LinearRowMultiplier](); output.reserveCapacity(rows.count)
        for r in 0..<rows.count {
            try LinearProgramArithmetic.charge(2, policy: policy, work: &work)
            let physical = try LinearProgramArithmetic.finite(values[r]*(problem.metadata.objectiveReference.magnitude/rows.references[r].magnitude))
            output.append(LinearRowMultiplier(row: rows.origins[r], normalized: values[r], physicalValue: physical,
                                             rowReference: rows.references[r], objectiveReference: problem.metadata.objectiveReference))
        }
        return output
    }

    static func optimal(point: [Double], weights: [Double], rows: LinearOriginalRows, problem: GeneralLinearProgram,
                        policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> LinearOptimalCertificate {
        var maximum = try primal(point, rows: rows, strict: false, policy: policy, work: &work)
        for r in 0..<rows.count {
            try LinearProgramArithmetic.charge(3, policy: policy, work: &work)
            guard weights[r].isFinite, r < rows.equalityCount || weights[r] >= 0 else { throw .certificateRejected }
            if r >= rows.equalityCount {
                let product = try rowProduct(r, point: point, rows: rows, policy: policy, work: &work)
                let slack = try LinearProgramArithmetic.finite(product.value-rows.rightHandSide[r])
                let complementarity = try LinearProgramArithmetic.finite(weights[r]*slack)
                let scale = try LinearProgramArithmetic.finite(abs(weights[r])*(product.scale+abs(rows.rightHandSide[r])))
                maximum = max(maximum, try LinearProgramArithmetic.residual(complementarity, scale: scale, tolerance: policy.certificateTolerance))
            }
        }
        for j in 0..<rows.variableCount {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(3, rows.count), policy: policy, work: &work)
            var stationarity = problem.linearCost[j], scale = abs(stationarity)
            for r in 0..<rows.count {
                let product = try LinearProgramArithmetic.finite(rows.coefficients[r*rows.variableCount+j]*weights[r])
                stationarity = try LinearProgramArithmetic.finite(stationarity+product); scale = try LinearProgramArithmetic.finite(scale+abs(product))
            }
            maximum = max(maximum, try LinearProgramArithmetic.residual(stationarity, scale: scale, tolerance: policy.certificateTolerance))
        }
        let cost = try objective(point, problem: problem, policy: policy, work: &work)
        var rhs: Double = 0, rhsScale: Double = 0
        for r in 0..<rows.count {
            try LinearProgramArithmetic.charge(3, policy: policy, work: &work)
            let product = try LinearProgramArithmetic.finite(weights[r]*rows.rightHandSide[r])
            rhs = try LinearProgramArithmetic.finite(rhs+product); rhsScale = try LinearProgramArithmetic.finite(rhsScale+abs(product))
        }
        let gap = try LinearProgramArithmetic.finite(cost.value+rhs)
        maximum = max(maximum, try LinearProgramArithmetic.residual(gap, scale: try LinearProgramArithmetic.finite(cost.scale+rhsScale), tolerance: policy.certificateTolerance))
        let value = try LinearProgramArithmetic.finite(problem.constantCost+cost.value)
        let physicalValue = try LinearProgramArithmetic.finite(problem.metadata.objectiveReference.magnitude*value)
        let physicalPoint = try physical(point, problem: problem, policy: policy, work: &work)
        let mapped = try multipliers(weights, rows: rows, problem: problem, policy: policy, work: &work)
        return LinearOptimalCertificate(point: point, physicalPoint: physicalPoint, objective: value, physicalObjective: physicalValue,
                                        multipliers: mapped, maximumNormalizedKKTResidual: maximum, primalDualGap: gap)
    }

    static func infeasible(weights: [Double], rows: LinearOriginalRows, problem: GeneralLinearProgram,
                           policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> LinearInfeasibilityCertificate {
        var rhs: Double = 0, rhsScale: Double = 0
        for r in 0..<rows.count {
            try LinearProgramArithmetic.charge(4, policy: policy, work: &work)
            guard weights[r].isFinite, r < rows.equalityCount || weights[r] >= 0 else { throw .certificateRejected }
            let product = try LinearProgramArithmetic.finite(weights[r]*rows.rightHandSide[r])
            rhs = try LinearProgramArithmetic.finite(rhs+product); rhsScale = try LinearProgramArithmetic.finite(rhsScale+abs(product))
        }
        try LinearProgramArithmetic.charge(rows.variableCount, policy: policy, work: &work)
        var normal = [Double](repeating: 0, count: rows.variableCount)
        var lower: Double = 0, lowerScale: Double = 0, maximum: Double = 0
        for j in 0..<rows.variableCount {
            try LinearProgramArithmetic.charge(try LinearProgramArithmetic.product(3, rows.count), policy: policy, work: &work)
            var value: Double = 0, scale: Double = 0
            for r in 0..<rows.count {
                let product = try LinearProgramArithmetic.finite(rows.coefficients[r*rows.variableCount+j]*weights[r])
                value = try LinearProgramArithmetic.finite(value+product); scale = try LinearProgramArithmetic.finite(scale+abs(product))
            }
            maximum = max(maximum, try LinearProgramArithmetic.residual(value, scale: scale, tolerance: policy.certificateTolerance))
            normal[j] = value
            let bound: Double
            if value > 0 {
                guard let actual = problem.bounds[j].lower else { throw .numericalAmbiguity }; bound = actual
            } else if value < 0 {
                guard let actual = problem.bounds[j].upper else { throw .numericalAmbiguity }; bound = actual
            } else { continue }
            let product = try LinearProgramArithmetic.finite(value*bound)
            lower = try LinearProgramArithmetic.finite(lower+product); lowerScale = try LinearProgramArithmetic.finite(lowerScale+abs(product))
        }
        let margin = try LinearProgramArithmetic.finite(lower-rhs)
        guard margin > (try LinearProgramArithmetic.threshold(policy.separationTolerance, scale: try LinearProgramArithmetic.finite(lowerScale+rhsScale))) else { throw .certificateRejected }
        let mapped = try multipliers(weights, rows: rows, problem: problem, policy: policy, work: &work)
        let physicalMargin = try LinearProgramArithmetic.finite(margin*problem.metadata.objectiveReference.magnitude)
        return LinearInfeasibilityCertificate(weights: mapped, combinedNormal: normal, weightedRightHandSide: rhs,
            normalLowerBound: lower, strictSeparationMargin: margin, physicalSeparationMargin: physicalMargin, maximumNormalizedNormalResidual: maximum)
    }

    static func unbounded(point: [Double], direction: [Double], rows: LinearOriginalRows, problem: GeneralLinearProgram,
                          policy: LinearProgramPolicy, work: inout NumericalWork) throws(LinearProgramCause) -> LinearUnboundedCertificate {
        let maximum = try primal(point, rows: rows, strict: true, policy: policy, work: &work)
        for r in 0..<rows.count {
            let product = try rowProduct(r, point: direction, rows: rows, policy: policy, work: &work)
            guard r < rows.equalityCount ? product.value == 0 : product.value <= 0 else { throw .certificateRejected }
        }
        let slope = try objective(direction, problem: problem, policy: policy, work: &work)
        guard slope.value < -(try LinearProgramArithmetic.threshold(policy.separationTolerance, scale: slope.scale)) else { throw .certificateRejected }
        let cost = try objective(point, problem: problem, policy: policy, work: &work)
        let base = try LinearProgramArithmetic.finite(problem.constantCost+cost.value)
        let physicalPoint = try physical(point, problem: problem, policy: policy, work: &work)
        let physicalDirection = try physical(direction, problem: problem, policy: policy, work: &work)
        let physicalSlope = try LinearProgramArithmetic.finite(slope.value*problem.metadata.objectiveReference.magnitude)
        return LinearUnboundedCertificate(feasiblePoint: point, physicalFeasiblePoint: physicalPoint, direction: direction,
            physicalDirection: physicalDirection, objectiveSlope: slope.value, physicalObjectiveSlope: physicalSlope,
            baseObjective: base, maximumNormalizedPrimalResidual: maximum)
    }
}
