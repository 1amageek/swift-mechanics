import SwiftMechanics

public enum LinearProgramsQualificationCases {
    private static func require(_ condition: Bool, _ name: String) throws {
        guard condition else { throw LinearProgramsQualificationError.rejectedWitness(name) }
    }
    private static func close(_ actual: Double, _ expected: Double, _ name: String) throws {
        try require(actual.isFinite && abs(actual - expected) <= 1e-9 * max(1, abs(expected)), name)
    }
    public static func policy(pivots: Int = 200, rows: Int = 32, entries: Int = 8192,
                              cancelled: @escaping @Sendable () -> Bool = { false }) throws -> LinearProgramPolicy {
        let tolerance = try NumericalTolerance(absolute: 1e-10, relative: 1e-10)
        return try LinearProgramPolicy(maximumVariables: 8, maximumRows: rows, maximumNonzeros: 128,
            maximumTableauEntries: entries, maximumPivots: pivots, pivotThreshold: 1e-12,
            reducedCostTolerance: tolerance, phaseOneTolerance: tolerance,
            certificateTolerance: tolerance, separationTolerance: tolerance, isCancelled: cancelled)
    }
    private static func numerical(storage: Int = 1_000_000, operations: Int = 10_000_000,
                                  iterations: Int = 1000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: iterations))
    }
    private static func matrix(_ rows: [[Double]], columns: Int) throws -> CSRMatrix<Double>? {
        if rows.isEmpty { return nil }
        var offsets = [0], indices: [Int] = [], values: [Double] = []
        for row in rows {
            try require(row.count == columns, "fixture dimensions")
            for column in row.indices where row[column] != 0 { indices.append(column); values.append(row[column]) }
            offsets.append(values.count)
        }
        return try CSRMatrix(rows: rows.count, columns: columns, rowOffsets: offsets, columnIndices: indices, values: values)
    }
    public static func problem(cost: [Double], constant: Double = 0, equalities: [[Double]] = [], rhs: [Double] = [],
                               inequalities: [[Double]] = [], limits: [Double] = [],
                               bounds: [LinearVariableBounds]? = nil, scales: [Double]? = nil) throws -> GeneralLinearProgram {
        let variableScales = scales ?? Array(repeating: 1, count: cost.count)
        let references = try variableScales.map { try SIReferenceQuantity<Double>(magnitude: $0, dimension: .length) }
        let rowReference = try SIReferenceQuantity<Double>(magnitude: 5, dimension: .length)
        let metadata = try OptimizationMetadata(identity: "independent-LP", provenance: SourceProvenance(source: "qualification-original", revision: 17),
            variableIDs: (0..<cost.count).map { UInt64($0 + 1) }, variableReferences: references,
            objectiveReference: SIReferenceQuantity(magnitude: 10, dimension: .energy),
            equalityReferences: Array(repeating: rowReference, count: equalities.count),
            inequalityReferences: Array(repeating: rowReference, count: inequalities.count))
        return try GeneralLinearProgram(metadata: metadata, linearCost: cost, constantCost: constant,
            equalities: matrix(equalities, columns: cost.count), equalityRightHandSide: rhs,
            inequalities: matrix(inequalities, columns: cost.count), inequalityRightHandSide: limits,
            bounds: bounds ?? Array(repeating: .unrestricted, count: cost.count))
    }
    private static func solve(_ problem: GeneralLinearProgram, with policy: LinearProgramPolicy? = nil) throws -> LinearProgramResult {
        let solver: any GeneralLinearProgramSolving = TwoPhaseLinearProgramSolver()
        var work = try numerical()
        let result = try solver.solve(problem, policy: policy ?? Self.policy(), work: &work)
        try require(result.problem.metadata.provenance == problem.metadata.provenance, "source retained")
        try require(result.numericalWork.operations == work.operations && work.operations > 0, "actual consumed work")
        try require(!result.uniquenessEstablished, "no invented uniqueness")
        return result
    }
    private static func originalRow(_ origin: LinearRowOrigin, problem: GeneralLinearProgram) throws -> ([Double], Double, Bool) {
        var row = [Double](repeating: 0, count: problem.linearCost.count)
        switch origin {
        case .equality(let index):
            guard let matrix = problem.equalities else { throw LinearProgramsQualificationError.rejectedWitness("missing equality") }
            for column in row.indices { row[column] = try matrix.coefficient(row: index, column: column) }
            return (row, problem.equalityRightHandSide[index], true)
        case .inequality(let index):
            guard let matrix = problem.inequalities else { throw LinearProgramsQualificationError.rejectedWitness("missing inequality") }
            for column in row.indices { row[column] = try matrix.coefficient(row: index, column: column) }
            return (row, problem.inequalityRightHandSide[index], false)
        case .lowerBound(let index):
            guard let lower = problem.bounds[index].lower else { throw LinearProgramsQualificationError.rejectedWitness("missing lower") }
            row[index] = -1; return (row, -lower, false)
        case .upperBound(let index):
            guard let upper = problem.bounds[index].upper else { throw LinearProgramsQualificationError.rejectedWitness("missing upper") }
            row[index] = 1; return (row, upper, false)
        }
    }
    private static func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
        var value = 0.0
        for index in lhs.indices { value += lhs[index] * rhs[index] }
        return value
    }
    private static func optimal(_ result: LinearProgramResult, point: [Double], objective: Double) throws {
        guard case .optimal(let certificate) = result.status else { throw LinearProgramsQualificationError.rejectedWitness("expected optimal") }
        let problem = result.problem
        try require(certificate.point.count == point.count, "point shape")
        for index in point.indices {
            try close(certificate.point[index], point[index], "analytic optimum")
            try close(certificate.physicalPoint[index], point[index] * problem.metadata.variableReferences[index].magnitude, "original SI point")
        }
        try close(certificate.objective, objective, "analytic objective including constant")
        try close(certificate.physicalObjective, objective * 10, "original SI objective")
        var stationarity = problem.linearCost, weightedRHS = 0.0
        var seen: [LinearRowOrigin] = []
        let expectedRows = (problem.equalities?.rowCount ?? 0) + (problem.inequalities?.rowCount ?? 0)
            + problem.bounds.reduce(0) { $0 + ($1.lower == nil ? 0 : 1) + ($1.upper == nil ? 0 : 1) }
        try require(certificate.multipliers.count == expectedRows, "all original rows retained")
        for multiplier in certificate.multipliers {
            try require(!seen.contains(multiplier.row), "unique original multiplier row"); seen.append(multiplier.row)
            let (row, rhs, equality) = try originalRow(multiplier.row, problem: problem)
            let residual = dot(row, certificate.point) - rhs
            if equality { try close(residual, 0, "original equality") }
            else {
                try require(residual <= 1e-9 && multiplier.normalized >= 0, "original inequality and dual sign")
                try close(multiplier.normalized * residual, 0, "original complementarity")
            }
            for column in stationarity.indices { stationarity[column] += row[column] * multiplier.normalized }
            weightedRHS += multiplier.normalized * rhs
            try close(multiplier.physicalValue, multiplier.normalized * 10 / multiplier.rowReference.magnitude, "physical dual scale")
        }
        for value in stationarity { try close(value, 0, "original stationarity") }
        try close(dot(problem.linearCost, certificate.point) + weightedRHS, 0, "independent dual gap")
    }
    public static func boundedAndPhysicalDuals() throws {
        let lower = try LinearVariableBounds(lower: 0, upper: nil)
        let input = try problem(cost: [-3, -2], constant: 7, inequalities: [[1, 1], [1, 0], [0, 1]],
            limits: [4, 2, 3], bounds: [lower, lower], scales: [2, 3])
        try optimal(solve(input), point: [2, 2], objective: -3)
    }
    public static func unrestrictedAndRedundantRows() throws {
        try optimal(solve(problem(cost: [1], constant: 5, equalities: [[1]], rhs: [-2], scales: [2])), point: [-2], objective: 3)
        try optimal(solve(problem(cost: [1], equalities: [[1], [2], [0]], rhs: [2, 4, 0])), point: [2], objective: 2)
        let fixed = try LinearVariableBounds(lower: 3, upper: 3)
        try optimal(solve(problem(cost: [-1], bounds: [fixed])), point: [3], objective: -3)
    }
    public static func farkasOriginalContradiction() throws {
        let input = try problem(cost: [0], inequalities: [[1], [-1]], limits: [0, -1])
        let result = try solve(input)
        guard case .infeasible(let certificate) = result.status else { throw LinearProgramsQualificationError.rejectedWitness("expected infeasible") }
        var normal = 0.0, rhs = 0.0
        try require(certificate.weights.count == 2, "contradiction original rows")
        for weight in certificate.weights {
            let (row, bound, equality) = try originalRow(weight.row, problem: input)
            try require(!equality && weight.normalized >= 0, "nonnegative Farkas weights")
            normal += row[0] * weight.normalized; rhs += bound * weight.normalized
        }
        try close(normal, 0, "unrestricted Farkas zero normal")
        try require(rhs < -1e-9 && certificate.strictSeparationMargin > 0, "strict original contradiction")
        try close(certificate.weightedRightHandSide, rhs, "original weighted RHS")
        try close(certificate.physicalSeparationMargin, -rhs * 10, "original physical contradiction")
        let contradiction = try LinearVariableBounds(lower: 2, upper: 1)
        guard case .infeasible = try solve(problem(cost: [1], bounds: [contradiction])).status else {
            throw LinearProgramsQualificationError.rejectedWitness("contradictory actual bounds")
        }
    }
    public static func equalityNullRecession() throws {
        let lower = try LinearVariableBounds(lower: 0, upper: nil)
        let input = try problem(cost: [-1, -1], constant: 3, equalities: [[1, -1]], rhs: [0],
            bounds: [lower, lower], scales: [2, 3])
        guard case .unbounded(let ray) = try solve(input).status else { throw LinearProgramsQualificationError.rejectedWitness("expected unbounded") }
        try require(ray.direction[0] >= 0 && ray.direction[1] >= 0, "true bound recession directions")
        try close(ray.direction[0] - ray.direction[1], 0, "exact equality-null ray")
        try require(dot(input.linearCost, ray.direction) < 0, "strict original descent")
        for travel in [0.0, 1.0, 1_000_000.0] {
            let x = ray.feasiblePoint[0] + travel * ray.direction[0]
            let y = ray.feasiblePoint[1] + travel * ray.direction[1]
            try close(x - y, 0, "arbitrarily distant feasible equality")
            try require(x >= 0 && y >= 0, "arbitrarily distant bound feasibility")
        }
        for index in ray.direction.indices { try close(ray.physicalDirection[index], ray.direction[index] * input.metadata.variableReferences[index].magnitude, "SI ray") }
        try close(ray.physicalObjectiveSlope, ray.objectiveSlope * 10, "SI recession slope")
        guard case .unbounded(let unrestricted) = try solve(problem(cost: [1])).status else {
            throw LinearProgramsQualificationError.rejectedWitness("zero-row unrestricted recession")
        }
        try require(unrestricted.direction[0] < 0, "unrestricted negative direction")
    }
    public static func degenerateBlandFixture() throws {
        let lower = try LinearVariableBounds(lower: 0, upper: nil)
        let input = try problem(cost: [-10, 57, 9, 24],
            inequalities: [[0.5, -5.5, -2.5, 9], [0.5, -1.5, -0.5, 1], [1, 0, 0, 0]],
            limits: [0, 0, 1], bounds: [lower, lower, lower, lower])
        let result = try solve(input)
        try optimal(result, point: [1, 0, 1, 0], objective: -1)
        try require(result.pivots > 0 && result.pivots <= 200, "bounded degenerate pivots")
    }
    public static func failureContracts() throws {
        let input = try problem(cost: [-1], bounds: [LinearVariableBounds(lower: 0, upper: 1)])
        let solver: any GeneralLinearProgramSolving = TwoPhaseLinearProgramSolver()
        func refused(_ policy: LinearProgramPolicy, work: inout NumericalWork,
                     accepts: (LinearProgramCause) -> Bool) throws {
            do {
                _ = try solver.solve(input, policy: policy, work: &work)
                throw LinearProgramsQualificationError.rejectedWitness("failure became success")
            } catch let error as LinearProgramFailure {
                try require(accepts(error.cause), "typed failure cause")
                try require(error.problemIdentity == input.metadata.identity && error.provenance == input.metadata.provenance, "failure provenance")
                try require(error.work.operations == work.operations, "failure consumed work")
            }
        }
        var work = try numerical()
        try refused(policy(rows: 0), work: &work) { if case .capacityExceeded = $0 { return true }; return false }
        work = try numerical()
        try refused(policy(pivots: 0), work: &work) { if case .pivotLimit = $0 { return true }; return false }
        try require(work.operations > 0, "pivot failure consumed work")
        work = try numerical(storage: 0)
        try refused(policy(), work: &work) { if case .numerical = $0 { return true }; return false }
        work = try numerical(operations: 0)
        try refused(policy(), work: &work) { if case .numerical = $0 { return true }; return false }
        work = try numerical()
        try refused(policy(cancelled: { true }), work: &work) { if case .cancelled = $0 { return true }; return false }
        let tiny = try problem(cost: [-1], inequalities: [[1e-15]], limits: [1])
        work = try numerical()
        do {
            _ = try solver.solve(tiny, policy: policy(), work: &work)
            throw LinearProgramsQualificationError.rejectedWitness("tiny pivot classified terminal")
        } catch let error as LinearProgramFailure {
            guard case .numericalAmbiguity = error.cause else { throw error }
        }
        let invalid = try problem(cost: [.infinity])
        work = try numerical()
        do {
            _ = try solver.solve(invalid, policy: policy(), work: &work)
            throw LinearProgramsQualificationError.rejectedWitness("nonfinite cost admitted")
        } catch let error as LinearProgramFailure {
            guard case .invalidProblem = error.cause else { throw error }
        }
    }
}
