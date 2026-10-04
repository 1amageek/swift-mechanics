import SwiftMechanics

enum OptimizationProbeContext {
    static func metadata(variables: Int, equality: Bool = false, inequality: Bool = false,
        scaled: Bool = false) throws -> OptimizationMetadata {
        var references: [SIReferenceQuantity<Double>] = []
        var ids: [UInt64] = []
        for i in 0..<variables {
            ids.append(UInt64(i + 1))
            references.append(try SIReferenceQuantity(magnitude: scaled ? (i == 0 ? 2 : 4) : 1, dimension: .length))
        }
        let row = try SIReferenceQuantity<Double>(magnitude: 1, dimension: .length)
        return try OptimizationMetadata(identity: "public-convex-oracle",
            provenance: SourceProvenance(source: "independent-analytic-probe", revision: 1), variableIDs: ids,
            variableReferences: references,
            objectiveReference: SIReferenceQuantity(magnitude: scaled ? 3 : 1, dimension: .energy),
            equalityReferences: equality ? [row] : [], inequalityReferences: inequality ? [row] : [])
    }

    static func row(_ values: [Double]) throws -> CSRMatrix<Double> {
        var indices: [Int] = []
        for i in values.indices { indices.append(i) }
        return try CSRMatrix(rows: 1, columns: values.count, rowOffsets: [0, values.count],
            columnIndices: indices, values: values)
    }

    static func policy(candidates: Int = 1000) throws -> OptimizationPolicy {
        try OptimizationPolicy(maximumVariables: 3, maximumRows: 16, maximumNonzeros: 16,
            maximumFactorEntries: 100, maximumCandidateBases: candidates, rankThreshold: 1e-12,
            certificateAbsolute: 1e-9, certificateRelative: 1e-10,
            luCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .partialPivotLU),
            curvatureCapability: LinearCapability(precision: .float64, backend: .referenceCPU, algorithm: .cholesky),
            linearTolerance: LinearTolerance(absoluteResidual: 1e-10, relativeResidual: 1e-10, pivotThreshold: 1e-14))
    }

    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100000,
            arithmeticOperations: 10000000, iterations: 100000))
    }
}
